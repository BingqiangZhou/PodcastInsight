"""Task orchestration helpers for maintenance and backlog flows."""

from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone

from sqlalchemy import and_, delete, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.admin.storage_service import StorageCleanupService
from app.core.config import settings
from app.domains.podcast.models import (
    PodcastEpisode,
    PodcastPlaybackState,
    TranscriptionTask,
)
from app.domains.podcast.services.search_service import PodcastSearchService
from app.domains.podcast.services.transcription_workflow_service import (
    TranscriptionWorkflowService,
)
from app.domains.subscription.models import (
    Subscription,
    SubscriptionStatus,
    UserSubscription,
)
from app.domains.user.models import User, UserStatus


logger = logging.getLogger(__name__)


class PodcastTaskMaintenanceService:
    """Handle task statistics, maintenance cleanup, and backlog processing."""

    def __init__(self, session: AsyncSession):
        self.session = session

    async def get_task_statistics(self) -> dict:
        count_stmt = select(
            TranscriptionTask.status, func.count(TranscriptionTask.id)
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
            "logged_at": datetime.now(timezone.utc).isoformat(),
        }

    async def cleanup_old_playback_states(self) -> dict:
        cutoff_date = datetime.now(timezone.utc) - timedelta(days=90)
        stmt = delete(PodcastPlaybackState).where(
            PodcastPlaybackState.last_updated_at < cutoff_date
        )
        result = await self.session.execute(stmt)
        await self.session.commit()
        return {
            "status": "success",
            "deleted_count": result.rowcount or 0,
            "processed_at": datetime.now(timezone.utc).isoformat(),
        }

    async def cleanup_old_transcription_temp_files(self, *, days: int = 7) -> dict:
        workflow = TranscriptionWorkflowService(self.session)
        result = await workflow.cleanup_old_temp_files(days=days)
        return {
            "status": "success",
            **result,
            "processed_at": datetime.now(timezone.utc).isoformat(),
        }

    async def auto_cleanup_cache_files(self) -> dict:
        service = StorageCleanupService(self.session)
        config = await service.get_cleanup_config()
        if not config.get("enabled"):
            return {
                "status": "skipped",
                "reason": "Auto cleanup is disabled",
                "checked_at": datetime.now(timezone.utc).isoformat(),
            }
        result = await service.execute_cleanup(keep_days=1)
        return {
            "status": "success",
            **result,
            "executed_at": datetime.now(timezone.utc).isoformat(),
        }

    async def process_pending_transcriptions(self) -> dict:
        if not settings.TRANSCRIPTION_BACKLOG_ENABLED:
            return {
                "status": "skipped",
                "reason": "backlog_transcription_disabled",
                "processed_at": datetime.now(timezone.utc).isoformat(),
            }

        filters = [
            Subscription.source_type == "podcast-rss",
            Subscription.status == SubscriptionStatus.ACTIVE.value,
            UserSubscription.is_archived.is_(False),
            PodcastEpisode.audio_url.is_not(None),
            PodcastEpisode.audio_url != "",
            or_(
                PodcastEpisode.transcript_content.is_(None),
                PodcastEpisode.transcript_content == "",
            ),
            or_(
                TranscriptionTask.id.is_(None),
                TranscriptionTask.status.in_(["failed", "cancelled"]),
            ),
        ]

        count_stmt = (
            select(func.count(func.distinct(PodcastEpisode.id)))
            .select_from(PodcastEpisode)
            .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .outerjoin(
                TranscriptionTask, TranscriptionTask.episode_id == PodcastEpisode.id
            )
            .where(and_(*filters))
        )
        total_candidates = int((await self.session.execute(count_stmt)).scalar() or 0)
        batch_size = max(1, settings.TRANSCRIPTION_BACKLOG_BATCH_SIZE)
        if total_candidates == 0:
            return {
                "status": "success",
                "total_candidates": 0,
                "checked": 0,
                "dispatched": 0,
                "skipped": 0,
                "failed": 0,
                "skipped_reasons": {},
                "processed_at": datetime.now(timezone.utc).isoformat(),
            }

        id_stmt = (
            select(PodcastEpisode.id, PodcastEpisode.published_at)
            .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .outerjoin(
                TranscriptionTask, TranscriptionTask.episode_id == PodcastEpisode.id
            )
            .where(and_(*filters))
            .distinct()
            .order_by(PodcastEpisode.published_at.desc(), PodcastEpisode.id.desc())
            .limit(batch_size)
        )
        rows = await self.session.execute(id_stmt)
        episode_ids = [row[0] for row in rows.all()]
        if not episode_ids:
            return {
                "status": "success",
                "total_candidates": total_candidates,
                "checked": 0,
                "dispatched": 0,
                "skipped": 0,
                "failed": 0,
                "skipped_reasons": {},
                "processed_at": datetime.now(timezone.utc).isoformat(),
            }

        workflow = TranscriptionWorkflowService(self.session)
        dispatch_result = await workflow.dispatch_pending_transcriptions(episode_ids)
        logger.info(
            "Backlog transcription run completed: total_candidates=%s checked=%s dispatched=%s skipped=%s failed=%s skipped_reasons=%s",
            total_candidates,
            dispatch_result["checked"],
            dispatch_result["dispatched"],
            dispatch_result["skipped"],
            dispatch_result["failed"],
            dispatch_result["skipped_reasons"],
        )
        return {
            "status": "success",
            "total_candidates": total_candidates,
            **dispatch_result,
            "processed_at": datetime.now(timezone.utc).isoformat(),
        }

    async def generate_podcast_recommendations(self) -> dict:
        stmt = select(User).where(User.status == UserStatus.ACTIVE)
        result = await self.session.execute(stmt)
        users = list(result.scalars().all())

        recommendations_generated = 0
        for user in users:
            service = PodcastSearchService(self.session, user.id)
            recommendations = await service.get_recommendations(limit=20)
            recommendations_generated += len(recommendations)

        return {
            "status": "success",
            "recommendations_generated": recommendations_generated,
            "processed_at": datetime.now(timezone.utc).isoformat(),
        }
