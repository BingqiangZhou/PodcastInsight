"""Podcast stats service.

Provides aggregated user-level podcast stats and cache handling.
"""

import asyncio
import logging
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.redis import (
    PodcastRedis,
    get_shared_redis,
)
from app.domains.podcast.repositories import PodcastStatsRepository
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
        self.redis = redis or get_shared_redis()

    async def get_user_stats(self) -> dict[str, Any]:
        """Get cached/aggregated user stats with playback context.

        Uses parallel fetching for stats, recently_played, and listening_streak
        to minimize API response time.
        """
        logger.info("Cache MISS for user stats: user_id=%s", self.user_id)

        # Fetch all data in parallel using asyncio.gather
        results = await asyncio.gather(
            self.repo.get_user_stats_aggregated(self.user_id),
            self.playback_service.get_recently_played(limit=5),
            self.playback_service.calculate_listening_streak(),
            return_exceptions=True,
        )

        # Extract results with error handling
        stats = results[0] if not isinstance(results[0], Exception) else {}
        recently_played = results[1] if not isinstance(results[1], Exception) else []
        listening_streak = results[2] if not isinstance(results[2], Exception) else 0

        if isinstance(results[1], Exception):
            logger.warning("Failed to get recently played, defaulting to empty list")
        if isinstance(results[2], Exception):
            logger.warning("Failed to calculate listening streak, defaulting to 0")

        result = {
            **stats,
            "recently_played": recently_played,
            "top_categories": [],
            "listening_streak": listening_streak,
        }

        return result

    async def get_profile_stats(self) -> dict[str, Any]:
        """Get lightweight profile stats for profile page cards."""
        logger.info("Cache MISS for profile stats: user_id=%s", self.user_id)
        result = await self.repo.get_profile_stats_aggregated(self.user_id)

        return result

    async def invalidate_cached_stats(self) -> None:
        """Invalidate user stats/profile stats caches in parallel."""
        try:
            await self.redis.delete(f"podcast:stats:{self.user_id}")
        except Exception as e:
            logger.warning(f"Redis user stats cache invalidation failed for user_id={self.user_id}: {e}")
        try:
            await self.redis.delete(f"podcast:stats:profile:{self.user_id}")
        except Exception as e:
            logger.warning(f"Redis profile stats cache invalidation failed for user_id={self.user_id}: {e}")
