"""Celery tasks and handlers for highlight extraction flows.

Merged from: highlight_extraction.py, handlers_highlight.py
"""

import logging
from datetime import UTC, datetime

from celery.exceptions import SoftTimeLimitExceeded

from app.core.celery_app import celery_app
from app.domains.podcast.services.highlight_service import (
    HighlightExtractionService,
)
from app.domains.podcast.tasks.runtime import (
    log_task_run,
    run_async,
    single_instance_task_lock,
    worker_session,
)


logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Handlers (formerly handlers_highlight.py)
# ---------------------------------------------------------------------------


async def extract_pending_highlights_handler(session) -> dict:
    """Extract highlights for episodes with transcripts but no highlights.

    This handler wraps the highlight extraction service with a distributed lock
    to ensure only one worker instance runs the task at a time.

    Args:
        session: Database session

    Returns:
        Dict with extraction results or skip status
    """
    async with single_instance_task_lock(
        "task:extract_pending_highlights",
        ttl_seconds=3600,  # 1 hour, as AI calls may be slow
    ) as acquired:
        if not acquired:
            logger.info(
                "Skipping highlight extraction task - another instance is already running",
            )
            return {
                "status": "skipped_locked",
                "reason": "highlight_extraction_task_already_running",
            }
        service = HighlightExtractionService(session)
        return await service.extract_pending_highlights()


# ---------------------------------------------------------------------------
# Tasks (formerly highlight_extraction.py)
# ---------------------------------------------------------------------------


@celery_app.task(bind=True, max_retries=3)
def extract_episode_highlights(
    self,
    episode_id: int,
    model_name: str | None = None,
):
    """Extract highlights from a single podcast episode."""
    started_at = datetime.now(UTC)
    task_name = "app.domains.podcast.tasks.tasks_highlight.extract_episode_highlights"
    queue_name = "default"
    try:
        result = run_async(
            _extract_episode_highlights_async(
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


async def _extract_episode_highlights_async(
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
    task_name = "app.domains.podcast.tasks.tasks_highlight.extract_pending_highlights"
    queue_name = "default"
    try:
        result = run_async(_extract_pending_highlights_async())
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


async def _extract_pending_highlights_async():
    async with worker_session("celery-highlight-worker") as session:
        return await extract_pending_highlights_handler(session)
