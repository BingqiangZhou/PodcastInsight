"""Celery tasks for OPML import background episode parsing."""

from datetime import UTC, datetime

from app.core.celery_app import celery_app
from app.domains.podcast.tasks.handlers_opml_import import (
    process_opml_subscription_episodes_handler,
)
from app.domains.podcast.tasks.runtime import log_task_run, run_async, worker_session


@celery_app.task(bind=True, max_retries=3)
def process_opml_subscription_episodes(
    self,
    subscription_id: int,
    user_id: int,
    source_url: str,
):
    started_at = datetime.now(UTC)
    task_name = (
        "app.domains.podcast.tasks.opml_import.process_opml_subscription_episodes"
    )
    queue_name = "subscription_sync"
    try:
        result = run_async(
            _process_opml_subscription_episodes(
                subscription_id=subscription_id,
                user_id=user_id,
                source_url=source_url,
            )
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
            raise self.retry(countdown=60 * (2 ** self.request.retries)) from exc
        raise


async def _process_opml_subscription_episodes(
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

