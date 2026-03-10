"""Celery tasks for recommendation generation."""

from datetime import UTC, datetime

from app.core.celery_app import celery_app
from app.domains.podcast.tasks.handlers_recommendation import (
    generate_podcast_recommendations_handler,
)
from app.domains.podcast.tasks.runtime import log_task_run, run_async, worker_session


@celery_app.task
def generate_podcast_recommendations():
    started_at = datetime.now(UTC)
    task_name = "app.domains.podcast.tasks.recommendation.generate_podcast_recommendations"
    queue_name = "ai_generation"
    try:
        result = run_async(_generate_podcast_recommendations())
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
        raise


async def _generate_podcast_recommendations():
    async with worker_session("celery-recommendation-worker") as session:
        return await generate_podcast_recommendations_handler(session)
