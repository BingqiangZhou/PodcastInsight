"""Celery tasks for summary generation flows."""

from celery.exceptions import SoftTimeLimitExceeded

from app.core.celery_app import celery_app
from app.domains.podcast.services.content_service import SummaryWorkflowService
from app.domains.podcast.tasks.runtime import (
    run_async,
    worker_session,
)


async def generate_pending_summaries_handler(session) -> dict:
    """Generate summaries for pending episodes."""
    workflow = SummaryWorkflowService(session)
    return await workflow.generate_pending_summaries_run()


@celery_app.task(bind=True, max_retries=3)
def generate_pending_summaries(self):
    try:
        return run_async(_generate_pending_summaries_async())
    except SoftTimeLimitExceeded:
        raise
    except Exception as exc:
        if self.request.retries < self.max_retries:
            raise self.retry(countdown=60 * (2**self.request.retries)) from exc
        raise


async def _generate_pending_summaries_async():
    async with worker_session("celery-summary-worker") as session:
        return await generate_pending_summaries_handler(session)


@celery_app.task(bind=True, max_retries=3)
def generate_episode_summary(
    self,
    episode_id: int,
    summary_model: str | None = None,
    custom_prompt: str | None = None,
):
    try:
        return run_async(
            _generate_episode_summary_async(
                episode_id=episode_id,
                summary_model=summary_model,
                custom_prompt=custom_prompt,
            ),
        )
    except SoftTimeLimitExceeded:
        raise
    except Exception as exc:
        if self.request.retries < self.max_retries:
            raise self.retry(countdown=60 * (2**self.request.retries)) from exc
        raise


async def _generate_episode_summary_async(
    *,
    episode_id: int,
    summary_model: str | None,
    custom_prompt: str | None,
):
    async with worker_session("celery-summary-episode-worker") as session:
        workflow = SummaryWorkflowService(session)
        return await workflow.execute_episode_summary_generation(
            episode_id,
            summary_model=summary_model,
            custom_prompt=custom_prompt,
        )
