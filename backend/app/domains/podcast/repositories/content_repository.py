"""Subscription repository (moved from domains/subscription)."""

from __future__ import annotations

from datetime import UTC, datetime

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.admin.settings_provider import DatabaseSettingsProvider
from app.domains.podcast.models import (
    Subscription,
    SubscriptionStatus,
    UpdateFrequency,
    UserSubscription,
)
from app.domains.podcast.schemas import SubscriptionCreate, SubscriptionUpdate
from app.shared.repository_helpers import resolve_window_total


class SubscriptionRepository:
    """Subscription data access layer."""

    def __init__(
        self,
        db: AsyncSession,
        settings_provider: DatabaseSettingsProvider | None = None,
    ):
        self.db = db
        self.settings_provider = settings_provider or DatabaseSettingsProvider()

    # ── Lookup helpers ─────────────────────────────────────────────────────

    async def get_subscription_by_id(
        self,
        user_id: int,
        sub_id: int,
    ) -> Subscription | None:
        query = (
            select(Subscription)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .where(
                Subscription.id == sub_id,
                UserSubscription.user_id == user_id,
                UserSubscription.is_archived.is_(False),
            )
        )
        result = await self.db.execute(query)
        return result.scalar_one_or_none()

    async def get_subscription_by_url(
        self,
        user_id: int,
        url: str,
    ) -> Subscription | None:
        query = select(Subscription).where(Subscription.source_url == url)
        result = await self.db.execute(query)
        return result.scalar_one_or_none()

    async def get_subscription_by_title(
        self,
        user_id: int,
        title: str,
    ) -> Subscription | None:
        query = (
            select(Subscription)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .where(
                UserSubscription.user_id == user_id,
                UserSubscription.is_archived.is_(False),
                func.lower(Subscription.title) == func.lower(title),
            )
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
            func.lower(Subscription.title) == func.lower(title),
        )
        result = await self.db.execute(query_title)
        return result.scalar_one_or_none()

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

        query = (
            base_query
            .add_columns(func.count(Subscription.id).over())
            .offset(skip)
            .limit(size)
            .order_by(Subscription.updated_at.desc())
        )
        result = await self.db.execute(query)
        rows = result.all()
        total = await resolve_window_total(
            self.db,
            rows,
            total_index=1,
            fallback_count_query=select(func.count()).select_from(
                base_query.subquery(),
            ),
        )
        items = [row[0] for row in rows]
        return items, total, {}

    # ── Mutation methods ───────────────────────────────────────────────────

    async def create_subscription(
        self,
        user_id: int,
        sub_data: SubscriptionCreate,
    ) -> Subscription:
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
                sub.status = (
                    SubscriptionStatus.INACTIVE
                    if not value
                    else SubscriptionStatus.ACTIVE
                )
            else:
                setattr(sub, key, value)

        await self.db.commit()
        return sub

    async def delete_subscription(self, user_id: int, sub_id: int) -> bool:
        from sqlalchemy import delete

        delete_user_sub_stmt = delete(UserSubscription).where(
            UserSubscription.user_id == user_id,
            UserSubscription.subscription_id == sub_id,
        )
        delete_result = await self.db.execute(delete_user_sub_stmt)
        deleted_count = int(delete_result.rowcount or 0)
        if deleted_count == 0:
            return False

        other_subs_query = (
            select(func.count())
            .select_from(UserSubscription)
            .where(
                UserSubscription.subscription_id == sub_id,
            )
        )
        remaining_count = await self.db.scalar(other_subs_query) or 0
        if remaining_count == 0:
            from sqlalchemy import delete as sa_delete

            await self.db.execute(sa_delete(Subscription).where(Subscription.id == sub_id))

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
        sub.last_fetched_at = datetime.now(UTC)
        if latest_published_at:
            sub.latest_item_published_at = latest_published_at

        await self.db.commit()
        return sub
