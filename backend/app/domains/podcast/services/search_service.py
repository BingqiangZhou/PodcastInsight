"""Podcast Search Service - Handles podcast content search.

播客搜索服务 - 处理播客内容搜索
"""

import logging
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.redis import (
    PodcastRedis,
    get_shared_redis,
)
from app.domains.podcast.models import PodcastEpisode
from app.domains.podcast.repositories import PodcastSearchRepository
from app.domains.podcast.services.episode_mapper import build_episode_dicts


logger = logging.getLogger(__name__)


class PodcastSearchService:
    """Service for searching podcast content.

    Handles:
    - Searching episodes by title, description, summary
    """

    def __init__(
        self,
        db: AsyncSession,
        user_id: int,
        *,
        repo: PodcastSearchRepository | None = None,
        redis: PodcastRedis | None = None,
    ):
        """Initialize search service.

        Args:
            db: Database session
            user_id: Current user ID

        """
        self.db = db
        self.user_id = user_id
        self.repo = repo or PodcastSearchRepository(db)
        self.redis = redis or get_shared_redis()

    async def search_podcasts(
        self,
        query: str,
        search_in: str = "all",
        page: int = 1,
        size: int = 20,
    ) -> tuple[list[dict[str, Any]], int]:
        """Search podcast content.

        Args:
            query: Search query string
            search_in: Where to search (title/description/summary/all)
            page: Page number
            size: Items per page

        Returns:
            Tuple of (results list, total count)

        """
        logger.info(f"Cache MISS for search: {query}, querying database")

        episodes, total = await self.repo.search_episodes(
            self.user_id,
            query=query,
            search_in=search_in,
            page=page,
            size=size,
        )

        # Batch fetch playback states
        episode_ids = [ep.id for ep in episodes]
        playback_states = await self.repo.get_playback_states_batch(
            self.user_id,
            episode_ids,
        )

        # Build response
        results = self._build_episode_dicts(episodes, playback_states)

        # Add relevance scores
        for i, ep in enumerate(episodes):
            results[i]["relevance_score"] = getattr(ep, "relevance_score", 1.0)

        return results, total

    def _build_episode_dicts(
        self,
        episodes: list[PodcastEpisode],
        playback_states: dict[int, Any],
    ) -> list[dict[str, Any]]:
        """Build episode dicts with playback states."""
        return build_episode_dicts(
            episodes=episodes,
            playback_states=playback_states,
            include_extended_fields=False,
        )
