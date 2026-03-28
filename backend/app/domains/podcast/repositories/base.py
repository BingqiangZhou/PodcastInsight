"""Shared repository base for podcast persistence helpers.

This module provides lazy imports for subscription models to maintain
clean domain boundaries while allowing SQLAlchemy queries to work.
"""

from __future__ import annotations

from typing import TYPE_CHECKING, Any

from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.redis import PodcastRedis, get_shared_redis
from app.domains.podcast.models import PodcastEpisode, PodcastPlaybackState


# Use TYPE_CHECKING to avoid runtime dependency on subscription domain
# This maintains clean domain boundaries while providing type hints
if TYPE_CHECKING:
    pass


def _get_subscription_models():
    """Lazy import subscription models to maintain domain boundaries.

    This function is called at runtime when the models are actually needed
    for SQLAlchemy queries, but the TYPE_CHECKING guard above ensures they
    are not imported during type checking.

    Returns:
        Tuple of (Subscription, UserSubscription) models
    """
    from app.domains.subscription.models import Subscription, UserSubscription

    return Subscription, UserSubscription


class BasePodcastRepository:
    """Small shared base for specialized podcast repositories."""

    def __init__(self, db: AsyncSession, redis: PodcastRedis | None = None):
        self.db = db
        self.redis = redis or get_shared_redis()
        self._queue_position_step = 1024
        self._queue_position_compaction_threshold = 1_000_000

    @staticmethod
    def _active_user_subscription_filters(user_id: int) -> tuple[Any, Any]:
        """Common filter for active user-subscription mappings.

        Uses lazy import to maintain domain boundary separation.
        """
        _, UserSubscription = _get_subscription_models()
        return (
            UserSubscription.user_id == user_id,
            UserSubscription.is_archived.is_(False),
        )

    @staticmethod
    def _podcast_source_type_filter() -> Any:
        """Filter for podcast source types.

        Uses lazy import to maintain domain boundary separation.
        """
        Subscription, _ = _get_subscription_models()
        return Subscription.source_type.in_(["podcast-rss", "rss"])

    async def get_playback_state(
        self,
        user_id: int,
        episode_id: int,
    ) -> PodcastPlaybackState | None:
        """Get playback state for one user and episode."""
        stmt = select(PodcastPlaybackState).where(
            and_(
                PodcastPlaybackState.user_id == user_id,
                PodcastPlaybackState.episode_id == episode_id,
            ),
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_playback_states_batch(
        self,
        user_id: int,
        episode_ids: list[int],
    ) -> dict[int, PodcastPlaybackState]:
        """Batch fetch playback states for multiple episodes."""
        if not episode_ids:
            return {}

        stmt = select(PodcastPlaybackState).where(
            and_(
                PodcastPlaybackState.user_id == user_id,
                PodcastPlaybackState.episode_id.in_(episode_ids),
            ),
        )
        result = await self.db.execute(stmt)
        states = result.scalars().all()
        return {state.episode_id: state for state in states}

    async def _cache_episode_metadata(self, episode: PodcastEpisode):
        """Cache lightweight episode metadata when Redis is available."""
        if not self.redis:
            return

        metadata = {
            "id": str(episode.id),
            "title": episode.title,
            "audio_url": episode.audio_url,
            "duration": str(episode.audio_duration or 0),
            "has_summary": "yes" if episode.ai_summary else "no",
        }

        await self.redis.set_episode_metadata(episode.id, metadata)
