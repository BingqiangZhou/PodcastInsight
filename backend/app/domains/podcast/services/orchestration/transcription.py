"""Transcription orchestrator -- transcription task dispatch and execution."""

from __future__ import annotations

import logging
from typing import Any

from sqlalchemy import and_, exists, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.cache_ttl import CacheTTL
from app.core.config import settings
from app.domains.podcast.models import (
    PodcastEpisode,
    PodcastEpisodeTranscript,
    TranscriptionTask,
)
from app.domains.podcast.services.transcription_workflow_service import (
    TranscriptionWorkflowService,
)
from app.domains.podcast.transcription_state import get_transcription_state_manager
from app.domains.podcast.utils.status_helpers import status_value

from .base import BaseOrchestrator


logger = logging.getLogger(__name__)


class TranscriptionOrchestrator(BaseOrchestrator):
    """Orchestrate transcription task dispatch and execution."""

    async def process_audio_transcription_task(
        self,
        *,
        task_id: int,
        config_db_id: int | None = None,
    ) -> dict:
        workflow = self.build_transcription_workflow()
        return await workflow.execute_transcription_task(
            task_id,
            config_db_id=config_db_id,
        )

    async def trigger_episode_transcription_pipeline(
        self,
        *,
        episode_id: int,
        user_id: int,
    ) -> dict:
        workflow = self.build_transcription_workflow()
        return await workflow.trigger_episode_pipeline(
            episode_id,
            user_id=user_id,
            episode_lookup=self.lookup_episode,
        )

    def build_transcription_workflow(self) -> TranscriptionWorkflowService:
        """Build a TranscriptionWorkflowService wired with claim/clear helpers."""
        return TranscriptionWorkflowService(
            self.session,
            state_manager_factory=get_transcription_state_manager,
            redis_factory=lambda: self.redis,
            claim_dispatched=self._claim_dispatched,
            clear_dispatched=self._clear_dispatched,
        )

    async def _clear_dispatched(self, task_id: int) -> None:
        key = f"podcast:transcription:dispatched:{task_id}"
        await self.redis.delete_keys(key)

    async def _claim_dispatched(self, session: AsyncSession, task_id: int) -> bool:
        key = f"podcast:transcription:dispatched:{task_id}"
        if await self.redis.set_if_not_exists(key, "1", ttl=CacheTTL.hours(2)):
            return True

        status_stmt = select(TranscriptionTask.status).where(
            TranscriptionTask.id == task_id,
        )
        status_result = await session.execute(status_stmt)
        status_obj = status_result.scalar_one_or_none()
        task_status_value = status_value(status_obj)
        if task_status_value in {"completed", "failed", "cancelled"}:
            return False
        raise RuntimeError(
            f"Task {task_id} dispatch key exists while task status={task_status_value}",
        )

    async def process_pending_transcriptions(self) -> dict:
        if not settings.TRANSCRIPTION_BACKLOG_ENABLED:
            return {
                "status": "skipped",
                "reason": "backlog_transcription_disabled",
                "processed_at": self._now_iso(),
            }

        from app.domains.subscription.models import (
            Subscription,
            SubscriptionStatus,
            UserSubscription,
        )

        active_user_subscription_exists = exists(
            select(1).where(
                and_(
                    UserSubscription.subscription_id == Subscription.id,
                    UserSubscription.is_archived.is_(False),
                ),
            ),
        )
        filters = [
            Subscription.source_type == "podcast-rss",
            Subscription.status == SubscriptionStatus.ACTIVE.value,
            active_user_subscription_exists,
            PodcastEpisode.audio_url.is_not(None),
            PodcastEpisode.audio_url != "",
            or_(
                ~PodcastEpisode.transcript.has(
                    PodcastEpisodeTranscript.transcript_content.is_not(None),
                ),
                PodcastEpisode.transcript.has(
                    PodcastEpisodeTranscript.transcript_content == "",
                ),
            ),
            or_(
                TranscriptionTask.id.is_(None),
                TranscriptionTask.status.in_(["failed", "cancelled"]),
            ),
        ]

        batch_size = max(1, settings.TRANSCRIPTION_BACKLOG_BATCH_SIZE)
        id_stmt = (
            select(PodcastEpisode.id, PodcastEpisode.published_at)
            .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
            .outerjoin(
                TranscriptionTask,
                TranscriptionTask.episode_id == PodcastEpisode.id,
            )
            .where(and_(*filters))
            .order_by(PodcastEpisode.published_at.desc(), PodcastEpisode.id.desc())
            .limit(batch_size)
            .with_for_update(skip_locked=True, of=PodcastEpisode)
        )
        rows = await self.session.execute(id_stmt)
        episode_ids = [row[0] for row in rows.all()]
        total_candidates = len(episode_ids)
        if not episode_ids:
            return {
                "status": "success",
                "total_candidates": 0,
                "checked": 0,
                "dispatched": 0,
                "skipped": 0,
                "failed": 0,
                "skipped_reasons": {},
                "processed_at": self._now_iso(),
            }

        workflow = TranscriptionWorkflowService(self.session)
        dispatch_result = await workflow.dispatch_pending_transcriptions(episode_ids)
        logger.info(
            "Backlog transcription run completed: total_candidates=%s checked=%s dispatched=%s skipped=%s failed=%s skipped_reasons=%s",
            total_candidates,
            dispatch_result["checked"],
            dispatch_result["dispatched"],
            dispatch_result["skipped"],
            dispatch_result["failed"],
            dispatch_result["skipped_reasons"],
        )
        return {
            "status": "success",
            "total_candidates": total_candidates,
            **dispatch_result,
            "processed_at": self._now_iso(),
        }

    @staticmethod
    def _now_iso() -> str:
        from datetime import UTC, datetime

        return datetime.now(UTC).isoformat()

    # -- Celery task enqueue helpers --

    def enqueue_audio_transcription(
        self,
        task_id: int,
        config_db_id: int | None = None,
    ) -> Any:
        """Queue a transcription worker task without exposing Celery imports."""
        from app.domains.podcast.tasks.tasks_transcription import (
            process_audio_transcription,
        )

        return process_audio_transcription.delay(task_id, config_db_id)

    def enqueue_episode_processing(
        self,
        *,
        episode_id: int,
        user_id: int,
    ) -> Any:
        """Queue the episode transcription/summary pipeline."""
        from app.domains.podcast.tasks.tasks_transcription import (
            process_podcast_episode_with_transcription,
        )

        return process_podcast_episode_with_transcription.delay(episode_id, user_id)
