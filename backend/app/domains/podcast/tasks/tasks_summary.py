"""Celery tasks and handlers for summary generation flows.

Merged from: summary_generation.py, handlers_summary.py
"""

from datetime import UTC, datetime

from app.core.celery_app import celery_app
from app.domains.podcast.services.summary_service import SummaryWorkflowService
from app.domains.podcast.tasks.runtime import (
    log_task_run,
    run_async,
    single_instance_task_lock,
    worker_session,
)


# ---------------------------------------------------------------------------
# Handlers (formerly handlers_summary.py)
# ---------------------------------------------------------------------------


async def generate_pending_summaries_handler(session) -> dict:
    """Generate summaries for pending episodes."""
    async with single_instance_task_lock(
        "task:generate_pending_summaries",
        ttl_seconds=1800,
    ) as acquired:
        if not acquired:
            return {
                "status": "skipped_locked",
                "reason": "summary_task_already_running",
            }
        workflow = SummaryWorkflowService(session)
        return await workflow.generate_pending_summaries_run()


# ---------------------------------------------------------------------------
# Tasks (formerly summary_generation.py)
# ---------------------------------------------------------------------------


@celery_app.task(bind=True, max_retries=3)
def generate_pending_summaries(self):
    started_at = datetime.now(UTC)
    task_name = "app.domains.podcast.tasks.tasks_summary.generate_pending_summaries"
    queue_name = "default"
    try:
        result = run_async(_generate_pending_summaries_async())
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
    started_at = datetime.now(UTC)
    task_name = "app.domains.podcast.tasks.tasks_summary.generate_episode_summary"
    queue_name = "default"
    try:
        result = run_async(
            _generate_episode_summary_async(
                episode_id=episode_id,
                summary_model=summary_model,
                custom_prompt=custom_prompt,
            ),
        )
        log_task_run(
            task_name=task_name,
            queue_name=queue_name,
            status="success",
            started_at=started_at,
            finished_at=datetime.now(UTC),
            metadata={"episode_id": episode_id, "summary_model": summary_model},
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
            metadata={"episode_id": episode_id, "summary_model": summary_model},
        )
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
