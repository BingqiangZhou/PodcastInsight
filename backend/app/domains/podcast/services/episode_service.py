"""Episode and subscription services."""

import logging
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.exceptions import SubscriptionNotFoundError
from app.core.redis import PodcastRedis, get_shared_redis
from app.core.utils import filter_thinking_content
from app.domains.podcast.integration.secure_rss_parser import SecureRSSParser
from app.domains.podcast.models import PodcastEpisode, Subscription, TranscriptionTask
from app.domains.podcast.repositories import (
    PodcastEpisodeRepository,
    PodcastSubscriptionRepository,
)
from app.domains.podcast.repositories.subscription_repository import (
    SubscriptionRepository,
)
from app.domains.podcast.services.content_service import (
    extract_one_line_summary,
)
from app.domains.podcast.services.episode_mapper import build_episode_dicts


logger = logging.getLogger(__name__)


def _derive_summary_status(
    episode_status: str | None,
    *,
    has_summary: bool,
) -> str:
    if episode_status in {
        "pending_summary",
        "summary_generating",
        "summary_failed",
        "summarized",
    }:
        return str(episode_status)
    return "summarized" if has_summary else "pending_summary"


class PodcastEpisodeService:
    """Service for managing podcast episodes.

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
        """Initialize episode service.

        Args:
            db: Database session
            user_id: Current user ID

        """
        self.db = db
        self.user_id = user_id
        self.repo = repo or PodcastEpisodeRepository(db)
        self.redis = redis or get_shared_redis()
        self._feed_description_max_length = 320

    async def list_episodes(
        self,
        filters: Any | None = None,
        page: int = 1,
        size: int = 20,
    ) -> tuple[list[dict[str, Any]], int]:
        """List podcast episodes with pagination.

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
                    f"Cache HIT for episode list: sub_id={subscription_id}, page={page}",
                )
                return (
                    list(cached["results"]),
                    cached["total"],
                )

            logger.info(
                f"Cache MISS for episode list: sub_id={subscription_id}, page={page}",
            )

        episodes, total = await self.repo.get_episodes_paginated(
            self.user_id,
            page=page,
            size=size,
            filters=filters,
        )

        # Batch fetch playback states
        episode_ids = [ep.id for ep in episodes]
        playback_states = await self.repo.get_playback_states_batch(
            self.user_id,
            episode_ids,
        )

        # Build response
        results = self._build_episode_dicts(episodes, playback_states)

        # Cache if filtering by subscription
        if subscription_id:
            await self.redis.set_episode_list(
                subscription_id,
                page,
                size,
                {
                    "results": results,
                    "total": total,
                },
            )

        return results, total

    async def list_playback_history(
        self,
        page: int = 1,
        size: int = 20,
    ) -> tuple[list[dict[str, Any]], int]:
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
        results = self._build_episode_dicts(episodes, playback_states)
        return results, total

    async def list_feed_by_cursor(
        self,
        size: int = 20,
        cursor_published_at: datetime | None = None,
        cursor_episode_id: int | None = None,
    ) -> tuple[list[dict[str, Any]], int, bool, tuple[datetime, int] | None]:
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
            self.user_id,
            episode_ids,
        )
        results = self._build_episode_dicts(episodes, playback_states)
        results = [
            self._rewrite_feed_item_description(item, hide_ai_summary=False)
            for item in results
        ]
        return results, total, has_more, next_cursor_values

    async def list_feed_by_page(
        self,
        page: int = 1,
        size: int = 20,
    ) -> tuple[list[dict[str, Any]], int]:
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
        results = self._build_episode_dicts(episodes, playback_states)
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
    ) -> tuple[list[dict[str, Any]], int, bool, tuple[datetime, int] | None]:
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
        results = self._build_episode_dicts(episodes, playback_states)
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
        """Get episode by ID.

        Args:
            episode_id: Episode ID

        Returns:
            PodcastEpisode or None

        """
        return await self.repo.get_episode_by_id(episode_id, self.user_id)

    async def get_episodes_by_ids(
        self, episode_ids: list[int], user_id: int | None = None
    ) -> dict[int, PodcastEpisode]:
        """Batch fetch episodes by IDs for efficient N+1 query resolution.

        Args:
            episode_ids: List of episode IDs
            user_id: Optional user ID for filtering

        Returns:
            Dict mapping episode_id -> episode
        """
        if not episode_ids:
            return {}

        # Use a single query with IN clause for efficiency
        # Note: episodes are shared across users (no user_id column),
        # so user_id filtering is handled at the subscription level by callers.
        stmt = select(PodcastEpisode).where(PodcastEpisode.id.in_(episode_ids))

        episodes = (await self.db.execute(stmt)).scalars().all()
        return {ep.id: ep for ep in episodes}

    async def get_episode_with_summary(
        self,
        episode_id: int,
    ) -> dict[str, Any] | None:
        """Get episode details with AI summary.

        Args:
            episode_id: Episode ID

        Returns:
            Episode details dict or None

        """
        async def _load_from_db() -> dict[str, Any] | None:
            episode = await self.repo.get_episode_by_id(episode_id, self.user_id)
            if not episode:
                return None

            playback = await self.repo.get_playback_state(self.user_id, episode_id)
            cleaned_summary = filter_thinking_content(episode.ai_summary)
            transcription_task = await self._get_transcription_task(episode_id)
            summary_status = _derive_summary_status(
                episode.status,
                has_summary=bool(cleaned_summary),
            )

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
                "transcript_content": episode.transcript.transcript_content
                if episode.transcript
                else None,
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
                "summary_status": summary_status,
                "summary_error_message": transcription_task.summary_error_message
                if transcription_task
                else None,
                "summary_model_used": transcription_task.summary_model_used
                if transcription_task
                else None,
                "summary_processing_time": transcription_task.summary_processing_time
                if transcription_task
                else None,
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

        return await self.redis.get_episode_detail(episode_id, _load_from_db)

    async def _get_transcription_task(
        self,
        episode_id: int,
    ) -> TranscriptionTask | None:
        stmt = select(TranscriptionTask).where(
            TranscriptionTask.episode_id == episode_id
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_recently_played(
        self,
        user_id: int,
        limit: int = 5,
    ) -> list[dict[str, Any]]:
        """Get recently played episodes.

        Args:
            user_id: User ID
            limit: Maximum number of episodes

        Returns:
            List of recently played episodes

        """
        return await self.repo.get_recently_played(user_id, limit)

    async def get_liked_episodes(
        self,
        user_id: int,
        limit: int = 20,
    ) -> list[PodcastEpisode]:
        """Get user's liked episodes (high completion rate).

        Args:
            user_id: User ID
            limit: Maximum number of episodes

        Returns:
            List of liked episodes

        """
        return await self.repo.get_liked_episodes(user_id, limit)

    def _build_episode_dicts(
        self,
        episodes: list[PodcastEpisode],
        playback_states: dict[int, Any],
    ) -> list[dict[str, Any]]:
        """Build episode dicts with playback states."""
        return build_episode_dicts(
            episodes=episodes,
            playback_states=playback_states,
            include_extended_fields=True,
        )

    def _normalize_feed_item(self, item: dict[str, Any]) -> dict[str, Any]:
        """Normalize lightweight feed payload fields for stable frontend semantics."""
        return self._rewrite_feed_item_description(item, hide_ai_summary=True)

    def _rewrite_feed_item_description(
        self,
        item: dict[str, Any],
        *,
        hide_ai_summary: bool,
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
        self,
        ai_summary: Any,
        fallback_description: Any,
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


# ── Subscription metadata helpers (merged from subscription_metadata.py) ──


def normalize_categories(raw_categories: list[Any]) -> list[dict[str, str]]:
    """Normalize categories to stable dict payloads."""
    categories: list[dict[str, str]] = []
    for category in raw_categories:
        if isinstance(category, str):
            categories.append({"name": category})
        elif isinstance(category, dict):
            name = category.get("name")
            categories.append({"name": str(name) if name is not None else ""})
        else:
            categories.append({"name": str(category)})
    return categories


def extract_subscription_metadata(
    subscription: Subscription,
    *,
    normalize_category_items: bool = True,
) -> dict[str, Any]:
    """Extract normalized metadata fields with image URL fallback."""
    config = subscription.config or {}
    image_url = config.get("image_url") or subscription.image_url
    raw_categories = config.get("categories") or []
    categories = (
        normalize_categories(raw_categories)
        if normalize_category_items
        else raw_categories
    )

    return {
        "image_url": image_url,
        "author": config.get("author"),
        "platform": config.get("platform"),
        "categories": categories,
        "podcast_type": config.get("podcast_type"),
        "language": config.get("language"),
        "explicit": config.get("explicit", False),
        "link": config.get("link"),
        "total_episodes_from_config": config.get("total_episodes"),
    }


logger = logging.getLogger(__name__)


class PodcastSubscriptionService:
    """Service for managing podcast subscriptions.

    Handles:
    - Adding new subscriptions
    - Listing subscriptions with pagination
    - Refreshing subscriptions
    - Removing subscriptions
    """

    def __init__(
        self,
        db: AsyncSession,
        user_id: int,
        *,
        repo: PodcastSubscriptionRepository | None = None,
        redis: PodcastRedis | None = None,
        parser: SecureRSSParser | None = None,
        subscription_repo: SubscriptionRepository | None = None,
    ):
        """Initialize subscription service.

        Args:
            db: Database session
            user_id: Current user ID

        """
        self.db = db
        self.user_id = user_id
        self.repo = repo or PodcastSubscriptionRepository(db)
        self.redis = redis or get_shared_redis()
        self.parser = parser or SecureRSSParser(user_id)
        self.subscription_repo = subscription_repo or SubscriptionRepository(db)

    async def add_subscription(
        self,
        feed_url: str,
    ) -> tuple[Subscription, list[PodcastEpisode]]:
        """Add a new podcast subscription.

        Args:
            feed_url: RSS feed URL

        Returns:
            Tuple of (subscription, new_episodes)

        Raises:
            ValueError: If feed cannot be parsed or limit reached

        """
        # 1. Validate and parse RSS feed
        success, feed, error = await self.parser.fetch_and_parse_feed(feed_url)
        if not success:
            raise ValueError(f"Cannot parse podcast: {error}")

        # 2. Check subscription limit (0 means unlimited)
        existing_subs = await self.repo.get_user_subscriptions(self.user_id)
        if (
            settings.MAX_PODCAST_SUBSCRIPTIONS > 0
            and len(existing_subs) >= settings.MAX_PODCAST_SUBSCRIPTIONS
        ):
            raise ValueError(
                f"Maximum subscription limit reached: {settings.MAX_PODCAST_SUBSCRIPTIONS}",
            )

        # 3. Create or update subscription
        metadata = {
            "author": feed.author,
            "language": feed.language,
            "categories": feed.categories,
            "explicit": feed.explicit,
            "image_url": feed.image_url,
            "podcast_type": feed.podcast_type,
            "link": feed.link,
            "total_episodes": len(feed.episodes),
            "platform": feed.platform,
        }

        subscription = await self.repo.create_or_update_subscription(
            self.user_id,
            feed_url,
            feed.title,
            feed.description,
            None,  # custom_name
            metadata=metadata,
        )

        # 4. Save episodes in one transaction.
        episodes_payload = [
            self._build_episode_payload(
                episode=episode,
                feed_title=feed.title,
                extra_metadata=None,
            )
            for episode in feed.episodes
        ]
        _, new_episodes = await self.repo.create_or_update_episodes_batch(
            subscription_id=subscription.id,
            episodes_data=episodes_payload,
        )

        try:
            await self.redis.delete_pattern(f"podcast:subscription:list:{self.user_id}:*")
        except Exception as e:
            logger.warning(
                f"Cache invalidation skipped: op=add cache=subscription_list user_id={self.user_id}: {e}"
            )

        logger.info(
            f"User {self.user_id} added podcast: {feed.title}, {len(new_episodes)} new episodes",
        )
        return subscription, new_episodes

    async def list_subscriptions(
        self,
        filters: dict | None = None,
        page: int = 1,
        size: int = 20,
    ) -> tuple[list[dict], int]:
        """List user subscriptions with pagination.

        Args:
            filters: Optional filters
            page: Page number
            size: Items per page

        Returns:
            Tuple of (subscriptions list, total count)

        """
        (
            subscriptions,
            total,
            episode_counts,
        ) = await self.repo.get_user_subscriptions_paginated(
            self.user_id,
            page=page,
            size=size,
            filters=filters,
        )

        # Batch fetch recent episodes
        subscription_ids = [sub.id for sub in subscriptions]
        episodes_batch = await self.repo.get_subscription_episodes_batch(
            subscription_ids,
            limit_per_subscription=settings.PODCAST_RECENT_EPISODES_LIMIT,
        )

        # Batch fetch playback states
        all_episode_ids = []
        for ep_list in episodes_batch.values():
            all_episode_ids.extend([ep.id for ep in ep_list])
        playback_states = await self.repo.get_playback_states_batch(
            self.user_id,
            all_episode_ids,
        )

        # Build response
        results = []
        for sub in subscriptions:
            episodes = episodes_batch.get(sub.id, [])

            # Calculate unplayed count
            unplayed_count = 0
            for ep in episodes:
                playback = playback_states.get(ep.id)
                if (
                    not playback
                    or not playback.current_position
                    or (
                        ep.audio_duration
                        and playback.current_position < ep.audio_duration * 0.9
                    )
                ):
                    unplayed_count += 1

            episode_count = episode_counts.get(sub.id, 0)

            metadata = extract_subscription_metadata(sub)

            # Debug logging for missing image_url
            if not metadata["image_url"]:
                config = sub.config or {}
                logger.warning(
                    "Subscription %s (%s) has no image_url. config keys: %s",
                    sub.id,
                    sub.title,
                    list(config.keys()) if config else "config is None",
                )

            # Latest episode
            latest_episode_dict = None
            if episodes:
                latest = episodes[0]
                latest_episode_dict = {
                    "id": latest.id,
                    "title": latest.title,
                    "audio_url": latest.audio_url,
                    "duration": latest.audio_duration,
                    "published_at": latest.published_at,
                    "ai_summary": latest.ai_summary,
                    "status": latest.status,
                }

            results.append(
                {
                    "id": sub.id,
                    "user_id": self.user_id,
                    "title": sub.title,
                    "description": sub.description,
                    "source_url": sub.source_url,
                    "status": sub.status,
                    "last_fetched_at": sub.last_fetched_at,
                    "error_message": sub.error_message,
                    "fetch_interval": sub.fetch_interval,
                    "episode_count": episode_count,
                    "unplayed_count": unplayed_count,
                    "latest_episode": latest_episode_dict,
                    "categories": metadata["categories"],
                    "image_url": metadata["image_url"],
                    "author": metadata["author"],
                    "platform": metadata["platform"],
                    "podcast_type": metadata["podcast_type"],
                    "language": metadata["language"],
                    "explicit": metadata["explicit"],
                    "link": metadata["link"],
                    "total_episodes_from_config": metadata[
                        "total_episodes_from_config"
                    ],
                    "created_at": sub.created_at,
                    "updated_at": sub.updated_at,
                },
            )

        return results, total

    async def get_subscription_details(self, subscription_id: int) -> dict | None:
        """Get subscription details with episodes.

        Args:
            subscription_id: Subscription ID

        Returns:
            Subscription details dict or None

        """
        sub = await self.repo.get_subscription_by_id(self.user_id, subscription_id)
        if not sub:
            return None

        episodes = await self.repo.get_subscription_episodes(
            subscription_id,
            limit=settings.PODCAST_EPISODE_BATCH_SIZE,
        )
        pending_count = len([e for e in episodes if not e.ai_summary])

        metadata = extract_subscription_metadata(sub, normalize_category_items=False)

        return {
            "id": sub.id,
            "title": sub.title,
            "description": sub.description,
            "source_url": sub.source_url,
            "image_url": metadata["image_url"],
            "author": metadata["author"],
            "categories": metadata["categories"],
            "podcast_type": metadata["podcast_type"],
            "language": metadata["language"],
            "explicit": metadata["explicit"],
            "link": metadata["link"],
            "episode_count": len(episodes),
            "pending_summaries": pending_count,
            "episodes": [
                {
                    "id": ep.id,
                    "title": ep.title,
                    "description": (ep.description or "")[:100] + "..."
                    if len(ep.description or "") > 100
                    else ep.description or "",
                    "audio_url": ep.audio_url,
                    "duration": ep.audio_duration,
                    "published_at": ep.published_at,
                    "has_summary": ep.ai_summary is not None,
                    "summary": (ep.ai_summary or "")[:200] + "..."
                    if ep.ai_summary and len(ep.ai_summary) > 200
                    else ep.ai_summary or "",
                    "ai_confidence": ep.ai_confidence_score,
                    "play_count": ep.play_count,
                }
                for ep in episodes
            ],
        }

    async def refresh_subscription(self, subscription_id: int) -> list[PodcastEpisode]:
        """Refresh podcast subscription to get latest episodes.

        Args:
            subscription_id: Subscription ID

        Returns:
            List of new episodes

        Raises:
            SubscriptionNotFoundError: If subscription not found

        """
        # Import here to avoid circular dependency

        sub = await self.repo.get_subscription_by_id(self.user_id, subscription_id)
        if not sub:
            raise SubscriptionNotFoundError("Subscription not found")

        # Parse RSS feed
        success, feed, error = await self.parser.fetch_and_parse_feed(sub.source_url)
        if not success:
            raise ValueError(f"Refresh failed: {error}")

        refreshed_at = datetime.now(UTC).isoformat()
        episodes_payload = [
            self._build_episode_payload(
                episode=episode,
                feed_title=feed.title,
                extra_metadata={"refreshed_at": refreshed_at},
            )
            for episode in feed.episodes
        ]
        _, new_episodes = await self.repo.create_or_update_episodes_batch(
            subscription_id=subscription_id,
            episodes_data=episodes_payload,
        )
        for saved_episode in new_episodes:
            # Manual refresh: NO auto-processing, user requests via frontend
            logger.info(
                "Episode %s discovered via manual refresh, awaiting user request",
                saved_episode.id,
            )

        # Update subscription metadata (including image_url) from feed
        # This ensures the subscription has correct metadata even on first refresh
        metadata = {
            "author": feed.author,
            "language": feed.language,
            "categories": feed.categories,
            "explicit": feed.explicit,
            "image_url": feed.image_url,
            "podcast_type": feed.podcast_type,
            "link": feed.link,
            "total_episodes": len(feed.episodes),
            "platform": feed.platform,
        }

        # Only update metadata if the feed provided valid data
        if feed.image_url or feed.author or feed.categories:
            await self.repo.update_subscription_metadata(subscription_id, metadata)
            logger.debug(
                f"Updated subscription {subscription_id} metadata: image_url={feed.image_url}",
            )

        # Update last fetch time
        await self.repo.update_subscription_fetch_time(
            subscription_id,
            feed.last_fetched,
        )

        # Invalidate related caches in best-effort mode.
        await self._invalidate_subscription_related_caches(
            subscription_id,
            operation="refresh_subscription",
        )

        if len(new_episodes) > 0:
            logger.info(
                f"User {self.user_id} refreshed subscription: {sub.title}, found {len(new_episodes)} new episodes",
            )

        return new_episodes

    async def reparse_subscription(
        self,
        subscription_id: int,
        force_all: bool = False,
    ) -> dict:
        """Re-parse all episodes for a subscription.

        Args:
            subscription_id: Subscription ID
            force_all: Force re-parse all episodes (default: only missing)

        Returns:
            Dict with parsing statistics

        """
        sub = await self.repo.get_subscription_by_id(self.user_id, subscription_id)
        if not sub:
            raise SubscriptionNotFoundError("Subscription not found")

        logger.info(
            f"User {self.user_id} starting re-parse of subscription: {sub.title}",
        )

        # Parse RSS feed
        success, feed, error = await self.parser.fetch_and_parse_feed(sub.source_url)
        if not success:
            raise ValueError(f"Re-parse failed: {error}")

        # Get existing episode links
        existing_item_links = set()
        if not force_all:
            existing_episodes = await self.repo.get_subscription_episodes(
                subscription_id,
                limit=None,
            )
            existing_item_links = {
                ep.item_link for ep in existing_episodes if ep.item_link
            }

        reparsed_at = datetime.now(UTC).isoformat()
        episodes_to_process = [
            episode
            for episode in feed.episodes
            if force_all or episode.link not in existing_item_links
        ]
        episodes_payload = [
            self._build_episode_payload(
                episode=episode,
                feed_title=feed.title,
                extra_metadata={
                    "reparsed_at": reparsed_at,
                    "item_link": episode.link,
                },
            )
            for episode in episodes_to_process
        ]
        (
            processed_episodes,
            new_episode_rows,
        ) = await self.repo.create_or_update_episodes_batch(
            subscription_id=subscription_id,
            episodes_data=episodes_payload,
        )
        processed = len(processed_episodes)
        new_episodes = len(new_episode_rows)
        updated_episodes = processed - new_episodes
        failed = 0

        # Update subscription metadata
        metadata = {
            "author": feed.author,
            "language": feed.language,
            "categories": feed.categories,
            "explicit": feed.explicit,
            "image_url": feed.image_url,
            "podcast_type": feed.podcast_type,
            "link": feed.link,
            "total_episodes": len(feed.episodes),
            "platform": feed.platform,
            "reparsed_at": reparsed_at,
        }

        await self.repo.update_subscription_metadata(subscription_id, metadata)
        await self.repo.update_subscription_fetch_time(
            subscription_id,
            feed.last_fetched,
        )

        # Invalidate related caches in best-effort mode.
        await self._invalidate_subscription_related_caches(
            subscription_id,
            operation="reparse_subscription",
        )

        result = {
            "subscription_id": subscription_id,
            "subscription_title": sub.title,
            "total_episodes_in_feed": len(feed.episodes),
            "processed": processed,
            "new_episodes": new_episodes,
            "updated_episodes": updated_episodes,
            "failed": failed,
            "message": f"Re-parse completed: {processed} processed, {new_episodes} new, {updated_episodes} updated, {failed} failed",
        }

        logger.info(f"User {self.user_id} re-parse completed: {result}")
        return result

    async def remove_subscription(self, subscription_id: int) -> bool:
        """Unsubscribe current user from a subscription.

        If this was the last subscriber, the shared subscription source
        and related data are deleted by cascade.

        Args:
            subscription_id: Subscription ID

        Returns:
            True if unsubscribed successfully

        """
        try:
            sub = await self._validate_and_get_subscription(subscription_id)
            if not sub:
                return False

            removed = await self.subscription_repo.delete_subscription(
                user_id=self.user_id,
                sub_id=subscription_id,
            )
            if not removed:
                return False

            await self._invalidate_subscription_related_caches(
                subscription_id,
                operation="remove_subscription",
            )
            logger.info(
                f"User {self.user_id} unsubscribed from subscription {subscription_id}",
            )
            return True

        except Exception as e:
            logger.error(f"Failed to remove subscription {subscription_id}: {e}")
            raise

    async def remove_subscriptions_bulk(
        self,
        subscription_ids: list[int],
    ) -> dict[str, Any]:
        """Bulk remove subscriptions.

        Args:
            subscription_ids: List of subscription IDs

        Returns:
            Dict with operation results

        """
        from sqlalchemy import and_, select
        from sqlalchemy import delete as sa_delete

        from app.domains.podcast.models import UserSubscription

        # Batch validate: find which subscriptions belong to this user
        valid_result = await self.db.execute(
            select(Subscription.id)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .where(
                and_(
                    Subscription.id.in_(subscription_ids),
                    UserSubscription.user_id == self.user_id,
                    UserSubscription.is_archived.is_(False),
                ),
            )
        )
        valid_ids = [row.id for row in valid_result.all()]
        invalid_ids = set(subscription_ids) - set(valid_ids)

        errors = [
            {
                "subscription_id": sid,
                "error": f"Subscription {sid} not found or access denied",
            }
            for sid in invalid_ids
        ]

        if not valid_ids:
            return {
                "success_count": 0,
                "failed_count": len(errors),
                "errors": errors,
                "deleted_subscription_ids": [],
            }

        # Batch delete user subscriptions
        await self.db.execute(
            sa_delete(UserSubscription).where(
                and_(
                    UserSubscription.user_id == self.user_id,
                    UserSubscription.subscription_id.in_(valid_ids),
                ),
            )
        )

        # Find orphaned subscriptions (no remaining subscribers)
        remaining_result = await self.db.execute(
            select(UserSubscription.subscription_id)
            .where(UserSubscription.subscription_id.in_(valid_ids))
            .group_by(UserSubscription.subscription_id)
        )
        ids_with_subscribers = {row.subscription_id for row in remaining_result.all()}
        orphaned_ids = set(valid_ids) - ids_with_subscribers

        if orphaned_ids:
            await self.db.execute(
                sa_delete(Subscription).where(Subscription.id.in_(orphaned_ids))
            )

        await self.db.commit()

        # Invalidate caches for all deleted subscriptions
        for subscription_id in valid_ids:
            await self._invalidate_subscription_related_caches(
                subscription_id,
                operation="remove_subscription",
            )

        logger.info(
            f"User {self.user_id} bulk removed {len(valid_ids)} subscriptions",
        )

        return {
            "success_count": len(valid_ids),
            "failed_count": len(errors),
            "errors": errors,
            "deleted_subscription_ids": valid_ids,
        }

    # === Private helper methods ===

    @staticmethod
    def _build_subscription_cache_filters(filters: Any) -> dict[str, Any]:
        """Build a compact, deterministic filter payload for cache keys."""
        if not filters:
            return {}
        return {
            "category_id": getattr(filters, "category_id", None),
            "status": getattr(filters, "status", None),
        }

    @staticmethod
    def _build_episode_payload(
        *,
        episode: Any,
        feed_title: str,
        extra_metadata: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        metadata = {"feed_title": feed_title}
        if extra_metadata:
            metadata.update(extra_metadata)
        return {
            "title": episode.title,
            "description": episode.description,
            "audio_url": episode.audio_url,
            "published_at": episode.published_at,
            "audio_duration": episode.duration,
            "transcript_url": episode.transcript_url,
            "item_link": episode.link,
            "metadata": metadata,
        }

    async def _validate_and_get_subscription(
        self,
        subscription_id: int,
        check_source_type: bool = False,
    ) -> Subscription | None:
        """Validate subscription exists and belongs to user."""
        from sqlalchemy import and_, select

        from app.domains.podcast.models import UserSubscription

        stmt = (
            select(Subscription)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .where(
                and_(
                    Subscription.id == subscription_id,
                    UserSubscription.user_id == self.user_id,
                    UserSubscription.is_archived.is_(False),
                ),
            )
        )

        if check_source_type:
            stmt = stmt.where(Subscription.source_type == "podcast-rss")

        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def _invalidate_subscription_related_caches(
        self,
        subscription_id: int,
        *,
        operation: str,
    ) -> None:
        """Invalidate caches without failing the business operation."""
        try:
            await self.redis.delete_pattern(f"podcast:episodes:list:{subscription_id}:*")
        except Exception as e:
            logger.warning(
                f"Cache invalidation skipped: "
                f"op={operation} cache=episode_list user_id={self.user_id} "
                f"subscription_id={subscription_id}: {e}"
            )
        try:
            await self.redis.delete_pattern(f"podcast:subscription:list:{self.user_id}:*")
        except Exception as e:
            logger.warning(
                f"Cache invalidation skipped: "
                f"op={operation} cache=subscription_list user_id={self.user_id} "
                f"subscription_id={subscription_id}: {e}"
            )