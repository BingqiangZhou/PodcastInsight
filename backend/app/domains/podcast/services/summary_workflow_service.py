"""Shared summary orchestration service for routes and background tasks."""

from __future__ import annotations

import logging
from collections.abc import Callable
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ValidationError
from app.domains.podcast.models import TranscriptionTask
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
            [AsyncSession], PodcastSummaryGenerationService
        ] = PodcastSummaryGenerationService,
    ):
        self.db = db
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
        pending_fetch_window = max_episodes_per_run * 5
        pending_episodes = await self.repo.get_unsummarized_episodes(
            limit=pending_fetch_window
        )
        if len(pending_episodes) > max_episodes_per_run:
            logger.info(
                "Found %s pending summaries, attempting up to %s eligible episodes this run",
                len(pending_episodes),
                max_episodes_per_run,
            )

        processed_count = 0
        failed_count = 0
        skipped_running_count = 0
        skipped_no_transcript_count = 0
        eligible_attempt_count = 0

        episodes_with_transcript = [
            episode
            for episode in pending_episodes
            if (episode.transcript_content or "").strip()
        ]
        skipped_no_transcript_count = len(pending_episodes) - len(episodes_with_transcript)

        if not episodes_with_transcript:
            return {
                "status": "success",
                "processed": 0,
                "failed": 0,
                "processed_at": datetime.now(UTC).isoformat(),
            }

        candidate_episode_ids = [episode.id for episode in episodes_with_transcript]
        running_stmt = select(TranscriptionTask.episode_id).where(
            TranscriptionTask.episode_id.in_(candidate_episode_ids),
            TranscriptionTask.status.in_(["pending", "in_progress"]),
        )
        running_result = await self.db.execute(running_stmt)
        running_episode_ids = set(running_result.scalars().all())

        for episode in episodes_with_transcript:
            if eligible_attempt_count >= max_episodes_per_run:
                break
            try:
                if episode.id in running_episode_ids:
                    skipped_running_count += 1
                    continue

                eligible_attempt_count += 1
                await self.summary_service.generate_summary(episode.id)
                processed_count += 1
            except ValidationError as exc:
                if self._is_skippable_validation_error(exc):
                    skipped_no_transcript_count += 1
                    logger.warning(
                        "Skipping summary for episode %s due to unmet generation precondition: %s",
                        episode.id,
                        exc,
                    )
                    continue

                failed_count += 1
                logger.exception("Failed to generate summary for episode %s", episode.id)
                await self.repo.mark_summary_failed(episode.id, str(exc))
            except Exception as exc:
                failed_count += 1
                logger.exception("Failed to generate summary for episode %s", episode.id)
                await self.repo.mark_summary_failed(episode.id, str(exc))

        logger.info(
            "Pending summary run completed: processed=%s failed=%s skipped_no_transcript=%s skipped_running=%s attempted=%s total_pending=%s",
            processed_count,
            failed_count,
            skipped_no_transcript_count,
            skipped_running_count,
            eligible_attempt_count,
            len(pending_episodes),
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
