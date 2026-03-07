"""
Podcast Search Service - Handles podcast content search and recommendations.

播客搜索服务 - 处理播客内容搜索和推荐
"""

import logging
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.redis import PodcastRedis
from app.domains.podcast.models import PodcastEpisode
from app.domains.podcast.repositories import PodcastSearchRepository
from app.domains.podcast.services.cache_utils import safe_cache_get, safe_cache_write
from app.domains.podcast.services.episode_mapper import build_episode_responses


logger = logging.getLogger(__name__)


class PodcastSearchService:
    """
    Service for searching podcast content and generating recommendations.

    Handles:
    - Searching episodes by title, description, summary
    - Generating recommendations based on listening history
    """

    def __init__(
        self,
        db: AsyncSession,
        user_id: int,
        *,
        repo: PodcastSearchRepository | None = None,
        redis: PodcastRedis | None = None,
    ):
        """
        Initialize search service.

        Args:
            db: Database session
            user_id: Current user ID
        """
        self.db = db
        self.user_id = user_id
        self.repo = repo or PodcastSearchRepository(db)
        self.redis = redis or PodcastRedis()

    async def search_podcasts(
        self, query: str, search_in: str = "all", page: int = 1, size: int = 20
    ) -> tuple[list[dict], int]:
        """
        Search podcast content.

        Args:
            query: Search query string
            search_in: Where to search (title/description/summary/all)
            page: Page number
            size: Items per page

        Returns:
            Tuple of (results list, total count)
        """
        # Try cache first
        cached = await safe_cache_get(
            lambda: self.redis.get_search_results(query, search_in, page, size),
            log_warning=logger.warning,
            error_message=(
                "Search cache read failed (continuing without cache) "
                f"user={self.user_id} query={query}"
            ),
        )

        if cached:
            logger.info(f"Cache HIT for search: {query}")
            return cached["results"], cached["total"]

        logger.info(f"Cache MISS for search: {query}, querying database")

        episodes, total = await self.repo.search_episodes(
            self.user_id, query=query, search_in=search_in, page=page, size=size
        )

        # Batch fetch playback states
        episode_ids = [ep.id for ep in episodes]
        playback_states = await self.repo.get_playback_states_batch(
            self.user_id, episode_ids
        )

        # Build response
        results = self._build_episode_response(episodes, playback_states)

        # Add relevance scores
        for i, ep in enumerate(episodes):
            results[i]["relevance_score"] = getattr(ep, "relevance_score", 1.0)

        # Cache results
        await safe_cache_write(
            lambda: self.redis.set_search_results(
                query,
                search_in,
                page,
                size,
                {
                    "results": results,
                    "total": total,
                },
            ),
            log_warning=logger.warning,
            error_message=(
                "Search cache write failed (results already returned) "
                f"user={self.user_id} query={query}"
            ),
        )

        return results, total

    async def get_recommendations(self, limit: int = 10) -> list[dict]:
        """
        Get podcast recommendations based on user history.

        Args:
            limit: Maximum number of recommendations

        Returns:
            List of recommendation dicts
        """
        # Get user's liked episodes (high completion rate)
        liked_episodes = await self.repo.get_liked_episodes(self.user_id, limit=20)

        # Simple recommendation logic based on listening history
        # TODO: Implement content-based recommendation algorithm

        recommendations = []
        for ep in liked_episodes[:limit]:
            recommendations.append(
                {
                    "episode_id": ep.id,
                    "title": ep.title,
                    "description": ep.description[:150] + "..."
                    if len(ep.description) > 150
                    else ep.description,
                    "subscription_title": ep.subscription.title
                    if ep.subscription
                    else None,
                    "recommendation_reason": "Based on your listening history",
                    "match_score": 0.85,
                }
            )

        return recommendations

    def _build_episode_response(
        self, episodes: list[PodcastEpisode], playback_states: dict[int, Any]
    ) -> list[dict]:
        """Build episode response list with playback states."""
        return build_episode_responses(
            episodes=episodes,
            playback_states=playback_states,
            include_extended_fields=False,
        )
