"""Celery tasks for transcription flows."""

from datetime import UTC, datetime

from app.core.celery_app import celery_app
from app.domains.podcast.tasks.handlers_transcription import (
    process_audio_transcription_handler,
    process_podcast_episode_with_transcription_handler,
)
from app.domains.podcast.tasks.runtime import log_task_run, run_async, worker_session


@celery_app.task(bind=True, max_retries=3)
def process_audio_transcription(self, task_id: int, config_db_id: int | None = None):
    started_at = datetime.now(UTC)
    task_name = "app.domains.podcast.tasks.transcription.process_audio_transcription"
    queue_name = "transcription"
    try:
        result = run_async(
            _process_audio_transcription(task_id=task_id, config_db_id=config_db_id)
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
            raise self.retry(countdown=60 * (2 ** self.request.retries)) from exc
        raise


async def _process_audio_transcription(task_id: int, config_db_id: int | None):
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
        "app.domains.podcast.tasks.transcription.process_podcast_episode_with_transcription"
    )
    queue_name = "transcription"
    try:
        result = run_async(
            _process_episode_with_transcription(episode_id=episode_id, user_id=user_id)
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
            raise self.retry(countdown=60 * (2 ** self.request.retries)) from exc
        raise


async def _process_episode_with_transcription(episode_id: int, user_id: int):
    async with worker_session("celery-episode-processor") as session:
        return await process_podcast_episode_with_transcription_handler(
            session=session,
            episode_id=episode_id,
            user_id=user_id,
        )
