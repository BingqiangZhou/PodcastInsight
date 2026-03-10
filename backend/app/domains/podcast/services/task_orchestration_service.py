"""Podcast background task orchestration service."""

from __future__ import annotations

import logging
from datetime import UTC, datetime, timedelta
from typing import Any

from sqlalchemy import and_, delete, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.admin.storage_service import StorageCleanupService
from app.core.config import settings
from app.core.redis import get_shared_redis
from app.domains.podcast.integration.secure_rss_parser import SecureRSSParser
from app.domains.podcast.models import (
    PodcastEpisode,
    PodcastPlaybackState,
    TranscriptionTask,
)
from app.domains.podcast.repositories import PodcastSubscriptionRepository
from app.domains.podcast.services.daily_report_service import DailyReportService
from app.domains.podcast.services.search_service import PodcastSearchService
from app.domains.podcast.services.sync_service import PodcastSyncService
from app.domains.podcast.services.transcription_workflow_service import (
    TranscriptionWorkflowService,
)
from app.domains.podcast.transcription_state import get_transcription_state_manager
from app.domains.subscription.models import (
    Subscription,
    SubscriptionStatus,
    UserSubscription,
)
from app.domains.user.models import User, UserStatus


logger = logging.getLogger(__name__)


class PodcastTaskOrchestrationService:
    """Orchestrate all background (Celery) task workflows."""

    def __init__(self, session: AsyncSession):
        self.session = session
        self.redis = get_shared_redis()

    # ── Feed sync ──────────────────────────────────────────────────────────

    async def refresh_all_podcast_feeds(self) -> dict:
        repo = PodcastSubscriptionRepository(self.session)
        sub_stmt = select(Subscription).where(
            and_(
                Subscription.source_type == "podcast-rss",
                Subscription.status == SubscriptionStatus.ACTIVE.value,
            )
        )
        sub_rows = await self.session.execute(sub_stmt)
        all_subscriptions = list(sub_rows.scalars().all())

        user_sub_stmt = (
            select(UserSubscription)
            .join(Subscription, UserSubscription.subscription_id == Subscription.id)
            .where(
                and_(
                    Subscription.source_type == "podcast-rss",
                    Subscription.status == SubscriptionStatus.ACTIVE.value,
                    UserSubscription.is_archived == False,  # noqa: E712
                )
            )
        )
        user_sub_rows = await self.session.execute(user_sub_stmt)
        user_subscriptions = list(user_sub_rows.scalars().all())

        subscriptions_to_update: set[int] = {
            item.subscription_id
            for item in user_subscriptions
            if item.should_update_now()
        }
        if not subscriptions_to_update:
            return {
                "status": "success",
                "refreshed_subscriptions": 0,
                "new_episodes": 0,
                "processed_at": datetime.now(UTC).isoformat(),
            }

        subscriptions_by_id = {sub.id: sub for sub in all_subscriptions}
        user_subscriptions_by_id = {
            user_sub.subscription_id: user_sub for user_sub in user_subscriptions
        }

        refreshed_count = 0
        new_episodes_count = 0

        for subscription_id in subscriptions_to_update:
            subscription = subscriptions_by_id.get(subscription_id)
            if subscription is None:
                continue

            user_sub = user_subscriptions_by_id.get(subscription_id)
            user_id = user_sub.user_id if user_sub else 1
            parser = SecureRSSParser(user_id)

            try:
                success, feed, error = await parser.fetch_and_parse_feed(
                    subscription.source_url
                )
                if not success:
                    logger.error(
                        "Failed refreshing subscription %s (%s): %s",
                        subscription.id,
                        subscription.title,
                        error,
                    )
                    continue

                sync_service = PodcastSyncService(self.session, user_id)
                refreshed_at = datetime.now(UTC).isoformat()
                episodes_payload = [
                    {
                        "title": episode.title,
                        "description": episode.description,
                        "audio_url": episode.audio_url,
                        "published_at": episode.published_at,
                        "audio_duration": episode.duration,
                        "transcript_url": episode.transcript_url,
                        "item_link": episode.link,
                        "metadata": {
                            "feed_title": feed.title,
                            "refreshed_at": refreshed_at,
                        },
                    }
                    for episode in feed.episodes
                ]
                _, new_episode_rows = await repo.create_or_update_episodes_batch(
                    subscription_id=subscription.id,
                    episodes_data=episodes_payload,
                )
                new_episodes = len(new_episode_rows)
                for saved_episode in new_episode_rows:
                    last_fetched = subscription.last_fetched_at

                    # Ensure both datetimes are timezone-aware before comparison
                    from app.core.datetime_utils import ensure_timezone_aware_fetch_time

                    # Normalize last_fetched to UTC if it exists
                    if last_fetched:
                        last_fetched = ensure_timezone_aware_fetch_time(last_fetched)

                    # Normalize published_at to UTC (handle both naive and aware cases)
                    published_at = saved_episode.published_at
                    if published_at.tzinfo is None:
                        published_at = ensure_timezone_aware_fetch_time(published_at)

                    if last_fetched and published_at > last_fetched:
                        await sync_service.trigger_transcription(saved_episode.id)
                    else:
                        logger.info(
                            "Episode %s (published: %s) is old (last fetch: %s), skipping auto-processing",
                            saved_episode.id,
                            published_at,
                            subscription.last_fetched_at,
                        )

                await repo.update_subscription_fetch_time(
                    subscription.id,
                    feed.last_fetched,
                )

                refreshed_count += 1
                new_episodes_count += new_episodes
                if new_episodes:
                    logger.info(
                        "Refreshed subscription %s (%s), %s new episodes",
                        subscription.id,
                        subscription.title,
                        new_episodes,
                    )
            except Exception:
                logger.exception(
                    "Unexpected failure during refresh for subscription %s",
                    subscription_id,
                )
            finally:
                await parser.close()

        return {
            "status": "success",
            "refreshed_subscriptions": refreshed_count,
            "new_episodes": new_episodes_count,
            "processed_at": datetime.now(UTC).isoformat(),
        }

    async def process_opml_subscription_episodes(
        self,
        *,
        subscription_id: int,
        user_id: int,
        source_url: str,
    ) -> dict:
        repo = PodcastSubscriptionRepository(self.session)
        parser = SecureRSSParser(user_id)

        try:
            success, feed, error = await parser.fetch_and_parse_feed(source_url)
            if not success:
                logger.warning(
                    "OPML background parse failed for subscription=%s, url=%s: %s",
                    subscription_id,
                    source_url,
                    error,
                )
                return {
                    "status": "error",
                    "subscription_id": subscription_id,
                    "source_url": source_url,
                    "error": error,
                }

            episodes_payload = [
                {
                    "title": episode.title,
                    "description": episode.description,
                    "audio_url": episode.audio_url,
                    "published_at": episode.published_at,
                    "audio_duration": episode.duration,
                    "transcript_url": episode.transcript_url,
                    "item_link": episode.link,
                    "metadata": {
                        "feed_title": feed.title,
                        "imported_via_opml": True,
                        "opml_background_parsed_at": datetime.now(
                            UTC
                        ).isoformat(),
                    },
                }
                for episode in feed.episodes
            ]

            _, new_episodes = await repo.create_or_update_episodes_batch(
                subscription_id=subscription_id,
                episodes_data=episodes_payload,
            )

            metadata = {
                "author": feed.author,
                "language": feed.language,
                "categories": feed.categories,
                "explicit": feed.explicit,
                "image_url": feed.image_url,
                "podcast_type": feed.podcast_type,
                "link": feed.link,
                "total_episodes": len(feed.episodes),
                "platform": feed.platform,
            }
            await repo.update_subscription_metadata(subscription_id, metadata)
            await repo.update_subscription_fetch_time(
                subscription_id, feed.last_fetched
            )

            return {
                "status": "success",
                "subscription_id": subscription_id,
                "source_url": source_url,
                "processed_episodes": len(episodes_payload),
                "new_episodes": len(new_episodes),
            }
        finally:
            await parser.close()

    # ── Transcription orchestration ────────────────────────────────────────

    async def process_audio_transcription_task(
        self,
        *,
        task_id: int,
        config_db_id: int | None = None,
    ) -> dict:
        workflow = self._build_transcription_workflow()
        return await workflow.execute_transcription_task(
            task_id,
            config_db_id=config_db_id,
        )

    async def trigger_episode_transcription_pipeline(
        self,
        *,
        episode_id: int,
        user_id: int,
    ) -> dict:
        workflow = self._build_transcription_workflow()
        return await workflow.trigger_episode_pipeline(
            episode_id,
            user_id=user_id,
            episode_lookup=self._lookup_episode,
        )

    def _build_transcription_workflow(self) -> TranscriptionWorkflowService:
        return TranscriptionWorkflowService(
            self.session,
            sync_service_factory=PodcastSyncService,
            state_manager_factory=get_transcription_state_manager,
            redis_factory=lambda: self.redis,
            claim_dispatched=self._claim_dispatched,
            clear_dispatched=self._clear_dispatched,
        )

    async def _clear_dispatched(self, task_id: int) -> None:
        key = f"podcast:transcription:dispatched:{task_id}"
        await self.redis.delete_keys(key)

    async def _claim_dispatched(self, session: AsyncSession, task_id: int) -> bool:
        key = f"podcast:transcription:dispatched:{task_id}"
        if await self.redis.set_if_not_exists(key, "1", ttl=7200):
            return True

        status_stmt = select(TranscriptionTask.status).where(
            TranscriptionTask.id == task_id
        )
        status_result = await session.execute(status_stmt)
        status_obj = status_result.scalar_one_or_none()
        task_status_value = (
            status_obj.value if hasattr(status_obj, "value") else str(status_obj)
        )
        if task_status_value in {"completed", "failed", "cancelled"}:
            return False
        raise RuntimeError(
            f"Task {task_id} dispatch key exists while task status={task_status_value}"
        )

    async def _lookup_episode(self, episode_id: int) -> PodcastEpisode | None:
        stmt = select(PodcastEpisode).where(PodcastEpisode.id == episode_id)
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    # ── Reporting ──────────────────────────────────────────────────────────

    async def generate_daily_reports(self, *, target_date=None) -> dict:
        users_stmt = (
            select(UserSubscription.user_id)
            .join(Subscription, UserSubscription.subscription_id == Subscription.id)
            .where(
                and_(
                    Subscription.source_type == "podcast-rss",
                    Subscription.status == SubscriptionStatus.ACTIVE.value,
                    UserSubscription.is_archived == False,  # noqa: E712
                )
            )
            .distinct()
        )
        user_ids = list((await self.session.execute(users_stmt)).scalars().all())

        success_count = 0
        failed_count = 0
        for user_id in user_ids:
            try:
                service = DailyReportService(self.session, user_id=user_id)
                await service.generate_daily_report(target_date=target_date)
                success_count += 1
            except Exception:
                failed_count += 1
                logger.exception("Failed to generate daily report for user=%s", user_id)
                await self.session.rollback()

        return {
            "status": "success",
            "processed_users": len(user_ids),
            "successful_users": success_count,
            "failed_users": failed_count,
            "report_date": target_date.isoformat() if target_date else None,
            "processed_at": datetime.now(UTC).isoformat(),
        }

    # ── Maintenance ────────────────────────────────────────────────────────

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
            "logged_at": datetime.now(UTC).isoformat(),
        }

    async def cleanup_old_playback_states(self) -> dict:
        cutoff_date = datetime.now(UTC) - timedelta(days=90)
        stmt = delete(PodcastPlaybackState).where(
            PodcastPlaybackState.last_updated_at < cutoff_date
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

    async def process_pending_transcriptions(self) -> dict:
        if not settings.TRANSCRIPTION_BACKLOG_ENABLED:
            return {
                "status": "skipped",
                "reason": "backlog_transcription_disabled",
                "processed_at": datetime.now(UTC).isoformat(),
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
                "processed_at": datetime.now(UTC).isoformat(),
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
                "processed_at": datetime.now(UTC).isoformat(),
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
            "processed_at": datetime.now(UTC).isoformat(),
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
            "processed_at": datetime.now(UTC).isoformat(),
        }

    # ── Celery task enqueue helpers ────────────────────────────────────────

    def enqueue_opml_subscription_episodes(self, **kwargs) -> Any:
        """Queue OPML episode parsing without exposing Celery task imports."""
        from app.domains.podcast.tasks.opml_import import (
            process_opml_subscription_episodes,
        )

        return process_opml_subscription_episodes.delay(**kwargs)

    def enqueue_audio_transcription(
        self,
        task_id: int,
        config_db_id: int | None = None,
    ) -> Any:
        """Queue a transcription worker task without exposing Celery imports."""
        from app.domains.podcast.tasks.transcription import process_audio_transcription

        return process_audio_transcription.delay(task_id, config_db_id)

    def enqueue_episode_processing(
        self,
        *,
        episode_id: int,
        user_id: int,
    ) -> Any:
        """Queue the episode transcription/summary pipeline."""
        from app.domains.podcast.tasks.transcription import (
            process_podcast_episode_with_transcription,
        )

        return process_podcast_episode_with_transcription.delay(episode_id, user_id)
