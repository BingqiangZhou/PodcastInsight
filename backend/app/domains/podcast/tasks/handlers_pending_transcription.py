"""Handlers for periodic transcription backlog dispatch."""

from __future__ import annotations

from app.domains.podcast.services.task_orchestration_service import (
    PodcastTaskOrchestrationService,
)
from app.domains.podcast.tasks.runtime import single_instance_task_lock


async def process_pending_transcriptions_handler(session) -> dict:
    """Dispatch periodic backlog transcription tasks."""
    async with single_instance_task_lock(
        "task:process_pending_transcriptions",
        ttl_seconds=1800,
    ) as acquired:
        if not acquired:
            return {
                "status": "skipped_locked",
                "reason": "pending_transcription_task_already_running",
            }
        return await PodcastTaskOrchestrationService(session).process_pending_transcriptions()
