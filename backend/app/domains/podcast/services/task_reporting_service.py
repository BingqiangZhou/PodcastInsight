"""Task orchestration helpers for reporting flows."""

from __future__ import annotations

import logging
from datetime import datetime, timezone

from sqlalchemy import and_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domains.podcast.services.daily_report_service import DailyReportService
from app.domains.subscription.models import (
    Subscription,
    SubscriptionStatus,
    UserSubscription,
)


logger = logging.getLogger(__name__)


class PodcastTaskReportingService:
    """Handle background daily report generation."""

    def __init__(self, session: AsyncSession):
        self.session = session

    async def generate_daily_reports(self, *, target_date=None) -> dict:
        users_stmt = (
            select(UserSubscription.user_id)
            .join(Subscription, UserSubscription.subscription_id == Subscription.id)
            .where(
                and_(
                    Subscription.source_type == "podcast-rss",
                    Subscription.status == SubscriptionStatus.ACTIVE.value,
                    UserSubscription.is_archived == False,  # noqa: E712
                )
            )
            .distinct()
        )
        user_ids = list((await self.session.execute(users_stmt)).scalars().all())

        success_count = 0
        failed_count = 0
        for user_id in user_ids:
            try:
                service = DailyReportService(self.session, user_id=user_id)
                await service.generate_daily_report(target_date=target_date)
                success_count += 1
            except Exception:
                failed_count += 1
                logger.exception("Failed to generate daily report for user=%s", user_id)
                await self.session.rollback()

        return {
            "status": "success",
            "processed_users": len(user_ids),
            "successful_users": success_count,
            "failed_users": failed_count,
            "report_date": target_date.isoformat() if target_date else None,
            "processed_at": datetime.now(timezone.utc).isoformat(),
        }
