"""
鎾鏁版嵁璁块棶灞?- Podcast Repository
"""

import logging
from typing import Any

from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.redis import PodcastRedis
from app.domains.podcast.models import (
    PodcastEpisode,
    PodcastPlaybackState,
)
from app.domains.podcast.repositories.analytics import PodcastAnalyticsRepositoryMixin
from app.domains.podcast.repositories.content import PodcastContentRepositoryMixin
from app.domains.podcast.repositories.feed import PodcastFeedRepositoryMixin
from app.domains.podcast.repositories.playback_queue import (
    PodcastPlaybackQueueRepositoryMixin,
)
from app.domains.subscription.models import Subscription, UserSubscription


logger = logging.getLogger(__name__)


class PodcastRepository(
    PodcastContentRepositoryMixin,
    PodcastFeedRepositoryMixin,
    PodcastPlaybackQueueRepositoryMixin,
    PodcastAnalyticsRepositoryMixin,
):
    """
    鎾鏁版嵁鎸佷箙鍖栨搷浣?
    """

    def __init__(self, db: AsyncSession, redis: PodcastRedis | None = None):
        self.db = db
        self.redis = redis or PodcastRedis()
        self._queue_position_step = 1024
        self._queue_position_compaction_threshold = 1_000_000

    @staticmethod
    def _active_user_subscription_filters(user_id: int) -> tuple[Any, Any]:
        """Common filter for active user-subscription mappings."""
        return (
            UserSubscription.user_id == user_id,
            UserSubscription.is_archived.is_(False),
        )

    @staticmethod
    def _podcast_source_type_filter() -> Any:
        return Subscription.source_type.in_(["podcast-rss", "rss"])

    async def _resolve_window_total(
        self,
        rows: list[Any],
        *,
        total_index: int,
        fallback_count_query: Any,
    ) -> int:
        """Resolve paged total via window count with empty-page fallback."""
        if rows:
            return int(rows[0][total_index] or 0)
        return int(await self.db.scalar(fallback_count_query) or 0)

    # === 璁㈤槄绠＄悊 ===

    async def get_playback_state(
        self, user_id: int, episode_id: int
    ) -> PodcastPlaybackState | None:
        """Get playback state for one user and episode."""
        stmt = select(PodcastPlaybackState).where(
            and_(
                PodcastPlaybackState.user_id == user_id,
                PodcastPlaybackState.episode_id == episode_id,
            )
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_playback_states_batch(
        self, user_id: int, episode_ids: list[int]
    ) -> dict[int, PodcastPlaybackState]:
        """
        Batch fetch playback states for multiple episodes.

        Returns a dictionary mapping episode_id to PodcastPlaybackState.
        Episodes without a playback state will not be in the dictionary.
        """
        if not episode_ids:
            return {}

        stmt = select(PodcastPlaybackState).where(
            and_(
                PodcastPlaybackState.user_id == user_id,
                PodcastPlaybackState.episode_id.in_(episode_ids),
            )
        )
        result = await self.db.execute(stmt)
        states = result.scalars().all()

        # Create a dictionary mapping episode_id to state
        return {state.episode_id: state for state in states}

    async def _cache_episode_metadata(self, episode: PodcastEpisode):
        """缂撳瓨episode鍏冩暟鎹埌Redis"""
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

    # === 鏂板鏂规硶鏀寔鍒嗛〉銆佹悳绱€佺粺璁＄瓑 ===

