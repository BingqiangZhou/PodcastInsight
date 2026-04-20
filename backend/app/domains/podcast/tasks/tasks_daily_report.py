"""Celery tasks for podcast daily report generation."""

from datetime import date

from app.core.celery_app import celery_app
from app.domains.podcast.services.task_orchestration_service import (
    PodcastTaskOrchestrationService,
)
from app.domains.podcast.tasks.runtime import (
    run_async,
    worker_session,
)


async def _generate_daily_reports_handler(
    session,
    target_date: date | None = None,
) -> dict:
    """Generate one daily report snapshot for each user with active subscriptions."""
    return await PodcastTaskOrchestrationService(session).generate_daily_reports(
        target_date=target_date,
    )


@celery_app.task(bind=True, max_retries=3)
def generate_daily_podcast_reports(self, report_date: str | None = None):
    try:
        target_date = date.fromisoformat(report_date) if report_date else None
        return run_async(
            _generate_daily_reports_async(target_date=target_date),
        )
    except Exception as exc:
        if self.request.retries < self.max_retries:
            raise self.retry(countdown=60 * (2**self.request.retries)) from exc
        raise


async def _generate_daily_reports_async(target_date: date | None):
    async with worker_session("celery-daily-report-worker") as session:
        return await _generate_daily_reports_handler(
            session=session,
            target_date=target_date,
        )
