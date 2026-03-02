"""Handlers for transcription Celery tasks."""

from __future__ import annotations

import logging
from datetime import datetime, timezone

from sqlalchemy import select

from app.core.redis import PodcastRedis
from app.domains.podcast.models import PodcastEpisode, TranscriptionTask
from app.domains.podcast.services.sync_service import PodcastSyncService
from app.domains.podcast.transcription_manager import DatabaseBackedTranscriptionService
from app.domains.podcast.transcription_state import get_transcription_state_manager


logger = logging.getLogger(__name__)


def _status_value(status: object) -> str:
    return status.value if hasattr(status, "value") else str(status)


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

    status_stmt = select(TranscriptionTask.status).where(
        TranscriptionTask.id == task_id
    )
    status_result = await session.execute(status_stmt)
    task_status_value = _status_value(status_result.scalar_one_or_none())
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
    dispatch_claimed = await _claim_dispatched(session, task_id)
    if not dispatch_claimed:
        return {
            "status": "skipped",
            "reason": "task_already_dispatched",
            "task_id": task_id,
        }

    state_manager = await get_transcription_state_manager()

    stmt = select(TranscriptionTask).where(TranscriptionTask.id == task_id)
    result = await session.execute(stmt)
    task = result.scalar_one_or_none()
    if task is None:
        await _clear_dispatched(task_id)
        return {"status": "error", "reason": "task_not_found", "task_id": task_id}

    episode_id = task.episode_id
    lock_acquired = await state_manager.acquire_task_lock(
        episode_id, task_id, expire_seconds=3600
    )
    if not lock_acquired:
        locked_task_id = await state_manager.is_episode_locked(episode_id)
        await _clear_dispatched(task_id)
        raise RuntimeError(
            f"Episode {episode_id} is locked by task {locked_task_id}, retry later"
        )

    service = DatabaseBackedTranscriptionService(session)
    original_update = service._update_task_progress_with_session

    async def redis_update_progress(
        db_session, internal_task_id, status, progress, message, error_message=None
    ):
        await original_update(
            db_session,
            internal_task_id,
            status,
            progress,
            message,
            error_message,
        )
        status_value = status.value if hasattr(status, "value") else str(status)
        await state_manager.set_task_progress(
            internal_task_id, status_value, progress, message
        )

    service._update_task_progress_with_session = redis_update_progress

    try:
        await state_manager.set_task_progress(
            task_id,
            "pending",
            0,
            "Worker starting transcription process...",
        )
        await service.execute_transcription_task(task_id, session, config_db_id)
        await state_manager.clear_task_state(task_id, episode_id)
        return {
            "status": "success",
            "task_id": task_id,
            "config_db_id": config_db_id,
            "processed_at": datetime.now(timezone.utc).isoformat(),
        }
    except Exception as exc:
        await state_manager.fail_task_state(task_id, episode_id, str(exc))
        logger.exception("Transcription task failed for task_id=%s", task_id)
        raise
    finally:
        await state_manager.release_task_lock(episode_id, task_id)
        await _clear_dispatched(task_id)


async def process_podcast_episode_with_transcription_handler(
    session,
    episode_id: int,
    user_id: int,
) -> dict:
    """Dispatch the transcription pipeline and return immediately."""
    stmt = select(PodcastEpisode).where(PodcastEpisode.id == episode_id)
    result = await session.execute(stmt)
    episode = result.scalar_one_or_none()
    if episode is None:
        return {
            "status": "error",
            "message": "Episode not found",
            "episode_id": episode_id,
        }

    sync_service = PodcastSyncService(session, user_id)
    transcription_task = await sync_service.trigger_transcription(episode_id)
    if not transcription_task:
        raise RuntimeError(
            f"Failed to trigger transcription for episode={episode_id}, user={user_id}"
        )

    return {
        "status": "queued",
        "episode_id": episode_id,
        "transcription_task_id": transcription_task["task_id"],
        "processed_at": datetime.now(timezone.utc).isoformat(),
    }
