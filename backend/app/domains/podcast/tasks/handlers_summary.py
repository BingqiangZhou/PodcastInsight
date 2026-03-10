"""Handlers for summary generation tasks."""

from __future__ import annotations

import logging

from app.domains.podcast.services.summary_workflow_service import SummaryWorkflowService
from app.domains.podcast.tasks.runtime import single_instance_task_lock


logger = logging.getLogger(__name__)


async def generate_pending_summaries_handler(session) -> dict:
    """Generate summaries for pending episodes."""
    async with single_instance_task_lock(
        "task:generate_pending_summaries",
        ttl_seconds=1800,
    ) as acquired:
        if not acquired:
            return {"status": "skipped_locked", "reason": "summary_task_already_running"}
        workflow = SummaryWorkflowService(session)
        return await workflow.generate_pending_summaries_run()
