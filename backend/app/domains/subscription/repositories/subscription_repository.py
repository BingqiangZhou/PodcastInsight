"""Subscription domain repository."""

from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.domains.subscription.models import (
    Subscription,
    SubscriptionCategory,
    SubscriptionCategoryMapping,
    SubscriptionItem,
    SubscriptionStatus,
    UserSubscription,
)
from app.shared.schemas import SubscriptionCreate, SubscriptionUpdate


class SubscriptionRepository:
    """Subscription data access layer."""

    def __init__(self, db: AsyncSession):
        self.db = db

    # ── Shared helpers ─────────────────────────────────────────────────────

    async def _resolve_window_total(
        self,
        rows: list,
        *,
        total_index: int,
        fallback_count_query,
    ) -> int:
        if rows:
            return int(rows[0][total_index] or 0)
        return int(await self.db.scalar(fallback_count_query) or 0)

    # ── Lookup helpers ─────────────────────────────────────────────────────

    async def get_subscription_by_id(
        self,
        user_id: int,
        sub_id: int,
    ) -> Subscription | None:
        query = (
            select(Subscription)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .options(selectinload(Subscription.categories))
            .where(
                Subscription.id == sub_id,
                UserSubscription.user_id == user_id,
                UserSubscription.is_archived.is_(False),
            )
        )
        result = await self.db.execute(query)
        return result.scalar_one_or_none()

    async def get_subscription_by_url(self, user_id: int, url: str) -> Subscription | None:
        query = select(Subscription).where(Subscription.source_url == url)
        result = await self.db.execute(query)
        return result.scalar_one_or_none()

    async def get_subscription_by_title(self, user_id: int, title: str) -> Subscription | None:
        query = select(Subscription).where(
            func.lower(Subscription.title) == func.lower(title)
        )
        result = await self.db.execute(query)
        return result.scalar_one_or_none()

    async def get_duplicate_subscription(
        self,
        user_id: int,
        url: str,
        title: str,
    ) -> Subscription | None:
        query_url = select(Subscription).where(Subscription.source_url == url)
        result = await self.db.execute(query_url)
        subscription = result.scalar_one_or_none()
        if subscription:
            return subscription

        query_title = select(Subscription).where(
            func.lower(Subscription.title) == func.lower(title)
        )
        result = await self.db.execute(query_title)
        return result.scalar_one_or_none()

    async def get_item_by_id(self, item_id: int, user_id: int) -> SubscriptionItem | None:
        query = (
            select(SubscriptionItem)
            .join(Subscription, SubscriptionItem.subscription_id == Subscription.id)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .where(
                SubscriptionItem.id == item_id,
                UserSubscription.user_id == user_id,
                UserSubscription.is_archived.is_(False),
            )
        )
        result = await self.db.execute(query)
        return result.scalar_one_or_none()

    async def get_category_by_id(
        self,
        category_id: int,
        user_id: int,
    ) -> SubscriptionCategory | None:
        query = select(SubscriptionCategory).where(
            SubscriptionCategory.id == category_id,
            SubscriptionCategory.user_id == user_id,
        )
        result = await self.db.execute(query)
        return result.scalar_one_or_none()

    async def get_unread_count(self, user_id: int) -> int:
        count_query = (
            select(func.count(SubscriptionItem.id))
            .select_from(SubscriptionItem)
            .join(Subscription, SubscriptionItem.subscription_id == Subscription.id)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .where(
                and_(
                    UserSubscription.user_id == user_id,
                    UserSubscription.is_archived.is_(False),
                    SubscriptionItem.read_at.is_(None),
                )
            )
        )
        return await self.db.scalar(count_query) or 0

    # ── Query methods ──────────────────────────────────────────────────────

    async def get_user_subscriptions(
        self,
        user_id: int,
        page: int = 1,
        size: int = 20,
        status: str | None = None,
        source_type: str | None = None,
    ) -> tuple[list[Subscription], int, dict[int, int]]:
        skip = (page - 1) * size
        base_query = (
            select(Subscription)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .where(UserSubscription.user_id == user_id)
        )
        if status:
            base_query = base_query.where(Subscription.status == status)
        if source_type:
            base_query = base_query.where(Subscription.source_type == source_type)
        base_query = base_query.where(UserSubscription.is_archived.is_(False))

        item_count_subquery = (
            select(
                SubscriptionItem.subscription_id.label("subscription_id"),
                func.count(SubscriptionItem.id).label("item_count"),
            )
            .group_by(SubscriptionItem.subscription_id)
            .subquery()
        )
        query = (
            base_query.outerjoin(
                item_count_subquery,
                item_count_subquery.c.subscription_id == Subscription.id,
            )
            .options(selectinload(Subscription.categories))
            .add_columns(
                func.coalesce(item_count_subquery.c.item_count, 0),
                func.count(Subscription.id).over(),
            )
            .offset(skip)
            .limit(size)
            .order_by(Subscription.updated_at.desc())
        )
        result = await self.db.execute(query)
        rows = result.all()
        total = await self._resolve_window_total(
            rows,
            total_index=2,
            fallback_count_query=select(func.count()).select_from(base_query.subquery()),
        )
        items = [row[0] for row in rows]
        item_counts = {row[0].id: int(row[1]) for row in rows}
        return items, total, item_counts

    async def get_subscription_items(
        self,
        subscription_id: int,
        user_id: int,
        page: int = 1,
        size: int = 20,
        unread_only: bool = False,
        bookmarked_only: bool = False,
    ) -> tuple[list[SubscriptionItem], int]:
        skip = (page - 1) * size
        base_query = (
            select(SubscriptionItem)
            .join(
                UserSubscription,
                UserSubscription.subscription_id == SubscriptionItem.subscription_id,
            )
            .where(
                SubscriptionItem.subscription_id == subscription_id,
                UserSubscription.user_id == user_id,
                UserSubscription.is_archived.is_(False),
            )
        )
        if unread_only:
            base_query = base_query.where(SubscriptionItem.read_at.is_(None))
        if bookmarked_only:
            base_query = base_query.where(SubscriptionItem.bookmarked.is_(True))

        query = (
            base_query.add_columns(func.count(SubscriptionItem.id).over())
            .offset(skip)
            .limit(size)
            .order_by(SubscriptionItem.published_at.desc())
        )
        result = await self.db.execute(query)
        rows = result.all()
        total = await self._resolve_window_total(
            rows,
            total_index=1,
            fallback_count_query=select(func.count()).select_from(base_query.subquery()),
        )
        return [row[0] for row in rows], total

    async def get_all_user_items(
        self,
        user_id: int,
        page: int = 1,
        size: int = 50,
        unread_only: bool = False,
        bookmarked_only: bool = False,
    ) -> tuple[list[SubscriptionItem], int]:
        skip = (page - 1) * size
        base_query = (
            select(SubscriptionItem)
            .join(
                UserSubscription,
                UserSubscription.subscription_id == SubscriptionItem.subscription_id,
            )
            .where(
                UserSubscription.user_id == user_id,
                UserSubscription.is_archived.is_(False),
            )
        )
        if unread_only:
            base_query = base_query.where(SubscriptionItem.read_at.is_(None))
        if bookmarked_only:
            base_query = base_query.where(SubscriptionItem.bookmarked.is_(True))

        query = (
            base_query.add_columns(func.count(SubscriptionItem.id).over())
            .offset(skip)
            .limit(size)
            .order_by(SubscriptionItem.published_at.desc())
        )
        result = await self.db.execute(query)
        rows = result.all()
        total = await self._resolve_window_total(
            rows,
            total_index=1,
            fallback_count_query=select(func.count()).select_from(base_query.subquery()),
        )
        return [row[0] for row in rows], total

    async def get_user_categories(self, user_id: int) -> list[SubscriptionCategory]:
        query = (
            select(SubscriptionCategory)
            .where(SubscriptionCategory.user_id == user_id)
            .order_by(SubscriptionCategory.name)
        )
        result = await self.db.execute(query)
        return list(result.scalars().all())

    # ── Mutation methods ───────────────────────────────────────────────────

    async def create_subscription(
        self,
        user_id: int,
        sub_data: SubscriptionCreate,
    ) -> Subscription:
        from app.admin.models import SystemSettings
        from app.domains.subscription.models import UpdateFrequency

        update_frequency = UpdateFrequency.HOURLY.value
        update_time = None
        update_day_of_week = None

        settings_result = await self.db.execute(
            select(SystemSettings).where(SystemSettings.key == "rss.frequency_settings")
        )
        setting = settings_result.scalar_one_or_none()
        if setting and setting.value:
            update_frequency = setting.value.get(
                "update_frequency", UpdateFrequency.HOURLY.value
            )
            update_time = setting.value.get("update_time")
            update_day_of_week = setting.value.get("update_day_of_week")

        sub = Subscription(
            title=sub_data.title,
            description=sub_data.description,
            source_type=sub_data.source_type,
            source_url=sub_data.source_url,
            image_url=sub_data.image_url,
            config=sub_data.config,
            fetch_interval=sub_data.fetch_interval,
            status=SubscriptionStatus.ACTIVE,
        )
        self.db.add(sub)
        await self.db.flush()

        user_sub = UserSubscription(
            user_id=user_id,
            subscription_id=sub.id,
            update_frequency=update_frequency,
            update_time=update_time,
            update_day_of_week=update_day_of_week,
        )
        self.db.add(user_sub)

        await self.db.commit()
        await self.db.refresh(sub)
        return sub

    async def update_subscription(
        self,
        user_id: int,
        sub_id: int,
        sub_data: SubscriptionUpdate,
    ) -> Subscription | None:
        sub = await self.get_subscription_by_id(user_id, sub_id)
        if not sub:
            return None

        update_data = sub_data.model_dump(exclude_unset=True)
        for key, value in update_data.items():
            if key == "is_active":
                sub.status = SubscriptionStatus.INACTIVE if not value else SubscriptionStatus.ACTIVE
            else:
                setattr(sub, key, value)

        await self.db.commit()
        await self.db.refresh(sub)
        return sub

    async def delete_subscription(self, user_id: int, sub_id: int) -> bool:
        user_sub_query = select(UserSubscription).where(
            UserSubscription.user_id == user_id,
            UserSubscription.subscription_id == sub_id,
        )
        result = await self.db.execute(user_sub_query)
        user_sub = result.scalar_one_or_none()
        if not user_sub:
            return False

        await self.db.delete(user_sub)
        other_subs_query = select(func.count()).select_from(
            select(UserSubscription).where(UserSubscription.subscription_id == sub_id).subquery()
        )
        remaining_count = await self.db.scalar(other_subs_query) or 0
        if remaining_count == 0:
            sub_query = select(Subscription).where(Subscription.id == sub_id)
            sub_result = await self.db.execute(sub_query)
            sub = sub_result.scalar_one_or_none()
            if sub:
                await self.db.delete(sub)

        await self.db.commit()
        return True

    async def update_fetch_status(
        self,
        sub_id: int,
        status: str = SubscriptionStatus.ACTIVE,
        error_message: str | None = None,
        latest_published_at: datetime | None = None,
    ) -> Subscription | None:
        query = select(Subscription).where(Subscription.id == sub_id)
        result = await self.db.execute(query)
        sub = result.scalar_one_or_none()
        if not sub:
            return None

        sub.status = status
        sub.error_message = error_message
        sub.last_fetched_at = datetime.now(timezone.utc)
        if latest_published_at:
            sub.latest_item_published_at = latest_published_at

        await self.db.commit()
        await self.db.refresh(sub)
        return sub

    async def create_or_update_item(
        self,
        subscription_id: int,
        external_id: str,
        title: str,
        content: str | None = None,
        summary: str | None = None,
        author: str | None = None,
        source_url: str | None = None,
        image_url: str | None = None,
        tags: list[str] | None = None,
        metadata: dict | None = None,
        published_at: datetime | None = None,
    ) -> SubscriptionItem:
        query = select(SubscriptionItem).where(
            SubscriptionItem.subscription_id == subscription_id,
            SubscriptionItem.external_id == external_id,
        )
        result = await self.db.execute(query)
        item = result.scalar_one_or_none()
        if item:
            item.title = title
            item.content = content
            item.summary = summary
            item.author = author
            item.source_url = source_url
            item.image_url = image_url
            item.tags = tags or []
            item.metadata_json = metadata or {}
            item.published_at = published_at
        else:
            item = SubscriptionItem(
                subscription_id=subscription_id,
                external_id=external_id,
                title=title,
                content=content,
                summary=summary,
                author=author,
                source_url=source_url,
                image_url=image_url,
                tags=tags or [],
                metadata_json=metadata or {},
                published_at=published_at,
            )
            self.db.add(item)

        await self.db.commit()
        await self.db.refresh(item)
        return item

    async def mark_item_as_read(self, item_id: int, user_id: int) -> SubscriptionItem | None:
        item = await self.get_item_by_id(item_id, user_id)
        if not item:
            return None
        if not item.read_at:
            item.read_at = datetime.now(timezone.utc)
            await self.db.commit()
            await self.db.refresh(item)
        return item

    async def mark_item_as_unread(self, item_id: int, user_id: int) -> SubscriptionItem | None:
        item = await self.get_item_by_id(item_id, user_id)
        if not item:
            return None
        item.read_at = None
        await self.db.commit()
        await self.db.refresh(item)
        return item

    async def toggle_bookmark(self, item_id: int, user_id: int) -> SubscriptionItem | None:
        item = await self.get_item_by_id(item_id, user_id)
        if not item:
            return None
        item.bookmarked = not item.bookmarked
        await self.db.commit()
        await self.db.refresh(item)
        return item

    async def delete_item(self, item_id: int, user_id: int) -> bool:
        item = await self.get_item_by_id(item_id, user_id)
        if not item:
            return False
        await self.db.delete(item)
        await self.db.commit()
        return True

    async def create_category(
        self,
        user_id: int,
        name: str,
        description: str | None = None,
        color: str | None = None,
    ) -> SubscriptionCategory:
        category = SubscriptionCategory(
            user_id=user_id,
            name=name,
            description=description,
            color=color,
        )
        self.db.add(category)
        await self.db.commit()
        await self.db.refresh(category)
        return category

    async def update_category(
        self,
        category_id: int,
        user_id: int,
        **kwargs,
    ) -> SubscriptionCategory | None:
        category = await self.get_category_by_id(category_id, user_id)
        if not category:
            return None
        for key, value in kwargs.items():
            if hasattr(category, key) and value is not None:
                setattr(category, key, value)
        await self.db.commit()
        await self.db.refresh(category)
        return category

    async def delete_category(self, category_id: int, user_id: int) -> bool:
        category = await self.get_category_by_id(category_id, user_id)
        if not category:
            return False
        await self.db.delete(category)
        await self.db.commit()
        return True

    async def add_subscription_to_category(self, subscription_id: int, category_id: int) -> bool:
        query = select(SubscriptionCategoryMapping).where(
            SubscriptionCategoryMapping.subscription_id == subscription_id,
            SubscriptionCategoryMapping.category_id == category_id,
        )
        result = await self.db.execute(query)
        existing = result.scalar_one_or_none()
        if existing:
            return True

        mapping = SubscriptionCategoryMapping(
            subscription_id=subscription_id,
            category_id=category_id,
        )
        self.db.add(mapping)
        await self.db.commit()
        return True

    async def remove_subscription_from_category(self, subscription_id: int, category_id: int) -> bool:
        query = select(SubscriptionCategoryMapping).where(
            SubscriptionCategoryMapping.subscription_id == subscription_id,
            SubscriptionCategoryMapping.category_id == category_id,
        )
        result = await self.db.execute(query)
        mapping = result.scalar_one_or_none()
        if not mapping:
            return False
        await self.db.delete(mapping)
        await self.db.commit()
        return True
