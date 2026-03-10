"""Celery tasks for maintenance and housekeeping."""

from datetime import UTC, datetime

from app.core.celery_app import celery_app
from app.domains.podcast.tasks.handlers_maintenance import (
    auto_cleanup_cache_files_handler,
    cleanup_old_playback_states_handler,
    cleanup_old_transcription_temp_files_handler,
    log_periodic_task_statistics_handler,
)
from app.domains.podcast.tasks.runtime import log_task_run, run_async, worker_session


@celery_app.task
def cleanup_old_playback_states():
    started_at = datetime.now(UTC)
    task_name = "app.domains.podcast.tasks.maintenance.cleanup_old_playback_states"
    queue_name = "maintenance"
    try:
        result = run_async(_cleanup_old_playback_states())
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


async def _cleanup_old_playback_states():
    async with worker_session("celery-playback-cleanup-worker") as session:
        return await cleanup_old_playback_states_handler(session)


@celery_app.task
def cleanup_old_transcription_temp_files(days: int = 7):
    started_at = datetime.now(UTC)
    task_name = "app.domains.podcast.tasks.maintenance.cleanup_old_transcription_temp_files"
    queue_name = "maintenance"
    try:
        result = run_async(_cleanup_old_transcription_temp_files(days=days))
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


async def _cleanup_old_transcription_temp_files(days: int):
    async with worker_session("celery-temp-cleanup-worker") as session:
        return await cleanup_old_transcription_temp_files_handler(session, days=days)


@celery_app.task
def log_periodic_task_statistics():
    started_at = datetime.now(UTC)
    task_name = "app.domains.podcast.tasks.maintenance.log_periodic_task_statistics"
    queue_name = "maintenance"
    try:
        result = run_async(_log_periodic_task_statistics())
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


async def _log_periodic_task_statistics():
    async with worker_session("celery-task-stats-worker") as session:
        return await log_periodic_task_statistics_handler(session)


@celery_app.task
def auto_cleanup_cache_files():
    started_at = datetime.now(UTC)
    task_name = "app.domains.podcast.tasks.maintenance.auto_cleanup_cache_files"
    queue_name = "maintenance"
    try:
        result = run_async(_auto_cleanup_cache_files())
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


async def _auto_cleanup_cache_files():
    async with worker_session("celery-auto-cleanup-worker") as session:
        return await auto_cleanup_cache_files_handler(session)
