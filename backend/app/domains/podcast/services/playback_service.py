"""
Podcast Playback Service - Manages playback progress and state.

播客播放服务 - 管理播放进度和状态
"""

import logging
from datetime import date, timedelta
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.redis import PodcastRedis
from app.domains.podcast.models import PodcastEpisode, PodcastPlaybackState
from app.domains.podcast.repositories import PodcastPlaybackRepository


logger = logging.getLogger(__name__)


class PodcastPlaybackService:
    """
    Service for managing podcast playback state.

    Handles:
    - Updating playback progress
    - Getting playback state
    - Managing play count
    - Tracking listening streaks
    """

    def __init__(
        self,
        db: AsyncSession,
        user_id: int,
        *,
        repo: PodcastPlaybackRepository | None = None,
        redis: PodcastRedis | None = None,
    ):
        """
        Initialize playback service.

        Args:
            db: Database session
            user_id: Current user ID
        """
        self.db = db
        self.user_id = user_id
        self.repo = repo or PodcastPlaybackRepository(db)
        self.redis = redis or PodcastRedis()

    async def update_playback_progress(
        self,
        episode_id: int,
        progress_seconds: int,
        is_playing: bool = False,
        playback_rate: float = 1.0,
    ) -> dict:
        """
        Update playback progress for an episode.

        Args:
            episode_id: Episode ID
            progress_seconds: Current position in seconds
            is_playing: Whether currently playing
            playback_rate: Playback rate (1.0 = normal)

        Returns:
            Updated playback state dict

        Raises:
            ValueError: If episode not found
        """
        # Get episode to verify access
        episode = await self.repo.get_episode_by_id(episode_id, self.user_id)
        if not episode:
            raise ValueError("Episode not found")

        playback = await self.repo.update_playback_progress(
            self.user_id, episode_id, progress_seconds, is_playing, playback_rate
        )
        await self._invalidate_stats_cache()

        progress_percentage = 0
        remaining_time = 0
        if episode.audio_duration and episode.audio_duration > 0:
            progress_percentage = (
                playback.current_position / episode.audio_duration
            ) * 100
            remaining_time = max(0, episode.audio_duration - playback.current_position)

        return {
            "episode_id": episode_id,
            "progress": playback.current_position,
            "is_playing": playback.is_playing,
            "playback_rate": playback.playback_rate,
            "play_count": playback.play_count,
            "last_updated_at": playback.last_updated_at,
            "progress_percentage": round(progress_percentage, 2),
            "remaining_time": remaining_time,
        }

    async def _invalidate_stats_cache(self) -> None:
        """Invalidate derived stats caches after playback mutation."""
        try:
            await self.redis.invalidate_user_stats(self.user_id)
            await self.redis.invalidate_profile_stats(self.user_id)
        except Exception as exc:
            logger.warning(
                "Failed to invalidate playback-related stats cache for user %s: %s",
                self.user_id,
                exc,
            )

    async def get_effective_playback_rate(
        self,
        subscription_id: int | None = None,
    ) -> dict[str, Any]:
        """Resolve effective playback-rate preference."""
        return await self.repo.get_effective_playback_rate(
            user_id=self.user_id,
            subscription_id=subscription_id,
        )

    async def apply_playback_rate_preference(
        self,
        playback_rate: float,
        apply_to_subscription: bool,
        subscription_id: int | None = None,
    ) -> dict[str, Any]:
        """Persist playback-rate preference and return effective values."""
        return await self.repo.apply_playback_rate_preference(
            user_id=self.user_id,
            playback_rate=playback_rate,
            apply_to_subscription=apply_to_subscription,
            subscription_id=subscription_id,
        )

    async def get_playback_state(self, episode_id: int) -> dict | None:
        """
        Get playback state for an episode.

        Args:
            episode_id: Episode ID

        Returns:
            Playback state dict or None
        """
        playback = await self.repo.get_playback_state(self.user_id, episode_id)
        if not playback:
            return None

        episode = await self.repo.get_episode_by_id(episode_id)
        if not episode:
            return None

        progress_percentage = 0
        remaining_time = 0
        if episode.audio_duration and episode.audio_duration > 0:
            progress_percentage = (
                playback.current_position / episode.audio_duration
            ) * 100
            remaining_time = max(0, episode.audio_duration - playback.current_position)

        return {
            "episode_id": episode_id,
            "current_position": playback.current_position,
            "is_playing": playback.is_playing,
            "playback_rate": playback.playback_rate,
            "play_count": playback.play_count,
            "last_updated_at": playback.last_updated_at,
            "progress_percentage": round(progress_percentage, 2),
            "remaining_time": remaining_time,
        }

    async def get_playback_states_batch(
        self, episode_ids: list[int]
    ) -> dict[int, PodcastPlaybackState]:
        """
        Batch fetch playback states for multiple episodes.

        Args:
            episode_ids: List of episode IDs

        Returns:
            Dictionary mapping episode_id to playback state
        """
        return await self.repo.get_playback_states_batch(self.user_id, episode_ids)

    async def get_recent_play_dates(self, days: int = 30) -> set[date]:
        """
        Get dates when user listened to podcasts.

        Args:
            days: Number of days to look back

        Returns:
            Set of dates
        """
        return await self.repo.get_recent_play_dates(self.user_id, days)

    async def calculate_listening_streak(self) -> int:
        """
        Calculate consecutive days of listening.

        Returns:
            Number of consecutive days
        """
        recent_plays = await self.repo.get_recent_play_dates(self.user_id, days=30)

        if not recent_plays:
            return 0

        # Calculate consecutive days
        streak = 1
        today = date.today()

        for i in range(1, 30):
            check_date = today - timedelta(days=i)
            if check_date in recent_plays:
                streak += 1
            else:
                break

        return streak

    async def get_recently_played(self, limit: int = 5) -> list[dict[str, Any]]:
        """
        Get recently played episodes.

        Args:
            limit: Maximum number of episodes

        Returns:
            List of recently played episode dicts
        """
        return await self.repo.get_recently_played(self.user_id, limit)

    async def get_liked_episodes(self, limit: int = 20) -> list[PodcastEpisode]:
        """
        Get user's liked episodes (high completion rate).

        Args:
            limit: Maximum number of episodes

        Returns:
            List of liked episodes
        """
        return await self.repo.get_liked_episodes(self.user_id, limit)
