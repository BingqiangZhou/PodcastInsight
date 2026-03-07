"""Task orchestration helpers for transcription flows."""

from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.redis import PodcastRedis
from app.domains.podcast.models import PodcastEpisode, TranscriptionTask
from app.domains.podcast.services.sync_service import PodcastSyncService
from app.domains.podcast.services.transcription_workflow_service import (
    TranscriptionWorkflowService,
)
from app.domains.podcast.transcription_state import get_transcription_state_manager


class PodcastTaskTranscriptionOrchestrationService:
    """Handle task-side transcription orchestration and dispatch guards."""

    def __init__(self, session: AsyncSession):
        self.session = session

    async def process_audio_transcription_task(
        self,
        *,
        task_id: int,
        config_db_id: int | None = None,
    ) -> dict:
        workflow = self._build_transcription_workflow()
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
        workflow = self._build_transcription_workflow()
        return await workflow.trigger_episode_pipeline(
            episode_id,
            user_id=user_id,
            episode_lookup=self._lookup_episode,
        )

    def _build_transcription_workflow(self) -> TranscriptionWorkflowService:
        return TranscriptionWorkflowService(
            self.session,
            sync_service_factory=PodcastSyncService,
            state_manager_factory=get_transcription_state_manager,
            claim_dispatched=self._claim_dispatched,
            clear_dispatched=self._clear_dispatched,
        )

    async def _clear_dispatched(self, task_id: int) -> None:
        redis = PodcastRedis()
        key = f"podcast:transcription:dispatched:{task_id}"
        client = await redis._get_client()
        await client.delete(key)

    async def _claim_dispatched(self, task_id: int) -> bool:
        redis = PodcastRedis()
        key = f"podcast:transcription:dispatched:{task_id}"
        client = await redis._get_client()
        result = await client.set(key, "1", nx=True, ex=7200)
        if result is not None:
            return True

        status_stmt = select(TranscriptionTask.status).where(
            TranscriptionTask.id == task_id
        )
        status_result = await self.session.execute(status_stmt)
        status_obj = status_result.scalar_one_or_none()
        task_status_value = (
            status_obj.value if hasattr(status_obj, "value") else str(status_obj)
        )
        if task_status_value in {"completed", "failed", "cancelled"}:
            return False
        raise RuntimeError(
            f"Task {task_id} dispatch key exists while task status={task_status_value}"
        )

    async def _lookup_episode(self, episode_id: int) -> PodcastEpisode | None:
        stmt = select(PodcastEpisode).where(PodcastEpisode.id == episode_id)
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()
