"""Handlers for highlight extraction tasks."""

from __future__ import annotations

import logging

from app.domains.podcast.services.highlight_extraction_service import (
    HighlightExtractionService,
)
from app.domains.podcast.tasks.runtime import single_instance_task_lock


logger = logging.getLogger(__name__)


async def extract_pending_highlights_handler(session) -> dict:
    """Extract highlights for episodes with transcripts but no highlights.

    This handler wraps the highlight extraction service with a distributed lock
    to ensure only one worker instance runs the task at a time.

    Args:
        session: Database session

    Returns:
        Dict with extraction results or skip status
    """
    async with single_instance_task_lock(
        "task:extract_pending_highlights",
        ttl_seconds=3600,  # 1 hour, as AI calls may be slow
    ) as acquired:
        if not acquired:
            logger.info(
                "Skipping highlight extraction task - another instance is already running"
            )
            return {
                "status": "skipped_locked",
                "reason": "highlight_extraction_task_already_running",
            }
        service = HighlightExtractionService(session)
        return await service.extract_pending_highlights()
