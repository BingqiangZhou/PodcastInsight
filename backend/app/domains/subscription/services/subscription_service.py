"""Subscription domain service."""

from __future__ import annotations

import asyncio
import logging
from datetime import UTC, datetime
from typing import Any
from urllib.parse import urlparse
from xml.etree.ElementTree import Element, SubElement, tostring

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.interfaces.settings_provider_impl import DatabaseSettingsProvider
from app.domains.subscription.models import (
    Subscription,
    SubscriptionItem,
    SubscriptionStatus,
    UserSubscription,
)
from app.domains.subscription.parsers.feed_parser import (
    FeedParseOptions,
    FeedParser,
    FeedParserConfig,
)
from app.domains.subscription.parsers.feed_schemas import (
    FeedParseResult,
    ParseErrorCode,
)
from app.domains.subscription.repositories import SubscriptionRepository
from app.shared.schemas import SubscriptionCreate, SubscriptionUpdate


logger = logging.getLogger(__name__)

# Maximum concurrent subscription operations
_MAX_BATCH_CONCURRENCY = 10


class SubscriptionService:
    """Subscription domain service handling queries, mutations, fetches, categories, and exports."""

    def __init__(self, db: AsyncSession, user_id: int):
        self.db = db
        self.user_id = user_id
        self.settings_provider = DatabaseSettingsProvider()
        self.repo = SubscriptionRepository(db, settings_provider=self.settings_provider)

    # ── Schedule helpers ───────────────────────────────────────────────────

    async def _get_default_schedule_settings(
        self,
    ) -> tuple[str, str | None, int | None]:
        from app.domains.subscription.models import UpdateFrequency

        update_frequency = UpdateFrequency.HOURLY.value
        update_time = None
        update_day_of_week = None

        setting = await self.settings_provider.get_setting(
            self.db, "rss.frequency_settings"
        )
        if setting:
            update_frequency = setting.get(
                "update_frequency", UpdateFrequency.HOURLY.value
            )
            update_time = setting.get("update_time")
            update_day_of_week = setting.get("update_day_of_week")

        return update_frequency, update_time, update_day_of_week

    async def _subscribe_or_attach(
        self,
        sub_data: SubscriptionCreate,
        *,
        raise_on_active_duplicate: bool = False,
    ) -> tuple[str, Subscription, str | None]:
        existing = await self.repo.get_duplicate_subscription(
            self.user_id,
            sub_data.source_url,
            sub_data.title,
        )

        if not existing:
            created = await self.repo.create_subscription(self.user_id, sub_data)
            return "success", created, "Subscription created"

        user_sub_result = await self.db.execute(
            select(UserSubscription).where(
                UserSubscription.user_id == self.user_id,
                UserSubscription.subscription_id == existing.id,
            ),
        )
        user_sub = user_sub_result.scalar_one_or_none()

        if user_sub:
            if user_sub.is_archived:
                user_sub.is_archived = False
                if not user_sub.update_frequency:
                    (
                        user_sub.update_frequency,
                        user_sub.update_time,
                        user_sub.update_day_of_week,
                    ) = await self._get_default_schedule_settings()
                await self.db.commit()
                # No refresh needed - existing is already in session with updated values
                return "updated", existing, "Subscription restored"

            if existing.status == SubscriptionStatus.ACTIVE:
                if raise_on_active_duplicate:
                    raise ValueError(f"Already subscribed to: {existing.title}")
                return (
                    "skipped",
                    existing,
                    f"Subscription already exists: {existing.title}",
                )

            existing.source_url = sub_data.source_url
            existing.title = sub_data.title
            existing.description = sub_data.description
            existing.status = SubscriptionStatus.ACTIVE
            existing.error_message = None
            existing.updated_at = datetime.now(UTC)
            await self.db.commit()
            # No refresh needed - existing is already in session with updated values
            return (
                "updated",
                existing,
                f"Updated existing subscription: {existing.title}",
            )

        (
            update_frequency,
            update_time,
            update_day_of_week,
        ) = await self._get_default_schedule_settings()
        self.db.add(
            UserSubscription(
                user_id=self.user_id,
                subscription_id=existing.id,
                update_frequency=update_frequency,
                update_time=update_time,
                update_day_of_week=update_day_of_week,
            ),
        )

        status = "success"
        message = f"Subscribed to existing source: {existing.title}"
        if existing.status != SubscriptionStatus.ACTIVE:
            existing.source_url = sub_data.source_url
            existing.title = sub_data.title
            existing.description = sub_data.description
            existing.status = SubscriptionStatus.ACTIVE
            existing.error_message = None
            existing.updated_at = datetime.now(UTC)
            status = "updated"
            message = f"Updated and subscribed to existing source: {existing.title}"

        await self.db.commit()
        # No refresh needed - existing is already in session with updated values
        return status, existing, message

    def _add_subscription_to_opml(
        self, parent: Element, subscription: Subscription
    ) -> None:
        outline = SubElement(parent, "outline")
        outline.set("text", subscription.title or "Untitled")
        outline.set("title", subscription.title or "Untitled")
        outline.set("xmlUrl", subscription.source_url)

        try:
            parsed = urlparse(subscription.source_url)
            html_url = f"{parsed.scheme}://{parsed.netloc}/"
            outline.set("htmlUrl", html_url)
        except ValueError:
            logger.debug("OPML htmlUrl skipped for %s", subscription.source_url[:80])

        if subscription.description:
            outline.set("description", subscription.description[:500])

    # ── Query methods ──────────────────────────────────────────────────────

    async def list_subscriptions(
        self,
        page: int = 1,
        size: int = 20,
        status: str | None = None,
        source_type: str | None = None,
    ) -> tuple:
        return await self.repo.get_user_subscriptions(
            self.user_id,
            page,
            size,
            status,
            source_type,
        )

    async def get_subscription(self, sub_id: int):
        sub = await self.repo.get_subscription_by_id(self.user_id, sub_id)
        if not sub:
            return None
        count_query = select(func.count()).where(
            SubscriptionItem.subscription_id == sub_id
        )
        item_count = await self.db.scalar(count_query) or 0
        return sub, item_count

    async def get_subscription_items(
        self,
        sub_id: int,
        page: int = 1,
        size: int = 20,
        unread_only: bool = False,
        bookmarked_only: bool = False,
    ) -> tuple:
        return await self.repo.get_subscription_items(
            sub_id,
            self.user_id,
            page,
            size,
            unread_only,
            bookmarked_only,
        )

    async def get_all_items(
        self,
        page: int = 1,
        size: int = 50,
        unread_only: bool = False,
        bookmarked_only: bool = False,
    ) -> tuple:
        return await self.repo.get_all_user_items(
            self.user_id,
            page,
            size,
            unread_only,
            bookmarked_only,
        )

    async def get_unread_count(self) -> int:
        return await self.repo.get_unread_count(self.user_id)

    # ── Mutation methods ───────────────────────────────────────────────────

    async def create_subscription(self, sub_data: SubscriptionCreate):
        status, sub, _ = await self._subscribe_or_attach(
            sub_data,
            raise_on_active_duplicate=True,
        )
        if status == "skipped":
            raise ValueError(f"Already subscribed to: {sub.title}")
        return sub

    async def create_subscriptions_batch(
        self,
        subscriptions_data: list[SubscriptionCreate],
    ) -> list[dict[str, Any]]:
        """Create multiple subscriptions concurrently with controlled parallelism.

        Uses asyncio.Semaphore to limit concurrent operations and isolates errors
        so individual failures don't affect other subscriptions.
        """
        if not subscriptions_data:
            return []

        semaphore = asyncio.Semaphore(_MAX_BATCH_CONCURRENCY)
        results = [None] * len(subscriptions_data)

        async def process_single(index: int, sub_data: SubscriptionCreate) -> dict:
            """Process a single subscription with error isolation."""
            async with semaphore:
                try:
                    status, sub, message = await self._subscribe_or_attach(sub_data)
                    return {
                        "source_url": sub_data.source_url,
                        "title": sub_data.title,
                        "status": status,
                        "id": sub.id,
                        "message": message,
                    }
                except ValueError as exc:
                    return {
                        "source_url": sub_data.source_url,
                        "title": sub_data.title,
                        "status": "skipped",
                        "message": str(exc),
                    }
                except Exception as exc:
                    logger.exception(
                        "Error processing subscription %s: %s",
                        sub_data.source_url,
                        exc,
                    )
                    return {
                        "source_url": sub_data.source_url,
                        "title": sub_data.title,
                        "status": "error",
                        "message": str(exc),
                    }

        # Create tasks for all subscriptions
        tasks = [
            process_single(i, sub_data) for i, sub_data in enumerate(subscriptions_data)
        ]

        # Execute concurrently with semaphore limiting parallelism
        completed_results = await asyncio.gather(*tasks)

        # Map results back to original order
        for i, result in enumerate(completed_results):
            results[i] = result

        return results

    async def update_subscription(self, sub_id: int, sub_data: SubscriptionUpdate):
        sub = await self.repo.update_subscription(self.user_id, sub_id, sub_data)
        if not sub:
            return None
        return await self.get_subscription(sub_id)

    async def delete_subscription(self, sub_id: int) -> bool:
        return await self.repo.delete_subscription(self.user_id, sub_id)

    async def mark_item_as_read(self, item_id: int) -> dict[str, Any] | None:
        item = await self.repo.mark_item_as_read(item_id, self.user_id)
        if not item:
            return None
        return {
            "id": item.id,
            "read_at": item.read_at.isoformat() if item.read_at else None,
        }

    async def mark_item_as_unread(self, item_id: int) -> dict[str, Any] | None:
        item = await self.repo.mark_item_as_unread(item_id, self.user_id)
        if not item:
            return None
        return {"id": item.id, "read_at": None}

    async def toggle_bookmark(self, item_id: int) -> dict[str, Any] | None:
        item = await self.repo.toggle_bookmark(item_id, self.user_id)
        if not item:
            return None
        return {"id": item.id, "bookmarked": item.bookmarked}

    async def delete_item(self, item_id: int) -> bool:
        return await self.repo.delete_item(item_id, self.user_id)

    # ── Fetch methods ──────────────────────────────────────────────────────

    async def fetch_subscription(self, sub_id: int) -> dict[str, Any]:
        sub = await self.repo.get_subscription_by_id(self.user_id, sub_id)
        if not sub:
            raise ValueError("Subscription not found")
        if sub.source_type != "rss":
            raise ValueError("Only RSS subscriptions support manual fetch")

        config = FeedParserConfig(
            max_entries=50,
            strip_html=True,
            strict_mode=False,
            log_raw_feed=False,
        )
        options = FeedParseOptions(strip_html_content=True, include_raw_metadata=False)
        parser = FeedParser(config)

        try:
            result: FeedParseResult = await parser.parse_feed(
                sub.source_url, options=options
            )
            if not result.success and result.has_errors():
                critical_errors = [
                    error
                    for error in result.errors
                    if error.code
                    in (ParseErrorCode.NETWORK_ERROR, ParseErrorCode.PARSE_ERROR)
                ]
                if critical_errors:
                    error_msgs = "; ".join(error.message for error in critical_errors)
                    await self.repo.update_fetch_status(
                        sub.id, SubscriptionStatus.ERROR, error_msgs
                    )
                    raise ValueError(f"Feed parsing failed: {error_msgs}")

            new_items = 0
            updated_items = 0
            latest_published_at: datetime | None = None
            items_payload: list[dict[str, Any]] = []
            for entry in result.entries:
                try:
                    items_payload.append(
                        {
                            "external_id": entry.id or entry.link or "",
                            "title": entry.title,
                            "content": entry.content,
                            "summary": entry.summary,
                            "author": entry.author,
                            "source_url": entry.link,
                            "image_url": entry.image_url,
                            "tags": entry.tags,
                            "published_at": entry.published_at,
                        },
                    )
                    if entry.published_at and (
                        latest_published_at is None
                        or entry.published_at > latest_published_at
                    ):
                        latest_published_at = entry.published_at
                except Exception as exc:
                    logger.warning("Error processing entry %s: %s", entry.id, exc)
                    if config.strict_mode:
                        raise

            _, created_items = await self.repo.create_or_update_items_batch(
                sub.id,
                items_payload,
                commit=False,
            )
            new_items = len(created_items)
            updated_items = len(items_payload) - new_items

            status = SubscriptionStatus.ACTIVE
            error_msg = None
            if result.has_warnings():
                logger.warning(
                    "Warnings parsing feed %s: %s", sub.source_url, result.warnings
                )
                if result.warnings:
                    error_msg = "; ".join(result.warnings)

            sub.status = status
            sub.error_message = error_msg
            sub.last_fetched_at = datetime.now(UTC)
            if latest_published_at:
                sub.latest_item_published_at = latest_published_at
            await self.db.commit()
            # No refresh needed - sub is already in session with updated values
            return {
                "subscription_id": sub.id,
                "status": "success",
                "new_items": new_items,
                "updated_items": updated_items,
                "total_items": new_items + updated_items,
                "warnings": result.warnings if result.has_warnings() else None,
            }
        except ValueError:
            raise
        except Exception as exc:
            await self.db.rollback()
            logger.error("Error fetching subscription %s: %s", sub_id, exc)
            await self.repo.update_fetch_status(
                sub.id, SubscriptionStatus.ERROR, str(exc)
            )
            raise
        finally:
            await parser.close()

    async def fetch_all_subscriptions(self) -> list[dict[str, Any]]:
        subs, *_ = await self.repo.get_user_subscriptions(
            self.user_id,
            page=1,
            size=100,
            status=SubscriptionStatus.ACTIVE,
            source_type="rss",
        )

        sem = asyncio.Semaphore(5)  # limit concurrency

        async def _fetch_one(sub: Subscription) -> dict[str, Any]:
            async with sem:
                try:
                    return await self.fetch_subscription(sub.id)
                except Exception as exc:
                    return {
                        "subscription_id": sub.id,
                        "status": "error",
                        "error": str(exc),
                    }

        return list(await asyncio.gather(*[_fetch_one(sub) for sub in subs]))

    # ── Category methods ───────────────────────────────────────────────────

    async def list_categories(self) -> list:
        return await self.repo.get_user_categories(self.user_id)

    async def create_category(
        self,
        name: str,
        description: str | None = None,
        color: str | None = None,
    ):
        return await self.repo.create_category(self.user_id, name, description, color)

    async def update_category(self, category_id: int, **kwargs):
        return await self.repo.update_category(category_id, self.user_id, **kwargs)

    async def delete_category(self, category_id: int) -> bool:
        return await self.repo.delete_category(category_id, self.user_id)

    async def add_subscription_to_category(
        self,
        subscription_id: int,
        category_id: int,
    ) -> bool:
        sub = await self.repo.get_subscription_by_id(self.user_id, subscription_id)
        category = await self.repo.get_category_by_id(category_id, self.user_id)
        if not sub or not category:
            return False
        return await self.repo.add_subscription_to_category(
            subscription_id, category_id
        )

    async def remove_subscription_from_category(
        self,
        subscription_id: int,
        category_id: int,
    ) -> bool:
        return await self.repo.remove_subscription_from_category(
            subscription_id, category_id
        )

    # ── Export methods ─────────────────────────────────────────────────────

    async def generate_opml_content(
        self,
        user_id: int | None = None,
        status_filter: str | None = SubscriptionStatus.ACTIVE,
    ) -> str:
        opml = Element("opml", version="2.0")
        head = SubElement(opml, "head")
        SubElement(head, "title").text = "Stella RSS Subscriptions"
        SubElement(head, "dateCreated").text = datetime.now(UTC).strftime(
            "%a, %d %b %Y %H:%M:%S GMT",
        )
        SubElement(head, "ownerName").text = "Stella Admin"

        if user_id is not None:
            query = (
                select(Subscription)
                .join(
                    UserSubscription,
                    UserSubscription.subscription_id == Subscription.id,
                )
                .options(selectinload(Subscription.categories))
                .where(
                    UserSubscription.user_id == user_id,
                    UserSubscription.is_archived.is_(False),
                )
            )
        else:
            # Admin export — cap at a reasonable limit to avoid unbounded load
            query = (
                select(Subscription)
                .options(selectinload(Subscription.categories))
                .limit(10000)
            )

        if status_filter:
            query = query.where(Subscription.status == status_filter)

        query = query.order_by(Subscription.title)
        result = await self.db.execute(query)
        subscriptions = result.scalars().all()
        SubElement(head, "totalSubscriptions").text = str(len(subscriptions))

        body = SubElement(opml, "body")
        categorized_subs: dict[str, list[Subscription]] = {}
        uncategorized_subs: list[Subscription] = []

        for sub in subscriptions:
            if sub.categories:
                category_name = sub.categories[0].name
                categorized_subs.setdefault(category_name, []).append(sub)
            else:
                uncategorized_subs.append(sub)

        for category_name in sorted(categorized_subs.keys()):
            category_outline = SubElement(body, "outline")
            category_outline.set("text", category_name)
            category_outline.set("title", category_name)
            for sub in categorized_subs[category_name]:
                self._add_subscription_to_opml(category_outline, sub)

        for sub in uncategorized_subs:
            self._add_subscription_to_opml(body, sub)

        return tostring(opml, encoding="unicode", xml_declaration=True)
