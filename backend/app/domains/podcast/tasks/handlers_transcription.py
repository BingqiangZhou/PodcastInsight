"""Handlers for transcription Celery tasks."""

from __future__ import annotations

import logging

from sqlalchemy import select

from app.core.redis import PodcastRedis
from app.domains.podcast.models import PodcastEpisode, TranscriptionTask
from app.domains.podcast.services.sync_service import PodcastSyncService
from app.domains.podcast.services.transcription_workflow_service import (
    TranscriptionWorkflowService,
)
from app.domains.podcast.transcription_manager import DatabaseBackedTranscriptionService
from app.domains.podcast.transcription_state import get_transcription_state_manager


logger = logging.getLogger(__name__)


async def _clear_dispatched(task_id: int) -> None:
    redis = PodcastRedis()
    key = f"podcast:transcription:dispatched:{task_id}"
    client = await redis._get_client()
    await client.delete(key)


async def _claim_dispatched(session, task_id: int) -> bool:
    redis = PodcastRedis()
    key = f"podcast:transcription:dispatched:{task_id}"
    client = await redis._get_client()
    result = await client.set(key, "1", nx=True, ex=7200)
    if result is not None:
        return True

    status_stmt = select(TranscriptionTask.status).where(TranscriptionTask.id == task_id)
    status_result = await session.execute(status_stmt)
    status_obj = status_result.scalar_one_or_none()
    task_status_value = status_obj.value if hasattr(status_obj, "value") else str(status_obj)
    if task_status_value in {"completed", "failed", "cancelled"}:
        return False
    raise RuntimeError(
        f"Task {task_id} dispatch key exists while task status={task_status_value}"
    )


async def process_audio_transcription_handler(
    session,
    task_id: int,
    config_db_id: int | None = None,
) -> dict:
    """Execute transcription with lock + redis state updates."""
    workflow = TranscriptionWorkflowService(
        session,
        transcription_service_factory=DatabaseBackedTranscriptionService,
        sync_service_factory=PodcastSyncService,
        state_manager_factory=get_transcription_state_manager,
        claim_dispatched=_claim_dispatched,
        clear_dispatched=_clear_dispatched,
    )
    return await workflow.execute_transcription_task(
        task_id,
        config_db_id=config_db_id,
    )


async def process_podcast_episode_with_transcription_handler(
    session,
    episode_id: int,
    user_id: int,
) -> dict:
    """Dispatch the transcription pipeline and return immediately."""
    workflow = TranscriptionWorkflowService(
        session,
        transcription_service_factory=DatabaseBackedTranscriptionService,
        sync_service_factory=PodcastSyncService,
        state_manager_factory=get_transcription_state_manager,
        claim_dispatched=_claim_dispatched,
        clear_dispatched=_clear_dispatched,
    )
    return await workflow.trigger_episode_pipeline(
        episode_id,
        user_id=user_id,
        episode_lookup=lambda target_episode_id: _lookup_episode(session, target_episode_id),
    )


async def _lookup_episode(session, episode_id: int) -> PodcastEpisode | None:
    stmt = select(PodcastEpisode).where(PodcastEpisode.id == episode_id)
    result = await session.execute(stmt)
    return result.scalar_one_or_none()
