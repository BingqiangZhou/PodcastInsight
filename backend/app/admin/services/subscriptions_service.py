"""Admin subscription management service.

Merges command and query services into a single cohesive class.
OPML operations are delegated to the separate AdminSubscriptionsOpmlService.
"""

from __future__ import annotations

import asyncio
import logging
import time
from datetime import UTC, datetime
from typing import Any

from fastapi import HTTPException
from sqlalchemy import delete, func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.admin.settings_helpers import persist_setting
from app.domains.podcast.models import (
    Subscription,
    SubscriptionStatus,
    UpdateFrequency,
    UserSubscription,
)


logger = logging.getLogger(__name__)

SUBSCRIPTION_TEST_PREVIEW_LIMIT = 25


class AdminSubscriptionsService:
    """Admin subscription management with command and query operations."""

    def __init__(self, db: AsyncSession):
        self.db = db
        self._opml_service = None

    @property
    def opml(self):
        """Lazy-load OPML service to avoid circular import."""
        if self._opml_service is None:
            from app.admin.services.subscriptions_opml_service import (
                AdminSubscriptionsOpmlService,
            )

            self._opml_service = AdminSubscriptionsOpmlService(self.db)
        return self._opml_service

    # ── Query operations ─────────────────────────────────────────────────────

    async def get_page_context(
        self,
        *,
        page: int,
        per_page: int,
        status_filter: str | None,
        search_query: str | None,
        user_filter: str | None,
    ) -> dict:
        """Build admin subscription page context without mutating state."""
        query = (
            select(
                Subscription,
                func.count(UserSubscription.id).label("subscriber_count"),
            )
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .group_by(Subscription.id)
        )

        if status_filter and status_filter in {
            "active",
            "inactive",
            "error",
            "pending",
        }:
            status_map = {
                "active": SubscriptionStatus.ACTIVE,
                "inactive": SubscriptionStatus.INACTIVE,
                "error": SubscriptionStatus.ERROR,
                "pending": SubscriptionStatus.PENDING,
            }
            query = query.where(Subscription.status == status_map[status_filter])

        if search_query and search_query.strip():
            query = query.where(Subscription.title.ilike(f"%{search_query.strip()}%"))

        if user_filter and user_filter.strip():
            # In single-user mode, no user filtering is available
            return self._empty_context(
                page=page,
                    per_page=per_page,
                    status_filter=status_filter,
                    search_query=search_query,
                    user_filter=user_filter,
                )

        count_query = select(func.count()).select_from(query.subquery())
        total_count_result = await self.db.execute(count_query)
        total_count = total_count_result.scalar() or 0

        total_pages = (total_count + per_page - 1) // per_page if total_count > 0 else 1
        offset = (page - 1) * per_page
        result = await self.db.execute(
            query.order_by(Subscription.created_at.desc())
            .limit(per_page)
            .offset(offset),
        )
        subscriptions = result.all()

        next_update_by_subscription = await self._load_next_update_map(subscriptions)
        frequency_defaults = await self._load_frequency_defaults(total_count)

        return {
            "subscriptions": subscriptions,
            "page": page,
            "per_page": per_page,
            "total_count": total_count,
            "total_pages": total_pages,
            "default_frequency": frequency_defaults["default_frequency"],
            "default_update_time": frequency_defaults["default_update_time"],
            "default_day_of_week": frequency_defaults["default_day_of_week"],
            "status_filter": status_filter or "",
            "search_query": search_query or "",
            "user_filter": user_filter or "",
            "next_update_by_subscription": next_update_by_subscription,
        }

    async def _load_next_update_map(self, subscriptions) -> dict[int, object]:
        next_update_by_subscription: dict[int, object] = {}
        if not subscriptions:
            return next_update_by_subscription

        subscription_ids = [sub_row[0].id for sub_row in subscriptions]
        user_sub_rows = (
            (
                await self.db.execute(
                    select(UserSubscription)
                    .where(
                        UserSubscription.subscription_id.in_(subscription_ids),
                        not UserSubscription.is_archived,
                    )
                    .order_by(
                        UserSubscription.subscription_id,
                        UserSubscription.updated_at.desc(),
                        UserSubscription.id.desc(),
                    ),
                )
            )
            .scalars()
            .all()
        )

        for user_sub in user_sub_rows:
            if user_sub.subscription_id not in next_update_by_subscription:
                next_update_by_subscription[user_sub.subscription_id] = (
                    user_sub.computed_next_update_at
                )

        return next_update_by_subscription

    async def _load_frequency_defaults(self, total_count: int) -> dict[str, object]:
        defaults = {
            "default_frequency": UpdateFrequency.HOURLY.value,
            "default_update_time": "00:00",
            "default_day_of_week": 1,
        }
        if total_count <= 0:
            return defaults

        freq_result = await self.db.execute(
            select(
                UserSubscription.update_frequency,
                UserSubscription.update_time,
                UserSubscription.update_day_of_week,
            )
            .where(UserSubscription.update_frequency.isnot(None))
            .group_by(
                UserSubscription.update_frequency,
                UserSubscription.update_time,
                UserSubscription.update_day_of_week,
            )
            .order_by(func.count().desc())
            .limit(1),
        )
        row = freq_result.first()
        if not row:
            return defaults

        defaults["default_frequency"] = row[0] or UpdateFrequency.HOURLY.value
        defaults["default_update_time"] = row[1] or "00:00"
        defaults["default_day_of_week"] = row[2] or 1
        return defaults

    def _empty_context(
        self,
        *,
        page: int,
        per_page: int,
        status_filter: str | None,
        search_query: str | None,
        user_filter: str | None,
    ) -> dict:
        return {
            "subscriptions": [],
            "page": page,
            "per_page": per_page,
            "total_count": 0,
            "total_pages": 0,
            "default_frequency": UpdateFrequency.HOURLY.value,
            "default_update_time": "00:00",
            "default_day_of_week": 1,
            "status_filter": status_filter or "",
            "search_query": search_query or "",
            "user_filter": user_filter or "",
            "next_update_by_subscription": {},
        }

    # ── Command operations ────────────────────────────────────────────────────

    async def update_frequency(
        self,
        *,
        request,
        user_id,
        update_frequency: str,
        update_time: str | None,
        update_day: int | None,
    ) -> dict:
        # Use shared validation from AdminSettingsService
        from app.admin.services.settings_service import AdminSettingsService

        AdminSettingsService.validate_frequency_settings(
            update_frequency=update_frequency,
            update_time=update_time,
            update_day=update_day,
        )

        day_of_week = (
            update_day if update_frequency == UpdateFrequency.WEEKLY.value else None
        )

        settings_data = {
            "update_frequency": update_frequency,
            "update_time": update_time
            if update_frequency in {"DAILY", "WEEKLY"}
            else None,
            "update_day_of_week": day_of_week,
        }

        await persist_setting(
            self.db,
            "rss.frequency_settings",
            settings_data,
            description="RSS subscription update frequency settings",
            category="subscription",
        )

        update_stmt = (
            update(UserSubscription)
            .where(
                UserSubscription.subscription_id.in_(
                    select(Subscription.id).where(
                        Subscription.source_type.in_(["rss", "podcast-rss"]),
                    ),
                ),
            )
            .values(
                update_frequency=settings_data["update_frequency"],
                update_time=settings_data["update_time"],
                update_day_of_week=settings_data["update_day_of_week"],
            )
        )
        update_result = await self.db.execute(update_stmt)
        update_count = int(update_result.rowcount or 0)

        await self.db.commit()
        return {
            "success": True,
            "message": f"Updated frequency settings for {update_count} user subscriptions",
        }

    async def edit_subscription(
        self,
        *,
        request,
        user_id,
        sub_id: int,
        title: str | None,
        source_url: str | None,
    ) -> dict | None:
        result = await self.db.execute(
            select(Subscription).where(Subscription.id == sub_id),
        )
        subscription = result.scalar_one_or_none()
        if not subscription:
            return None

        if title is not None:
            subscription.title = title
        if source_url is not None:
            subscription.source_url = source_url

        from app.domains.podcast.parsers.feed_parser import (
            FeedParserConfig,
            parse_feed_url,
        )

        config = FeedParserConfig(
            max_entries=10,
            strip_html=True,
            strict_mode=False,
            log_raw_feed=False,
        )

        try:
            test_result = await parse_feed_url(subscription.source_url, config=config)
            if test_result and test_result.success and test_result.entries:
                subscription.status = SubscriptionStatus.ACTIVE
                subscription.error_message = None
            else:
                subscription.status = SubscriptionStatus.ERROR
                subscription.error_message = (
                    test_result.errors[0]
                    if test_result and test_result.errors
                    else "No entries found or invalid feed"
                )
        except Exception as exc:  # noqa: BLE001
            subscription.status = SubscriptionStatus.ERROR
            subscription.error_message = str(exc)

        await self.db.commit()
        return {
            "success": True,
            "status": subscription.status,
            "error_message": subscription.error_message,
        }

    async def test_subscription_url(
        self,
        *,
        source_url: str,
        username: str,
    ) -> tuple[dict, int]:
        from app.domains.podcast.parsers.feed_parser import (
            FeedParseOptions,
            FeedParser,
            FeedParserConfig,
        )

        config = FeedParserConfig(
            max_entries=SUBSCRIPTION_TEST_PREVIEW_LIMIT,
            strip_html=True,
            strict_mode=False,
            log_raw_feed=False,
        )
        options = FeedParseOptions(strip_html_content=True, include_raw_metadata=False)
        parser = FeedParser(config)
        start_time = time.time()
        try:
            result = await parser.parse_feed(source_url, options=options)
            response_time_ms = int((time.time() - start_time) * 1000)
            if not result.success or result.has_errors():
                error_messages = (
                    [err.message for err in result.errors] if result.errors else []
                )
                return {
                    "success": False,
                    "message": (
                        "RSS feed test failed: "
                        f"{error_messages[0] if error_messages else 'Failed to parse feed'}"
                    ),
                    "error_message": error_messages[0]
                    if error_messages
                    else "Failed to parse feed",
                }, 400

            logger.info(
                "RSS feed test successful for %s by user %s",
                source_url,
                username,
            )
            return {
                "success": True,
                "message": "RSS feed test successful",
                "feed_title": result.feed_info.title or "Untitled",
                "feed_description": result.feed_info.description or "",
                "entry_count": len(result.entries),
                "total_entry_count": result.total_entries,
                "response_time_ms": response_time_ms,
            }, 200
        finally:
            await parser.close()

    async def test_all_subscriptions(self, *, request, user_id) -> dict:
        from app.domains.podcast.parsers.feed_parser import (
            FeedParserConfig,
            parse_feed_url,
        )

        result = await self.db.execute(
            select(Subscription).order_by(Subscription.created_at.desc()),
        )
        subscriptions = result.scalars().all()
        if not subscriptions:
            return {
                "success": True,
                "message": "No RSS subscriptions found",
                "total_count": 0,
                "success_count": 0,
                "failed_count": 0,
                "disabled_count": 0,
                "failed_items": [],
            }

        config = FeedParserConfig(
            max_entries=10,
            strip_html=True,
            strict_mode=False,
            log_raw_feed=False,
        )

        async def test_single_subscription(
            subscription: Subscription,
            timeout: int = 15,
        ) -> dict[str, Any]:
            try:
                start_time = time.time()
                result = await asyncio.wait_for(
                    parse_feed_url(subscription.source_url, config=config),
                    timeout=timeout,
                )
                response_time_ms = int((time.time() - start_time) * 1000)
                if result and result.success and result.entries:
                    return {
                        "id": subscription.id,
                        "title": subscription.title,
                        "source_url": subscription.source_url,
                        "success": True,
                        "response_time_ms": response_time_ms,
                    }
                error_msg = (
                    result.errors[0]
                    if result and result.errors
                    else "No entries found or invalid feed"
                )
                return {
                    "id": subscription.id,
                    "title": subscription.title,
                    "source_url": subscription.source_url,
                    "success": False,
                    "error": error_msg,
                }
            except TimeoutError:
                return {
                    "id": subscription.id,
                    "title": subscription.title,
                    "source_url": subscription.source_url,
                    "success": False,
                    "error": f"Timeout after {timeout} seconds",
                }
            except Exception as exc:  # noqa: BLE001
                return {
                    "id": subscription.id,
                    "title": subscription.title,
                    "source_url": subscription.source_url,
                    "success": False,
                    "error": str(exc),
                }

        semaphore = asyncio.Semaphore(5)

        async def test_with_semaphore(subscription: Subscription) -> dict[str, Any]:
            async with semaphore:
                return await test_single_subscription(subscription)

        test_results = await asyncio.gather(
            *[test_with_semaphore(sub) for sub in subscriptions],
            return_exceptions=True,
        )

        success_count = 0
        failed_count = 0
        disabled_count = 0
        failed_items: list[dict[str, Any]] = []
        subscriptions_to_disable: list[int] = []

        for index, result in enumerate(test_results):
            if isinstance(result, Exception):
                subscription = subscriptions[index]
                failed_count += 1
                failed_items.append(
                    {
                        "id": subscription.id,
                        "title": subscription.title,
                        "source_url": subscription.source_url,
                        "error": f"Unexpected error: {result}",
                    },
                )
                if subscription.status == SubscriptionStatus.ACTIVE:
                    subscriptions_to_disable.append(subscription.id)
                continue

            if result["success"]:
                success_count += 1
                continue

            failed_count += 1
            failed_items.append(
                {
                    "id": result["id"],
                    "title": result["title"],
                    "source_url": result["source_url"],
                    "error": result["error"],
                },
            )
            subscription = subscriptions[index]
            if subscription.status == SubscriptionStatus.ACTIVE:
                subscriptions_to_disable.append(subscription.id)

        if subscriptions_to_disable:
            await self.db.execute(
                update(Subscription)
                .where(Subscription.id.in_(subscriptions_to_disable))
                .values(status=SubscriptionStatus.ERROR),
            )
            await self.db.commit()
            disabled_count = len(subscriptions_to_disable)
        else:
            disabled_count = 0

        total_count = len(subscriptions)
        return {
            "success": True,
            "message": (
                f"Finished testing subscriptions: {success_count}/{total_count} "
                f"succeeded, {failed_count} failed, {disabled_count} disabled."
            ),
            "total_count": total_count,
            "success_count": success_count,
            "failed_count": failed_count,
            "disabled_count": disabled_count,
            "failed_items": failed_items,
        }

    async def delete_subscription(self, *, request, user_id, sub_id: int) -> dict | None:
        result = await self.db.execute(
            select(Subscription).where(Subscription.id == sub_id),
        )
        subscription = result.scalar_one_or_none()
        if not subscription:
            return None

        await self._delete_subscription_records([subscription])
        return {"success": True}

    async def refresh_subscription(self, *, request, user_id, sub_id: int) -> dict | None:
        result = await self.db.execute(
            select(Subscription).where(Subscription.id == sub_id),
        )
        subscription = result.scalar_one_or_none()
        if not subscription:
            return None

        subscription.last_fetched_at = datetime.now(UTC)
        await self.db.commit()
        return {"success": True}

    async def batch_refresh_subscriptions(self, *, request, user_id) -> None:
        ids = await self._load_request_ids(request)
        result = await self.db.execute(
            select(Subscription).where(Subscription.id.in_(ids)),
        )
        subscriptions = result.scalars().all()
        for subscription in subscriptions:
            subscription.last_fetched_at = datetime.now(UTC)

        await self.db.commit()

    async def batch_toggle_subscriptions(self, *, request, user_id) -> None:
        ids = await self._load_request_ids(request)
        result = await self.db.execute(
            select(Subscription).where(Subscription.id.in_(ids)),
        )
        subscriptions = result.scalars().all()
        for subscription in subscriptions:
            subscription.is_active = not subscription.is_active

        await self.db.commit()

    async def batch_delete_subscriptions(self, *, request, user_id) -> None:
        ids = await self._load_request_ids(request)
        result = await self.db.execute(
            select(Subscription).where(Subscription.id.in_(ids)),
        )
        subscriptions = result.scalars().all()

        await self._delete_subscription_records(subscriptions)

    async def _load_request_ids(self, request) -> list[int]:
        body = await request.json()
        ids = body.get("ids", [])
        if not ids:
            raise HTTPException(status_code=400, detail="No subscription IDs provided")
        return [int(id_) for id_ in ids]

    async def _delete_subscription_records(
        self,
        subscriptions: list[Subscription],
    ) -> None:
        """Delete subscription records in bulk to avoid N+1 queries.

        Optimized to use batch DELETE operations instead of per-subscription loops.
        """
        from app.domains.podcast.models import (
            PodcastConversation,
            PodcastEpisode,
            PodcastPlaybackState,
            TranscriptionTask,
        )

        if not subscriptions:
            return

        # Separate podcast-rss subscriptions from others
        podcast_sub_ids = [
            sub.id for sub in subscriptions if sub.source_type == "podcast-rss"
        ]
        all_sub_ids = [sub.id for sub in subscriptions]

        # Batch delete podcast-related records for all podcast subscriptions at once
        if podcast_sub_ids:
            # Get all episode IDs for all podcast subscriptions in one query
            ep_result = await self.db.execute(
                select(PodcastEpisode.id).where(
                    PodcastEpisode.subscription_id.in_(podcast_sub_ids),
                ),
            )
            episode_ids = [row[0] for row in ep_result.fetchall()]

            if episode_ids:
                # Delete all related records in bulk
                await self.db.execute(
                    delete(PodcastConversation).where(
                        PodcastConversation.episode_id.in_(episode_ids),
                    ),
                )
                await self.db.execute(
                    delete(PodcastPlaybackState).where(
                        PodcastPlaybackState.episode_id.in_(episode_ids),
                    ),
                )
                await self.db.execute(
                    delete(TranscriptionTask).where(
                        TranscriptionTask.episode_id.in_(episode_ids),
                    ),
                )

            # Delete all episodes for all podcast subscriptions
            await self.db.execute(
                delete(PodcastEpisode).where(
                    PodcastEpisode.subscription_id.in_(podcast_sub_ids),
                ),
            )

        # Delete all subscriptions in one batch
        await self.db.execute(
            delete(Subscription).where(Subscription.id.in_(all_sub_ids)),
        )

        await self.db.commit()

    # ── OPML delegation ───────────────────────────────────────────────────────

    async def export_subscriptions_opml(self, **kwargs):
        """Delegate OPML export to the OPML service."""
        return await self.opml.export_subscriptions_opml(**kwargs)

    async def import_subscriptions_opml(self, **kwargs):
        """Delegate OPML import to the OPML service."""
        return await self.opml.import_subscriptions_opml(**kwargs)
