"""
Podcast Episode Service - Manages podcast episodes.

播客单集服务 - 管理播客单集
"""

import logging
from datetime import datetime
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.redis import PodcastRedis
from app.core.utils import filter_thinking_content
from app.domains.podcast.models import PodcastEpisode
from app.domains.podcast.repositories import PodcastEpisodeRepository
from app.domains.podcast.services.daily_report_summary_extractor import (
    extract_one_line_summary,
)
from app.domains.podcast.services.episode_mapper import build_episode_responses


logger = logging.getLogger(__name__)


class PodcastEpisodeService:
    """
    Service for managing podcast episodes.

    Handles:
    - Listing episodes with pagination
    - Getting episode details
    - Episode metadata management
    """

    def __init__(
        self,
        db: AsyncSession,
        user_id: int,
        *,
        repo: PodcastEpisodeRepository | None = None,
        redis: PodcastRedis | None = None,
    ):
        """
        Initialize episode service.

        Args:
            db: Database session
            user_id: Current user ID
        """
        self.db = db
        self.user_id = user_id
        self.repo = repo or PodcastEpisodeRepository(db)
        self.redis = redis or PodcastRedis()
        self._feed_description_max_length = 320

    async def list_episodes(
        self, filters: Any | None = None, page: int = 1, size: int = 20
    ) -> tuple[list[dict], int]:
        """
        List podcast episodes with pagination.

        Args:
            filters: Optional PodcastEpisodeFilter Pydantic model (subscription_id, has_summary, is_played)
            page: Page number
            size: Items per page

        Returns:
            Tuple of (episodes list, total count)
        """
        # Handle both dict and Pydantic model inputs
        if filters is None:
            subscription_id = None
        elif isinstance(filters, dict):
            subscription_id = filters.get("subscription_id")
        else:
            # Pydantic model - access attributes directly
            subscription_id = getattr(filters, "subscription_id", None)

        # Try cache first
        if subscription_id:
            cached = await self.redis.get_episode_list(subscription_id, page, size)
            if cached:
                logger.info(
                    f"Cache HIT for episode list: sub_id={subscription_id}, page={page}"
                )
                return cached["results"], cached["total"]

            logger.info(
                f"Cache MISS for episode list: sub_id={subscription_id}, page={page}"
            )

        episodes, total = await self.repo.get_episodes_paginated(
            self.user_id, page=page, size=size, filters=filters
        )

        # Batch fetch playback states
        episode_ids = [ep.id for ep in episodes]
        playback_states = await self.repo.get_playback_states_batch(
            self.user_id, episode_ids
        )

        # Build response
        results = self._build_episode_response(episodes, playback_states)

        # Cache if filtering by subscription
        if subscription_id:
            await self.redis.set_episode_list(
                subscription_id, page, size, {"results": results, "total": total}
            )

        return results, total

    async def list_playback_history(
        self,
        page: int = 1,
        size: int = 20,
    ) -> tuple[list[dict], int]:
        """List user playback/view history ordered by latest activity."""
        episodes, total = await self.repo.get_playback_history_paginated(
            self.user_id,
            page=page,
            size=size,
        )

        episode_ids = [ep.id for ep in episodes]
        playback_states = await self.repo.get_playback_states_batch(
            self.user_id,
            episode_ids,
        )
        results = self._build_episode_response(episodes, playback_states)
        return results, total

    async def list_feed_by_cursor(
        self,
        size: int = 20,
        cursor_published_at: datetime | None = None,
        cursor_episode_id: int | None = None,
    ) -> tuple[list[dict], int, bool, tuple[datetime, int] | None]:
        """List feed via keyset cursor pagination."""
        if settings.PODCAST_FEED_LIGHTWEIGHT_ENABLED:
            (
                items,
                total,
                has_more,
                next_cursor_values,
            ) = await self.repo.get_feed_lightweight_cursor_paginated(
                self.user_id,
                size=size,
                cursor_published_at=cursor_published_at,
                cursor_episode_id=cursor_episode_id,
            )
            return (
                [self._normalize_feed_item(item) for item in items],
                total,
                has_more,
                next_cursor_values,
            )

        (
            episodes,
            total,
            has_more,
            next_cursor_values,
        ) = await self.repo.get_feed_cursor_paginated(
            self.user_id,
            size=size,
            cursor_published_at=cursor_published_at,
            cursor_episode_id=cursor_episode_id,
        )

        episode_ids = [ep.id for ep in episodes]
        playback_states = await self.repo.get_playback_states_batch(
            self.user_id, episode_ids
        )
        results = self._build_episode_response(episodes, playback_states)
        results = [
            self._rewrite_feed_item_description(item, hide_ai_summary=False)
            for item in results
        ]
        return results, total, has_more, next_cursor_values

    async def list_feed_by_page(
        self,
        page: int = 1,
        size: int = 20,
    ) -> tuple[list[dict], int]:
        """List feed via legacy page-based pagination for backward compatibility."""
        if settings.PODCAST_FEED_LIGHTWEIGHT_ENABLED:
            items, total = await self.repo.get_feed_lightweight_page_paginated(
                self.user_id,
                page=page,
                size=size,
            )
            return [self._normalize_feed_item(item) for item in items], total

        episodes, total = await self.repo.get_episodes_paginated(
            self.user_id,
            page=page,
            size=size,
            filters=None,
        )
        episode_ids = [ep.id for ep in episodes]
        playback_states = await self.repo.get_playback_states_batch(
            self.user_id,
            episode_ids,
        )
        results = self._build_episode_response(episodes, playback_states)
        results = [
            self._rewrite_feed_item_description(item, hide_ai_summary=False)
            for item in results
        ]
        return results, total

    async def list_playback_history_by_cursor(
        self,
        size: int = 20,
        cursor_last_updated_at: datetime | None = None,
        cursor_episode_id: int | None = None,
    ) -> tuple[list[dict], int, bool, tuple[datetime, int] | None]:
        """List playback history via keyset cursor pagination."""
        (
            episodes,
            total,
            has_more,
            next_cursor_values,
        ) = await self.repo.get_playback_history_cursor_paginated(
            self.user_id,
            size=size,
            cursor_last_updated_at=cursor_last_updated_at,
            cursor_episode_id=cursor_episode_id,
        )

        episode_ids = [ep.id for ep in episodes]
        playback_states = await self.repo.get_playback_states_batch(
            self.user_id,
            episode_ids,
        )
        results = self._build_episode_response(episodes, playback_states)
        return results, total, has_more, next_cursor_values

    async def list_playback_history_lite(
        self,
        page: int = 1,
        size: int = 20,
    ) -> tuple[list[dict[str, Any]], int]:
        """List lightweight playback history for profile history page."""
        return await self.repo.get_playback_history_lite_paginated(
            self.user_id,
            page=page,
            size=size,
        )

    async def get_episode_by_id(self, episode_id: int) -> PodcastEpisode | None:
        """
        Get episode by ID.

        Args:
            episode_id: Episode ID

        Returns:
            PodcastEpisode or None
        """
        return await self.repo.get_episode_by_id(episode_id, self.user_id)

    async def get_episode_with_summary(self, episode_id: int) -> dict | None:
        """
        Get episode details with AI summary.

        Args:
            episode_id: Episode ID

        Returns:
            Episode details dict or None
        """
        episode = await self.repo.get_episode_by_id(episode_id, self.user_id)
        if not episode:
            return None

        playback = await self.repo.get_playback_state(self.user_id, episode_id)
        cleaned_summary = filter_thinking_content(episode.ai_summary)

        # Extract subscription metadata
        subscription_image_url = None
        subscription_author = None
        subscription_categories = []
        if episode.subscription and episode.subscription.config:
            config = episode.subscription.config
            subscription_image_url = config.get("image_url")
            subscription_author = config.get("author")
            subscription_categories = config.get("categories") or []

        return {
            "id": episode.id,
            "subscription_id": episode.subscription_id,
            "title": episode.title,
            "description": episode.description,
            "audio_url": episode.audio_url,
            "audio_duration": episode.audio_duration,
            "audio_file_size": episode.audio_file_size,
            "published_at": episode.published_at,
            "image_url": episode.image_url,
            "item_link": episode.item_link,
            "subscription_image_url": subscription_image_url,
            "transcript_url": episode.transcript_url,
            "transcript_content": episode.transcript_content,
            "ai_summary": cleaned_summary,
            "summary_version": episode.summary_version,
            "ai_confidence_score": episode.ai_confidence_score,
            "play_count": episode.play_count,
            # Use per-user playback timestamp when available.
            "last_played_at": playback.last_updated_at
            if playback
            else episode.last_played_at,
            "season": episode.season,
            "episode_number": episode.episode_number,
            "explicit": episode.explicit,
            "status": episode.status,
            "metadata": episode.metadata_json or {},
            "created_at": episode.created_at,
            "updated_at": episode.updated_at,
            "playback_position": playback.current_position if playback else None,
            "is_playing": playback.is_playing if playback else False,
            "playback_rate": playback.playback_rate if playback else 1.0,
            "is_played": None,
            "subscription": {
                "id": episode.subscription.id,
                "title": episode.subscription.title,
                "description": episode.subscription.description,
                "image_url": subscription_image_url,
                "author": subscription_author,
                "categories": subscription_categories,
            }
            if episode.subscription
            else None,
            "related_episodes": [],
        }

    async def get_recently_played(
        self, user_id: int, limit: int = 5
    ) -> list[dict[str, Any]]:
        """
        Get recently played episodes.

        Args:
            user_id: User ID
            limit: Maximum number of episodes

        Returns:
            List of recently played episodes
        """
        return await self.repo.get_recently_played(user_id, limit)

    async def get_liked_episodes(
        self, user_id: int, limit: int = 20
    ) -> list[PodcastEpisode]:
        """
        Get user's liked episodes (high completion rate).

        Args:
            user_id: User ID
            limit: Maximum number of episodes

        Returns:
            List of liked episodes
        """
        return await self.repo.get_liked_episodes(user_id, limit)

    def _build_episode_response(
        self, episodes: list[PodcastEpisode], playback_states: dict[int, Any]
    ) -> list[dict]:
        """Build episode response list with playback states."""
        return build_episode_responses(
            episodes=episodes,
            playback_states=playback_states,
            include_extended_fields=True,
        )

    def _normalize_feed_item(self, item: dict[str, Any]) -> dict[str, Any]:
        """Normalize lightweight feed payload fields for stable frontend semantics."""
        return self._rewrite_feed_item_description(item, hide_ai_summary=True)

    def _rewrite_feed_item_description(
        self, item: dict[str, Any], *, hide_ai_summary: bool
    ) -> dict[str, Any]:
        normalized = dict(item)
        normalized["description"] = self._resolve_feed_description(
            ai_summary=normalized.get("ai_summary"),
            fallback_description=normalized.get("description"),
        )
        normalized["transcript_content"] = None
        if hide_ai_summary:
            normalized["ai_summary"] = None
        return normalized

    def _resolve_feed_description(
        self, ai_summary: Any, fallback_description: Any
    ) -> str | None:
        summary_text = filter_thinking_content(ai_summary) if ai_summary else ""
        one_line_summary = extract_one_line_summary(summary_text)
        if one_line_summary:
            collapsed_summary = " ".join(one_line_summary.split())
            if collapsed_summary:
                return collapsed_summary[: self._feed_description_max_length]
        return self._collapse_feed_description(fallback_description)

    def _collapse_feed_description(self, raw_description: Any) -> str | None:
        if not isinstance(raw_description, str):
            return None
        collapsed = " ".join(raw_description.split())
        if not collapsed:
            return None
        return collapsed[: self._feed_description_max_length]
