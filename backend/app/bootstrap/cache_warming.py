"""Cache warming service for preloading hot data into Redis.

This module handles the preloading of frequently accessed data into
Redis cache during application startup to improve initial performance.
"""

import asyncio
import logging
from datetime import UTC, datetime, timedelta
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.cache_ttl import CacheTTL
from app.core.redis import PodcastRedis, get_shared_redis
from app.domains.subscription.models import (
    Subscription,
    SubscriptionStatus,
    UserSubscription,
)
from app.domains.user.models import User, UserStatus


logger = logging.getLogger(__name__)

# Cache TTL settings
WARMED_CACHE_TTL_SECONDS = CacheTTL.DEFAULT  # 1 hour
ACTIVE_USER_DAYS = 7  # Consider users active if they logged in within 7 days
MAX_ACTIVE_USERS_TO_WARM = 100  # Limit to avoid excessive memory usage
MAX_POPULAR_PODCASTS = 50  # Limit popular podcasts to warm


class CacheWarmupService:
    """Service for warming up Redis cache with frequently accessed data."""

    def __init__(self, db: AsyncSession, redis: PodcastRedis):
        self.db = db
        self.redis = redis
        self._stats: dict[str, Any] = {
            "users_warmed": 0,
            "subscriptions_warmed": 0,
            "podcasts_warmed": 0,
            "system_settings_warmed": 0,
            "errors": [],
        }

    async def warm_all(self) -> dict[str, Any]:
        """Execute all cache warming strategies with priority ordering.

        Priorities:
        1. System settings (highest - small, frequently accessed)
        2. Popular podcasts (medium - commonly viewed)
        3. User subscriptions (lower - user-specific, larger dataset)

        Returns:
            Dictionary containing warm-up statistics.
        """

        logger.info("Starting prioritized cache warm-up...")
        start_time = datetime.now(UTC)

        # Define warm-up tasks with priorities (lower number = higher priority)
        priorities = [
            (self._warm_system_settings, "system_settings", 30.0),
            (self._warm_popular_podcasts, "popular_podcasts", 45.0),
            (self._warm_active_users_subscriptions, "user_subscriptions", 60.0),
        ]

        for task_func, task_name, timeout_seconds in priorities:
            try:
                async with asyncio.timeout(timeout_seconds):
                    logger.debug("Starting cache warm-up task: %s", task_name)
                    task_start = datetime.now(UTC)
                    await task_func()
                    task_duration = (datetime.now(UTC) - task_start).total_seconds()
                    logger.info(
                        "Cache warm-up task '%s' completed in %.2fs",
                        task_name,
                        task_duration,
                    )
            except TimeoutError:
                logger.warning(
                    "Cache warm-up task '%s' timed out after %.1fs (continuing)",
                    task_name,
                    timeout_seconds,
                )
                self._stats["errors"].append(f"{task_name}: timeout")
            except Exception as exc:
                logger.error(
                    "Cache warm-up task '%s' failed: %s",
                    task_name,
                    exc,
                )
                self._stats["errors"].append(f"{task_name}: {exc}")

        duration = (datetime.now(UTC) - start_time).total_seconds()
        logger.info(
            "Prioritized cache warm-up completed in %.2fs: %s",
            duration,
            self._stats,
        )
        return self._stats

    async def _warm_active_users_subscriptions(self) -> None:
        """Warm up subscription lists for recently active users."""
        try:
            # Find active users (logged in within last N days)
            active_since = datetime.now(UTC) - timedelta(days=ACTIVE_USER_DAYS)
            result = await self.db.execute(
                select(User.id)
                .where(User.status == UserStatus.ACTIVE)
                .where(User.last_login_at >= active_since)
                .order_by(User.last_login_at.desc())
                .limit(MAX_ACTIVE_USERS_TO_WARM),
            )
            user_ids = [row[0] for row in result.all()]

            if not user_ids:
                logger.info("No active users found for cache warm-up")
                return

            logger.info("Warming subscriptions for %d active users", len(user_ids))

            # Batch query: fetch all subscriptions for all active users at once
            all_subs_result = await self.db.execute(
                select(
                    UserSubscription.user_id,
                    Subscription.id,
                    Subscription.title,
                    Subscription.source_url,
                )
                .join(Subscription, Subscription.id == UserSubscription.subscription_id)
                .where(
                    UserSubscription.user_id.in_(user_ids),
                    UserSubscription.is_archived.is_(False),
                    Subscription.status == SubscriptionStatus.ACTIVE,
                )
                .order_by(Subscription.updated_at.desc())
            )

            # Group subscriptions by user
            user_subs: dict[int, list[dict]] = {}
            for uid, sub_id, title, url in all_subs_result.all():
                user_subs.setdefault(uid, []).append(
                    {"id": sub_id, "title": title, "source_url": url}
                )

            # Batch write to Redis using pipeline
            for uid, subs in user_subs.items():
                try:
                    cache_key = f"podcast:subscriptions:{uid}"
                    await self.redis.cache_set_json(
                        cache_key,
                        subs,
                        ttl=WARMED_CACHE_TTL_SECONDS,
                    )
                    self._stats["subscriptions_warmed"] += len(subs)
                except Exception as exc:
                    logger.debug("Failed to warm user %d subscriptions: %s", uid, exc)

            self._stats["users_warmed"] = len(user_subs)
            logger.info(
                "Warmed subscriptions for %d active users",
                len(user_subs),
            )
        except Exception as exc:
            logger.error("Error warming active users: %s", exc)
            self._stats["errors"].append(f"Active users: {exc}")

    async def _warm_popular_podcasts(self) -> None:
        """Warm up metadata for the most popular podcasts.

        Popularity is determined by the number of subscribers.
        """
        try:
            # Get podcasts with most subscribers
            result = await self.db.execute(
                select(
                    Subscription.id,
                    Subscription.title,
                    Subscription.description,
                    Subscription.image_url,
                    Subscription.source_url,
                    func.count(UserSubscription.user_id).label("subscriber_count"),
                )
                .join(
                    UserSubscription,
                    UserSubscription.subscription_id == Subscription.id,
                )
                .where(
                    Subscription.status == SubscriptionStatus.ACTIVE,
                    UserSubscription.is_archived.is_(False),
                )
                .group_by(Subscription.id)
                .order_by(func.count(UserSubscription.user_id).desc())
                .limit(MAX_POPULAR_PODCASTS),
            )
            podcasts = result.all()

            if not podcasts:
                logger.info("No popular podcasts found for cache warm-up")
                return

            logger.info("Warming metadata for %d popular podcasts", len(podcasts))

            for podcast_data in podcasts:
                try:
                    podcast_id, title, description, image_url, source_url, _ = podcast_data
                    cache_key = f"podcast:meta:{podcast_id}"
                    metadata = {
                        "id": podcast_id,
                        "title": title,
                        "description": description,
                        "image_url": image_url,
                        "source_url": source_url,
                    }
                    await self.redis.cache_set_json(
                        cache_key,
                        metadata,
                        ttl=WARMED_CACHE_TTL_SECONDS,
                    )
                except Exception as exc:
                    logger.debug("Failed to warm podcast %d: %s", podcast_data[0], exc)

            self._stats["podcasts_warmed"] = len(podcasts)
            logger.info("Warmed metadata for %d popular podcasts", len(podcasts))
        except Exception as exc:
            logger.error("Error warming popular podcasts: %s", exc)
            self._stats["errors"].append(f"Popular podcasts: {exc}")

    async def _warm_system_settings(self) -> None:
        """Warm up frequently accessed system settings.

        This includes RSS frequency settings and other common config.
        """
        try:
            from app.admin.models import SystemSettings

            # Get common settings keys
            common_keys = [
                "rss.frequency_settings",
                "audio.default_playback_rate",
                "ai.transcription_enabled",
                "ai.summary_enabled",
            ]

            result = await self.db.execute(
                select(SystemSettings).where(SystemSettings.key.in_(common_keys))
            )
            settings = result.scalars().all()

            for setting in settings:
                # Cache individual setting
                cache_key = f"system:setting:{setting.key}"
                await self.redis.cache_set_json(
                    cache_key,
                    setting.value,
                    ttl=WARMED_CACHE_TTL_SECONDS,
                )

            self._stats["system_settings_warmed"] = len(settings)
            logger.info("Warmed %d system settings", len(settings))
        except Exception as exc:
            logger.error("Error warming system settings: %s", exc)
            self._stats["errors"].append(f"System settings: {exc}")


async def execute_cache_warmup(db_factory) -> dict[str, Any]:
    """Execute cache warm-up using the provided database session factory.

    This function is designed to be called during application startup.

    Args:
        db_factory: Async session factory for database access.

    Returns:
        Dictionary containing warm-up statistics.
    """
    redis = get_shared_redis()
    async with db_factory() as session:
        service = CacheWarmupService(session, redis)
        return await service.warm_all()
