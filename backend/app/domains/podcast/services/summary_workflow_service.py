"""Shared summary orchestration service for routes and background tasks."""

from __future__ import annotations

import logging
from collections.abc import Callable
from datetime import UTC, datetime, timedelta
from typing import Any

from sqlalchemy import and_, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import worker_db_session
from app.core.exceptions import ValidationError
from app.domains.podcast.models import (
    PodcastEpisode,
    PodcastEpisodeTranscript,
    TranscriptionTask,
)
from app.domains.podcast.repositories import PodcastSummaryRepository
from app.domains.podcast.services.summary_generation_service import (
    PodcastSummaryGenerationService,
)


logger = logging.getLogger(__name__)


class SummaryWorkflowService:
    """Coordinate summary operations for both HTTP routes and task handlers."""

    def __init__(
        self,
        db: AsyncSession,
        *,
        repo_factory: Callable[[AsyncSession], PodcastSummaryRepository] = (
            PodcastSummaryRepository
        ),
        summary_service_factory: Callable[
            [AsyncSession],
            PodcastSummaryGenerationService,
        ] = PodcastSummaryGenerationService,
    ):
        self.db = db
        self.repo_factory = repo_factory
        self.summary_service_factory = summary_service_factory
        self.repo = repo_factory(db)
        self.summary_service = summary_service_factory(db)

    async def generate_episode_summary(
        self,
        episode_id: int,
        summary_model: str | None = None,
        custom_prompt: str | None = None,
    ) -> dict[str, Any]:
        """Generate summary and return aligned response payload parts."""
        episode = await self.repo.get_episode_by_id(episode_id)
        if not episode:
            raise ValueError(f"Episode {episode_id} not found")

        summary_result = await self.summary_service.generate_summary(
            episode_id,
            summary_model,
            custom_prompt,
        )
        episode = await self.repo.get_episode_by_id(episode_id)
        final_summary = episode.ai_summary if episode and episode.ai_summary else ""
        final_version = episode.summary_version if episode else "1.0"
        return {
            "episode_id": episode_id,
            "summary": final_summary,
            "version": final_version or "1.0",
            "model_used": summary_result["model_name"],
            "processing_time": summary_result["processing_time"],
            "generated_at": datetime.now(UTC),
        }

    async def accept_episode_summary_generation(
        self,
        episode_id: int,
    ) -> dict[str, Any]:
        """Validate and mark one episode as queued for async summary generation."""
        episode = await self.repo.get_episode_by_id(episode_id)
        if not episode:
            raise ValueError(f"Episode {episode_id} not found")
        if not episode.transcript or not episode.transcript.transcript_content:
            raise ValidationError(
                f"No transcript content available for episode {episode_id}"
            )

        accepted_at = datetime.now(UTC)
        if episode.status == "summary_generating":
            return {
                "episode_id": episode_id,
                "summary_status": "summary_generating",
                "accepted_at": accepted_at,
                "already_queued": True,
            }

        await self.db.execute(
            update(PodcastEpisode)
            .where(PodcastEpisode.id == episode_id)
            .values(
                status="summary_generating",
                updated_at=accepted_at,
            ),
        )
        await self.db.execute(
            update(TranscriptionTask)
            .where(TranscriptionTask.episode_id == episode_id)
            .values(
                summary_error_message=None,
                updated_at=accepted_at,
            ),
        )
        await self.db.commit()
        return {
            "episode_id": episode_id,
            "summary_status": "summary_generating",
            "accepted_at": accepted_at,
            "already_queued": False,
        }

    async def execute_episode_summary_generation(
        self,
        episode_id: int,
        *,
        summary_model: str | None = None,
        custom_prompt: str | None = None,
    ) -> dict[str, Any]:
        """Run one episode summary generation inside a worker context."""
        try:
            result = await self.generate_episode_summary(
                episode_id,
                summary_model=summary_model,
                custom_prompt=custom_prompt,
            )
            logger.info(
                "Episode summary generation completed: episode_id=%s model=%s",
                episode_id,
                result.get("model_used"),
            )
            return result
        except Exception as exc:
            logger.exception(
                "Episode summary generation failed: episode_id=%s", episode_id
            )
            await self._mark_episode_summary_failed(episode_id, str(exc))
            raise

    async def list_pending_summaries_for_user(
        self,
        user_id: int,
    ) -> list[dict[str, Any]]:
        """Return pending summaries for one user."""
        return await self.repo.get_pending_summaries_for_user(user_id)

    async def get_summary_models(self) -> list[dict[str, Any]]:
        """List available summary models."""
        return await self.summary_service.get_summary_models()

    async def generate_pending_summaries_run(
        self,
        *,
        max_episodes_per_run: int = 10,
    ) -> dict[str, Any]:
        """Run the pending-summary batch flow shared by Celery handlers."""
        await self._reset_stale_summary_claims()
        claimed_episode_ids = await self._claim_pending_summary_episode_ids(
            limit=max_episodes_per_run,
        )
        processed_count = 0
        failed_count = 0
        skipped_count = 0

        if not claimed_episode_ids:
            return {
                "status": "success",
                "processed": 0,
                "failed": 0,
                "processed_at": datetime.now(UTC).isoformat(),
            }

        for episode_id in claimed_episode_ids:
            try:
                async with worker_db_session(
                    "celery-summary-episode"
                ) as episode_session:
                    summary_service = self.summary_service_factory(episode_session)
                    await summary_service.generate_summary(episode_id)
                processed_count += 1
            except ValidationError as exc:
                if self._is_skippable_validation_error(exc):
                    skipped_count += 1
                    logger.warning(
                        "Skipping summary for episode %s due to unmet generation precondition: %s",
                        episode_id,
                        exc,
                    )
                    await self._reset_claimed_summary_status(episode_id)
                    continue

                failed_count += 1
                logger.exception(
                    "Failed to generate summary for episode %s", episode_id
                )
                async with worker_db_session(
                    "celery-summary-episode"
                ) as episode_session:
                    repo = self.repo_factory(episode_session)
                    await repo.mark_summary_failed(episode_id, str(exc))
            except Exception as exc:
                failed_count += 1
                logger.exception(
                    "Failed to generate summary for episode %s", episode_id
                )
                async with worker_db_session(
                    "celery-summary-episode"
                ) as episode_session:
                    repo = self.repo_factory(episode_session)
                    await repo.mark_summary_failed(episode_id, str(exc))

        logger.info(
            "Pending summary run completed: processed=%s failed=%s skipped=%s claimed=%s",
            processed_count,
            failed_count,
            skipped_count,
            len(claimed_episode_ids),
        )

        return {
            "status": "success",
            "processed": processed_count,
            "failed": failed_count,
            "processed_at": datetime.now(UTC).isoformat(),
        }

    @staticmethod
    def _is_skippable_validation_error(exc: ValidationError) -> bool:
        message = str(exc)
        return (
            "No transcript content available for episode" in message
            or "Summary generation already in progress for episode" in message
        )

    async def _reset_stale_summary_claims(self) -> None:
        stale_before = datetime.now(UTC) - timedelta(hours=1)
        stmt = (
            update(PodcastEpisode)
            .where(
                and_(
                    PodcastEpisode.status == "summary_generating",
                    PodcastEpisode.ai_summary.is_(None),
                    PodcastEpisode.updated_at < stale_before,
                ),
            )
            .values(
                status="summary_failed",
                updated_at=datetime.now(UTC),
            )
        )
        await self.db.execute(stmt)
        await self.db.commit()

    async def _claim_pending_summary_episode_ids(self, *, limit: int) -> list[int]:
        claim_stmt = (
            select(PodcastEpisode.id)
            .outerjoin(
                TranscriptionTask, TranscriptionTask.episode_id == PodcastEpisode.id
            )
            .where(
                and_(
                    PodcastEpisode.ai_summary.is_(None),
                    PodcastEpisode.status.in_(["pending_summary", "summary_failed"]),
                    PodcastEpisode.transcript.has(
                        PodcastEpisodeTranscript.transcript_content.is_not(None),
                    ),
                    PodcastEpisode.transcript.has(
                        PodcastEpisodeTranscript.transcript_content != "",
                    ),
                    or_(
                        TranscriptionTask.id.is_(None),
                        ~TranscriptionTask.status.in_(["pending", "in_progress"]),
                    ),
                ),
            )
            .order_by(PodcastEpisode.published_at.desc(), PodcastEpisode.id.desc())
            .limit(limit)
            .with_for_update(skip_locked=True, of=PodcastEpisode)
        )
        result = await self.db.execute(claim_stmt)
        episode_ids = list(result.scalars().all())
        if not episode_ids:
            return []

        await self.db.execute(
            update(PodcastEpisode)
            .where(PodcastEpisode.id.in_(episode_ids))
            .values(
                status="summary_generating",
                updated_at=datetime.now(UTC),
            ),
        )
        await self.db.commit()
        return episode_ids

    async def _reset_claimed_summary_status(self, episode_id: int) -> None:
        await self.db.execute(
            update(PodcastEpisode)
            .where(PodcastEpisode.id == episode_id)
            .values(
                status="pending_summary",
                updated_at=datetime.now(UTC),
            ),
        )
        await self.db.commit()

    async def _mark_episode_summary_failed(self, episode_id: int, error: str) -> None:
        failed_at = datetime.now(UTC)
        await self.db.execute(
            update(PodcastEpisode)
            .where(PodcastEpisode.id == episode_id)
            .values(
                status="summary_failed",
                updated_at=failed_at,
            ),
        )
        await self.db.execute(
            update(TranscriptionTask)
            .where(TranscriptionTask.episode_id == episode_id)
            .values(
                summary_error_message=error,
                updated_at=failed_at,
            ),
        )
        await self.db.commit()
