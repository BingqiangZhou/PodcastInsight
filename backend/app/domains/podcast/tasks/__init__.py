"""Podcast Celery task package."""

from app.core.celery_app import celery_app
from app.domains.podcast.tasks.tasks_daily_report import generate_daily_podcast_reports
from app.domains.podcast.tasks.tasks_highlight import (
    extract_episode_highlights,
    extract_pending_highlights,
)
from app.domains.podcast.tasks.tasks_maintenance import (
    auto_cleanup_cache_files,
    cleanup_old_playback_states,
    cleanup_old_transcription_temp_files,
    process_opml_subscription_episodes,
)
from app.domains.podcast.tasks.tasks_subscription import refresh_all_podcast_feeds
from app.domains.podcast.tasks.tasks_summary import (
    generate_episode_summary,
    generate_pending_summaries,
)
from app.domains.podcast.tasks.tasks_transcription import (
    process_audio_transcription,
    process_pending_transcriptions,
    process_podcast_episode_with_transcription,
)


__all__ = [
    "auto_cleanup_cache_files",
    "celery_app",
    "cleanup_old_playback_states",
    "cleanup_old_transcription_temp_files",
    "extract_episode_highlights",
    "extract_pending_highlights",
    "generate_daily_podcast_reports",
    "generate_episode_summary",
    "generate_pending_summaries",
    "process_audio_transcription",
    "process_opml_subscription_episodes",
    "process_pending_transcriptions",
    "process_podcast_episode_with_transcription",
    "refresh_all_podcast_feeds",
]
