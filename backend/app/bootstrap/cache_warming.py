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

from app.core.redis import PodcastRedis, get_shared_redis
from app.domains.subscription.models import Subscription, SubscriptionStatus, UserSubscription
from app.domains.user.models import User, UserStatus


logger = logging.getLogger(__name__)

# Cache TTL settings
WARMED_CACHE_TTL_SECONDS = 3600  # 1 hour
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
        """Execute all cache warming strategies.

        Returns:
            Dictionary containing warm-up statistics.
        """
        logger.info("Starting cache warm-up...")
        start_time = datetime.now(UTC)

        try:
            # Run warm-up tasks concurrently
            await asyncio.gather(
                self._warm_active_users_subscriptions(),
                self._warm_popular_podcasts(),
                self._warm_system_settings(),
                return_exceptions=True,
            )

            duration = (datetime.now(UTC) - start_time).total_seconds()
            logger.info(
                "Cache warm-up completed in %.2fs: %s",
                duration,
                self._stats,
            )
            return self._stats
        except Exception as exc:
            logger.error("Fatal error during cache warm-up: %s", exc)
            self._stats["errors"].append(f"Fatal: {exc}")
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

            for user_id in user_ids:
                await self._warm_user_subscriptions(user_id)

            self._stats["users_warmed"] = len(user_ids)
            logger.info(
                "Warmed subscriptions for %d active users",
                len(user_ids),
            )
        except Exception as exc:
            logger.error("Error warming active users: %s", exc)
            self._stats["errors"].append(f"Active users: {exc}")

    async def _warm_user_subscriptions(self, user_id: int) -> None:
        """Warm up a single user's subscription list.

        Args:
            user_id: The user ID to warm subscriptions for.
        """
        try:
            # Get user's active subscriptions
            result = await self.db.execute(
                select(Subscription.id, Subscription.title, Subscription.source_url)
                .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
                .where(
                    UserSubscription.user_id == user_id,
                    UserSubscription.is_archived.is_(False),
                    Subscription.status == SubscriptionStatus.ACTIVE,
                )
                .order_by(Subscription.updated_at.desc())
            )
            subscriptions = result.all()

            if not subscriptions:
                return

            # Cache subscription list
            cache_key = f"podcast:subscriptions:{user_id}"
            subscription_data = [
                {"id": sub_id, "title": title, "source_url": url}
                for sub_id, title, url in subscriptions
            ]

            await self.redis.cache_set_json(
                cache_key,
                subscription_data,
                ttl=WARMED_CACHE_TTL_SECONDS,
            )
            self._stats["subscriptions_warmed"] += len(subscriptions)
        except Exception as exc:
            logger.debug("Failed to warm user %d subscriptions: %s", user_id, exc)

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
                .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
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
                await self._warm_podcast_metadata(podcast_data)

            self._stats["podcasts_warmed"] = len(podcasts)
            logger.info("Warmed metadata for %d popular podcasts", len(podcasts))
        except Exception as exc:
            logger.error("Error warming popular podcasts: %s", exc)
            self._stats["errors"].append(f"Popular podcasts: {exc}")

    async def _warm_podcast_metadata(self, podcast_data: tuple) -> None:
        """Warm up a single podcast's metadata.

        Args:
            podcast_data: Tuple containing podcast metadata.
        """
        try:
            podcast_id, title, description, image_url, source_url, _ = podcast_data

            # Cache podcast metadata
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
