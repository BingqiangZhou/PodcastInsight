"""Celery tasks for highlight extraction flows."""

import logging

from celery.exceptions import SoftTimeLimitExceeded

from app.core.celery_app import celery_app
from app.domains.podcast.services.highlight_service import (
    HighlightExtractionService,
)
from app.domains.podcast.tasks.runtime import (
    run_async,
    worker_session,
)


logger = logging.getLogger(__name__)


async def extract_pending_highlights_handler(session) -> dict:
    """Extract highlights for episodes with transcripts but no highlights."""
    service = HighlightExtractionService(session)
    return await service.extract_pending_highlights()


@celery_app.task(bind=True, max_retries=3)
def extract_episode_highlights(
    self,
    episode_id: int,
    model_name: str | None = None,
):
    """Extract highlights from a single podcast episode."""
    try:
        return run_async(
            _extract_episode_highlights_async(
                episode_id=episode_id,
                model_name=model_name,
            ),
        )
    except SoftTimeLimitExceeded:
        logger.warning(
            "extract_episode_highlights timed out for episode_id=%s",
            episode_id,
        )
    except Exception as exc:
        logger.exception(
            "extract_episode_highlights failed for episode_id=%s (retry %d/%d)",
            episode_id,
            self.request.retries,
            self.max_retries,
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
    soft_time_limit=20 * 60,
    time_limit=25 * 60,
)
def extract_pending_highlights(self):
    """Extract highlights for episodes with transcripts but no highlights."""
    try:
        return run_async(_extract_pending_highlights_async())
    except SoftTimeLimitExceeded:
        logger.warning("Highlight extraction soft timeout exceeded")
        raise
    except Exception as exc:
        logger.exception(
            "extract_pending_highlights failed (retry %d/%d)",
            self.request.retries,
            self.max_retries,
        )
        if self.request.retries < self.max_retries:
            raise self.retry(countdown=60 * (2**self.request.retries)) from exc
        raise


async def _extract_pending_highlights_async():
    async with worker_session("celery-highlight-worker") as session:
        return await extract_pending_highlights_handler(session)
