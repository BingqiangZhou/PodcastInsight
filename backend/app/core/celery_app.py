"""Central Celery application entrypoint."""

from celery import Celery
from celery.schedules import crontab

from app.core.config import settings


celery_app = Celery(
    "personal_ai_tasks",
    broker=settings.CELERY_BROKER_URL,
    backend=settings.CELERY_RESULT_BACKEND,
)

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
    task_track_started=True,
    task_time_limit=30 * 60,
    task_soft_time_limit=25 * 60,
    worker_prefetch_multiplier=1,
    worker_max_tasks_per_child=1000,
    task_routes={
        "app.domains.podcast.tasks.subscription_sync.refresh_all_podcast_feeds": {
            "queue": "subscription_sync"
        },
        "app.domains.podcast.tasks.opml_import.process_opml_subscription_episodes": {
            "queue": "subscription_sync"
        },
        "app.domains.podcast.tasks.summary_generation.generate_pending_summaries": {
            "queue": "ai_generation"
        },
        "app.domains.podcast.tasks.summary_generation.generate_summary_for_episode": {
            "queue": "ai_generation"
        },
        "app.domains.podcast.tasks.transcription.process_audio_transcription": {
            "queue": "transcription"
        },
        "app.domains.podcast.tasks.transcription.process_podcast_episode_with_transcription": {
            "queue": "transcription"
        },
        "app.domains.podcast.tasks.maintenance.cleanup_old_playback_states": {
            "queue": "maintenance"
        },
        "app.domains.podcast.tasks.maintenance.cleanup_old_transcription_temp_files": {
            "queue": "maintenance"
        },
        "app.domains.podcast.tasks.maintenance.auto_cleanup_cache_files": {
            "queue": "maintenance"
        },
        "app.domains.podcast.tasks.recommendation.generate_podcast_recommendations": {
            "queue": "ai_generation"
        },
        "app.domains.podcast.tasks.daily_report.generate_daily_podcast_reports": {
            "queue": "ai_generation"
        },
    },
    beat_schedule={
        "log-task-statistics": {
            "task": "app.domains.podcast.tasks.maintenance.log_periodic_task_statistics",
            "schedule": 600.0,
            "options": {"queue": "maintenance"},
        },
        "refresh-podcast-feeds": {
            "task": "app.domains.podcast.tasks.subscription_sync.refresh_all_podcast_feeds",
            "schedule": crontab(minute=0),
            "options": {"queue": "subscription_sync"},
        },
        "generate-pending-summaries": {
            "task": "app.domains.podcast.tasks.summary_generation.generate_pending_summaries",
            "schedule": 1800.0,
            "options": {"queue": "ai_generation"},
        },
        "auto-cleanup-cache": {
            "task": "app.domains.podcast.tasks.maintenance.auto_cleanup_cache_files",
            "schedule": crontab(hour=4, minute=0),
            "options": {"queue": "maintenance"},
        },
        "generate-daily-podcast-reports": {
            "task": "app.domains.podcast.tasks.daily_report.generate_daily_podcast_reports",
            "schedule": crontab(hour=19, minute=30),
            "options": {"queue": "ai_generation"},
        },
    },
)


# Ensure task modules are imported so Celery registers them.
import app.domains.podcast.tasks  # noqa: F401,E402
