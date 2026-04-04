"""Celery configuration snapshot checks."""

from app.core.celery_app import celery_app
from app.core.config import settings


def test_celery_task_routes_snapshot() -> None:
    task_routes = celery_app.conf.task_routes

    assert "app.domains.podcast.tasks.tasks_subscription.refresh_all_podcast_feeds" in task_routes
    assert "app.domains.podcast.tasks.tasks_summary.generate_pending_summaries" in task_routes
    assert "app.domains.podcast.tasks.tasks_transcription.process_audio_transcription" in task_routes
    assert "app.domains.podcast.tasks.tasks_transcription.process_pending_transcriptions" in task_routes
    assert "app.domains.podcast.tasks.tasks_maintenance.cleanup_old_playback_states" in task_routes
    assert "app.domains.podcast.tasks.tasks_daily_report.generate_daily_podcast_reports" in task_routes

    assert task_routes[
        "app.domains.podcast.tasks.tasks_subscription.refresh_all_podcast_feeds"
    ]["queue"] == "default"
    assert task_routes[
        "app.domains.podcast.tasks.tasks_transcription.process_audio_transcription"
    ]["queue"] == "transcription"


def test_celery_beat_schedule_snapshot() -> None:
    beat_schedule = celery_app.conf.beat_schedule

    assert "refresh-podcast-feeds" in beat_schedule
    assert "generate-pending-summaries" in beat_schedule
    if settings.TRANSCRIPTION_BACKLOG_ENABLED:
        assert "process-pending-transcriptions" in beat_schedule
    else:
        assert "process-pending-transcriptions" not in beat_schedule
    assert "log-task-statistics" in beat_schedule
    assert "auto-cleanup-cache" in beat_schedule
    assert "generate-daily-podcast-reports" in beat_schedule
