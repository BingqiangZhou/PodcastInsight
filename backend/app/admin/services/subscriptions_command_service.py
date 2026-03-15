"""Command-side helpers for admin subscription actions."""

from __future__ import annotations

import asyncio
import logging
import time
from datetime import UTC, datetime
from typing import Any

from fastapi import HTTPException
from sqlalchemy import delete, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.admin.audit import log_admin_action
from app.domains.subscription.models import (
    Subscription,
    SubscriptionStatus,
    UpdateFrequency,
    UserSubscription,
)
from app.shared.settings_helpers import persist_setting


logger = logging.getLogger(__name__)

SUBSCRIPTION_TEST_PREVIEW_LIMIT = 25


class AdminSubscriptionsCommandService:
    """Execute mutating admin subscription actions."""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def update_frequency(
        self,
        *,
        request,
        user,
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
        await log_admin_action(
            db=self.db,
            user_id=user.id,
            username=user.username,
            action="update",
            resource_type="subscription_frequency",
            resource_name=f"All user subscriptions ({update_count})",
            details=settings_data,
            request=request,
        )
        return {
            "success": True,
            "message": f"Updated frequency settings for {update_count} user subscriptions",
        }

    async def edit_subscription(
        self,
        *,
        request,
        user,
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

        from app.domains.subscription.parsers.feed_parser import (
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
        await self.db.refresh(subscription)
        await log_admin_action(
            db=self.db,
            user_id=user.id,
            username=user.username,
            action="update",
            resource_type="subscription",
            resource_id=sub_id,
            resource_name=subscription.title,
            details={
                "title": title,
                "source_url": source_url,
                "status": subscription.status,
                "error_message": subscription.error_message,
            },
            request=request,
        )
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
        from app.domains.subscription.parsers.feed_parser import (
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

    async def test_all_subscriptions(self, *, request, user) -> dict:
        from app.domains.subscription.parsers.feed_parser import (
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

        total_count = len(subscriptions)
        await log_admin_action(
            db=self.db,
            user_id=user.id,
            username=user.username,
            action="test_all",
            resource_type="subscription",
            resource_name="All RSS subscriptions",
            details={
                "total_count": total_count,
                "success_count": success_count,
                "failed_count": failed_count,
                "disabled_count": disabled_count,
            },
            request=request,
        )
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

    async def delete_subscription(self, *, request, user, sub_id: int) -> dict | None:
        result = await self.db.execute(
            select(Subscription).where(Subscription.id == sub_id),
        )
        subscription = result.scalar_one_or_none()
        if not subscription:
            return None

        await self._delete_subscription_records([subscription])
        await log_admin_action(
            db=self.db,
            user_id=user.id,
            username=user.username,
            action="delete",
            resource_type="subscription",
            resource_id=sub_id,
            resource_name=subscription.title,
            request=request,
        )
        return {"success": True}

    async def refresh_subscription(self, *, request, user, sub_id: int) -> dict | None:
        result = await self.db.execute(
            select(Subscription).where(Subscription.id == sub_id),
        )
        subscription = result.scalar_one_or_none()
        if not subscription:
            return None

        subscription.last_fetched_at = datetime.now(UTC)
        await self.db.commit()
        await self.db.refresh(subscription)
        await log_admin_action(
            db=self.db,
            user_id=user.id,
            username=user.username,
            action="update",
            resource_type="subscription",
            resource_id=sub_id,
            resource_name=subscription.title,
            details={"action": "refresh"},
            request=request,
        )
        return {"success": True}

    async def batch_refresh_subscriptions(self, *, request, user) -> None:
        ids = await self._load_request_ids(request)
        result = await self.db.execute(
            select(Subscription).where(Subscription.id.in_(ids)),
        )
        subscriptions = result.scalars().all()
        for subscription in subscriptions:
            subscription.last_fetched_at = datetime.now(UTC)

        await self.db.commit()
        await log_admin_action(
            db=self.db,
            user_id=user.id,
            username=user.username,
            action="batch_refresh",
            resource_type="subscription",
            details={"count": len(subscriptions), "ids": ids},
            request=request,
        )

    async def batch_toggle_subscriptions(self, *, request, user) -> None:
        ids = await self._load_request_ids(request)
        result = await self.db.execute(
            select(Subscription).where(Subscription.id.in_(ids)),
        )
        subscriptions = result.scalars().all()
        for subscription in subscriptions:
            subscription.is_active = not subscription.is_active

        await self.db.commit()
        await log_admin_action(
            db=self.db,
            user_id=user.id,
            username=user.username,
            action="batch_toggle",
            resource_type="subscription",
            details={"count": len(subscriptions), "ids": ids},
            request=request,
        )

    async def batch_delete_subscriptions(self, *, request, user) -> None:
        ids = await self._load_request_ids(request)
        result = await self.db.execute(
            select(Subscription).where(Subscription.id.in_(ids)),
        )
        subscriptions = result.scalars().all()

        await self._delete_subscription_records(subscriptions)
        await log_admin_action(
            db=self.db,
            user_id=user.id,
            username=user.username,
            action="batch_delete",
            resource_type="subscription",
            details={"count": len(subscriptions), "ids": ids},
            request=request,
        )

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
        from app.domains.podcast.models import (
            PodcastConversation,
            PodcastEpisode,
            PodcastPlaybackState,
            TranscriptionTask,
        )

        for subscription in subscriptions:
            sub_id = subscription.id
            if subscription.source_type == "podcast-rss":
                ep_result = await self.db.execute(
                    select(PodcastEpisode.id).where(
                        PodcastEpisode.subscription_id == sub_id,
                    ),
                )
                episode_ids = [row[0] for row in ep_result.fetchall()]
                if episode_ids:
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
                await self.db.execute(
                    delete(PodcastEpisode).where(
                        PodcastEpisode.subscription_id == sub_id,
                    ),
                )
            await self.db.execute(delete(Subscription).where(Subscription.id == sub_id))

        await self.db.commit()
