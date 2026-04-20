"""Podcast Subscription Service - Manages podcast subscriptions.

播客订阅服务 - 管理播客订阅
"""

import logging
from datetime import UTC, datetime
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.exceptions import SubscriptionNotFoundError
from app.core.redis import (
    PodcastRedis,
    get_shared_redis,
    safe_cache_get,
    safe_cache_invalidate,
    safe_cache_write,
)
from app.domains.podcast.integration.secure_rss_parser import SecureRSSParser
from app.domains.podcast.models import PodcastEpisode
from app.domains.podcast.repositories import PodcastSubscriptionRepository
from app.domains.subscription.models import Subscription
from app.domains.subscription.repositories import SubscriptionRepository


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

        await safe_cache_invalidate(
            lambda: self.redis.invalidate_subscription_list(self.user_id),
            log_warning=logger.warning,
            error_message=(
                "Cache invalidation skipped: "
                f"op=add cache=subscription_list user_id={self.user_id}"
            ),
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
        cache_filters = self._build_subscription_cache_filters(filters)
        cached = await safe_cache_get(
            lambda: self.redis.get_subscription_list(
                self.user_id,
                page,
                size,
                filters=cache_filters,
            ),
            log_warning=logger.warning,
            error_message="Redis cache read failed for subscription list, falling back to DB",
        )
        if (
            isinstance(cached, dict)
            and isinstance(cached.get("subscriptions"), list)
            and isinstance(cached.get("total"), int)
        ):
            return cached["subscriptions"], cached["total"]

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

        await safe_cache_write(
            lambda: self.redis.set_subscription_list(
                self.user_id,
                page,
                size,
                {"subscriptions": results, "total": total},
                filters=cache_filters,
            ),
            log_warning=logger.warning,
            error_message="Redis cache write failed for subscription list, skipping",
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

        from app.domains.subscription.models import UserSubscription

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

        from app.domains.subscription.models import UserSubscription

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
        await safe_cache_invalidate(
            lambda: self.redis.invalidate_episode_list(subscription_id),
            log_warning=logger.warning,
            error_message=(
                "Cache invalidation skipped: "
                f"op={operation} cache=episode_list user_id={self.user_id} "
                f"subscription_id={subscription_id}"
            ),
        )
        await safe_cache_invalidate(
            lambda: self.redis.invalidate_subscription_list(self.user_id),
            log_warning=logger.warning,
            error_message=(
                "Cache invalidation skipped: "
                f"op={operation} cache=subscription_list user_id={self.user_id} "
                f"subscription_id={subscription_id}"
            ),
        )
