"""Celery tasks for maintenance, housekeeping, and OPML import."""

from app.core.celery_app import celery_app
from app.domains.podcast.tasks.task_orchestration import (
    PodcastTaskOrchestrationService,
)
from app.domains.podcast.tasks.runtime import (
    run_async,
    worker_session,
)


async def cleanup_old_playback_states_handler(session) -> dict:
    """Delete playback states older than 90 days."""
    return await PodcastTaskOrchestrationService(session).cleanup_old_playback_states()


async def cleanup_old_transcription_temp_files_handler(session, days: int = 7) -> dict:
    """Clean stale transcription temporary files."""
    return await PodcastTaskOrchestrationService(
        session,
    ).cleanup_old_transcription_temp_files(days=days)


async def auto_cleanup_cache_files_handler(session) -> dict:
    """Execute cache cleanup when enabled by admin settings."""
    return await PodcastTaskOrchestrationService(session).auto_cleanup_cache_files()


async def process_opml_subscription_episodes_handler(
    session,
    *,
    subscription_id: int,
    user_id: int,
    source_url: str,
) -> dict:
    """Parse and upsert episodes for one OPML subscription in background."""
    return await PodcastTaskOrchestrationService(
        session,
    ).process_opml_subscription_episodes(
        subscription_id=subscription_id,
        user_id=user_id,
        source_url=source_url,
    )


@celery_app.task(bind=True, max_retries=2)
def cleanup_old_playback_states(self):
    try:
        return run_async(_cleanup_old_playback_states_async())
    except Exception:
        raise


async def _cleanup_old_playback_states_async():
    async with worker_session("celery-playback-cleanup-worker") as session:
        return await cleanup_old_playback_states_handler(session)


@celery_app.task(bind=True, max_retries=2)
def cleanup_old_transcription_temp_files(self, days: int = 7):
    try:
        return run_async(_cleanup_old_transcription_temp_files_async(days=days))
    except Exception:
        raise


async def _cleanup_old_transcription_temp_files_async(days: int):
    async with worker_session("celery-temp-cleanup-worker") as session:
        return await cleanup_old_transcription_temp_files_handler(session, days=days)


@celery_app.task
def auto_cleanup_cache_files():
    try:
        return run_async(_auto_cleanup_cache_files_async())
    except Exception:
        raise


async def _auto_cleanup_cache_files_async():
    async with worker_session("celery-auto-cleanup-worker") as session:
        return await auto_cleanup_cache_files_handler(session)


@celery_app.task(bind=True, max_retries=3)
def process_opml_subscription_episodes(
    self,
    subscription_id: int,
    user_id: int,
    source_url: str,
):
    try:
        return run_async(
            _process_opml_subscription_episodes_async(
                subscription_id=subscription_id,
                user_id=user_id,
                source_url=source_url,
            ),
        )
    except Exception as exc:
        if self.request.retries < self.max_retries:
            raise self.retry(countdown=60 * (2**self.request.retries)) from exc
        raise


async def _process_opml_subscription_episodes_async(
    subscription_id: int,
    user_id: int,
    source_url: str,
):
    async with worker_session("celery-opml-import-worker") as session:
        return await process_opml_subscription_episodes_handler(
            session=session,
            subscription_id=subscription_id,
            user_id=user_id,
            source_url=source_url,
        )
