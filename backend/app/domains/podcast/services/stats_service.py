"""Podcast stats service.

Provides aggregated user-level podcast stats and cache handling.
"""

import logging
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.redis import PodcastRedis
from app.domains.podcast.repositories import PodcastStatsRepository
from app.domains.podcast.services.cache_utils import (
    safe_cache_get,
    safe_cache_invalidate,
    safe_cache_write,
)
from app.domains.podcast.services.playback_service import PodcastPlaybackService


logger = logging.getLogger(__name__)


class PodcastStatsService:
    """Service for user podcast statistics."""

    def __init__(
        self,
        db: AsyncSession,
        user_id: int,
        *,
        repo: PodcastStatsRepository | None = None,
        redis: PodcastRedis | None = None,
        playback_service: PodcastPlaybackService | None = None,
    ):
        self.db = db
        self.user_id = user_id
        self.repo = repo or PodcastStatsRepository(db)
        self.playback_service = playback_service or PodcastPlaybackService(db, user_id)
        self.redis = redis or PodcastRedis()

    async def get_user_stats(self) -> dict[str, Any]:
        """Get cached/aggregated user stats with playback context."""
        cached = await safe_cache_get(
            lambda: self.redis.get_user_stats(self.user_id),
            log_warning=logger.warning,
            error_message="Redis cache read failed for user stats, skipping cache",
        )
        if cached:
            logger.info("Cache HIT for user stats: user_id=%s", self.user_id)
            return cached

        logger.info("Cache MISS for user stats: user_id=%s", self.user_id)

        stats = await self.repo.get_user_stats_aggregated(self.user_id)

        try:
            recently_played = await self.playback_service.get_recently_played(limit=5)
        except Exception:
            logger.warning("Failed to get recently played, defaulting to empty list")
            recently_played = []

        try:
            listening_streak = await self.playback_service.calculate_listening_streak()
        except Exception:
            logger.warning("Failed to calculate listening streak, defaulting to 0")
            listening_streak = 0

        result = {
            **stats,
            "recently_played": recently_played,
            "top_categories": [],
            "listening_streak": listening_streak,
        }

        await safe_cache_write(
            lambda: self.redis.set_user_stats(self.user_id, result),
            log_warning=logger.warning,
            error_message="Redis cache write failed for user stats, skipping cache",
        )

        return result

    async def get_profile_stats(self) -> dict[str, Any]:
        """Get lightweight profile stats for profile page cards."""
        cached = await safe_cache_get(
            lambda: self.redis.get_profile_stats(self.user_id),
            log_warning=logger.warning,
            error_message="Redis cache read failed for profile stats, skipping cache",
        )
        if cached:
            logger.info("Cache HIT for profile stats: user_id=%s", self.user_id)
            return cached

        logger.info("Cache MISS for profile stats: user_id=%s", self.user_id)
        result = await self.repo.get_profile_stats_aggregated(self.user_id)

        await safe_cache_write(
            lambda: self.redis.set_profile_stats(self.user_id, result),
            log_warning=logger.warning,
            error_message="Redis cache write failed for profile stats, skipping cache",
        )

        return result

    async def invalidate_cached_stats(self) -> None:
        """Invalidate user stats/profile stats caches."""
        await safe_cache_invalidate(
            lambda: self.redis.invalidate_user_stats(self.user_id),
            log_warning=logger.warning,
            error_message=f"Redis user stats cache invalidation failed for user_id={self.user_id}",
        )
        await safe_cache_invalidate(
            lambda: self.redis.invalidate_profile_stats(self.user_id),
            log_warning=logger.warning,
            error_message=f"Redis profile stats cache invalidation failed for user_id={self.user_id}",
        )
