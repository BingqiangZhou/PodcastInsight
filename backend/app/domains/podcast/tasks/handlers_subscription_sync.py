"""Handlers for subscription sync background tasks."""

from __future__ import annotations

from app.domains.podcast.services.task_orchestration_service import (
    PodcastTaskOrchestrationService,
)
from app.domains.podcast.tasks.runtime import single_instance_task_lock


async def refresh_all_podcast_feeds_handler(session) -> dict:
    """Refresh all active podcast-rss subscriptions due by user schedule."""
    async with single_instance_task_lock(
        "task:refresh_all_podcast_feeds",
        ttl_seconds=3600,
    ) as acquired:
        if not acquired:
            return {"status": "skipped_locked", "reason": "refresh_task_already_running"}
        return await PodcastTaskOrchestrationService(session).refresh_all_podcast_feeds()
