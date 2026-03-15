"""Handlers for maintenance and housekeeping tasks."""

from __future__ import annotations

from app.domains.podcast.services.task_orchestration_service import (
    PodcastTaskOrchestrationService,
)


async def log_periodic_task_statistics_handler(session) -> dict:
    """Log current task statistics and return snapshot."""
    return await PodcastTaskOrchestrationService(session).log_periodic_task_statistics()


async def cleanup_old_playback_states_handler(session) -> dict:
    """Delete playback states older than 90 days."""
    return await PodcastTaskOrchestrationService(session).cleanup_old_playback_states()


async def cleanup_old_transcription_temp_files_handler(session, days: int = 7) -> dict:
    """Clean stale transcription temporary files."""
    return await PodcastTaskOrchestrationService(
        session,
    ).cleanup_old_transcription_temp_files(days=days)


async def auto_cleanup_cache_files_handler(session) -> dict:
    """Execute cache cleanup when enabled by admin settings."""
    return await PodcastTaskOrchestrationService(session).auto_cleanup_cache_files()
