"""Podcast background task orchestration service -- thin facade.

Delegates to four focused orchestrators (merged from orchestration/ package):
- FeedSyncOrchestrator      -- RSS feed refresh and OPML parsing
- TranscriptionOrchestrator -- transcription dispatch and execution
- ReportOrchestrator        -- daily report generation
- MaintenanceOrchestrator   -- statistics, cleanup, housekeeping

The public API is preserved so that all Celery task handlers and tests
continue to import ``PodcastTaskOrchestrationService`` unchanged.
"""

from __future__ import annotations

import asyncio
import logging
from datetime import UTC, datetime, timedelta
from typing import Any

import aiohttp
from sqlalchemy import and_, delete, exists, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload

from app.admin.storage_service import StorageCleanupService
from app.core.config import settings
from app.core.database import get_async_session_factory  # noqa: F401
from app.core.datetime_utils import ensure_timezone_aware_fetch_time
from app.core.redis import CacheTTL, get_shared_redis
from app.domains.podcast.integration.secure_rss_parser import (
    SecureRSSParser,  # noqa: F401
)
from app.domains.podcast.models import (
    PodcastEpisode,
    PodcastEpisodeTranscript,
    PodcastPlaybackState,
    Subscription,
    SubscriptionStatus,
    TranscriptionTask,
    UserSubscription,
)
from app.domains.podcast.repositories import PodcastSubscriptionRepository  # noqa: F401
from app.domains.podcast.services.content_service import DailyReportService
from app.domains.podcast.services.transcription_service import (  # noqa: F401
    TranscriptionWorkflowService,
)
from app.domains.podcast.transcription_state import get_transcription_state_manager
from app.domains.podcast.utils.status_helpers import status_value


logger = logging.getLogger(__name__)


# ── Base orchestrator (merged from orchestration/base.py) ──


class BaseOrchestrator:
    """Common infrastructure shared across all orchestrators."""

    def __init__(self, session: AsyncSession):
        self.session = session
        self.redis = get_shared_redis()

    async def lookup_episode(self, episode_id: int) -> PodcastEpisode | None:
        """Look up a single episode by ID."""
        stmt = select(PodcastEpisode).where(PodcastEpisode.id == episode_id)
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()


# ── Feed sync orchestrator (merged from orchestration/feed_sync.py) ──


class FeedSyncOrchestrator(BaseOrchestrator):
    """Orchestrate RSS feed refresh and OPML episode parsing tasks."""

    _refresh_batch_size = 100

    async def refresh_all_podcast_feeds(self) -> dict:
        refreshed_count = 0
        new_episodes_count = 0
        pending_transcription_episode_ids: list[int] = []
        next_subscription_id = 0
        concurrency = max(1, settings.RSS_REFRESH_CONCURRENCY)

        while True:
            candidates, next_subscription_id = await self._load_due_refresh_candidates(
                after_subscription_id=next_subscription_id,
                limit=self._refresh_batch_size,
            )
            if not candidates and next_subscription_id is None:
                break
            if not candidates:
                continue

            batch_result = await self._refresh_due_subscription_batch(
                candidates,
                concurrency=concurrency,
            )
            refreshed_count += batch_result["refreshed_subscriptions"]
            new_episodes_count += batch_result["new_episodes"]
            pending_transcription_episode_ids.extend(
                batch_result["transcription_episode_ids"],
            )

            if next_subscription_id is None:
                break

        if pending_transcription_episode_ids:
            transcription = TranscriptionOrchestrator(self.session)
            workflow = transcription.build_transcription_workflow()
            dispatch_result = await workflow.dispatch_pending_transcriptions(
                pending_transcription_episode_ids,
            )
            logger.info(
                "Feed refresh transcription dispatch completed: checked=%s dispatched=%s skipped=%s failed=%s",
                dispatch_result["checked"],
                dispatch_result["dispatched"],
                dispatch_result["skipped"],
                dispatch_result["failed"],
            )

        return {
            "status": "success",
            "refreshed_subscriptions": refreshed_count,
            "new_episodes": new_episodes_count,
            "processed_at": datetime.now(UTC).isoformat(),
        }

    async def _load_due_refresh_candidates(
        self,
        *,
        after_subscription_id: int,
        limit: int,
    ) -> tuple[list[dict[str, Any]], int | None]:
        sub_stmt = (
            select(Subscription)
            .where(
                and_(
                    Subscription.source_type == "podcast-rss",
                    Subscription.status == SubscriptionStatus.ACTIVE.value,
                    Subscription.id > after_subscription_id,
                ),
            )
            .order_by(Subscription.id.asc())
            .limit(limit)
        )
        sub_rows = await self.session.execute(sub_stmt)
        subscriptions = list(sub_rows.scalars().all())
        if not subscriptions:
            return [], None

        subscription_ids = [subscription.id for subscription in subscriptions]
        user_sub_stmt = (
            select(UserSubscription)
            .options(joinedload(UserSubscription.subscription))
            .where(
                and_(
                    UserSubscription.subscription_id.in_(subscription_ids),
                    UserSubscription.is_archived.is_(False),
                ),
            )
            .order_by(UserSubscription.subscription_id.asc(), UserSubscription.id.asc())
        )
        user_sub_rows = await self.session.execute(user_sub_stmt)
        user_subscriptions = list(user_sub_rows.scalars().all())

        due_candidates: list[dict[str, Any]] = []
        seen_subscription_ids: set[int] = set()
        for user_subscription in user_subscriptions:
            if user_subscription.subscription_id in seen_subscription_ids:
                continue
            if not user_subscription.should_update_now():
                continue

            seen_subscription_ids.add(user_subscription.subscription_id)
            due_candidates.append(
                {
                    "subscription_id": user_subscription.subscription_id,
                    "user_id": user_subscription.user_id,
                },
            )

        next_cursor = subscriptions[-1].id if len(subscriptions) >= limit else None
        return due_candidates, next_cursor

    async def _refresh_due_subscription_batch(
        self,
        candidates: list[dict[str, Any]],
        *,
        concurrency: int,
    ) -> dict[str, Any]:
        semaphore = asyncio.Semaphore(concurrency)
        timeout = aiohttp.ClientTimeout(total=60, connect=10)
        connector = aiohttp.TCPConnector(limit=concurrency, limit_per_host=concurrency)
        headers = {
            "User-Agent": (
                "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
                "(KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36"
            ),
        }

        async with aiohttp.ClientSession(
            timeout=timeout,
            connector=connector,
            headers=headers,
        ) as http_session:

            async def _run_candidate(candidate: dict[str, Any]) -> dict[str, Any]:
                async with semaphore:
                    return await self._refresh_single_subscription(
                        candidate,
                        http_session=http_session,
                    )

            results = await asyncio.gather(
                *[_run_candidate(candidate) for candidate in candidates],
                return_exceptions=True,
            )

        refreshed_subscriptions = 0
        new_episodes = 0
        transcription_episode_ids: list[int] = []
        for candidate, result in zip(candidates, results, strict=False):
            if isinstance(result, Exception):
                logger.exception(
                    "Unexpected failure during refresh for subscription %s",
                    candidate["subscription_id"],
                    exc_info=result,
                )
                continue

            refreshed_subscriptions += result["refreshed"]
            new_episodes += result["new_episodes"]
            transcription_episode_ids.extend(result["transcription_episode_ids"])

        return {
            "refreshed_subscriptions": refreshed_subscriptions,
            "new_episodes": new_episodes,
            "transcription_episode_ids": transcription_episode_ids,
        }

    async def _refresh_single_subscription(
        self,
        candidate: dict[str, Any],
        *,
        http_session: aiohttp.ClientSession,
    ) -> dict[str, Any]:
        subscription_id = int(candidate["subscription_id"])
        user_id = int(candidate["user_id"])

        session_factory = get_async_session_factory()
        async with session_factory() as session:
            repo = PodcastSubscriptionRepository(session)
            subscription = await repo.get_subscription_by_id_direct(subscription_id)
            if subscription is None:
                return {
                    "refreshed": 0,
                    "new_episodes": 0,
                    "transcription_episode_ids": [],
                }

            parser = SecureRSSParser(user_id=user_id, shared_session=http_session)
            try:
                success, feed, error = await parser.fetch_and_parse_feed(
                    subscription.source_url,
                    max_episodes=settings.PODCAST_EPISODE_BATCH_SIZE,
                    newer_than=subscription.last_fetched_at,
                )
                if not success or feed is None:
                    logger.error(
                        "Failed refreshing subscription %s (%s): %s",
                        subscription.id,
                        subscription.title,
                        error,
                    )
                    return {
                        "refreshed": 0,
                        "new_episodes": 0,
                        "transcription_episode_ids": [],
                    }

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

                last_fetched = ensure_timezone_aware_fetch_time(
                    subscription.last_fetched_at,
                )
                transcription_episode_ids: list[int] = []
                for saved_episode in new_episode_rows:
                    published_at = ensure_timezone_aware_fetch_time(
                        saved_episode.published_at,
                    )
                    if last_fetched and published_at and published_at > last_fetched:
                        transcription_episode_ids.append(saved_episode.id)

                await repo.update_subscription_fetch_time(
                    subscription.id,
                    feed.last_fetched,
                )

                if new_episode_rows:
                    logger.info(
                        "Refreshed subscription %s (%s), %s new episodes",
                        subscription.id,
                        subscription.title,
                        len(new_episode_rows),
                    )

                return {
                    "refreshed": 1,
                    "new_episodes": len(new_episode_rows),
                    "transcription_episode_ids": transcription_episode_ids,
                }
            finally:
                await parser.close()

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
                            UTC,
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
                subscription_id,
                feed.last_fetched,
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


# ── Transcription orchestrator (merged from orchestration/transcription.py) ──


class TranscriptionOrchestrator(BaseOrchestrator):
    """Orchestrate transcription task dispatch and execution."""

    async def process_audio_transcription_task(
        self,
        *,
        task_id: int,
        config_db_id: int | None = None,
    ) -> dict:
        workflow = self.build_transcription_workflow()
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
        workflow = self.build_transcription_workflow()
        return await workflow.trigger_episode_pipeline(
            episode_id,
            user_id=user_id,
            episode_lookup=self.lookup_episode,
        )

    def build_transcription_workflow(self) -> TranscriptionWorkflowService:
        """Build a TranscriptionWorkflowService wired with claim/clear helpers."""
        return TranscriptionWorkflowService(
            self.session,
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
        if await self.redis.set_if_not_exists(key, "1", ttl=CacheTTL.hours(2)):
            return True

        status_stmt = select(TranscriptionTask.status).where(
            TranscriptionTask.id == task_id,
        )
        status_result = await session.execute(status_stmt)
        status_obj = status_result.scalar_one_or_none()
        task_status_value = status_value(status_obj)
        if task_status_value in {"completed", "failed", "cancelled"}:
            return False
        raise RuntimeError(
            f"Task {task_id} dispatch key exists while task status={task_status_value}",
        )

    async def process_pending_transcriptions(self) -> dict:
        if not settings.TRANSCRIPTION_BACKLOG_ENABLED:
            return {
                "status": "skipped",
                "reason": "backlog_transcription_disabled",
                "processed_at": self._now_iso(),
            }

        active_user_subscription_exists = exists(
            select(1).where(
                and_(
                    UserSubscription.subscription_id == Subscription.id,
                    UserSubscription.is_archived.is_(False),
                ),
            ),
        )
        filters = [
            Subscription.source_type == "podcast-rss",
            Subscription.status == SubscriptionStatus.ACTIVE.value,
            active_user_subscription_exists,
            PodcastEpisode.audio_url.is_not(None),
            PodcastEpisode.audio_url != "",
            or_(
                ~PodcastEpisode.transcript.has(
                    PodcastEpisodeTranscript.transcript_content.is_not(None),
                ),
                PodcastEpisode.transcript.has(
                    PodcastEpisodeTranscript.transcript_content == "",
                ),
            ),
            or_(
                TranscriptionTask.id.is_(None),
                TranscriptionTask.status.in_(["failed", "cancelled"]),
            ),
        ]

        batch_size = max(1, settings.TRANSCRIPTION_BACKLOG_BATCH_SIZE)
        id_stmt = (
            select(PodcastEpisode.id, PodcastEpisode.published_at)
            .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
            .outerjoin(
                TranscriptionTask,
                TranscriptionTask.episode_id == PodcastEpisode.id,
            )
            .where(and_(*filters))
            .order_by(PodcastEpisode.published_at.desc(), PodcastEpisode.id.desc())
            .limit(batch_size)
            .with_for_update(skip_locked=True, of=PodcastEpisode)
        )
        rows = await self.session.execute(id_stmt)
        episode_ids = [row[0] for row in rows.all()]
        total_candidates = len(episode_ids)
        if not episode_ids:
            return {
                "status": "success",
                "total_candidates": 0,
                "checked": 0,
                "dispatched": 0,
                "skipped": 0,
                "failed": 0,
                "skipped_reasons": {},
                "processed_at": self._now_iso(),
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
            "processed_at": self._now_iso(),
        }

    @staticmethod
    def _now_iso() -> str:
        return datetime.now(UTC).isoformat()

    # -- Celery task enqueue helpers --

    def enqueue_audio_transcription(
        self,
        task_id: int,
        config_db_id: int | None = None,
    ) -> Any:
        """Queue a transcription worker task without exposing Celery imports."""
        from app.domains.podcast.tasks.tasks_transcription import (
            process_audio_transcription,
        )

        return process_audio_transcription.delay(task_id, config_db_id)

    def enqueue_episode_processing(
        self,
        *,
        episode_id: int,
        user_id: int,
    ) -> Any:
        """Queue the episode transcription/summary pipeline."""
        from app.domains.podcast.tasks.tasks_transcription import (
            process_podcast_episode_with_transcription,
        )

        return process_podcast_episode_with_transcription.delay(episode_id, user_id)


# ── Report orchestrator (merged from orchestration/report.py) ──


class ReportOrchestrator(BaseOrchestrator):
    """Orchestrate daily report generation tasks."""

    async def generate_daily_reports(self, *, target_date=None) -> dict:
        """Generate daily reports for all podcast users."""
        batch_size = max(1, settings.TASK_ORCHESTRATION_USER_BATCH_SIZE)
        max_concurrent = min(10, batch_size)
        last_user_id = 0
        processed_users = 0
        success_count = 0
        failed_count = 0

        semaphore = asyncio.Semaphore(max_concurrent)

        async def process_user_report(user_id: int) -> bool:
            async with semaphore:
                try:
                    session_factory = get_async_session_factory()
                    async with session_factory() as session:
                        service = DailyReportService(session, user_id=user_id)
                        await service.generate_daily_report(target_date=target_date)
                        return True
                except (aiohttp.ClientError, TimeoutError, ValueError, RuntimeError, OSError):
                    logger.exception(
                        "Failed to generate daily report for user=%s",
                        user_id,
                    )
                    return False

        while True:
            users_stmt = (
                select(UserSubscription.user_id)
                .join(Subscription, UserSubscription.subscription_id == Subscription.id)
                .where(
                    and_(
                        Subscription.source_type == "podcast-rss",
                        Subscription.status == SubscriptionStatus.ACTIVE.value,
                        UserSubscription.is_archived == False,  # noqa: E712
                        UserSubscription.user_id > last_user_id,
                    ),
                )
                .distinct()
                .order_by(UserSubscription.user_id.asc())
                .limit(batch_size)
            )
            user_ids = list((await self.session.execute(users_stmt)).scalars().all())
            if not user_ids:
                break

            results = await asyncio.gather(
                *[process_user_report(user_id) for user_id in user_ids],
                return_exceptions=True,
            )

            for result in results:
                if isinstance(result, Exception):
                    failed_count += 1
                elif result is True:
                    success_count += 1
                else:
                    failed_count += 1

            processed_users += len(user_ids)
            last_user_id = user_ids[-1]

        return {
            "status": "success",
            "processed_users": processed_users,
            "successful_users": success_count,
            "failed_users": failed_count,
            "report_date": target_date.isoformat() if target_date else None,
            "processed_at": datetime.now(UTC).isoformat(),
        }


# ── Maintenance orchestrator (merged from orchestration/maintenance.py) ──


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


# ── Podcast task orchestration facade ──


class PodcastTaskOrchestrationService:
    """Facade that delegates to four focused orchestrators.

    All public methods forward to the corresponding orchestrator so that
    existing Celery task handler imports remain unchanged.
    """

    _refresh_batch_size = 100  # preserved for test compatibility

    def __init__(self, session: AsyncSession):
        self.session = session
        self.redis = get_shared_redis()
        self._feed_sync = FeedSyncOrchestrator(session)
        self._transcription = TranscriptionOrchestrator(session)
        self._report = ReportOrchestrator(session)
        self._maintenance = MaintenanceOrchestrator(session)

    # ── Feed sync ──────────────────────────────────────────────────────────

    async def refresh_all_podcast_feeds(self) -> dict:
        return await self._feed_sync.refresh_all_podcast_feeds()

    async def _load_due_refresh_candidates(self, **kwargs):
        return await self._feed_sync._load_due_refresh_candidates(**kwargs)

    async def process_opml_subscription_episodes(self, **kwargs) -> dict:
        return await self._feed_sync.process_opml_subscription_episodes(**kwargs)

    # ── Transcription orchestration ────────────────────────────────────────

    async def process_audio_transcription_task(self, **kwargs) -> dict:
        return await self._transcription.process_audio_transcription_task(**kwargs)

    async def trigger_episode_transcription_pipeline(self, **kwargs) -> dict:
        return await self._transcription.trigger_episode_transcription_pipeline(
            **kwargs,
        )

    def _build_transcription_workflow(self):
        return self._transcription.build_transcription_workflow()

    # ── Reporting ──────────────────────────────────────────────────────────

    async def generate_daily_reports(self, **kwargs) -> dict:
        return await self._report.generate_daily_reports(**kwargs)

    # ── Maintenance ────────────────────────────────────────────────────────

    async def get_task_statistics(self) -> dict:
        return await self._maintenance.get_task_statistics()

    async def log_periodic_task_statistics(self) -> dict:
        return await self._maintenance.log_periodic_task_statistics()

    async def cleanup_old_playback_states(self) -> dict:
        return await self._maintenance.cleanup_old_playback_states()

    async def cleanup_old_transcription_temp_files(self, **kwargs) -> dict:
        return await self._maintenance.cleanup_old_transcription_temp_files(**kwargs)

    async def auto_cleanup_cache_files(self) -> dict:
        return await self._maintenance.auto_cleanup_cache_files()

    async def process_pending_transcriptions(self) -> dict:
        return await self._transcription.process_pending_transcriptions()

    # ── Celery task enqueue helpers ────────────────────────────────────────

    def enqueue_opml_subscription_episodes(self, **kwargs) -> Any:
        return self._maintenance.enqueue_opml_subscription_episodes(**kwargs)

    def enqueue_audio_transcription(
        self,
        task_id: int,
        config_db_id: int | None = None,
    ) -> Any:
        return self._transcription.enqueue_audio_transcription(
            task_id,
            config_db_id,
        )

    def enqueue_episode_processing(self, **kwargs) -> Any:
        return self._transcription.enqueue_episode_processing(**kwargs)

    # ── Shared utilities (preserved for test monkeypatching) ───────────────

    async def _lookup_episode(self, episode_id: int):
        return await self._feed_sync.lookup_episode(episode_id)

    async def _claim_dispatched(self, session, task_id: int) -> bool:
        return await self._transcription._claim_dispatched(session, task_id)

    async def _clear_dispatched(self, task_id: int) -> None:
        await self._transcription._clear_dispatched(task_id)
