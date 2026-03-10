"""Celery tasks for periodic transcription backlog dispatch."""

from datetime import UTC, datetime

from app.core.celery_app import celery_app
from app.domains.podcast.tasks.handlers_pending_transcription import (
    process_pending_transcriptions_handler,
)
from app.domains.podcast.tasks.runtime import log_task_run, run_async, worker_session


@celery_app.task(bind=True, max_retries=3)
def process_pending_transcriptions(self):
    started_at = datetime.now(UTC)
    task_name = "app.domains.podcast.tasks.pending_transcription.process_pending_transcriptions"
    queue_name = "transcription"
    metadata = None
    try:
        result = run_async(_process_pending_transcriptions())
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
            raise self.retry(countdown=60 * (2 ** self.request.retries)) from exc
        raise


async def _process_pending_transcriptions():
    async with worker_session("celery-transcription-backlog-worker") as session:
        return await process_pending_transcriptions_handler(session)
