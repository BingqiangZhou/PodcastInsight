"""Unified podcast repository - episodes, subscriptions, playback, search, stats."""

from __future__ import annotations

import logging
from collections.abc import Mapping
from datetime import UTC, date, datetime, timedelta
from inspect import isawaitable
from time import perf_counter
from typing import TYPE_CHECKING, Any

from sqlalchemy import and_, case, desc, func, or_, select
from sqlalchemy.exc import DBAPIError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import attributes, joinedload, lazyload

from app.core.datetime_utils import (
    ensure_timezone_aware_fetch_time,
    sanitize_published_date,
)
from app.core.exceptions import (
    EpisodeNotInQueueError,
    InvalidReorderPayloadError,
    QueueLimitExceededError,
    SubscriptionNotFoundError,
)
from app.admin.settings_provider import DatabaseSettingsProvider
from app.core.redis import RedisCache, get_shared_redis
from app.domains.podcast.models import (
    EpisodeHighlight,
    PodcastDailyReport,
    PodcastEpisode,
    PodcastPlaybackState,
    PodcastQueue,
    PodcastQueueItem,
)
from app.shared.repository_helpers import resolve_window_total


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
    from app.domains.podcast.models import Subscription, UserSubscription

    return Subscription, UserSubscription

if TYPE_CHECKING:
    pass

if TYPE_CHECKING:
    pass

logger = logging.getLogger(__name__)

if TYPE_CHECKING:
    pass

logger = logging.getLogger(__name__)

if TYPE_CHECKING:
    pass

logger = logging.getLogger(__name__)

def _get_user_subscription_model():
    """Lazy import UserSubscription model to maintain domain boundaries.

    Returns:
        UserSubscription model class
    """
    from app.domains.podcast.models import UserSubscription

    return UserSubscription

class PodcastRepository:
    """Unified podcast data access."""

    """Small shared base for specialized podcast repositories."""

    def __init__(
        self,
        db: AsyncSession,
        redis: RedisCache | None = None,
        settings_provider: DatabaseSettingsProvider | None = None,
    ):
        self.db = db
        self.redis = redis or get_shared_redis()
        self.settings_provider = settings_provider or DatabaseSettingsProvider()
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

    """Subscription upsert, episode upsert, and summary state."""

    async def create_or_update_subscription(
        self,
        user_id: int,
        feed_url: str,
        title: str,
        description: str = "",
        custom_name: str | None = None,
        metadata: dict | None = None,
    ):
        """Create or update a podcast subscription.

        Uses lazy imports to maintain domain boundary separation.
        """
        from app.domains.podcast.models import UpdateFrequency

        Subscription, UserSubscription = _get_subscription_models()

        stmt = select(Subscription).where(
            and_(
                Subscription.source_url == feed_url,
                Subscription.source_type == "podcast-rss",
            ),
        )
        result = await self.db.execute(stmt)
        subscription = result.scalar_one_or_none()

        update_frequency = UpdateFrequency.HOURLY.value
        update_time = None
        update_day_of_week = None

        setting = await self.settings_provider.get_setting(
            self.db, "rss.frequency_settings"
        )
        if setting:
            update_frequency = setting.get(
                "update_frequency",
                UpdateFrequency.HOURLY.value,
            )
            update_time = setting.get("update_time")
            update_day_of_week = setting.get("update_day_of_week")

        if subscription:
            user_sub_stmt = select(UserSubscription).where(
                and_(
                    UserSubscription.user_id == user_id,
                    UserSubscription.subscription_id == subscription.id,
                ),
            )
            user_sub_result = await self.db.execute(user_sub_stmt)
            user_sub = user_sub_result.scalar_one_or_none()

            if not user_sub:
                user_sub = UserSubscription(
                    user_id=user_id,
                    subscription_id=subscription.id,
                    update_frequency=update_frequency,
                    update_time=update_time,
                    update_day_of_week=update_day_of_week,
                )
                self.db.add(user_sub)
            elif user_sub.is_archived:
                user_sub.is_archived = False

            subscription.title = custom_name or title
            subscription.description = description
            subscription.updated_at = datetime.now(UTC)
            if metadata:
                if "image_url" in metadata:
                    subscription.image_url = metadata.get("image_url")
                existing_config = dict(subscription.config or {})
                existing_config.update(metadata)
                subscription.config = existing_config
                attributes.flag_modified(subscription, "config")
        else:
            subscription = Subscription(
                source_url=feed_url,
                source_type="podcast-rss",
                title=custom_name or title,
                description=description,
                status="active",
                fetch_interval=3600,
                image_url=(metadata or {}).get("image_url"),
                config=metadata or {},
            )
            self.db.add(subscription)
            await self.db.flush()

            user_sub = UserSubscription(
                user_id=user_id,
                subscription_id=subscription.id,
                update_frequency=update_frequency,
                update_time=update_time,
                update_day_of_week=update_day_of_week,
            )
            self.db.add(user_sub)

        await self.db.commit()
        # No refresh needed - subscription is already in session with updated values
        return subscription

    async def get_user_subscriptions(self, user_id: int) -> list:
        """Get all user subscriptions for podcasts.

        Uses lazy imports to maintain domain boundary separation.
        """
        Subscription, UserSubscription = _get_subscription_models()

        stmt = (
            select(Subscription)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .where(
                and_(
                    *self._active_user_subscription_filters(user_id),
                    self._podcast_source_type_filter(),
                ),
            )
            .order_by(Subscription.created_at.desc())
        )
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def get_subscription_by_id(
        self,
        user_id: int,
        sub_id: int,
    ):
        """Get a subscription by ID.

        Uses lazy imports to maintain domain boundary separation.
        """
        Subscription, UserSubscription = _get_subscription_models()

        stmt = (
            select(Subscription)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .where(
                and_(
                    *self._active_user_subscription_filters(user_id),
                    Subscription.id == sub_id,
                    self._podcast_source_type_filter(),
                ),
            )
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_subscription_by_url(
        self,
        user_id: int,
        feed_url: str,
    ):
        """Get a subscription by URL.

        Uses lazy imports to maintain domain boundary separation.
        """
        Subscription, UserSubscription = _get_subscription_models()

        stmt = (
            select(Subscription)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .where(
                and_(
                    *self._active_user_subscription_filters(user_id),
                    Subscription.source_url == feed_url,
                    self._podcast_source_type_filter(),
                ),
            )
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_subscription_by_id_direct(
        self,
        subscription_id: int,
    ):
        """Get a subscription by ID without user filter.

        Uses lazy imports to maintain domain boundary separation.
        """
        Subscription, _ = _get_subscription_models()

        stmt = select(Subscription).where(
            and_(
                Subscription.id == subscription_id,
                Subscription.source_type.in_(["podcast-rss", "rss"]),
            ),
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def create_or_update_episode(
        self,
        subscription_id: int,
        title: str,
        description: str,
        audio_url: str,
        published_at: datetime,
        audio_duration: int | None = None,
        transcript_url: str | None = None,
        item_link: str | None = None,
        metadata: dict | None = None,
    ) -> tuple[PodcastEpisode, bool]:
        stmt = select(PodcastEpisode).where(PodcastEpisode.item_link == item_link)
        result = await self.db.execute(stmt)
        episode = result.scalar_one_or_none()

        if episode:
            episode.title = title
            episode.description = description
            episode.audio_url = audio_url
            episode.published_at = sanitize_published_date(published_at)
            episode.audio_duration = audio_duration
            episode.transcript_url = transcript_url
            episode.updated_at = datetime.now(UTC)
            if episode.subscription_id != subscription_id:
                episode.subscription_id = subscription_id
            if metadata:
                current_metadata = episode.metadata_json or {}
                episode.metadata_json = {**current_metadata, **metadata}
            is_new = False
        else:
            episode = PodcastEpisode(
                subscription_id=subscription_id,
                title=title,
                description=description,
                audio_url=audio_url,
                published_at=sanitize_published_date(published_at),
                audio_duration=audio_duration,
                transcript_url=transcript_url,
                item_link=item_link,
                status="pending_summary",
                metadata_json=metadata or {},
            )
            self.db.add(episode)
            is_new = True

        await self.db.commit()
        # episode.id auto-populated by SQLAlchemy after flush/commit
        if is_new or episode.ai_summary:
            await self._cache_episode_metadata(episode)
        return episode, is_new

    async def create_or_update_episodes_batch(
        self,
        subscription_id: int,
        episodes_data: list[dict[str, Any]],
    ) -> tuple[list[PodcastEpisode], list[PodcastEpisode]]:
        if not episodes_data:
            return [], []

        item_links = list(
            {data["item_link"] for data in episodes_data if data.get("item_link")},
        )
        existing_by_item_link: dict[str, PodcastEpisode] = {}

        if item_links:
            existing_stmt = select(PodcastEpisode).where(
                PodcastEpisode.item_link.in_(item_links),
            )
            existing_result = await self.db.execute(existing_stmt)
            existing_episodes = list(existing_result.scalars().all())
            existing_by_item_link = {
                episode.item_link: episode
                for episode in existing_episodes
                if episode.item_link
            }

        processed_episodes: list[PodcastEpisode] = []
        new_episodes: list[PodcastEpisode] = []
        now = datetime.now(UTC)

        for data in episodes_data:
            title = data.get("title") or "Untitled"
            description = data.get("description") or ""
            audio_url = data.get("audio_url") or ""
            transcript_url = data.get("transcript_url")
            audio_duration = data.get("audio_duration")
            item_link = data.get("item_link")
            metadata = data.get("metadata") or {}
            published_at_raw = data.get("published_at") or now
            published_at = sanitize_published_date(published_at_raw)

            episode = existing_by_item_link.get(item_link) if item_link else None
            if episode:
                episode.title = title
                episode.description = description
                episode.audio_url = audio_url
                episode.published_at = published_at
                episode.audio_duration = audio_duration
                episode.transcript_url = transcript_url
                episode.updated_at = now
                if episode.subscription_id != subscription_id:
                    episode.subscription_id = subscription_id
                if metadata:
                    current_metadata = episode.metadata_json or {}
                    episode.metadata_json = {**current_metadata, **metadata}
                processed_episodes.append(episode)
                continue

            new_episode = PodcastEpisode(
                subscription_id=subscription_id,
                title=title,
                description=description,
                audio_url=audio_url,
                published_at=published_at,
                audio_duration=audio_duration,
                transcript_url=transcript_url,
                item_link=item_link,
                status="pending_summary",
                metadata_json=metadata,
            )
            self.db.add(new_episode)
            processed_episodes.append(new_episode)
            new_episodes.append(new_episode)

        await self.db.flush()
        await self.db.commit()

        for episode in new_episodes:
            if episode.id:
                await self._cache_episode_metadata(episode)

        return processed_episodes, new_episodes

    async def get_unsummarized_episodes(
        self,
        subscription_id: int | None = None,
        limit: int | None = 100,
    ) -> list[PodcastEpisode]:
        stmt = select(PodcastEpisode).where(
            and_(
                PodcastEpisode.ai_summary.is_(None),
                PodcastEpisode.status.in_(["pending_summary", "summary_failed"]),
            ),
        )
        if subscription_id:
            stmt = stmt.where(PodcastEpisode.subscription_id == subscription_id)

        stmt = stmt.order_by(PodcastEpisode.published_at.desc())
        if limit and limit > 0:
            stmt = stmt.limit(limit)
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def get_pending_summaries_for_user(
        self,
        user_id: int,
    ) -> list[dict[str, Any]]:
        """Get pending summaries for a user.

        Uses lazy imports to maintain domain boundary separation.
        """
        Subscription, UserSubscription = _get_subscription_models()

        stmt = (
            select(PodcastEpisode, Subscription.title)
            .options(joinedload(PodcastEpisode.transcript))
            .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .where(
                and_(
                    *self._active_user_subscription_filters(user_id),
                    self._podcast_source_type_filter(),
                    PodcastEpisode.ai_summary.is_(None),
                    PodcastEpisode.status.in_(["pending_summary", "summary_failed"]),
                ),
            )
            .order_by(PodcastEpisode.published_at.desc(), PodcastEpisode.id.desc())
        )
        rows = (await self.db.execute(stmt)).unique().all()
        results: list[dict[str, Any]] = []
        for episode, subscription_title in rows:
            description = episode.description or ""
            transcript = (
                episode.transcript.transcript_content if episode.transcript else ""
            )
            results.append(
                {
                    "episode_id": episode.id,
                    "subscription_title": subscription_title,
                    "episode_title": episode.title,
                    "size_estimate": len(description) + len(transcript),
                },
            )
        return results

    async def get_subscription_episodes(
        self,
        subscription_id: int,
        limit: int = 20,
    ) -> list[PodcastEpisode]:
        stmt = (
            select(PodcastEpisode)
            .options(joinedload(PodcastEpisode.subscription))
            .where(PodcastEpisode.subscription_id == subscription_id)
            .order_by(desc(PodcastEpisode.published_at))
            .limit(limit)
        )

        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def count_subscription_episodes(self, subscription_id: int) -> int:
        stmt = select(func.count(PodcastEpisode.id)).where(
            PodcastEpisode.subscription_id == subscription_id,
        )
        result = await self.db.execute(stmt)
        return result.scalar() or 0

    async def get_episode_by_id(
        self,
        episode_id: int,
        user_id: int | None = None,
    ) -> PodcastEpisode | None:
        """Get an episode by ID.

        Uses lazy imports to maintain domain boundary separation.
        """
        Subscription, UserSubscription = _get_subscription_models()

        stmt = (
            select(PodcastEpisode)
            .options(
                joinedload(PodcastEpisode.subscription),
                joinedload(PodcastEpisode.transcript),
            )
            .where(PodcastEpisode.id == episode_id)
        )
        if user_id:
            stmt = (
                stmt.join(Subscription)
                .join(
                    UserSubscription,
                    UserSubscription.subscription_id == Subscription.id,
                )
                .where(and_(*self._active_user_subscription_filters(user_id)))
            )

        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_episode_by_item_link(
        self,
        subscription_id: int,
        item_link: str,
    ) -> PodcastEpisode | None:
        stmt = select(PodcastEpisode).where(
            and_(
                PodcastEpisode.subscription_id == subscription_id,
                PodcastEpisode.item_link == item_link,
            ),
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def update_ai_summary(
        self,
        episode_id: int,
        summary: str,
        version: str = "v1",
        confidence: float | None = None,
        transcript_used: bool = False,
    ) -> PodcastEpisode:
        episode = await self.get_episode_by_id(episode_id)
        if not episode:
            raise ValueError(f"Episode {episode_id} not found")

        episode.ai_summary = summary
        episode.summary_version = version
        episode.status = "summarized"
        if confidence:
            episode.ai_confidence_score = confidence

        metadata = episode.metadata_json or {}
        metadata["transcript_used"] = transcript_used
        metadata["summarized_at"] = datetime.now(UTC).isoformat()
        metadata.pop("summary_error", None)
        metadata.pop("summary_failed_at", None)
        episode.metadata_json = metadata

        await self.db.commit()
        # No refresh needed - episode is already in session with updated values
        await self.redis.set_ai_summary(episode_id, summary, version)
        return episode

    async def mark_summary_failed(self, episode_id: int, error: str) -> None:
        episode = await self.get_episode_by_id(episode_id)
        if episode:
            episode.status = "summary_failed"
            metadata = episode.metadata_json or {}
            metadata["summary_error"] = error
            metadata["failed_at"] = datetime.now(UTC).isoformat()
            episode.metadata_json = metadata
            await self.db.commit()

    """Subscription/episode pagination and lightweight feed queries."""

    async def get_user_subscriptions_paginated(
        self,
        user_id: int,
        page: int = 1,
        size: int = 20,
        filters: dict | None = None,
    ) -> tuple[list, int, dict[int, int]]:
        """Get paginated user subscriptions.

        Uses lazy imports to maintain domain boundary separation.
        """
        Subscription, UserSubscription = _get_subscription_models()

        skip = (page - 1) * size
        base_query = (
            select(Subscription)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .where(
                and_(
                    *self._active_user_subscription_filters(user_id),
                    self._podcast_source_type_filter(),
                ),
            )
        )

        if filters and filters.status:
            base_query = base_query.where(Subscription.status == filters.status)

        episode_count_subquery = (
            select(
                PodcastEpisode.subscription_id.label("subscription_id"),
                func.count(PodcastEpisode.id).label("episode_count"),
            )
            .group_by(PodcastEpisode.subscription_id)
            .subquery()
        )

        query = (
            base_query.outerjoin(
                episode_count_subquery,
                episode_count_subquery.c.subscription_id == Subscription.id,
            )
            .add_columns(
                func.coalesce(episode_count_subquery.c.episode_count, 0),
                func.count(Subscription.id).over(),
            )
            .order_by(Subscription.created_at.desc(), Subscription.id.desc())
            .offset(skip)
            .limit(size)
        )

        result = await self.db.execute(query)
        rows = result.all()
        total = await resolve_window_total(
            self.db,
            rows,
            total_index=2,
            fallback_count_query=select(func.count()).select_from(
                base_query.subquery(),
            ),
        )
        subscriptions = [row[0] for row in rows]
        episode_counts = {row[0].id: int(row[1]) for row in rows}
        return subscriptions, total, episode_counts

    async def get_episodes_paginated(
        self,
        user_id: int,
        page: int = 1,
        size: int = 20,
        filters: dict | None = None,
    ) -> tuple[list[PodcastEpisode], int]:
        """Get paginated episodes.

        Uses lazy imports to maintain domain boundary separation.
        """
        Subscription, UserSubscription = _get_subscription_models()

        skip = (page - 1) * size
        base_query = (
            select(PodcastEpisode)
            .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .options(
                joinedload(PodcastEpisode.subscription),
                joinedload(PodcastEpisode.transcript),
            )
            .where(and_(*self._active_user_subscription_filters(user_id)))
        )

        if filters:
            if filters.subscription_id:
                base_query = base_query.where(
                    PodcastEpisode.subscription_id == filters.subscription_id,
                )
            if filters.has_summary is not None:
                if filters.has_summary:
                    base_query = base_query.where(PodcastEpisode.ai_summary.isnot(None))
                else:
                    base_query = base_query.where(PodcastEpisode.ai_summary.is_(None))
            if filters.is_played is not None:
                if filters.is_played:
                    base_query = base_query.join(PodcastPlaybackState).where(
                        PodcastPlaybackState.current_position
                        >= PodcastEpisode.audio_duration * 0.9,
                    )
                else:
                    base_query = base_query.outerjoin(PodcastPlaybackState).where(
                        or_(
                            PodcastPlaybackState.id.is_(None),
                            PodcastPlaybackState.current_position
                            < PodcastEpisode.audio_duration * 0.9,
                        ),
                    )

        total_result = await self.db.execute(
            select(func.count()).select_from(base_query.subquery()),
        )
        total = int(total_result.scalar() or 0)

        query = (
            base_query.order_by(
                PodcastEpisode.published_at.desc(),
                PodcastEpisode.id.desc(),
            )
            .offset(skip)
            .limit(size)
        )

        result = await self.db.execute(query)
        rows = list(result.unique().scalars().all())
        return rows, total

    @staticmethod
    def _feed_count_cache_key(user_id: int) -> str:
        return f"podcast:feed:count:{user_id}"

    async def _get_feed_total_count(self, user_id: int) -> int:
        cache_key = self._feed_count_cache_key(user_id)
        cached_total = await self.redis.get(cache_key)
        if cached_total is not None:
            try:
                return int(cached_total)
            except (TypeError, ValueError):
                logger.warning("Invalid cached feed total count for user %s", user_id)

        Subscription, UserSubscription = _get_subscription_models()
        count_query = (
            select(func.count(PodcastEpisode.id))
            .select_from(PodcastEpisode)
            .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .where(and_(*self._active_user_subscription_filters(user_id)))
        )
        total_result = await self.db.execute(count_query)
        total = int(total_result.scalar() or 0)
        await self.redis.set(cache_key, str(total), ttl=120)
        return total

    def _build_feed_lightweight_base_query(self, user_id: int):
        """Build base query for lightweight feed.

        Uses lazy imports to maintain domain boundary separation.
        """
        Subscription, UserSubscription = _get_subscription_models()

        return (
            select(
                PodcastEpisode.id.label("id"),
                PodcastEpisode.subscription_id.label("subscription_id"),
                Subscription.title.label("subscription_title"),
                Subscription.image_url.label("subscription_image_url"),
                Subscription.config.label("subscription_config"),
                PodcastEpisode.title.label("title"),
                PodcastEpisode.description.label("description"),
                PodcastEpisode.ai_summary.label("ai_summary"),
                PodcastEpisode.audio_url.label("audio_url"),
                PodcastEpisode.audio_duration.label("audio_duration"),
                PodcastEpisode.audio_file_size.label("audio_file_size"),
                PodcastEpisode.published_at.label("published_at"),
                PodcastEpisode.image_url.label("image_url"),
                PodcastEpisode.item_link.label("item_link"),
                PodcastEpisode.transcript_url.label("transcript_url"),
                PodcastEpisode.summary_version.label("summary_version"),
                PodcastEpisode.ai_confidence_score.label("ai_confidence_score"),
                PodcastEpisode.play_count.label("play_count"),
                PodcastEpisode.season.label("season"),
                PodcastEpisode.episode_number.label("episode_number"),
                PodcastEpisode.explicit.label("explicit"),
                PodcastEpisode.status.label("status"),
                PodcastEpisode.metadata_json.label("metadata"),
                PodcastEpisode.created_at.label("created_at"),
                PodcastEpisode.updated_at.label("updated_at"),
                PodcastPlaybackState.current_position.label("playback_position"),
                PodcastPlaybackState.is_playing.label("is_playing"),
                PodcastPlaybackState.playback_rate.label("playback_rate"),
                PodcastPlaybackState.last_updated_at.label("last_played_at"),
            )
            .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .outerjoin(
                PodcastPlaybackState,
                and_(
                    PodcastPlaybackState.episode_id == PodcastEpisode.id,
                    PodcastPlaybackState.user_id == user_id,
                ),
            )
            .where(and_(*self._active_user_subscription_filters(user_id)))
        )

    def _build_feed_lightweight_item(self, row: Mapping[str, Any]) -> dict[str, Any]:
        row_data = dict(row)
        subscription_config = row_data.pop("subscription_config", None)
        subscription_image_url = self._normalize_optional_image_url(
            row_data.get("subscription_image_url"),
        )
        config_image_url = None
        if isinstance(subscription_config, dict):
            config_image_url = self._normalize_optional_image_url(
                subscription_config.get("image_url"),
            )
        effective_subscription_image = config_image_url or subscription_image_url

        playback_position = row_data.get("playback_position")
        audio_duration = row_data.get("audio_duration")
        is_played = bool(
            playback_position
            and audio_duration
            and playback_position >= audio_duration * 0.9,
        )
        image_url = self._normalize_optional_image_url(row_data.get("image_url"))
        if image_url is None:
            image_url = effective_subscription_image

        return {
            "id": row_data["id"],
            "subscription_id": row_data["subscription_id"],
            "subscription_title": row_data.get("subscription_title"),
            "subscription_image_url": effective_subscription_image,
            "title": row_data["title"],
            "description": row_data.get("description"),
            "audio_url": row_data["audio_url"],
            "audio_duration": row_data.get("audio_duration"),
            "audio_file_size": row_data.get("audio_file_size"),
            "published_at": row_data["published_at"],
            "image_url": image_url,
            "item_link": row_data.get("item_link"),
            "transcript_url": row_data.get("transcript_url"),
            "transcript_content": None,
            "ai_summary": row_data.get("ai_summary"),
            "summary_version": row_data.get("summary_version"),
            "ai_confidence_score": row_data.get("ai_confidence_score"),
            "play_count": row_data.get("play_count") or 0,
            "last_played_at": row_data.get("last_played_at"),
            "season": row_data.get("season"),
            "episode_number": row_data.get("episode_number"),
            "explicit": bool(row_data.get("explicit", False)),
            "status": row_data.get("status") or "published",
            "metadata": row_data.get("metadata") or {},
            "playback_position": playback_position,
            "is_playing": bool(row_data.get("is_playing", False)),
            "playback_rate": float(row_data.get("playback_rate") or 1.0),
            "is_played": is_played,
            "created_at": row_data["created_at"],
            "updated_at": row_data.get("updated_at"),
        }

    async def get_feed_lightweight_page_paginated(
        self,
        user_id: int,
        page: int = 1,
        size: int = 20,
    ) -> tuple[list[dict[str, Any]], int]:
        total = await self._get_feed_total_count(user_id)
        query = self._build_feed_lightweight_base_query(user_id).order_by(
            desc(PodcastEpisode.published_at),
            desc(PodcastEpisode.id),
        )
        query = query.offset((page - 1) * size).limit(size)

        result = await self.db.execute(query)
        rows = result.mappings().all()
        items = [self._build_feed_lightweight_item(row) for row in rows]
        return items, total

    async def get_feed_lightweight_cursor_paginated(
        self,
        user_id: int,
        size: int = 20,
        cursor_published_at: Any = None,
        cursor_episode_id: int | None = None,
    ) -> tuple[list[dict[str, Any]], int, bool, tuple[Any, int] | None]:
        total = await self._get_feed_total_count(user_id)
        query = self._build_feed_lightweight_base_query(user_id)

        if cursor_published_at is not None and cursor_episode_id is not None:
            query = query.where(
                or_(
                    PodcastEpisode.published_at < cursor_published_at,
                    and_(
                        PodcastEpisode.published_at == cursor_published_at,
                        PodcastEpisode.id < cursor_episode_id,
                    ),
                ),
            )

        query = query.order_by(
            desc(PodcastEpisode.published_at),
            desc(PodcastEpisode.id),
        ).limit(size + 1)

        result = await self.db.execute(query)
        rows = result.mappings().all()

        has_more = len(rows) > size
        trimmed_rows = rows[:size]
        items = [self._build_feed_lightweight_item(row) for row in trimmed_rows]
        next_cursor_values: tuple[Any, int] | None = None
        if has_more and trimmed_rows:
            tail = trimmed_rows[-1]
            next_cursor_values = (tail["published_at"], tail["id"])

        return items, total, has_more, next_cursor_values

    async def get_feed_cursor_paginated(
        self,
        user_id: int,
        size: int = 20,
        cursor_published_at: Any = None,
        cursor_episode_id: int | None = None,
    ) -> tuple[list[PodcastEpisode], int, bool, tuple[Any, int] | None]:
        """Get cursor-paginated feed.

        Uses lazy imports to maintain domain boundary separation.
        """
        Subscription, UserSubscription = _get_subscription_models()

        query = (
            select(PodcastEpisode)
            .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .options(
                joinedload(PodcastEpisode.subscription),
                joinedload(PodcastEpisode.transcript),
            )
            .where(and_(*self._active_user_subscription_filters(user_id)))
        )
        total = await self._get_feed_total_count(user_id)

        if cursor_published_at is not None and cursor_episode_id is not None:
            query = query.where(
                or_(
                    PodcastEpisode.published_at < cursor_published_at,
                    and_(
                        PodcastEpisode.published_at == cursor_published_at,
                        PodcastEpisode.id < cursor_episode_id,
                    ),
                ),
            )

        query = query.order_by(
            desc(PodcastEpisode.published_at),
            desc(PodcastEpisode.id),
        ).limit(size + 1)

        result = await self.db.execute(query)
        rows = list(result.unique().scalars().all())

        has_more = len(rows) > size
        episodes = rows[:size]
        next_cursor_values: tuple[Any, int] | None = None
        if has_more and episodes:
            tail = episodes[-1]
            next_cursor_values = (tail.published_at, tail.id)

        return episodes, total, has_more, next_cursor_values

    async def get_playback_history_paginated(
        self,
        user_id: int,
        page: int = 1,
        size: int = 20,
    ) -> tuple[list[PodcastEpisode], int]:
        """Get paginated playback history.

        Uses lazy imports to maintain domain boundary separation.
        """
        Subscription, UserSubscription = _get_subscription_models()

        skip = (page - 1) * size
        base_query = (
            select(PodcastEpisode)
            .join(
                PodcastPlaybackState,
                and_(
                    PodcastPlaybackState.episode_id == PodcastEpisode.id,
                    PodcastPlaybackState.user_id == user_id,
                ),
            )
            .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .options(
                joinedload(PodcastEpisode.subscription),
                joinedload(PodcastEpisode.transcript),
            )
            .where(and_(*self._active_user_subscription_filters(user_id)))
        )

        query = (
            base_query.add_columns(func.count(PodcastEpisode.id).over())
            .order_by(
                PodcastPlaybackState.last_updated_at.desc(),
                PodcastEpisode.id.desc(),
            )
            .offset(skip)
            .limit(size)
        )

        result = await self.db.execute(query)
        rows = list(result.unique().all())
        total = await resolve_window_total(
            self.db,
            rows,
            total_index=1,
            fallback_count_query=select(func.count()).select_from(
                base_query.subquery(),
            ),
        )
        return [row[0] for row in rows], total

    async def get_playback_history_cursor_paginated(
        self,
        user_id: int,
        size: int = 20,
        cursor_last_updated_at: Any = None,
        cursor_episode_id: int | None = None,
    ) -> tuple[list[PodcastEpisode], int, bool, tuple[Any, int] | None]:
        """Get cursor-paginated playback history.

        Uses lazy imports to maintain domain boundary separation.
        """
        Subscription, UserSubscription = _get_subscription_models()

        base_query = (
            select(
                PodcastEpisode,
                PodcastPlaybackState.last_updated_at.label("last_updated_at"),
            )
            .join(
                PodcastPlaybackState,
                and_(
                    PodcastPlaybackState.episode_id == PodcastEpisode.id,
                    PodcastPlaybackState.user_id == user_id,
                ),
            )
            .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .options(
                joinedload(PodcastEpisode.subscription),
                joinedload(PodcastEpisode.transcript),
            )
            .where(and_(*self._active_user_subscription_filters(user_id)))
        )
        query = base_query

        if cursor_last_updated_at is not None and cursor_episode_id is not None:
            query = query.where(
                or_(
                    PodcastPlaybackState.last_updated_at < cursor_last_updated_at,
                    and_(
                        PodcastPlaybackState.last_updated_at == cursor_last_updated_at,
                        PodcastEpisode.id < cursor_episode_id,
                    ),
                ),
            )

        query = (
            query.add_columns(func.count(PodcastEpisode.id).over().label("total_count"))
            .order_by(
                desc(PodcastPlaybackState.last_updated_at),
                desc(PodcastEpisode.id),
            )
            .limit(size + 1)
        )

        result = await self.db.execute(query)
        rows = list(result.all())
        total = await resolve_window_total(
            self.db,
            rows,
            total_index=2,
            fallback_count_query=select(func.count()).select_from(
                base_query.subquery(),
            ),
        )

        has_more = len(rows) > size
        trimmed_rows = rows[:size]
        episodes = [row[0] for row in trimmed_rows]

        next_cursor_values: tuple[Any, int] | None = None
        if has_more and trimmed_rows:
            tail_episode, tail_last_updated_at, _ = trimmed_rows[-1]
            next_cursor_values = (tail_last_updated_at, tail_episode.id)

        return episodes, total, has_more, next_cursor_values

    async def get_playback_history_lite_paginated(
        self,
        user_id: int,
        page: int = 1,
        size: int = 20,
    ) -> tuple[list[dict[str, Any]], int]:
        """Get paginated playback history (lite version).

        Uses lazy imports to maintain domain boundary separation.
        """
        Subscription, UserSubscription = _get_subscription_models()

        skip = (page - 1) * size
        base_query = (
            select(
                PodcastEpisode.id.label("id"),
                PodcastEpisode.subscription_id.label("subscription_id"),
                Subscription.title.label("subscription_title"),
                Subscription.image_url.label("subscription_image_url"),
                Subscription.config.label("subscription_config"),
                PodcastEpisode.title.label("title"),
                PodcastEpisode.image_url.label("image_url"),
                PodcastEpisode.audio_duration.label("audio_duration"),
                PodcastPlaybackState.current_position.label("playback_position"),
                PodcastPlaybackState.last_updated_at.label("last_played_at"),
                PodcastEpisode.published_at.label("published_at"),
            )
            .join(
                PodcastPlaybackState,
                and_(
                    PodcastPlaybackState.episode_id == PodcastEpisode.id,
                    PodcastPlaybackState.user_id == user_id,
                ),
            )
            .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .where(and_(*self._active_user_subscription_filters(user_id)))
        )

        query = (
            base_query.add_columns(
                func.count(PodcastEpisode.id).over().label("total_count"),
            )
            .order_by(PodcastPlaybackState.last_updated_at.desc())
            .offset(skip)
            .limit(size)
        )

        result = await self.db.execute(query)
        rows = result.mappings().all()
        if rows:
            total = int(rows[0].get("total_count") or 0)
        else:
            total = int(
                await self.db.scalar(
                    select(func.count()).select_from(base_query.subquery()),
                )
                or 0,
            )

        items: list[dict[str, Any]] = []
        for row in rows:
            item = dict(row)
            item.pop("total_count", None)
            subscription_config = item.pop("subscription_config", None)

            config_image_url = None
            if isinstance(subscription_config, dict):
                config_image_url = self._normalize_optional_image_url(
                    subscription_config.get("image_url"),
                )

            subscription_image_url = self._normalize_optional_image_url(
                item.get("subscription_image_url"),
            )
            item["subscription_image_url"] = config_image_url or subscription_image_url
            items.append(item)

        return items, total

    @staticmethod
    def _normalize_optional_image_url(value: Any) -> str | None:
        if not isinstance(value, str):
            return None
        normalized = value.strip()
        return normalized or None

    """Search, recent activity, and aggregated stats."""

    async def search_episodes(
        self,
        user_id: int,
        query: str,
        search_in: str = "all",
        page: int = 1,
        size: int = 20,
    ) -> tuple[list[PodcastEpisode], int]:
        keyword = query.strip()
        if not keyword:
            return [], 0

        like_pattern = f"%{keyword}%"
        bind: Any = None
        try:
            bind = self.db.get_bind()
            if isawaitable(bind):
                bind = await bind
        except Exception:
            bind = getattr(self.db, "bind", None)
        is_postgresql = bool(bind and bind.dialect.name == "postgresql")

        def _coalesced_text(column: Any) -> Any:
            return func.coalesce(column, "")

        def _build_text_match_condition(column: Any, enable_pg_trgm: bool) -> Any:
            coalesced = _coalesced_text(column)
            ilike_condition = coalesced.ilike(like_pattern)
            if not enable_pg_trgm:
                return ilike_condition
            return or_(coalesced.op("%")(keyword), ilike_condition)

        def _build_relevance_term(
            column: Any,
            weight: float,
            enable_pg_trgm: bool,
        ) -> Any:
            coalesced = _coalesced_text(column)
            if enable_pg_trgm:
                return func.similarity(coalesced, keyword) * weight
            return case((coalesced.ilike(like_pattern), weight), else_=0.0)

        async def _execute_search(
            enable_pg_trgm: bool,
        ) -> tuple[list[PodcastEpisode], int]:
            search_conditions: list[Any] = []
            relevance_terms: list[Any] = []

            if search_in in {"title", "all"}:
                search_conditions.append(
                    _build_text_match_condition(PodcastEpisode.title, enable_pg_trgm),
                )
                relevance_terms.append(
                    _build_relevance_term(PodcastEpisode.title, 1.0, enable_pg_trgm),
                )
            if search_in in {"description", "all"}:
                search_conditions.append(
                    _build_text_match_condition(
                        PodcastEpisode.description,
                        enable_pg_trgm,
                    ),
                )
                relevance_terms.append(
                    _build_relevance_term(
                        PodcastEpisode.description,
                        0.7,
                        enable_pg_trgm,
                    ),
                )
            if search_in in {"summary", "all"}:
                search_conditions.append(
                    _build_text_match_condition(
                        PodcastEpisode.ai_summary,
                        enable_pg_trgm,
                    ),
                )
                relevance_terms.append(
                    _build_relevance_term(
                        PodcastEpisode.ai_summary,
                        0.9,
                        enable_pg_trgm,
                    ),
                )

            if not search_conditions:
                search_conditions.append(
                    _build_text_match_condition(PodcastEpisode.title, enable_pg_trgm),
                )
                relevance_terms.append(
                    _build_relevance_term(PodcastEpisode.title, 1.0, enable_pg_trgm),
                )

            relevance_score = relevance_terms[0]
            for term in relevance_terms[1:]:
                relevance_score = relevance_score + term
            relevance_score = relevance_score.label("relevance_score")

            # Get models lazily to maintain domain boundaries
            Subscription, UserSubscription = _get_subscription_models()

            base_query = (
                select(PodcastEpisode, relevance_score)
                .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
                .join(
                    UserSubscription,
                    UserSubscription.subscription_id == Subscription.id,
                )
                .options(joinedload(PodcastEpisode.subscription))
                .where(
                    and_(
                        *self._active_user_subscription_filters(user_id),
                        or_(*search_conditions),
                    ),
                )
            )

            paged_query = (
                base_query.add_columns(
                    func.count(PodcastEpisode.id).over().label("total_count"),
                )
                .order_by(
                    desc(relevance_score),
                    desc(PodcastEpisode.published_at),
                    desc(PodcastEpisode.id),
                )
                .offset((page - 1) * size)
                .limit(size)
            )
            result = await self.db.execute(paged_query)
            rows = list(result.unique().all())
            if rows:
                total = int(rows[0][2] or 0)
            else:
                total = int(
                    await self.db.scalar(
                        select(func.count()).select_from(base_query.subquery()),
                    )
                    or 0,
                )

            episodes: list[PodcastEpisode] = []
            for episode, score, _ in rows:
                try:
                    episode.relevance_score = float(score or 0.0)
                except Exception:
                    episode.relevance_score = 0.0
                episodes.append(episode)
            return episodes, total

        if is_postgresql:
            try:
                async with self.db.begin_nested():
                    return await _execute_search(enable_pg_trgm=True)
            except DBAPIError as exc:
                message = str(getattr(exc, "orig", exc)).lower()
                pg_trgm_error = (
                    "similarity(" in message
                    or "operator does not exist" in message
                    or "pg_trgm" in message
                )
                if pg_trgm_error:
                    logger.warning(
                        "pg_trgm unavailable; fallback to ILIKE: %s",
                        exc,
                    )
                    return await _execute_search(enable_pg_trgm=False)
                raise
        return await _execute_search(enable_pg_trgm=False)

    async def update_subscription_fetch_time(
        self,
        subscription_id: int,
        fetch_time: datetime | None = None,
    ):
        Subscription, _ = _get_subscription_models()
        stmt = select(Subscription).where(Subscription.id == subscription_id)
        result = await self.db.execute(stmt)
        subscription = result.scalar_one_or_none()

        if subscription:
            time_to_set = ensure_timezone_aware_fetch_time(
                fetch_time or datetime.now(UTC),
            )
            subscription.last_fetched_at = time_to_set
            await self.db.commit()

    async def update_subscription_metadata(self, subscription_id: int, metadata: dict):
        from sqlalchemy.orm import attributes

        Subscription, _ = _get_subscription_models()
        stmt = select(Subscription).where(Subscription.id == subscription_id)
        result = await self.db.execute(stmt)
        subscription = result.scalar_one_or_none()

        if subscription:
            current_config = dict(subscription.config or {})
            current_config.update(metadata)
            subscription.config = current_config
            attributes.flag_modified(subscription, "config")
            subscription.updated_at = datetime.now(UTC)
            await self.db.commit()

    async def get_recently_played(
        self,
        user_id: int,
        limit: int = 5,
    ) -> list[dict[str, Any]]:
        Subscription, UserSubscription = _get_subscription_models()
        stmt = (
            select(
                PodcastEpisode,
                PodcastPlaybackState.current_position,
                PodcastPlaybackState.last_updated_at,
            )
            .join(PodcastPlaybackState)
            .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .options(joinedload(PodcastEpisode.subscription))
            .where(
                and_(
                    *self._active_user_subscription_filters(user_id),
                    PodcastPlaybackState.last_updated_at
                    >= datetime.now(UTC) - timedelta(days=7),
                ),
            )
            .order_by(PodcastPlaybackState.last_updated_at.desc())
            .limit(limit)
        )

        result = await self.db.execute(stmt)
        rows = result.unique().all()
        recently_played = []
        for episode, position, last_played in rows:
            sub_title = episode.subscription.title if episode.subscription else None
            recently_played.append(
                {
                    "episode_id": episode.id,
                    "title": episode.title,
                    "subscription_title": sub_title,
                    "position": position,
                    "last_played": last_played,
                    "duration": episode.audio_duration,
                },
            )
        return recently_played

    async def get_liked_episodes(
        self,
        user_id: int,
        limit: int = 20,
    ) -> list[PodcastEpisode]:
        Subscription, UserSubscription = _get_subscription_models()
        stmt = (
            select(PodcastEpisode)
            .join(PodcastPlaybackState)
            .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .options(joinedload(PodcastEpisode.subscription))
            .where(
                and_(
                    *self._active_user_subscription_filters(user_id),
                    PodcastEpisode.audio_duration > 0,
                    PodcastPlaybackState.current_position
                    >= PodcastEpisode.audio_duration * 0.8,
                ),
            )
            .order_by(PodcastPlaybackState.play_count.desc())
            .limit(limit)
        )

        result = await self.db.execute(stmt)
        return list(result.scalars().unique().all())

    async def get_recent_play_dates(self, user_id: int, days: int = 30) -> set[date]:
        stmt = (
            select(PodcastPlaybackState.last_updated_at)
            .where(
                and_(
                    PodcastPlaybackState.user_id == user_id,
                    PodcastPlaybackState.last_updated_at
                    >= datetime.now(UTC) - timedelta(days=days),
                ),
            )
            .distinct()
        )

        result = await self.db.execute(stmt)
        dates = set()
        for (last_updated,) in result:
            dates.add(last_updated.date())
        return dates

    def _subscription_count_stmt(self, user_id: int) -> Any:
        Subscription, UserSubscription = _get_subscription_models()
        return (
            select(func.count(Subscription.id))
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .where(and_(*self._active_user_subscription_filters(user_id)))
        )

    def _episode_stats_stmt(
        self,
        user_id: int,
        *,
        include_played_episodes: bool = False,
        include_total_playtime: bool = False,
    ) -> Any:
        Subscription, UserSubscription = _get_subscription_models()
        columns: list[Any] = [
            func.count(PodcastEpisode.id).label("total_episodes"),
            func.sum(case((PodcastEpisode.ai_summary.isnot(None), 1), else_=0)).label(
                "summaries_generated",
            ),
            func.sum(case((PodcastEpisode.ai_summary.is_(None), 1), else_=0)).label(
                "pending_summaries",
            ),
        ]

        if include_played_episodes:
            columns.append(
                func.count(func.distinct(PodcastPlaybackState.episode_id)).label(
                    "played_episodes",
                ),
            )
        if include_total_playtime:
            columns.append(
                func.coalesce(func.sum(PodcastPlaybackState.current_position), 0).label(
                    "total_playtime",
                ),
            )

        return select(*columns).select_from(
            PodcastEpisode.__table__.join(
                Subscription.__table__,
                PodcastEpisode.subscription_id == Subscription.id,
            )
            .join(
                UserSubscription.__table__,
                and_(
                    UserSubscription.subscription_id == Subscription.id,
                    *self._active_user_subscription_filters(user_id),
                ),
            )
            .outerjoin(
                PodcastPlaybackState.__table__,
                and_(
                    PodcastPlaybackState.episode_id == PodcastEpisode.id,
                    PodcastPlaybackState.user_id == user_id,
                ),
            ),
        )

    async def get_profile_stats_aggregated(self, user_id: int) -> dict[str, Any]:
        Subscription, UserSubscription = _get_subscription_models()
        total_subscriptions = (
            await self.db.scalar(self._subscription_count_stmt(user_id)) or 0
        )
        episode_stats_result = await self.db.execute(
            self._episode_stats_stmt(user_id, include_played_episodes=True),
        )
        episode_stats = episode_stats_result.one()

        latest_report_stmt = (
            select(PodcastDailyReport.report_date)
            .where(PodcastDailyReport.user_id == user_id)
            .order_by(PodcastDailyReport.report_date.desc())
            .limit(1)
        )
        latest_report_result = await self.db.execute(latest_report_stmt)
        latest_report_date = latest_report_result.scalar_one_or_none()

        # Count highlights from user's active subscriptions
        highlight_count_stmt = (
            select(func.count(EpisodeHighlight.id))
            .join(PodcastEpisode, EpisodeHighlight.episode_id == PodcastEpisode.id)
            .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
            .join(
                UserSubscription,
                Subscription.id == UserSubscription.subscription_id,
            )
            .where(
                and_(
                    *self._active_user_subscription_filters(user_id),
                    EpisodeHighlight.status == "active",
                )
            )
        )
        highlight_count_result = await self.db.execute(highlight_count_stmt)
        total_highlights = highlight_count_result.scalar() or 0

        return {
            "total_subscriptions": total_subscriptions,
            "total_episodes": episode_stats.total_episodes or 0,
            "summaries_generated": episode_stats.summaries_generated or 0,
            "pending_summaries": episode_stats.pending_summaries or 0,
            "played_episodes": episode_stats.played_episodes or 0,
            "latest_daily_report_date": latest_report_date.isoformat()
            if latest_report_date
            else None,
            "total_highlights": total_highlights,
        }

    async def get_user_stats_aggregated(self, user_id: int) -> dict[str, Any]:
        Subscription, UserSubscription = _get_subscription_models()
        total_subscriptions = (
            await self.db.scalar(self._subscription_count_stmt(user_id)) or 0
        )
        episode_stats_result = await self.db.execute(
            self._episode_stats_stmt(user_id, include_total_playtime=True),
        )
        episode_stats = episode_stats_result.one()

        active_check_stmt = (
            select(func.count(Subscription.id))
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .where(
                and_(
                    *self._active_user_subscription_filters(user_id),
                    Subscription.status == "active",
                ),
            )
        )
        active_check_result = await self.db.execute(active_check_stmt)
        has_active_plus = (active_check_result.scalar() or 0) > 0

        return {
            "total_subscriptions": total_subscriptions,
            "total_episodes": episode_stats.total_episodes or 0,
            "total_playtime": episode_stats.total_playtime or 0,
            "summaries_generated": episode_stats.summaries_generated or 0,
            "pending_summaries": episode_stats.pending_summaries or 0,
            "has_active_plus": has_active_plus,
        }

    """Playback preference/progress and queue operations."""

    async def get_user_default_playback_rate(self, user_id: int) -> float:
        # Hardcoded default playback rate for single-user mode
        return 1.0

    async def get_subscription_playback_rate_preference(
        self,
        user_id: int,
        subscription_id: int,
    ) -> float | None:
        UserSubscription = _get_user_subscription_model()
        stmt = select(UserSubscription.playback_rate_preference).where(
            and_(
                *self._active_user_subscription_filters(user_id),
                UserSubscription.subscription_id == subscription_id,
            ),
        )
        result = await self.db.execute(stmt)
        value = result.scalar_one_or_none()
        return float(value) if value is not None else None

    async def get_effective_playback_rate(
        self,
        user_id: int,
        subscription_id: int | None = None,
    ) -> dict[str, Any]:
        global_rate = await self.get_user_default_playback_rate(user_id)
        subscription_rate: float | None = None
        source = "global"
        effective_rate = global_rate

        if subscription_id is not None:
            subscription_rate = await self.get_subscription_playback_rate_preference(
                user_id=user_id,
                subscription_id=subscription_id,
            )
            if subscription_rate is not None:
                source = "subscription"
                effective_rate = subscription_rate
            elif global_rate == 1.0:
                source = "default"
        elif global_rate == 1.0:
            source = "default"

        return {
            "global_playback_rate": global_rate,
            "subscription_playback_rate": subscription_rate,
            "effective_playback_rate": effective_rate,
            "source": source,
        }

    async def apply_playback_rate_preference(
        self,
        user_id: int,
        playback_rate: float,
        apply_to_subscription: bool,
        subscription_id: int | None = None,
    ) -> dict[str, Any]:
        UserSubscription = _get_user_subscription_model()
        if apply_to_subscription:
            if subscription_id is None:
                raise ValueError("SUBSCRIPTION_ID_REQUIRED")

            stmt = select(UserSubscription).where(
                and_(
                    *self._active_user_subscription_filters(user_id),
                    UserSubscription.subscription_id == subscription_id,
                ),
            )
            result = await self.db.execute(stmt)
            user_sub = result.scalar_one_or_none()
            if user_sub is None:
                raise SubscriptionNotFoundError("Subscription not found")

            user_sub.playback_rate_preference = playback_rate
            await self.db.commit()
            return await self.get_effective_playback_rate(user_id, subscription_id)

        # In single-user mode, global playback rate is not stored
        # Just return the current effective rate
        return await self.get_effective_playback_rate(user_id, subscription_id)

    async def get_subscription_episodes_batch(
        self,
        subscription_ids: list[int],
        limit_per_subscription: int = 3,
    ) -> dict[int, list[PodcastEpisode]]:
        if not subscription_ids:
            return {}

        ranked_subquery = (
            select(
                PodcastEpisode.id.label("episode_id"),
                func.row_number()
                .over(
                    partition_by=PodcastEpisode.subscription_id,
                    order_by=(
                        PodcastEpisode.published_at.desc(),
                        PodcastEpisode.id.desc(),
                    ),
                )
                .label("row_number"),
            )
            .where(PodcastEpisode.subscription_id.in_(subscription_ids))
            .subquery()
        )

        stmt = (
            select(PodcastEpisode)
            .join(ranked_subquery, ranked_subquery.c.episode_id == PodcastEpisode.id)
            .where(ranked_subquery.c.row_number <= limit_per_subscription)
            .order_by(
                PodcastEpisode.subscription_id.asc(),
                PodcastEpisode.published_at.desc(),
                PodcastEpisode.id.desc(),
            )
        )

        result = await self.db.execute(stmt)
        rows = result.scalars().all()

        episodes_by_sub: dict[int, list[PodcastEpisode]] = {}
        for episode in rows:
            episodes_by_sub.setdefault(episode.subscription_id, []).append(episode)
        return episodes_by_sub

    async def update_playback_progress(
        self,
        user_id: int,
        episode_id: int,
        position: int,
        is_playing: bool = False,
        playback_rate: float = 1.0,
    ) -> PodcastPlaybackState:
        # Use SELECT ... FOR UPDATE to prevent race condition on concurrent
        # progress updates for the same user+episode pair.
        stmt = (
            select(PodcastPlaybackState)
            .where(
                PodcastPlaybackState.user_id == user_id,
                PodcastPlaybackState.episode_id == episode_id,
            )
            .with_for_update()
        )
        result = await self.db.execute(stmt)
        state = result.scalar_one_or_none()

        if state is not None:
            was_playing = bool(state.is_playing)
            state.current_position = position
            state.playback_rate = playback_rate
            if not was_playing and is_playing:
                state.play_count += 1
            state.is_playing = is_playing
            state.last_updated_at = datetime.now(UTC)
            await self.db.flush()
        else:
            state = PodcastPlaybackState(
                user_id=user_id,
                episode_id=episode_id,
                current_position=position,
                is_playing=is_playing,
                playback_rate=playback_rate,
                play_count=1 if is_playing else 0,
                last_updated_at=datetime.now(UTC),
            )
            self.db.add(state)
            await self.db.flush()

        await self.db.commit()

        if self.redis:
            await self.redis.set_user_progress(user_id, episode_id, position / 100)

        return state

    async def get_or_create_queue(self, user_id: int) -> PodcastQueue:
        # Use FOR UPDATE to prevent concurrent queue creation for the same user.
        stmt = (
            select(PodcastQueue)
            .options(lazyload(PodcastQueue.current_episode))
            .where(PodcastQueue.user_id == user_id)
            .with_for_update()
        )
        result = await self.db.execute(stmt)
        queue = result.scalar_one_or_none()
        if queue is not None:
            return queue

        # Savepoint isolates the INSERT so a concurrent creation that already
        # committed (unique constraint on user_id) can be caught gracefully.
        async with self.db.begin_nested():
            queue = PodcastQueue(user_id=user_id, revision=0)
            self.db.add(queue)
            await self.db.flush()

        return queue

    async def get_queue_with_items(self, user_id: int) -> PodcastQueue:
        queue = await self.get_or_create_queue(user_id)
        stmt = (
            select(PodcastQueue)
            .options(
                joinedload(PodcastQueue.items)
                .joinedload(PodcastQueueItem.episode)
                .joinedload(PodcastEpisode.subscription),
                joinedload(PodcastQueue.current_episode),
            )
            .where(PodcastQueue.id == queue.id)
        )
        result = await self.db.execute(stmt)
        return result.unique().scalar_one()

    async def _refresh_queue_with_items(self, queue: PodcastQueue) -> PodcastQueue:
        """Refresh queue with all relations loaded efficiently.

        This is more efficient than get_queue_with_items when we already have
        the queue object, as it avoids the initial get_or_create_queue query.
        """
        stmt = (
            select(PodcastQueue)
            .options(
                joinedload(PodcastQueue.items)
                .joinedload(PodcastQueueItem.episode)
                .joinedload(PodcastEpisode.subscription),
                joinedload(PodcastQueue.current_episode),
            )
            .where(PodcastQueue.id == queue.id)
        )
        result = await self.db.execute(stmt)
        return result.unique().scalar_one()

    @staticmethod
    def _sorted_queue_items(queue: PodcastQueue) -> list[PodcastQueueItem]:
        return sorted(queue.items, key=lambda item: (item.position, item.id))

    def _queue_needs_compaction(self, items: list[PodcastQueueItem]) -> bool:
        if not items:
            return False

        head_position = items[0].position
        tail_position = items[-1].position
        threshold = self._queue_position_compaction_threshold
        return head_position <= -threshold or tail_position >= threshold

    async def _rewrite_queue_positions(
        self,
        items: list[PodcastQueueItem],
        *,
        start: int = 0,
        step: int | None = None,
    ) -> None:
        """Rewrite queue positions with a single flush for better performance."""
        if not items:
            return

        position_step = step or self._queue_position_step
        # Directly assign final positions without intermediate flush
        for idx, item in enumerate(items):
            item.position = start + (idx * position_step)
        # Single flush at the end for batch efficiency
        await self.db.flush()

    @staticmethod
    def _touch_queue(queue: PodcastQueue) -> None:
        queue.revision = (queue.revision or 0) + 1
        queue.updated_at = datetime.now(UTC)

    @staticmethod
    def _resolve_next_episode_id_after_removal(
        ordered_items_before: list[PodcastQueueItem],
        removed_index: int,
        ordered_items_after: list[PodcastQueueItem],
    ) -> int | None:
        candidate_episode_id: int | None = None
        next_index = removed_index + 1
        if next_index < len(ordered_items_before):
            candidate_episode_id = ordered_items_before[next_index].episode_id

        if candidate_episode_id is not None and any(
            item.episode_id == candidate_episode_id for item in ordered_items_after
        ):
            return candidate_episode_id

        if ordered_items_after:
            return ordered_items_after[0].episode_id
        return None

    async def _ensure_current_at_head(
        self,
        queue: PodcastQueue,
        ordered_items: list[PodcastQueueItem],
    ) -> bool:
        if not ordered_items:
            if queue.current_episode_id is not None:
                queue.current_episode_id = None
                return True
            return False

        current_id = queue.current_episode_id
        if current_id is None:
            queue.current_episode_id = ordered_items[0].episode_id
            return True

        current_item = next(
            (item for item in ordered_items if item.episode_id == current_id),
            None,
        )
        if current_item is None:
            queue.current_episode_id = ordered_items[0].episode_id
            return True

        head_item = ordered_items[0]
        if current_item.id == head_item.id:
            return False

        current_item.position = head_item.position - self._queue_position_step
        await self.db.flush()
        return True

    async def _finalize_queue_mutation(
        self,
        queue: PodcastQueue,
        ordered_items: list[PodcastQueueItem],
        *,
        changed: bool,
        expire_queue_after_commit: bool = False,
    ) -> tuple[list[PodcastQueueItem], bool]:
        if await self._ensure_current_at_head(queue, ordered_items):
            changed = True

        ordered_items = self._sorted_queue_items(queue)
        if self._queue_needs_compaction(ordered_items):
            await self._rewrite_queue_positions(
                ordered_items,
                step=self._queue_position_step,
            )
            changed = True
            ordered_items = self._sorted_queue_items(queue)

        if changed:
            self._touch_queue(queue)
            await self.db.commit()
            if expire_queue_after_commit:
                self.db.expire(queue)

        return ordered_items, changed

    def _queue_operation_log(
        self,
        operation: str,
        *,
        user_id: int,
        queue_size: int,
        revision_before: int,
        revision_after: int,
        elapsed_ms: float,
    ) -> None:
        logger.debug(
            "[Queue] op=%s uid=%s size=%s rev=%s->%s elapsed=%.2fms",
            operation,
            user_id,
            queue_size,
            revision_before,
            revision_after,
            elapsed_ms,
        )

    async def add_or_move_to_tail(
        self,
        user_id: int,
        episode_id: int,
        max_items: int = 500,
    ) -> PodcastQueue:
        started_at = perf_counter()
        queue = await self.get_queue_with_items(user_id)
        revision_before = queue.revision or 0
        ordered_items = self._sorted_queue_items(queue)
        existing = next(
            (item for item in ordered_items if item.episode_id == episode_id),
            None,
        )
        changed = False

        if existing is None and len(ordered_items) >= max_items:
            raise QueueLimitExceededError("Queue has reached its limit")

        tail_position = ordered_items[-1].position if ordered_items else 0

        if existing is not None:
            if (
                queue.current_episode_id != episode_id
                and existing.position != tail_position
            ):
                existing.position = tail_position + self._queue_position_step
                await self.db.flush()
                changed = True
        else:
            self.db.add(
                PodcastQueueItem(
                    queue_id=queue.id,
                    episode_id=episode_id,
                    position=tail_position + self._queue_position_step
                    if ordered_items
                    else 0,
                ),
            )
            await self.db.flush()
            changed = True

        ordered_items = self._sorted_queue_items(queue)
        _, changed = await self._finalize_queue_mutation(
            queue,
            ordered_items,
            changed=changed,
        )

        self._queue_operation_log(
            "add_or_move_to_tail",
            user_id=user_id,
            queue_size=len(self._sorted_queue_items(queue)),
            revision_before=revision_before,
            revision_after=(revision_before + 1) if changed else revision_before,
            elapsed_ms=(perf_counter() - started_at) * 1000,
        )
        return await self._refresh_queue_with_items(queue)

    async def remove_item(self, user_id: int, episode_id: int) -> PodcastQueue:
        started_at = perf_counter()
        queue = await self.get_queue_with_items(user_id)
        revision_before = queue.revision or 0
        ordered_items_before = self._sorted_queue_items(queue)

        target = next(
            (item for item in ordered_items_before if item.episode_id == episode_id),
            None,
        )
        if not target:
            return queue

        removed_index = ordered_items_before.index(target)
        await self.db.delete(target)
        await self.db.flush()
        ordered_items = self._sorted_queue_items(queue)
        changed = True

        if queue.current_episode_id == episode_id:
            queue.current_episode_id = self._resolve_next_episode_id_after_removal(
                ordered_items_before,
                removed_index,
                ordered_items,
            )

        ordered_items, changed = await self._finalize_queue_mutation(
            queue,
            ordered_items,
            changed=changed,
            expire_queue_after_commit=True,
        )

        self._queue_operation_log(
            "remove_item",
            user_id=user_id,
            queue_size=len(ordered_items),
            revision_before=revision_before,
            revision_after=(revision_before + 1) if changed else revision_before,
            elapsed_ms=(perf_counter() - started_at) * 1000,
        )
        return await self._refresh_queue_with_items(queue)

    async def activate_episode(
        self,
        user_id: int,
        episode_id: int,
        max_items: int = 500,
    ) -> PodcastQueue:
        started_at = perf_counter()
        queue = await self.get_queue_with_items(user_id)
        revision_before = queue.revision or 0
        ordered_items = self._sorted_queue_items(queue)
        existing = next(
            (item for item in ordered_items if item.episode_id == episode_id),
            None,
        )
        changed = False

        if existing is None and len(ordered_items) >= max_items:
            raise QueueLimitExceededError("Queue has reached its limit")

        if existing is None:
            head_position = ordered_items[0].position if ordered_items else 0
            self.db.add(
                PodcastQueueItem(
                    queue_id=queue.id,
                    episode_id=episode_id,
                    position=head_position - self._queue_position_step
                    if ordered_items
                    else 0,
                ),
            )
            await self.db.flush()
            changed = True
            ordered_items = self._sorted_queue_items(queue)
        else:
            head_item = ordered_items[0] if ordered_items else None
            if head_item is not None and existing.id != head_item.id:
                existing.position = head_item.position - self._queue_position_step
                await self.db.flush()
                changed = True
                ordered_items = self._sorted_queue_items(queue)

        if queue.current_episode_id != episode_id:
            queue.current_episode_id = episode_id
            changed = True

        _, changed = await self._finalize_queue_mutation(
            queue,
            ordered_items,
            changed=changed,
        )

        self._queue_operation_log(
            "activate_episode",
            user_id=user_id,
            queue_size=len(self._sorted_queue_items(queue)),
            revision_before=revision_before,
            revision_after=(revision_before + 1) if changed else revision_before,
            elapsed_ms=(perf_counter() - started_at) * 1000,
        )
        return await self._refresh_queue_with_items(queue)

    async def reorder_items(
        self,
        user_id: int,
        ordered_episode_ids: list[int],
    ) -> PodcastQueue:
        started_at = perf_counter()
        queue = await self.get_queue_with_items(user_id)
        revision_before = queue.revision or 0
        ordered_items = self._sorted_queue_items(queue)

        current_ids = [item.episode_id for item in ordered_items]
        if len(set(ordered_episode_ids)) != len(ordered_episode_ids):
            raise InvalidReorderPayloadError("Invalid reorder payload")
        if set(current_ids) != set(ordered_episode_ids):
            raise InvalidReorderPayloadError("Invalid reorder payload")
        if len(current_ids) != len(ordered_episode_ids):
            raise InvalidReorderPayloadError("Invalid reorder payload")

        changed = current_ids != ordered_episode_ids
        desired_current = ordered_episode_ids[0] if ordered_episode_ids else None
        if changed:
            item_map = {item.episode_id: item for item in ordered_items}
            reordered_items = [
                item_map[episode_id] for episode_id in ordered_episode_ids
            ]
            await self._rewrite_queue_positions(
                reordered_items,
                step=self._queue_position_step,
            )

        if queue.current_episode_id != desired_current:
            queue.current_episode_id = desired_current
            changed = True

        _, changed = await self._finalize_queue_mutation(
            queue,
            self._sorted_queue_items(queue),
            changed=changed,
        )

        self._queue_operation_log(
            "reorder_items",
            user_id=user_id,
            queue_size=len(current_ids),
            revision_before=revision_before,
            revision_after=(revision_before + 1) if changed else revision_before,
            elapsed_ms=(perf_counter() - started_at) * 1000,
        )
        return await self._refresh_queue_with_items(queue)

    async def set_current(self, user_id: int, episode_id: int) -> PodcastQueue:
        started_at = perf_counter()
        queue = await self.get_queue_with_items(user_id)
        revision_before = queue.revision or 0
        ordered_items = self._sorted_queue_items(queue)
        target = next(
            (item for item in ordered_items if item.episode_id == episode_id),
            None,
        )
        if target is None:
            raise EpisodeNotInQueueError("Episode not in queue")

        changed = False
        head_item = ordered_items[0] if ordered_items else None
        if head_item is not None and target.id != head_item.id:
            target.position = head_item.position - self._queue_position_step
            await self.db.flush()
            changed = True

        if queue.current_episode_id != episode_id:
            queue.current_episode_id = episode_id
            changed = True

        ordered_items, changed = await self._finalize_queue_mutation(
            queue,
            self._sorted_queue_items(queue),
            changed=changed,
        )

        self._queue_operation_log(
            "set_current",
            user_id=user_id,
            queue_size=len(ordered_items),
            revision_before=revision_before,
            revision_after=(revision_before + 1) if changed else revision_before,
            elapsed_ms=(perf_counter() - started_at) * 1000,
        )
        return await self._refresh_queue_with_items(queue)

    async def complete_current(self, user_id: int) -> PodcastQueue:
        started_at = perf_counter()
        queue = await self.get_queue_with_items(user_id)
        revision_before = queue.revision or 0
        ordered_items_before = self._sorted_queue_items(queue)

        if not ordered_items_before:
            return queue

        target_index = 0
        if queue.current_episode_id is not None:
            current_index = next(
                (
                    idx
                    for idx, item in enumerate(ordered_items_before)
                    if item.episode_id == queue.current_episode_id
                ),
                None,
            )
            if current_index is not None:
                target_index = current_index

        target = ordered_items_before[target_index]
        await self.db.delete(target)
        await self.db.flush()
        ordered_items = self._sorted_queue_items(queue)
        queue.current_episode_id = self._resolve_next_episode_id_after_removal(
            ordered_items_before,
            target_index,
            ordered_items,
        )

        ordered_items, changed = await self._finalize_queue_mutation(
            queue,
            ordered_items,
            changed=True,
            expire_queue_after_commit=True,
        )

        self._queue_operation_log(
            "complete_current",
            user_id=user_id,
            queue_size=len(ordered_items),
            revision_before=revision_before,
            revision_after=(revision_before + 1) if changed else revision_before,
            elapsed_ms=(perf_counter() - started_at) * 1000,
        )
        return await self._refresh_queue_with_items(queue)



# Backward compatibility aliases
PodcastEpisodeRepository = PodcastRepository
PodcastSubscriptionRepository = PodcastRepository
PodcastPlaybackRepository = PodcastRepository
PodcastQueueRepository = PodcastRepository
PodcastSearchRepository = PodcastRepository
PodcastStatsRepository = PodcastRepository
