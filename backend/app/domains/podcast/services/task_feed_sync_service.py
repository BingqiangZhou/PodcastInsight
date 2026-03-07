"""Task orchestration helpers for feed refresh and OPML sync flows."""

from __future__ import annotations

import logging
from collections.abc import Callable
from datetime import datetime, timezone

from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domains.podcast.integration.secure_rss_parser import SecureRSSParser
from app.domains.podcast.repositories import PodcastSubscriptionRepository
from app.domains.podcast.services.sync_service import PodcastSyncService
from app.domains.subscription.models import (
    Subscription,
    SubscriptionStatus,
    UserSubscription,
)


logger = logging.getLogger(__name__)


class PodcastTaskFeedSyncService:
    """Handle background feed refresh and OPML parsing."""

    def __init__(
        self,
        session: AsyncSession,
        *,
        repo_factory: Callable[
            [AsyncSession], PodcastSubscriptionRepository
        ] = PodcastSubscriptionRepository,
        parser_factory: Callable[[int], SecureRSSParser] = SecureRSSParser,
        sync_service_factory: Callable[
            [AsyncSession, int], PodcastSyncService
        ] = PodcastSyncService,
    ):
        self.session = session
        self.repo_factory = repo_factory
        self.parser_factory = parser_factory
        self.sync_service_factory = sync_service_factory

    async def refresh_all_podcast_feeds(self) -> dict:
        repo = self.repo_factory(self.session)
        sub_stmt = select(Subscription).where(
            and_(
                Subscription.source_type == "podcast-rss",
                Subscription.status == SubscriptionStatus.ACTIVE.value,
            )
        )
        sub_rows = await self.session.execute(sub_stmt)
        all_subscriptions = list(sub_rows.scalars().all())

        user_sub_stmt = (
            select(UserSubscription)
            .join(Subscription, UserSubscription.subscription_id == Subscription.id)
            .where(
                and_(
                    Subscription.source_type == "podcast-rss",
                    Subscription.status == SubscriptionStatus.ACTIVE.value,
                    UserSubscription.is_archived == False,  # noqa: E712
                )
            )
        )
        user_sub_rows = await self.session.execute(user_sub_stmt)
        user_subscriptions = list(user_sub_rows.scalars().all())

        subscriptions_to_update: set[int] = {
            item.subscription_id
            for item in user_subscriptions
            if item.should_update_now()
        }
        target_ids = subscriptions_to_update or {sub.id for sub in all_subscriptions}

        refreshed_count = 0
        new_episodes_count = 0

        for subscription_id in target_ids:
            subscription = next(
                (sub for sub in all_subscriptions if sub.id == subscription_id),
                None,
            )
            if subscription is None:
                continue

            user_sub = next(
                (
                    us
                    for us in user_subscriptions
                    if us.subscription_id == subscription_id
                ),
                None,
            )
            user_id = user_sub.user_id if user_sub else 1
            parser = self.parser_factory(user_id)

            try:
                success, feed, error = await parser.fetch_and_parse_feed(
                    subscription.source_url
                )
                if not success:
                    logger.error(
                        "Failed refreshing subscription %s (%s): %s",
                        subscription.id,
                        subscription.title,
                        error,
                    )
                    continue

                sync_service = self.sync_service_factory(self.session, user_id)
                refreshed_at = datetime.now(timezone.utc).isoformat()
                episodes_payload = [
                    {
                        "title": episode.title,
                        "description": episode.description,
                        "audio_url": episode.audio_url,
                        "published_at": episode.published_at,
                        "audio_duration": episode.duration,
                        "transcript_url": episode.transcript_url,
                        "item_link": episode.link,
                        "metadata": {
                            "feed_title": feed.title,
                            "refreshed_at": refreshed_at,
                        },
                    }
                    for episode in feed.episodes
                ]
                _, new_episode_rows = await repo.create_or_update_episodes_batch(
                    subscription_id=subscription.id,
                    episodes_data=episodes_payload,
                )
                new_episodes = len(new_episode_rows)
                for saved_episode in new_episode_rows:
                    if (
                        subscription.last_fetched_at
                        and saved_episode.published_at > subscription.last_fetched_at
                    ):
                        await sync_service.trigger_transcription(saved_episode.id)
                    else:
                        logger.info(
                            "Episode %s (published: %s) is old (last fetch: %s), skipping auto-processing",
                            saved_episode.id,
                            saved_episode.published_at,
                            subscription.last_fetched_at,
                        )

                await repo.update_subscription_fetch_time(
                    subscription.id,
                    feed.last_fetched,
                )

                refreshed_count += 1
                new_episodes_count += new_episodes
                if new_episodes:
                    logger.info(
                        "Refreshed subscription %s (%s), %s new episodes",
                        subscription.id,
                        subscription.title,
                        new_episodes,
                    )
            except Exception:
                logger.exception(
                    "Unexpected failure during refresh for subscription %s",
                    subscription_id,
                )
            finally:
                await parser.close()

        return {
            "status": "success",
            "refreshed_subscriptions": refreshed_count,
            "new_episodes": new_episodes_count,
            "processed_at": datetime.now(timezone.utc).isoformat(),
        }

    async def process_opml_subscription_episodes(
        self,
        *,
        subscription_id: int,
        user_id: int,
        source_url: str,
    ) -> dict:
        repo = self.repo_factory(self.session)
        parser = self.parser_factory(user_id)

        try:
            success, feed, error = await parser.fetch_and_parse_feed(source_url)
            if not success:
                logger.warning(
                    "OPML background parse failed for subscription=%s, url=%s: %s",
                    subscription_id,
                    source_url,
                    error,
                )
                return {
                    "status": "error",
                    "subscription_id": subscription_id,
                    "source_url": source_url,
                    "error": error,
                }

            episodes_payload = [
                {
                    "title": episode.title,
                    "description": episode.description,
                    "audio_url": episode.audio_url,
                    "published_at": episode.published_at,
                    "audio_duration": episode.duration,
                    "transcript_url": episode.transcript_url,
                    "item_link": episode.link,
                    "metadata": {
                        "feed_title": feed.title,
                        "imported_via_opml": True,
                        "opml_background_parsed_at": datetime.now(
                            timezone.utc
                        ).isoformat(),
                    },
                }
                for episode in feed.episodes
            ]

            _, new_episodes = await repo.create_or_update_episodes_batch(
                subscription_id=subscription_id,
                episodes_data=episodes_payload,
            )

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
            await repo.update_subscription_metadata(subscription_id, metadata)
            await repo.update_subscription_fetch_time(
                subscription_id, feed.last_fetched
            )

            return {
                "status": "success",
                "subscription_id": subscription_id,
                "source_url": source_url,
                "processed_episodes": len(episodes_payload),
                "new_episodes": len(new_episodes),
            }
        finally:
            await parser.close()
