"""Celery tasks and handlers for transcription flows.

Merged from: transcription.py, pending_transcription.py,
handlers_transcription.py, handlers_pending_transcription.py
"""

from datetime import UTC, datetime

from app.core.celery_app import celery_app
from app.domains.podcast.services.task_orchestration_service import (
    PodcastTaskOrchestrationService,
)
from app.domains.podcast.tasks.runtime import (
    log_task_run,
    run_async,
    single_instance_task_lock,
    worker_session,
)


# ---------------------------------------------------------------------------
# Handlers (formerly handlers_transcription.py + handlers_pending_transcription.py)
# ---------------------------------------------------------------------------


async def process_audio_transcription_handler(
    session,
    task_id: int,
    config_db_id: int | None = None,
) -> dict:
    """Execute transcription with lock + redis state updates."""
    return await PodcastTaskOrchestrationService(
        session,
    ).process_audio_transcription_task(
        task_id=task_id,
        config_db_id=config_db_id,
    )


async def process_podcast_episode_with_transcription_handler(
    session,
    episode_id: int,
    user_id: int,
) -> dict:
    """Dispatch the transcription pipeline and return immediately."""
    return await PodcastTaskOrchestrationService(
        session,
    ).trigger_episode_transcription_pipeline(
        episode_id=episode_id,
        user_id=user_id,
    )


async def process_pending_transcriptions_handler(session) -> dict:
    """Dispatch periodic backlog transcription tasks."""
    async with single_instance_task_lock(
        "task:process_pending_transcriptions",
        ttl_seconds=1800,
    ) as acquired:
        if not acquired:
            return {
                "status": "skipped_locked",
                "reason": "pending_transcription_task_already_running",
            }
        return await PodcastTaskOrchestrationService(
            session,
        ).process_pending_transcriptions()


# ---------------------------------------------------------------------------
# Tasks (formerly transcription.py + pending_transcription.py)
# ---------------------------------------------------------------------------


@celery_app.task(bind=True, max_retries=3)
def process_audio_transcription(self, task_id: int, config_db_id: int | None = None):
    started_at = datetime.now(UTC)
    task_name = "app.domains.podcast.tasks.tasks_transcription.process_audio_transcription"
    queue_name = "transcription"
    try:
        result = run_async(
            _process_audio_transcription_async(task_id=task_id, config_db_id=config_db_id),
        )
        log_task_run(
            task_name=task_name,
            queue_name=queue_name,
            status="success",
            started_at=started_at,
            finished_at=datetime.now(UTC),
            metadata={"task_id": task_id, "config_db_id": config_db_id},
        )
        return result
    except Exception as exc:
        log_task_run(
            task_name=task_name,
            queue_name=queue_name,
            status="failed",
            started_at=started_at,
            finished_at=datetime.now(UTC),
            error_message=str(exc),
            metadata={"task_id": task_id, "config_db_id": config_db_id},
        )
        if self.request.retries < self.max_retries:
            raise self.retry(countdown=60 * (2**self.request.retries)) from exc
        raise


async def _process_audio_transcription_async(task_id: int, config_db_id: int | None):
    async with worker_session("celery-transcription-worker") as session:
        return await process_audio_transcription_handler(
            session=session,
            task_id=task_id,
            config_db_id=config_db_id,
        )


@celery_app.task(bind=True, max_retries=3)
def process_podcast_episode_with_transcription(self, episode_id: int, user_id: int):
    started_at = datetime.now(UTC)
    task_name = (
        "app.domains.podcast.tasks.tasks_transcription.process_podcast_episode_with_transcription"
    )
    queue_name = "transcription"
    try:
        result = run_async(
            _process_episode_with_transcription_async(episode_id=episode_id, user_id=user_id),
        )
        log_task_run(
            task_name=task_name,
            queue_name=queue_name,
            status="success",
            started_at=started_at,
            finished_at=datetime.now(UTC),
            metadata={"episode_id": episode_id, "user_id": user_id},
        )
        return result
    except Exception as exc:
        log_task_run(
            task_name=task_name,
            queue_name=queue_name,
            status="failed",
            started_at=started_at,
            finished_at=datetime.now(UTC),
            error_message=str(exc),
            metadata={"episode_id": episode_id, "user_id": user_id},
        )
        if self.request.retries < self.max_retries:
            raise self.retry(countdown=60 * (2**self.request.retries)) from exc
        raise


async def _process_episode_with_transcription_async(episode_id: int, user_id: int):
    async with worker_session("celery-episode-processor") as session:
        return await process_podcast_episode_with_transcription_handler(
            session=session,
            episode_id=episode_id,
            user_id=user_id,
        )


@celery_app.task(bind=True, max_retries=3)
def process_pending_transcriptions(self):
    started_at = datetime.now(UTC)
    task_name = "app.domains.podcast.tasks.tasks_transcription.process_pending_transcriptions"
    queue_name = "transcription"
    metadata = None
    try:
        result = run_async(_process_pending_transcriptions_async())
        if isinstance(result, dict):
            metadata = result
        log_task_run(
            task_name=task_name,
            queue_name=queue_name,
            status="success",
            started_at=started_at,
            finished_at=datetime.now(UTC),
            metadata=metadata,
        )
        return result
    except Exception as exc:
        log_task_run(
            task_name=task_name,
            queue_name=queue_name,
            status="failed",
            started_at=started_at,
            finished_at=datetime.now(UTC),
            error_message=str(exc),
            metadata=metadata,
        )
        if self.request.retries < self.max_retries:
            raise self.retry(countdown=60 * (2**self.request.retries)) from exc
        raise


async def _process_pending_transcriptions_async():
    async with worker_session("celery-transcription-backlog-worker") as session:
        return await process_pending_transcriptions_handler(session)
