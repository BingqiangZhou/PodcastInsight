"""Celery tasks for highlight extraction flows."""

import logging
from datetime import UTC, datetime

from celery.exceptions import SoftTimeLimitExceeded

from app.core.celery_app import celery_app
from app.domains.podcast.services.highlight_extraction_service import (
    HighlightExtractionService,
)
from app.domains.podcast.tasks.handlers_highlight import (
    extract_pending_highlights_handler,
)
from app.domains.podcast.tasks.runtime import log_task_run, run_async, worker_session


logger = logging.getLogger(__name__)


@celery_app.task(bind=True, max_retries=3)
def extract_episode_highlights(
    self,
    episode_id: int,
    model_name: str | None = None,
):
    """Extract highlights from a single podcast episode."""
    started_at = datetime.now(UTC)
    task_name = (
        "app.domains.podcast.tasks.highlight_extraction.extract_episode_highlights"
    )
    queue_name = "ai_generation"
    try:
        result = run_async(
            _extract_episode_highlights(
                episode_id=episode_id,
                model_name=model_name,
            ),
        )
        log_task_run(
            task_name=task_name,
            queue_name=queue_name,
            status="success",
            started_at=started_at,
            finished_at=datetime.now(UTC),
            metadata={"episode_id": episode_id, "model_name": model_name},
        )
        return result
    except Exception as exc:
        logger.exception(
            "extract_episode_highlights failed for episode_id=%s (retry %d/%d)",
            episode_id,
            self.request.retries,
            self.max_retries,
        )
        log_task_run(
            task_name=task_name,
            queue_name=queue_name,
            status="failed",
            started_at=started_at,
            finished_at=datetime.now(UTC),
            error_message=str(exc),
            metadata={"episode_id": episode_id, "model_name": model_name},
        )
        if self.request.retries < self.max_retries:
            raise self.retry(countdown=60 * (2**self.request.retries)) from exc
        raise


async def _extract_episode_highlights(
    *,
    episode_id: int,
    model_name: str | None,
):
    async with worker_session("celery-highlight-worker") as session:
        workflow = HighlightExtractionService(session)
        return await workflow.extract_highlights_for_episode(
            episode_id=episode_id,
            model_name=model_name,
        )


@celery_app.task(
    bind=True,
    max_retries=3,
    soft_time_limit=20 * 60,  # 20 minutes soft timeout
    time_limit=25 * 60,  # 25 minutes hard timeout (below global 30 min)
)
def extract_pending_highlights(self):
    """Extract highlights for episodes with transcripts but no highlights."""
    started_at = datetime.now(UTC)
    task_name = (
        "app.domains.podcast.tasks.highlight_extraction.extract_pending_highlights"
    )
    queue_name = "ai_generation"
    try:
        result = run_async(_extract_pending_highlights())
        log_task_run(
            task_name=task_name,
            queue_name=queue_name,
            status="success",
            started_at=started_at,
            finished_at=datetime.now(UTC),
        )
        return result
    except SoftTimeLimitExceeded:
        logger.warning("Highlight extraction soft timeout exceeded")
        log_task_run(
            task_name=task_name,
            queue_name=queue_name,
            status="failed",
            started_at=started_at,
            finished_at=datetime.now(UTC),
            error_message="Soft timeout exceeded (20 minutes)",
        )
        # Don't retry on timeout - tasks will be picked up in next run
        raise
    except Exception as exc:
        logger.exception(
            "extract_pending_highlights failed (retry %d/%d)",
            self.request.retries,
            self.max_retries,
        )
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


async def _extract_pending_highlights():
    async with worker_session("celery-highlight-worker") as session:
        return await extract_pending_highlights_handler(session)
