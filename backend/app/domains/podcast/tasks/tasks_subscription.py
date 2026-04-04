"""Celery tasks and handlers for subscription sync flows.

Merged from: subscription_sync.py, handlers_subscription_sync.py
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
# Handlers (formerly handlers_subscription_sync.py)
# ---------------------------------------------------------------------------


async def _refresh_all_podcast_feeds_handler(session) -> dict:
    """Refresh all active podcast-rss subscriptions due by user schedule."""
    async with single_instance_task_lock(
        "task:refresh_all_podcast_feeds",
        ttl_seconds=3600,
    ) as acquired:
        if not acquired:
            return {
                "status": "skipped_locked",
                "reason": "refresh_task_already_running",
            }
        return await PodcastTaskOrchestrationService(
            session,
        ).refresh_all_podcast_feeds()


# ---------------------------------------------------------------------------
# Tasks (formerly subscription_sync.py)
# ---------------------------------------------------------------------------


@celery_app.task(bind=True, max_retries=3)
def refresh_all_podcast_feeds(self):
    started_at = datetime.now(UTC)
    task_name = "app.domains.podcast.tasks.tasks_subscription.refresh_all_podcast_feeds"
    queue_name = "default"
    try:
        result = run_async(_refresh_all_podcast_feeds_async())
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
        if self.request.retries < self.max_retries:
            raise self.retry(countdown=60 * (2**self.request.retries)) from exc
        raise


async def _refresh_all_podcast_feeds_async():
    async with worker_session("celery-feed-refresh-worker") as session:
        return await _refresh_all_podcast_feeds_handler(session)
