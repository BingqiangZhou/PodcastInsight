"""Playback and queue services."""

import logging
from datetime import date, timedelta
from time import perf_counter
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import EpisodeNotFoundError
from app.core.redis import RedisCache, get_shared_redis
from app.domains.podcast.models import PodcastEpisode, PodcastPlaybackState
from app.domains.podcast.repositories import (
    PodcastPlaybackRepository,
    PodcastQueueRepository,
)


logger = logging.getLogger(__name__)


class PodcastPlaybackService:
    """Service for managing podcast playback state.

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
        redis: RedisCache | None = None,
    ):
        """Initialize playback service.

        Args:
            db: Database session
            user_id: Current user ID

        """
        self.db = db
        self.user_id = user_id
        self.repo = repo or PodcastPlaybackRepository(db)
        self.redis = redis or get_shared_redis()

    async def update_playback_progress(
        self,
        episode_id: int,
        progress_seconds: int,
        is_playing: bool = False,
        playback_rate: float = 1.0,
    ) -> dict[str, Any]:
        """Update playback progress for an episode.

        Args:
            episode_id: Episode ID
            progress_seconds: Current position in seconds
            is_playing: Whether currently playing
            playback_rate: Playback rate (1.0 = normal)

        Returns:
            Updated playback state dict

        Raises:
            EpisodeNotFoundError: If episode not found

        """
        # Get episode to verify access
        episode = await self.repo.get_episode_by_id(episode_id, self.user_id)
        if not episode:
            raise EpisodeNotFoundError("Episode not found")

        playback = await self.repo.update_playback_progress(
            self.user_id,
            episode_id,
            progress_seconds,
            is_playing,
            playback_rate,
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
            "current_position": playback.current_position,
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
        """Resolve effective playback-rate preference (cached)."""
        async def _loader() -> dict[str, Any]:
            return await self.repo.get_effective_playback_rate(
                user_id=self.user_id,
                subscription_id=subscription_id,
            )

        try:
            result = await self.redis.get_effective_playback_rate(
                self.user_id, subscription_id, _loader
            )
            return result if result is not None else await _loader()
        except Exception:
            return await _loader()

    async def apply_playback_rate_preference(
        self,
        playback_rate: float,
        apply_to_subscription: bool,
        subscription_id: int | None = None,
    ) -> dict[str, Any]:
        """Persist playback-rate preference and return effective values."""
        result = await self.repo.apply_playback_rate_preference(
            user_id=self.user_id,
            playback_rate=playback_rate,
            apply_to_subscription=apply_to_subscription,
            subscription_id=subscription_id,
        )

        # Invalidate playback rate cache after preference change
        try:
            await self.redis.invalidate_playback_rate(self.user_id, subscription_id)
            # Also invalidate the global cache if subscription-specific change
            if apply_to_subscription:
                await self.redis.invalidate_playback_rate(self.user_id, None)
        except Exception:
            pass  # Cache invalidation is best-effort

        return result

    async def get_playback_state(
        self,
        episode_id: int,
    ) -> dict[str, Any] | None:
        """Get playback state for an episode.

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
        self,
        episode_ids: list[int],
    ) -> dict[int, PodcastPlaybackState]:
        """Batch fetch playback states for multiple episodes.

        Args:
            episode_ids: List of episode IDs

        Returns:
            Dictionary mapping episode_id to playback state

        """
        return await self.repo.get_playback_states_batch(self.user_id, episode_ids)

    async def get_recent_play_dates(self, days: int = 30) -> set[date]:
        """Get dates when user listened to podcasts.

        Args:
            days: Number of days to look back

        Returns:
            Set of dates

        """
        return await self.repo.get_recent_play_dates(self.user_id, days)

    async def calculate_listening_streak(self) -> int:
        """Calculate consecutive days of listening.

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
        """Get recently played episodes.

        Args:
            limit: Maximum number of episodes

        Returns:
            List of recently played episode dicts

        """
        return await self.repo.get_recently_played(self.user_id, limit)

    async def get_liked_episodes(self, limit: int = 20) -> list[PodcastEpisode]:
        """Get user's liked episodes (high completion rate).

        Args:
            limit: Maximum number of episodes

        Returns:
            List of liked episodes

        """
        return await self.repo.get_liked_episodes(self.user_id, limit)


logger = logging.getLogger(__name__)


class PodcastQueueService:
    """Service for queue operations and queue snapshot building."""

    MAX_QUEUE_ITEMS = 500

    def __init__(
        self,
        db: AsyncSession,
        user_id: int,
        *,
        repo: PodcastQueueRepository | None = None,
    ):
        self.db = db
        self.user_id = user_id
        self.repo = repo or PodcastQueueRepository(db)

    async def get_queue(self) -> dict[str, Any]:
        queue = await self.repo.get_queue_with_items(self.user_id)
        return await self._build_queue_dict(queue)

    async def add_to_queue(self, episode_id: int) -> dict[str, Any]:
        started_at = perf_counter()
        episode = await self.repo.get_episode_by_id(episode_id, self.user_id)
        if not episode:
            raise EpisodeNotFoundError("Episode not found")

        queue = await self.repo.add_or_move_to_tail(
            user_id=self.user_id,
            episode_id=episode_id,
            max_items=self.MAX_QUEUE_ITEMS,
        )
        result = await self._build_queue_dict(queue)
        logger.debug(
            "[Queue] add_to_queue user_id=%s episode_id=%s items=%s elapsed_ms=%.2f",
            self.user_id,
            episode_id,
            len(result["items"]),
            (perf_counter() - started_at) * 1000,
        )
        return result

    async def remove_from_queue(self, episode_id: int) -> dict[str, Any]:
        queue = await self.repo.remove_item(self.user_id, episode_id)
        return await self._build_queue_dict(queue)

    async def reorder_queue(self, episode_ids: list[int]) -> dict[str, Any]:
        queue = await self.repo.reorder_items(self.user_id, episode_ids)
        return await self._build_queue_dict(queue)

    async def set_current(self, episode_id: int) -> dict[str, Any]:
        queue = await self.repo.set_current(self.user_id, episode_id)
        return await self._build_queue_dict(queue)

    async def activate_episode(self, episode_id: int) -> dict[str, Any]:
        started_at = perf_counter()
        episode = await self.repo.get_episode_by_id(episode_id, self.user_id)
        if not episode:
            raise EpisodeNotFoundError("Episode not found")

        queue = await self.repo.activate_episode(
            user_id=self.user_id,
            episode_id=episode_id,
            max_items=self.MAX_QUEUE_ITEMS,
        )
        result = await self._build_queue_dict(queue)
        logger.debug(
            "[Queue] activate_episode user_id=%s episode_id=%s items=%s elapsed_ms=%.2f",
            self.user_id,
            episode_id,
            len(result["items"]),
            (perf_counter() - started_at) * 1000,
        )
        return result

    async def complete_current(self) -> dict[str, Any]:
        queue = await self.repo.complete_current(self.user_id)
        return await self._build_queue_dict(queue)

    async def _build_queue_dict(self, queue) -> dict[str, Any]:
        items: list[dict[str, Any]] = []
        ordered_items = sorted(queue.items, key=lambda item: (item.position, item.id))
        episode_ids = [item.episode_id for item in ordered_items]
        playback_states = (
            await self.repo.get_playback_states_batch(self.user_id, episode_ids)
            if episode_ids
            else {}
        )

        for item in ordered_items:
            episode = item.episode
            subscription = episode.subscription if episode else None
            subscription_image = None
            if subscription and subscription.config:
                subscription_image = subscription.config.get("image_url")
            playback_state = playback_states.get(item.episode_id)

            items.append(
                {
                    "episode_id": item.episode_id,
                    "position": item.position,
                    "playback_position": (
                        playback_state.current_position if playback_state else None
                    ),
                    "title": episode.title if episode else "",
                    "podcast_id": episode.subscription_id if episode else 0,
                    "audio_url": episode.audio_url if episode else "",
                    "duration": episode.audio_duration if episode else None,
                    "published_at": episode.published_at if episode else None,
                    "image_url": episode.image_url if episode else None,
                    "subscription_title": subscription.title if subscription else None,
                    "subscription_image_url": subscription_image,
                }
            )

        return {
            "current_episode_id": queue.current_episode_id,
            "revision": queue.revision or 0,
            "updated_at": queue.updated_at,
            "items": items,
        }
