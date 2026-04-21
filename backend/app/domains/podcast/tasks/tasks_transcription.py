"""Celery tasks for transcription flows."""

from celery.exceptions import SoftTimeLimitExceeded

from app.core.celery_app import celery_app
from app.domains.podcast.tasks.runtime import (
    run_async,
    worker_session,
)
from app.domains.podcast.tasks.task_orchestration import (
    PodcastTaskOrchestrationService,
)


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
    return await PodcastTaskOrchestrationService(
        session,
    ).process_pending_transcriptions()


@celery_app.task(
    bind=True, max_retries=3, soft_time_limit=25 * 60, time_limit=28 * 60
)
def process_audio_transcription(self, task_id: int, config_db_id: int | None = None):
    try:
        return run_async(
            _process_audio_transcription_async(
                task_id=task_id, config_db_id=config_db_id
            ),
        )
    except SoftTimeLimitExceeded:
        raise
    except Exception as exc:
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
    try:
        return run_async(
            _process_episode_with_transcription_async(
                episode_id=episode_id, user_id=user_id
            ),
        )
    except SoftTimeLimitExceeded:
        raise
    except Exception as exc:
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
    try:
        return run_async(_process_pending_transcriptions_async())
    except SoftTimeLimitExceeded:
        raise
    except Exception as exc:
        if self.request.retries < self.max_retries:
            raise self.retry(countdown=60 * (2**self.request.retries)) from exc
        raise


async def _process_pending_transcriptions_async():
    async with worker_session("celery-transcription-backlog-worker") as session:
        return await process_pending_transcriptions_handler(session)
