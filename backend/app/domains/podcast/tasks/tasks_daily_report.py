"""Celery tasks and handlers for podcast daily report generation.

Merged from: daily_report.py, handlers_daily_report.py
"""

from datetime import UTC, date, datetime

from app.core.celery_app import celery_app
from app.domains.podcast.services.task_orchestration_service import (
    PodcastTaskOrchestrationService,
)
from app.domains.podcast.tasks.runtime import log_task_run, run_async, worker_session


# ---------------------------------------------------------------------------
# Handlers (formerly handlers_daily_report.py)
# ---------------------------------------------------------------------------


async def _generate_daily_reports_handler(
    session,
    target_date: date | None = None,
) -> dict:
    """Generate one daily report snapshot for each user with active subscriptions."""
    return await PodcastTaskOrchestrationService(session).generate_daily_reports(
        target_date=target_date,
    )


# ---------------------------------------------------------------------------
# Tasks (formerly daily_report.py)
# ---------------------------------------------------------------------------


@celery_app.task(bind=True, max_retries=3)
def generate_daily_podcast_reports(self, report_date: str | None = None):
    started_at = datetime.now(UTC)
    task_name = "app.domains.podcast.tasks.tasks_daily_report.generate_daily_podcast_reports"
    queue_name = "default"
    try:
        target_date = date.fromisoformat(report_date) if report_date else None
        result = run_async(_generate_daily_reports_async(target_date=target_date))
        log_task_run(
            task_name=task_name,
            queue_name=queue_name,
            status="success",
            started_at=started_at,
            finished_at=datetime.now(UTC),
            metadata={"report_date": report_date},
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
            metadata={"report_date": report_date},
        )
        if self.request.retries < self.max_retries:
            raise self.retry(countdown=60 * (2**self.request.retries)) from exc
        raise


async def _generate_daily_reports_async(target_date: date | None):
    async with worker_session("celery-daily-report-worker") as session:
        return await _generate_daily_reports_handler(
            session=session,
            target_date=target_date,
        )
