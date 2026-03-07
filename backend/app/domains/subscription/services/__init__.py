"""Subscription domain services."""

import logging
from datetime import datetime, timezone
from typing import Any
from urllib.parse import urlparse
from xml.etree.ElementTree import Element, SubElement, tostring

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.domains.subscription.models import (
    Subscription,
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
from app.shared.schemas import (
    PaginatedResponse,
    SubscriptionCreate,
    SubscriptionResponse,
    SubscriptionUpdate,
)


logger = logging.getLogger(__name__)


class SubscriptionService:
    """Service for orchestrating subscription logic."""

    def __init__(self, db: AsyncSession, user_id: int):
        self.db = db
        self.user_id = user_id
        self.repo = SubscriptionRepository(db)

    # Subscription operations
    async def list_subscriptions(
        self,
        page: int = 1,
        size: int = 20,
        status: str | None = None,
        source_type: str | None = None,
    ) -> PaginatedResponse:
        """
        List user's subscriptions.

        Optimized to use batch fetched item counts instead of N+1 queries.
        """
        items, total, item_counts = await self.repo.get_user_subscriptions(
            self.user_id, page, size, status, source_type
        )

        response_items = []
        for sub in items:
            # Get item count from batch result (default to 0 if not found)
            item_count = item_counts.get(sub.id, 0)

            response_items.append(
                SubscriptionResponse(
                    id=sub.id,
                    title=sub.title,
                    description=sub.description,
                    source_type=sub.source_type,
                    source_url=sub.source_url,
                    image_url=sub.image_url,
                    config=sub.config,
                    status=sub.status,
                    last_fetched_at=sub.last_fetched_at,
                    latest_item_published_at=sub.latest_item_published_at,
                    error_message=sub.error_message,
                    fetch_interval=sub.fetch_interval,
                    item_count=item_count,
                    created_at=sub.created_at,
                    updated_at=sub.updated_at,
                )
            )

        return PaginatedResponse.create(
            items=response_items,
            total=total,
            page=page,
            size=size
        )

    async def create_subscription(
        self, sub_data: SubscriptionCreate
    ) -> SubscriptionResponse:
        """
        Create a new subscription with enhanced duplicate detection.

        Create and attach a subscription with robust duplicate detection.
        With many-to-many relationship:
        1. Check if subscription exists globally by URL
        2. If exists and user already subscribed: raise error
        3. If exists but user not subscribed: create UserSubscription mapping
        4. If not exists: create Subscription + UserSubscription
        """
        status, sub, _ = await self._subscribe_or_attach(
            sub_data, raise_on_active_duplicate=True
        )
        if status == "skipped":
            raise ValueError(f"Already subscribed to: {sub.title}")
        return self._to_response(sub)

    async def create_subscriptions_batch(
        self, subscriptions_data: list[SubscriptionCreate]
    ) -> list[dict[str, Any]]:
        """
        Batch create subscriptions with enhanced duplicate detection.

        Batch create subscriptions with robust duplicate detection.
        Returns results with status:
        - success: New subscription created
        - updated: Existing subscription updated (non-active status)
        - skipped: Existing active subscription (no change)
        - error: Error occurred
        """
        results = []
        for sub_data in subscriptions_data:
            try:
                status, sub, message = await self._subscribe_or_attach(sub_data)
                results.append(
                    {
                        "source_url": sub_data.source_url,
                        "title": sub_data.title,
                        "status": status,
                        "id": sub.id,
                        "message": message,
                    }
                )

            except ValueError as e:
                # Validation errors (like active duplicate)
                results.append(
                    {
                        "source_url": sub_data.source_url,
                        "title": sub_data.title,
                        "status": "skipped",
                        "message": str(e),
                    }
                )
            except Exception as e:
                logger.error(
                    f"Error creating subscription for {sub_data.source_url}: {e}"
                )
                results.append(
                    {
                        "source_url": sub_data.source_url,
                        "title": sub_data.title,
                        "status": "error",
                        "message": str(e),
                    }
                )
        return results

    async def _subscribe_or_attach(
        self,
        sub_data: SubscriptionCreate,
        raise_on_active_duplicate: bool = False,
    ) -> tuple[str, Subscription, str | None]:
        """Create a global subscription or attach current user mapping."""
        existing = await self.repo.get_duplicate_subscription(
            self.user_id, sub_data.source_url, sub_data.title
        )

        if not existing:
            created = await self.repo.create_subscription(self.user_id, sub_data)
            return "success", created, "Subscription created"

        user_sub_result = await self.db.execute(
            select(UserSubscription).where(
                UserSubscription.user_id == self.user_id,
                UserSubscription.subscription_id == existing.id,
            )
        )
        user_sub = user_sub_result.scalar_one_or_none()

        # Existing source + user already mapped.
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
                await self.db.refresh(existing)
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
            existing.updated_at = datetime.now(timezone.utc)
            await self.db.commit()
            await self.db.refresh(existing)
            return "updated", existing, f"Updated existing subscription: {existing.title}"

        # Existing source + user not mapped: create user mapping only.
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
            )
        )

        status = "success"
        message = f"Subscribed to existing source: {existing.title}"
        if existing.status != SubscriptionStatus.ACTIVE:
            existing.source_url = sub_data.source_url
            existing.title = sub_data.title
            existing.description = sub_data.description
            existing.status = SubscriptionStatus.ACTIVE
            existing.error_message = None
            existing.updated_at = datetime.now(timezone.utc)
            status = "updated"
            message = f"Updated and subscribed to existing source: {existing.title}"

        await self.db.commit()
        await self.db.refresh(existing)
        return status, existing, message

    async def _get_default_schedule_settings(self) -> tuple[str, str | None, int | None]:
        from app.admin.models import SystemSettings
        from app.domains.subscription.models import UpdateFrequency

        update_frequency = UpdateFrequency.HOURLY.value
        update_time = None
        update_day_of_week = None

        settings_result = await self.db.execute(
            select(SystemSettings).where(
                SystemSettings.key == "rss.frequency_settings"
            )
        )
        setting = settings_result.scalar_one_or_none()
        if setting and setting.value:
            update_frequency = setting.value.get(
                "update_frequency", UpdateFrequency.HOURLY.value
            )
            update_time = setting.value.get("update_time")
            update_day_of_week = setting.value.get("update_day_of_week")

        return update_frequency, update_time, update_day_of_week

    @staticmethod
    def _to_response(sub: Subscription) -> SubscriptionResponse:
        return SubscriptionResponse(
            id=sub.id,
            title=sub.title,
            description=sub.description,
            source_type=sub.source_type,
            source_url=sub.source_url,
            image_url=sub.image_url,
            config=sub.config,
            status=sub.status,
            last_fetched_at=sub.last_fetched_at,
            latest_item_published_at=sub.latest_item_published_at,
            error_message=sub.error_message,
            fetch_interval=sub.fetch_interval,
            item_count=0,
            created_at=sub.created_at,
            updated_at=sub.updated_at,
        )

    async def get_subscription(self, sub_id: int) -> SubscriptionResponse | None:
        """Get subscription details."""
        sub = await self.repo.get_subscription_by_id(self.user_id, sub_id)
        if not sub:
            return None

        # Get item count
        from sqlalchemy import func, select

        from app.domains.subscription.models import SubscriptionItem

        count_query = select(func.count()).where(
            SubscriptionItem.subscription_id == sub_id
        )
        item_count = await self.db.scalar(count_query) or 0

        return SubscriptionResponse(
            id=sub.id,
            title=sub.title,
            description=sub.description,
            source_type=sub.source_type,
            source_url=sub.source_url,
            config=sub.config,
            status=sub.status,
            last_fetched_at=sub.last_fetched_at,
            latest_item_published_at=sub.latest_item_published_at,
            error_message=sub.error_message,
            fetch_interval=sub.fetch_interval,
            item_count=item_count,
            created_at=sub.created_at,
            updated_at=sub.updated_at,
        )

    async def update_subscription(
        self, sub_id: int, sub_data: SubscriptionUpdate
    ) -> SubscriptionResponse | None:
        """Update subscription."""
        sub = await self.repo.update_subscription(self.user_id, sub_id, sub_data)
        if not sub:
            return None

        return await self.get_subscription(sub_id)

    async def delete_subscription(self, sub_id: int) -> bool:
        """Delete subscription."""
        return await self.repo.delete_subscription(self.user_id, sub_id)

    async def fetch_subscription(self, sub_id: int) -> dict[str, Any]:
        """
        Manually trigger subscription fetch (for RSS feeds).

        Manually trigger RSS subscription fetch.
        Uses the enhanced FeedParser component for robust parsing.
        Uses the enhanced FeedParser component for resilient parsing.
        """
        sub = await self.repo.get_subscription_by_id(self.user_id, sub_id)
        if not sub:
            raise ValueError("Subscription not found")

        if sub.source_type != "rss":
            raise ValueError("Only RSS subscriptions support manual fetch")

        # Configure parser
        config = FeedParserConfig(
            max_entries=50,  # Limit to 50 items per fetch
            strip_html=True,
            strict_mode=False,  # Continue on entry errors
            log_raw_feed=False,
        )

        options = FeedParseOptions(strip_html_content=True, include_raw_metadata=False)

        # Parse feed using new FeedParser
        parser = FeedParser(config)
        try:
            result: FeedParseResult = await parser.parse_feed(
                sub.source_url, options=options
            )

            # Check for critical errors
            if not result.success and result.has_errors():
                critical_errors = [
                    e
                    for e in result.errors
                    if e.code
                    in (ParseErrorCode.NETWORK_ERROR, ParseErrorCode.PARSE_ERROR)
                ]
                if critical_errors:
                    error_msgs = "; ".join(e.message for e in critical_errors)
                    await self.repo.update_fetch_status(
                        sub.id, SubscriptionStatus.ERROR, error_msgs
                    )
                    raise ValueError(f"Feed parsing failed: {error_msgs}")

            # Process feed entries
            new_items = 0
            updated_items = 0
            latest_published_at: datetime | None = None

            for entry in result.entries:
                try:
                    # Create or update item using parsed entry data
                    item = await self.repo.create_or_update_item(
                        subscription_id=sub.id,
                        external_id=entry.id or entry.link or "",
                        title=entry.title,
                        content=entry.content,
                        summary=entry.summary,
                        author=entry.author,
                        source_url=entry.link,
                        image_url=entry.image_url,
                        tags=entry.tags,
                        published_at=entry.published_at,
                    )

                    # Check if this was a new item (simplified check)
                    if item.created_at == item.updated_at:
                        new_items += 1
                    else:
                        updated_items += 1

                    # Track the latest published_at
                    if (
                        entry.published_at
                        and (
                            latest_published_at is None
                            or entry.published_at > latest_published_at
                        )
                    ):
                        latest_published_at = entry.published_at

                except Exception as e:
                    logger.warning(f"Error processing entry {entry.id}: {e}")
                    if config.strict_mode:
                        raise

            # Update subscription status
            status = SubscriptionStatus.ACTIVE
            error_msg = None

            # Include warnings in error message if any
            if result.has_warnings():
                logger.warning(
                    f"Warnings parsing feed {sub.source_url}: {result.warnings}"
                )
                if result.warnings:
                    error_msg = "; ".join(result.warnings)

            await self.repo.update_fetch_status(
                sub.id, status, error_msg, latest_published_at
            )

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
        except Exception as e:
            logger.error(f"Error fetching subscription {sub_id}: {e}")
            await self.repo.update_fetch_status(
                sub.id, SubscriptionStatus.ERROR, str(e)
            )
            raise
        finally:
            await parser.close()

    async def fetch_all_subscriptions(self) -> list[dict[str, Any]]:
        """Fetch all active RSS subscriptions."""
        subs, _ = await self.repo.get_user_subscriptions(
            self.user_id,
            page=1,
            size=100,
            status=SubscriptionStatus.ACTIVE,
            source_type="rss",
        )

        results = []
        for sub in subs:
            try:
                result = await self.fetch_subscription(sub.id)
                results.append(result)
            except Exception as e:
                results.append(
                    {"subscription_id": sub.id, "status": "error", "error": str(e)}
                )

        return results

    # Subscription Item operations
    async def get_subscription_items(
        self,
        sub_id: int,
        page: int = 1,
        size: int = 20,
        unread_only: bool = False,
        bookmarked_only: bool = False,
    ) -> PaginatedResponse:
        """Get items from a subscription."""
        items, total = await self.repo.get_subscription_items(
            sub_id, self.user_id, page, size, unread_only, bookmarked_only
        )

        response_items = [
            {
                "id": item.id,
                "subscription_id": item.subscription_id,
                "external_id": item.external_id,
                "title": item.title,
                "content": item.content,
                "summary": item.summary,
                "author": item.author,
                "source_url": item.source_url,
                "image_url": item.image_url,
                "tags": item.tags,
                "metadata": item.metadata_json,
                "published_at": item.published_at.isoformat() if item.published_at else None,
                "read_at": item.read_at.isoformat() if item.read_at else None,
                "bookmarked": item.bookmarked,
                "created_at": item.created_at.isoformat(),
            }
            for item in items
        ]

        return PaginatedResponse.create(
            items=response_items, total=total, page=page, size=size
        )

    async def get_all_items(
        self,
        page: int = 1,
        size: int = 50,
        unread_only: bool = False,
        bookmarked_only: bool = False,
    ) -> PaginatedResponse:
        """Get all items from all subscriptions."""
        items, total = await self.repo.get_all_user_items(
            self.user_id, page, size, unread_only, bookmarked_only
        )

        response_items = [
            {
                "id": item.id,
                "subscription_id": item.subscription_id,
                "external_id": item.external_id,
                "title": item.title,
                "content": item.content,
                "summary": item.summary,
                "author": item.author,
                "source_url": item.source_url,
                "image_url": item.image_url,
                "tags": item.tags,
                "metadata": item.metadata_json,
                "published_at": item.published_at.isoformat() if item.published_at else None,
                "read_at": item.read_at.isoformat() if item.read_at else None,
                "bookmarked": item.bookmarked,
                "created_at": item.created_at.isoformat(),
            }
            for item in items
        ]

        return PaginatedResponse.create(
            items=response_items,
            total=total,
            page=page,
            size=size
        )

    async def mark_item_as_read(self, item_id: int) -> dict[str, Any] | None:
        """Mark an item as read."""
        item = await self.repo.mark_item_as_read(item_id, self.user_id)
        if not item:
            return None

        return {
            "id": item.id,
            "read_at": item.read_at.isoformat() if item.read_at else None,
        }

    async def mark_item_as_unread(self, item_id: int) -> dict[str, Any] | None:
        """Mark an item as unread."""
        item = await self.repo.mark_item_as_unread(item_id, self.user_id)
        if not item:
            return None

        return {"id": item.id, "read_at": None}

    async def toggle_bookmark(self, item_id: int) -> dict[str, Any] | None:
        """Toggle item bookmark status."""
        item = await self.repo.toggle_bookmark(item_id, self.user_id)
        if not item:
            return None

        return {"id": item.id, "bookmarked": item.bookmarked}

    async def delete_item(self, item_id: int) -> bool:
        """Delete an item."""
        return await self.repo.delete_item(item_id, self.user_id)

    async def get_unread_count(self) -> int:
        """Get total unread items count."""
        return await self.repo.get_unread_count(self.user_id)

    # Category operations
    async def list_categories(self) -> list[dict[str, Any]]:
        """Get all user's categories."""
        categories = await self.repo.get_user_categories(self.user_id)

        return [
            {
                "id": cat.id,
                "name": cat.name,
                "description": cat.description,
                "color": cat.color,
                "created_at": cat.created_at.isoformat(),
            }
            for cat in categories
        ]

    async def create_category(
        self, name: str, description: str | None = None, color: str | None = None
    ) -> dict[str, Any]:
        """Create a new category."""
        cat = await self.repo.create_category(self.user_id, name, description, color)

        return {
            "id": cat.id,
            "name": cat.name,
            "description": cat.description,
            "color": cat.color,
            "created_at": cat.created_at.isoformat(),
        }

    async def update_category(
        self, category_id: int, **kwargs
    ) -> dict[str, Any] | None:
        """Update category."""
        cat = await self.repo.update_category(category_id, self.user_id, **kwargs)
        if not cat:
            return None

        return {
            "id": cat.id,
            "name": cat.name,
            "description": cat.description,
            "color": cat.color,
        }

    async def delete_category(self, category_id: int) -> bool:
        """Delete category."""
        return await self.repo.delete_category(category_id, self.user_id)

    async def add_subscription_to_category(
        self, subscription_id: int, category_id: int
    ) -> bool:
        """Add subscription to category."""
        # Verify ownership
        sub = await self.repo.get_subscription_by_id(self.user_id, subscription_id)
        cat = await self.repo.get_category_by_id(category_id, self.user_id)

        if not sub or not cat:
            return False

        return await self.repo.add_subscription_to_category(
            subscription_id, category_id
        )

    async def remove_subscription_from_category(
        self, subscription_id: int, category_id: int
    ) -> bool:
        """Remove subscription from category."""
        return await self.repo.remove_subscription_from_category(
            subscription_id, category_id
        )

    async def generate_opml_content(
        self,
        user_id: int | None = None,
        status_filter: str | None = SubscriptionStatus.ACTIVE,
    ) -> str:
        """
        Generate OPML 2.0 format XML content for RSS subscriptions using ElementTree.

        Generate OPML 2.0 compliant XML content for RSS subscriptions.
        Args:
            user_id: Optional user ID to filter subscriptions. If None, exports all subscriptions.
            status_filter: Subscription status filter (default: ACTIVE)

        Returns:
            OPML format XML string with proper formatting
        """
        # Create root OPML element
        opml = Element("opml", version="2.0")

        # Create head section
        head = SubElement(opml, "head")
        SubElement(head, "title").text = "Stella RSS Subscriptions"
        SubElement(head, "dateCreated").text = datetime.now(timezone.utc).strftime("%a, %d %b %Y %H:%M:%S GMT")
        SubElement(head, "ownerName").text = "Stella Admin"

        # Query all subscriptions
        if user_id is not None:
            # Filter by user's subscriptions
            query = (
                select(Subscription)
                .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
                .options(selectinload(Subscription.categories))
                .where(UserSubscription.user_id == user_id, not UserSubscription.is_archived)
            )
        else:
            # Get all subscriptions
            query = select(Subscription).options(selectinload(Subscription.categories))

        if status_filter:
            query = query.where(Subscription.status == status_filter)

        query = query.order_by(Subscription.title)
        result = await self.db.execute(query)
        subscriptions = result.scalars().all()

        SubElement(head, "totalSubscriptions").text = str(len(subscriptions))

        # Create body section
        body = SubElement(opml, "body")

        # Group subscriptions by category
        categorized_subs: dict[str, list[Subscription]] = {}
        uncategorized_subs: list[Subscription] = []

        for sub in subscriptions:
            if sub.categories:
                category_name = sub.categories[0].name
                if category_name not in categorized_subs:
                    categorized_subs[category_name] = []
                categorized_subs[category_name].append(sub)
            else:
                uncategorized_subs.append(sub)

        # Add categorized subscriptions under category folders
        for category_name in sorted(categorized_subs.keys()):
            category_outline = SubElement(body, "outline")
            category_outline.set("text", category_name)
            category_outline.set("title", category_name)

            for sub in categorized_subs[category_name]:
                self._add_subscription_to_opml(category_outline, sub)

        # Add uncategorized subscriptions directly to body
        for sub in uncategorized_subs:
            self._add_subscription_to_opml(body, sub)

        # Convert to string with proper formatting
        return tostring(opml, encoding="unicode", xml_declaration=True)

    def _add_subscription_to_opml(self, parent: Element, subscription: Subscription) -> None:
        """
        Add a subscription as an outline element to the given parent.

        Add the subscription as an OPML outline element under the given parent.
        Args:
            parent: Parent Element to add the outline to
            subscription: Subscription model instance
        """
        outline = SubElement(parent, "outline")
        outline.set("text", subscription.title or "Untitled")
        outline.set("title", subscription.title or "Untitled")
        outline.set("xmlUrl", subscription.source_url)

        # Try to extract htmlUrl from source_url
        try:
            parsed = urlparse(subscription.source_url)
            html_url = f"{parsed.scheme}://{parsed.netloc}/"
            outline.set("htmlUrl", html_url)
        except Exception:
            pass

        # Add description if available (truncated if too long)
        if subscription.description:
            outline.set("description", subscription.description[:500])
