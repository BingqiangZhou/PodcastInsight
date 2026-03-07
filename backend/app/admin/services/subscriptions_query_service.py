"""Query-side helpers for admin subscription pages."""

from __future__ import annotations

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domains.subscription.models import (
    Subscription,
    SubscriptionStatus,
    UpdateFrequency,
    UserSubscription,
)
from app.domains.user.models import User


class AdminSubscriptionsQueryService:
    """Build admin subscription page context without mutating state."""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_page_context(
        self,
        *,
        page: int,
        per_page: int,
        status_filter: str | None,
        search_query: str | None,
        user_filter: str | None,
    ) -> dict:
        query = (
            select(
                Subscription, func.count(UserSubscription.id).label("subscriber_count")
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
            user_query = select(User.id).where(
                User.username.ilike(f"%{user_filter.strip()}%")
            )
            user_result = await self.db.execute(user_query)
            user_ids = [row[0] for row in user_result.fetchall()]
            if user_ids:
                query = query.where(UserSubscription.user_id.in_(user_ids))
            else:
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
            .offset(offset)
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
                    )
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
            .limit(1)
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
