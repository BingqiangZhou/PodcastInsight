"""Celery tasks and handlers for maintenance, housekeeping, and OPML import.

Merged from: maintenance.py, opml_import.py,
handlers_maintenance.py, handlers_opml_import.py
"""

from datetime import UTC, datetime

from app.core.celery_app import celery_app
from app.domains.podcast.services.task_orchestration_service import (
    PodcastTaskOrchestrationService,
)
from app.domains.podcast.tasks.runtime import log_task_run, run_async, worker_session


# ---------------------------------------------------------------------------
# Handlers (formerly handlers_maintenance.py + handlers_opml_import.py)
# ---------------------------------------------------------------------------


async def log_periodic_task_statistics_handler(session) -> dict:
    """Log current task statistics and return snapshot."""
    return await PodcastTaskOrchestrationService(session).log_periodic_task_statistics()


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
    """Parse and upsert episodes for one OPML subscription in background.

    Important status rule:
    - This handler must not mutate existing ``podcast_episodes.status``.
    - New rows are initialized to ``pending_summary`` by repository layer.
    """
    return await PodcastTaskOrchestrationService(
        session,
    ).process_opml_subscription_episodes(
        subscription_id=subscription_id,
        user_id=user_id,
        source_url=source_url,
    )


# ---------------------------------------------------------------------------
# Tasks (formerly maintenance.py + opml_import.py)
# ---------------------------------------------------------------------------


@celery_app.task
def cleanup_old_playback_states():
    started_at = datetime.now(UTC)
    task_name = "app.domains.podcast.tasks.tasks_maintenance.cleanup_old_playback_states"
    queue_name = "default"
    try:
        result = run_async(_cleanup_old_playback_states_async())
        log_task_run(
            task_name=task_name,
            queue_name=queue_name,
            status="success",
            started_at=started_at,
            finished_at=datetime.now(UTC),
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
        )
        raise


async def _cleanup_old_playback_states_async():
    async with worker_session("celery-playback-cleanup-worker") as session:
        return await cleanup_old_playback_states_handler(session)


@celery_app.task
def cleanup_old_transcription_temp_files(days: int = 7):
    started_at = datetime.now(UTC)
    task_name = (
        "app.domains.podcast.tasks.tasks_maintenance.cleanup_old_transcription_temp_files"
    )
    queue_name = "default"
    try:
        result = run_async(_cleanup_old_transcription_temp_files_async(days=days))
        log_task_run(
            task_name=task_name,
            queue_name=queue_name,
            status="success",
            started_at=started_at,
            finished_at=datetime.now(UTC),
            metadata={"days": days},
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
            metadata={"days": days},
        )
        raise


async def _cleanup_old_transcription_temp_files_async(days: int):
    async with worker_session("celery-temp-cleanup-worker") as session:
        return await cleanup_old_transcription_temp_files_handler(session, days=days)


@celery_app.task
def log_periodic_task_statistics():
    started_at = datetime.now(UTC)
    task_name = "app.domains.podcast.tasks.tasks_maintenance.log_periodic_task_statistics"
    queue_name = "default"
    try:
        result = run_async(_log_periodic_task_statistics_async())
        log_task_run(
            task_name=task_name,
            queue_name=queue_name,
            status="success",
            started_at=started_at,
            finished_at=datetime.now(UTC),
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
        )
        raise


async def _log_periodic_task_statistics_async():
    async with worker_session("celery-task-stats-worker") as session:
        return await log_periodic_task_statistics_handler(session)


@celery_app.task
def auto_cleanup_cache_files():
    started_at = datetime.now(UTC)
    task_name = "app.domains.podcast.tasks.tasks_maintenance.auto_cleanup_cache_files"
    queue_name = "default"
    try:
        result = run_async(_auto_cleanup_cache_files_async())
        log_task_run(
            task_name=task_name,
            queue_name=queue_name,
            status="success",
            started_at=started_at,
            finished_at=datetime.now(UTC),
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
        )
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
    started_at = datetime.now(UTC)
    task_name = (
        "app.domains.podcast.tasks.tasks_maintenance.process_opml_subscription_episodes"
    )
    queue_name = "default"
    try:
        result = run_async(
            _process_opml_subscription_episodes_async(
                subscription_id=subscription_id,
                user_id=user_id,
                source_url=source_url,
            ),
        )
        log_task_run(
            task_name=task_name,
            queue_name=queue_name,
            status="success",
            started_at=started_at,
            finished_at=datetime.now(UTC),
            metadata={
                "subscription_id": subscription_id,
                "user_id": user_id,
                "source_url": source_url,
            },
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
            metadata={
                "subscription_id": subscription_id,
                "user_id": user_id,
                "source_url": source_url,
            },
        )
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
