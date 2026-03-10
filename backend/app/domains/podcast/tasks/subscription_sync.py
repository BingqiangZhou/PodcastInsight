"""Celery tasks for subscription sync flows."""

from datetime import UTC, datetime

from app.core.celery_app import celery_app
from app.domains.podcast.tasks.handlers_subscription_sync import (
    refresh_all_podcast_feeds_handler,
)
from app.domains.podcast.tasks.runtime import log_task_run, run_async, worker_session


@celery_app.task(bind=True, max_retries=3)
def refresh_all_podcast_feeds(self):
    started_at = datetime.now(UTC)
    task_name = "app.domains.podcast.tasks.subscription_sync.refresh_all_podcast_feeds"
    queue_name = "subscription_sync"
    try:
        result = run_async(_refresh_all_podcast_feeds())
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
            raise self.retry(countdown=60 * (2 ** self.request.retries)) from exc
        raise


async def _refresh_all_podcast_feeds():
    async with worker_session("celery-feed-refresh-worker") as session:
        return await refresh_all_podcast_feeds_handler(session)
