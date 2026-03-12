"""Podcast Celery task package."""

from app.core.celery_app import celery_app
from app.domains.podcast.tasks.daily_report import generate_daily_podcast_reports
from app.domains.podcast.tasks.maintenance import (
    auto_cleanup_cache_files,
    cleanup_old_playback_states,
    cleanup_old_transcription_temp_files,
    log_periodic_task_statistics,
)
from app.domains.podcast.tasks.opml_import import process_opml_subscription_episodes
from app.domains.podcast.tasks.pending_transcription import (
    process_pending_transcriptions,
)
from app.domains.podcast.tasks.recommendation import generate_podcast_recommendations
from app.domains.podcast.tasks.subscription_sync import refresh_all_podcast_feeds
from app.domains.podcast.tasks.summary_generation import (
    generate_episode_summary,
    generate_pending_summaries,
)
from app.domains.podcast.tasks.transcription import (
    process_audio_transcription,
    process_podcast_episode_with_transcription,
)


__all__ = [
    "celery_app",
    "refresh_all_podcast_feeds",
    "process_opml_subscription_episodes",
    "generate_episode_summary",
    "generate_pending_summaries",
    "process_audio_transcription",
    "cleanup_old_playback_states",
    "generate_podcast_recommendations",
    "process_podcast_episode_with_transcription",
    "process_pending_transcriptions",
    "cleanup_old_transcription_temp_files",
    "log_periodic_task_statistics",
    "auto_cleanup_cache_files",
    "generate_daily_podcast_reports",
]
