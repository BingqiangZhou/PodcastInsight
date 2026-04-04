"""Maintenance orchestrator -- statistics, cleanup, and housekeeping tasks."""

from __future__ import annotations

import logging
from datetime import UTC, datetime, timedelta
from typing import Any

from sqlalchemy import delete, func, select

from app.admin.storage_service import StorageCleanupService
from app.domains.podcast.models import PodcastPlaybackState, TranscriptionTask
from app.domains.podcast.services.transcription_workflow_service import (
    TranscriptionWorkflowService,
)

from .base import BaseOrchestrator


logger = logging.getLogger(__name__)


class MaintenanceOrchestrator(BaseOrchestrator):
    """Orchestrate maintenance and housekeeping tasks."""

    async def get_task_statistics(self) -> dict:
        count_stmt = select(
            TranscriptionTask.status,
            func.count(TranscriptionTask.id),
        ).group_by(TranscriptionTask.status)
        count_result = await self.session.execute(count_stmt)
        grouped = dict(count_result.all())

        pending_time_stmt = select(
            func.min(TranscriptionTask.created_at),
            func.max(TranscriptionTask.created_at),
        ).where(TranscriptionTask.status == "pending")
        pending_time_result = await self.session.execute(pending_time_stmt)
        oldest_pending, newest_pending = pending_time_result.one()

        return {
            "pending": grouped.get("pending", 0),
            "in_progress": grouped.get("in_progress", 0),
            "completed": grouped.get("completed", 0),
            "failed": grouped.get("failed", 0),
            "cancelled": grouped.get("cancelled", 0),
            "oldest_pending": oldest_pending,
            "newest_pending": newest_pending,
        }

    async def log_periodic_task_statistics(self) -> dict:
        stats = await self.get_task_statistics()
        total_waiting = stats["pending"] + stats["in_progress"]
        total_processed = stats["completed"] + stats["failed"] + stats["cancelled"]
        logger.info(
            "Task stats: waiting=%s processed=%s pending=%s in_progress=%s failed=%s",
            total_waiting,
            total_processed,
            stats["pending"],
            stats["in_progress"],
            stats["failed"],
        )
        return {
            "status": "success",
            "stats": stats,
            "logged_at": datetime.now(UTC).isoformat(),
        }

    async def cleanup_old_playback_states(self) -> dict:
        cutoff_date = datetime.now(UTC) - timedelta(days=90)
        stmt = delete(PodcastPlaybackState).where(
            PodcastPlaybackState.last_updated_at < cutoff_date,
        )
        result = await self.session.execute(stmt)
        await self.session.commit()
        return {
            "status": "success",
            "deleted_count": result.rowcount or 0,
            "processed_at": datetime.now(UTC).isoformat(),
        }

    async def cleanup_old_transcription_temp_files(self, *, days: int = 7) -> dict:
        workflow = TranscriptionWorkflowService(self.session)
        result = await workflow.cleanup_old_temp_files(days=days)
        return {
            "status": "success",
            **result,
            "processed_at": datetime.now(UTC).isoformat(),
        }

    async def auto_cleanup_cache_files(self) -> dict:
        service = StorageCleanupService(self.session)
        config = await service.get_cleanup_config()
        if not config.get("enabled"):
            return {
                "status": "skipped",
                "reason": "Auto cleanup is disabled",
                "checked_at": datetime.now(UTC).isoformat(),
            }
        result = await service.execute_cleanup(keep_days=1)
        return {
            "status": "success",
            **result,
            "executed_at": datetime.now(UTC).isoformat(),
        }

    # -- Celery task enqueue helpers --

    def enqueue_opml_subscription_episodes(self, **kwargs) -> Any:
        """Queue OPML episode parsing without exposing Celery task imports."""
        from app.domains.podcast.tasks.tasks_maintenance import (
            process_opml_subscription_episodes,
        )

        return process_opml_subscription_episodes.delay(**kwargs)
