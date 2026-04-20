"""Celery tasks for subscription sync flows."""

from celery.exceptions import SoftTimeLimitExceeded

from app.core.celery_app import celery_app
from app.domains.podcast.tasks.task_orchestration import (
    PodcastTaskOrchestrationService,
)
from app.domains.podcast.tasks.runtime import (
    run_async,
    worker_session,
)


async def _refresh_all_podcast_feeds_handler(session) -> dict:
    """Refresh all active podcast-rss subscriptions due by user schedule."""
    return await PodcastTaskOrchestrationService(
        session,
    ).refresh_all_podcast_feeds()


@celery_app.task(bind=True, max_retries=3)
def refresh_all_podcast_feeds(self):
    try:
        return run_async(_refresh_all_podcast_feeds_async())
    except SoftTimeLimitExceeded:
        raise
    except Exception as exc:
        if self.request.retries < self.max_retries:
            raise self.retry(countdown=60 * (2**self.request.retries)) from exc
        raise


async def _refresh_all_podcast_feeds_async():
    async with worker_session("celery-feed-refresh-worker") as session:
        return await _refresh_all_podcast_feeds_handler(session)
