"""Feed and pagination repository mixin.

This module uses lazy imports for subscription models to maintain domain boundaries.
"""

from __future__ import annotations

import logging
from collections.abc import Mapping
from typing import TYPE_CHECKING, Any

from sqlalchemy import and_, desc, func, or_, select
from sqlalchemy.orm import joinedload

from app.domains.podcast.models import PodcastEpisode, PodcastPlaybackState
from app.domains.podcast.repositories.base import _get_subscription_models
from app.shared.repository_helpers import resolve_window_total

# Use TYPE_CHECKING to avoid runtime dependency on subscription domain
if TYPE_CHECKING:
    from app.domains.subscription.models import Subscription, UserSubscription


logger = logging.getLogger(__name__)


class PodcastFeedRepositoryMixin:
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
            .options(joinedload(PodcastEpisode.subscription))
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
        cached_total = await self.redis.cache_get(cache_key)
        if cached_total is not None:
            try:
                return int(cached_total)
            except (TypeError, ValueError):
                logger.warning("Invalid cached feed total count for user %s", user_id)

        count_query = (
            select(func.count(PodcastEpisode.id))
            .select_from(PodcastEpisode)
            .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .where(and_(*self._active_user_subscription_filters(user_id)))
        )
        total_result = await self.db.execute(count_query)
        total = int(total_result.scalar() or 0)
        await self.redis.cache_set(cache_key, str(total), ttl=120)
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
            .options(joinedload(PodcastEpisode.subscription))
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
        rows = list(result.scalars().all())

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
            .options(joinedload(PodcastEpisode.subscription))
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
            .options(joinedload(PodcastEpisode.subscription))
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
