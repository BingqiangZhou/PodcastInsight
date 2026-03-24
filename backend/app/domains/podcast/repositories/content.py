"""Subscription and episode content repository mixin.

This module uses lazy imports for subscription models to maintain domain boundaries.
"""

from __future__ import annotations

from datetime import UTC, datetime
from typing import TYPE_CHECKING, Any

from sqlalchemy import and_, desc, func, select
from sqlalchemy.orm import attributes, joinedload

from app.core.datetime_utils import sanitize_published_date
from app.domains.podcast.models import PodcastEpisode
from app.domains.podcast.repositories.base import _get_subscription_models

# Use TYPE_CHECKING to avoid runtime dependency on subscription domain
if TYPE_CHECKING:
    from app.domains.subscription.models import Subscription, UserSubscription


class PodcastContentRepositoryMixin:
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
        from app.admin.models import SystemSettings
        from app.domains.subscription.models import UpdateFrequency

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

        settings_result = await self.db.execute(
            select(SystemSettings).where(
                SystemSettings.key == "rss.frequency_settings"
            ),
        )
        setting = settings_result.scalar_one_or_none()
        if setting and setting.value:
            update_frequency = setting.value.get(
                "update_frequency",
                UpdateFrequency.HOURLY.value,
            )
            update_time = setting.value.get("update_time")
            update_day_of_week = setting.value.get("update_day_of_week")

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
        # No refresh needed - episode.id is auto-populated by SQLAlchemy after flush/commit
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
        limit: int | None = None,
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
        rows = (await self.db.execute(stmt)).all()
        results: list[dict[str, Any]] = []
        for episode, subscription_title in rows:
            description = episode.description or ""
            transcript = episode.transcript_content or ""
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
            .options(joinedload(PodcastEpisode.subscription))
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
