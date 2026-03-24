"""Podcast schedule service.

Handles user-specific schedule settings for podcast subscriptions.
"""

from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domains.podcast.schedule_projections import ScheduleConfigProjection
from app.domains.subscription.models import Subscription, UserSubscription


class PodcastScheduleService:
    """Service for querying and updating podcast subscription schedules."""

    def __init__(self, db: AsyncSession, user_id: int):
        self.db = db
        self.user_id = user_id

    def _build_schedule_projection(
        self,
        subscription: Subscription,
        user_sub: UserSubscription,
    ) -> ScheduleConfigProjection:
        return ScheduleConfigProjection(
            id=subscription.id,
            title=subscription.title,
            update_frequency=user_sub.update_frequency,
            update_time=user_sub.update_time,
            update_day_of_week=user_sub.update_day_of_week,
            fetch_interval=subscription.fetch_interval,
            next_update_at=user_sub.computed_next_update_at,
            last_updated_at=subscription.last_fetched_at,
        )

    async def get_subscription_schedule(
        self,
        subscription_id: int,
    ) -> ScheduleConfigProjection | None:
        """Get schedule settings for a specific subscription."""
        stmt = (
            select(Subscription, UserSubscription)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .where(
                Subscription.id == subscription_id,
                UserSubscription.user_id == self.user_id,
            )
        )
        result = await self.db.execute(stmt)
        row = result.first()
        if not row:
            return None

        subscription, user_sub = row
        return self._build_schedule_projection(subscription, user_sub)

    async def update_subscription_schedule(
        self,
        subscription_id: int,
        update_frequency: str | None,
        update_time: str | None,
        update_day_of_week: int | None,
        fetch_interval: int | None,
    ) -> ScheduleConfigProjection | None:
        """Update schedule settings for a specific subscription."""
        stmt = (
            select(Subscription, UserSubscription)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .where(
                Subscription.id == subscription_id,
                UserSubscription.user_id == self.user_id,
            )
        )
        result = await self.db.execute(stmt)
        row = result.first()
        if not row:
            return None

        subscription, user_sub = row
        user_sub.update_frequency = update_frequency
        user_sub.update_time = update_time
        user_sub.update_day_of_week = update_day_of_week

        if fetch_interval is not None:
            subscription.fetch_interval = fetch_interval

        await self.db.commit()
        # No refresh needed - subscription and user_sub are already in session with updated values

        return self._build_schedule_projection(subscription, user_sub)

    async def get_all_subscription_schedules(self) -> list[ScheduleConfigProjection]:
        """Get schedule settings for all user podcast subscriptions."""
        stmt = (
            select(Subscription, UserSubscription)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .where(
                and_(
                    UserSubscription.user_id == self.user_id,
                    UserSubscription.is_archived == False,  # noqa: E712
                    Subscription.source_type.in_(["podcast-rss", "rss"]),
                ),
            )
            .order_by(Subscription.created_at)
        )
        result = await self.db.execute(stmt)
        rows = list(result.all())
        return [
            self._build_schedule_projection(sub, user_sub) for sub, user_sub in rows
        ]

    async def batch_update_subscription_schedules(
        self,
        subscription_ids: list[int],
        update_frequency: str | None,
        update_time: str | None,
        update_day_of_week: int | None,
        fetch_interval: int | None,
    ) -> list[ScheduleConfigProjection]:
        """Batch update schedule settings for multiple subscriptions."""
        stmt = (
            select(Subscription, UserSubscription)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .where(
                and_(
                    Subscription.id.in_(subscription_ids),
                    UserSubscription.user_id == self.user_id,
                    UserSubscription.is_archived == False,  # noqa: E712
                    Subscription.source_type.in_(["podcast-rss", "rss"]),
                ),
            )
        )
        result = await self.db.execute(stmt)
        rows = list(result.all())

        updated_rows: list[tuple[Subscription, UserSubscription]] = []
        for sub, user_sub in rows:
            user_sub.update_frequency = update_frequency
            user_sub.update_time = update_time
            user_sub.update_day_of_week = update_day_of_week
            if fetch_interval is not None:
                sub.fetch_interval = fetch_interval
            updated_rows.append((sub, user_sub))

        await self.db.commit()
        # No refresh needed - sub and user_sub are already in session with updated values

        return [
            self._build_schedule_projection(sub, user_sub)
            for sub, user_sub in updated_rows
        ]
