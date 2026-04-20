"""Celery configuration snapshot checks."""

from app.core.celery_app import celery_app


def test_celery_beat_schedule_snapshot() -> None:
    beat_schedule = celery_app.conf.beat_schedule

    assert "refresh-podcast-feeds" in beat_schedule
    assert "generate-pending-summaries" in beat_schedule
    assert "auto-cleanup-cache" in beat_schedule
    assert "generate-daily-podcast-reports" in beat_schedule
