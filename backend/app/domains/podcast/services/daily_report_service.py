"""Daily report service for podcast episode updates."""

from __future__ import annotations

import logging
from datetime import UTC, date, datetime, time, timedelta
from typing import TYPE_CHECKING
from zoneinfo import ZoneInfo

from sqlalchemy import and_, delete, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.domains.podcast.models import (
    PodcastDailyReport,
    PodcastDailyReportItem,
    PodcastEpisode,
)
from app.domains.podcast.services.daily_report_summary_extractor import (
    extract_one_line_summary,
)
from app.domains.subscription.models import Subscription, UserSubscription


if TYPE_CHECKING:
    pass


logger = logging.getLogger(__name__)


class DailyReportService:
    """Generate and query daily report snapshots for one user."""

    REPORT_TIMEZONE = "Asia/Shanghai"
    REPORT_SCHEDULE_TIME = "03:30"

    def __init__(
        self,
        db: AsyncSession,
        user_id: int,
        task_orchestration_service_factory=None,
    ):
        self.db = db
        self.user_id = user_id
        self._task_orchestration_service_factory = task_orchestration_service_factory

    def _task_orchestration_service(self):
        factory = self._task_orchestration_service_factory
        if factory is None:
            from app.domains.podcast.services.task_orchestration_service import (
                PodcastTaskOrchestrationService,
            )

            factory = PodcastTaskOrchestrationService
        return factory(self.db)

    async def generate_daily_report(
        self,
        target_date: date | None = None,
        *,
        rebuild: bool = False,
    ) -> dict:
        """Generate (or update) report snapshot for a report date."""
        report_date = self._resolve_report_date(target_date)
        window_start_utc, window_end_utc = self._compute_window_utc(report_date)
        now_utc = datetime.now(UTC)

        report = await self._get_or_create_report(report_date, now_utc)
        if rebuild:
            await self._clear_report_items(report.id)

        window_summarized = await self._list_window_summarized_episodes(
            window_start_utc,
            window_end_utc,
        )
        window_unsummarized = await self._list_window_unsummarized_episodes(
            window_start_utc,
            window_end_utc,
        )

        for episode in window_unsummarized:
            await self._trigger_episode_processing(episode.id)

        added_count = 0
        for episode in window_summarized:
            added_count += await self._append_item_if_needed(
                report,
                episode,
                is_carryover=False,
            )

        report.generated_at = now_utc
        report.total_items = await self._count_report_items(report.id)
        await self.db.commit()

        logger.info(
            "Generated daily report for user=%s report_date=%s added=%s total=%s",
            self.user_id,
            report_date,
            added_count,
            report.total_items,
        )
        return await self.get_daily_report(report_date)

    async def get_daily_report(self, target_date: date | None = None) -> dict:
        """Get one report by date; default to latest available."""
        report = await self._load_report(target_date)
        if report is None:
            return {
                "available": False,
                "report_date": None,
                "timezone": self.REPORT_TIMEZONE,
                "schedule_time_local": self.REPORT_SCHEDULE_TIME,
                "generated_at": None,
                "total_items": 0,
                "items": [],
            }

        sorted_items = sorted(report.items, key=lambda item: item.id)
        return {
            "available": True,
            "report_date": report.report_date,
            "timezone": report.timezone,
            "schedule_time_local": report.schedule_time_local,
            "generated_at": report.generated_at,
            "total_items": report.total_items,
            "items": [
                {
                    "episode_id": item.episode_id,
                    "subscription_id": item.subscription_id,
                    "episode_title": item.episode_title_snapshot,
                    "subscription_title": item.subscription_title_snapshot,
                    "one_line_summary": item.one_line_summary,
                    "is_carryover": item.is_carryover,
                    "episode_created_at": item.episode_created_at,
                    "episode_published_at": item.episode_published_at,
                }
                for item in sorted_items
            ],
        }

    async def list_report_dates(self, page: int = 1, size: int = 30) -> dict:
        """List report dates for history date selector."""
        safe_page = max(1, page)
        safe_size = min(max(1, size), 100)

        base_stmt = select(PodcastDailyReport).where(
            PodcastDailyReport.user_id == self.user_id
        )
        count_stmt = select(func.count()).select_from(base_stmt.subquery())
        total = (await self.db.execute(count_stmt)).scalar() or 0

        stmt = (
            base_stmt.order_by(PodcastDailyReport.report_date.desc())
            .offset((safe_page - 1) * safe_size)
            .limit(safe_size)
        )
        rows = (await self.db.execute(stmt)).scalars().all()
        pages = (total + safe_size - 1) // safe_size if total else 0

        return {
            "dates": [
                {
                    "report_date": row.report_date,
                    "total_items": row.total_items,
                    "generated_at": row.generated_at,
                }
                for row in rows
            ],
            "total": total,
            "page": safe_page,
            "size": safe_size,
            "pages": pages,
        }

    def _resolve_report_date(self, target_date: date | None) -> date:
        if target_date is not None:
            return target_date
        tz = ZoneInfo(self.REPORT_TIMEZONE)
        return (datetime.now(tz).date() - timedelta(days=1))

    def _compute_window_utc(self, report_date: date) -> tuple[datetime, datetime]:
        tz = ZoneInfo(self.REPORT_TIMEZONE)
        start_local = datetime.combine(report_date, time.min, tzinfo=tz)
        end_local = start_local + timedelta(days=1)
        return start_local.astimezone(UTC), end_local.astimezone(UTC)

    async def _get_or_create_report(
        self,
        report_date: date,
        now_utc: datetime,
    ) -> PodcastDailyReport:
        stmt = select(PodcastDailyReport).where(
            and_(
                PodcastDailyReport.user_id == self.user_id,
                PodcastDailyReport.report_date == report_date,
            )
        )
        report = (await self.db.execute(stmt)).scalar_one_or_none()
        if report is not None:
            return report

        report = PodcastDailyReport(
            user_id=self.user_id,
            report_date=report_date,
            timezone=self.REPORT_TIMEZONE,
            schedule_time_local=self.REPORT_SCHEDULE_TIME,
            generated_at=now_utc,
            total_items=0,
        )
        self.db.add(report)
        await self.db.flush()
        return report

    def _base_user_episode_stmt(self):
        return (
            select(PodcastEpisode)
            .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
            .join(
                UserSubscription,
                UserSubscription.subscription_id == Subscription.id,
            )
            .options(selectinload(PodcastEpisode.subscription))
            .where(
                and_(
                    UserSubscription.user_id == self.user_id,
                    UserSubscription.is_archived == False,  # noqa: E712
                    Subscription.source_type == "podcast-rss",
                    Subscription.status == "active",
                )
            )
        )

    def _has_summary_expr(self):
        return and_(
            PodcastEpisode.ai_summary.isnot(None),
            func.length(func.trim(PodcastEpisode.ai_summary)) > 0,
        )

    def _missing_summary_expr(self):
        return and_(
            PodcastEpisode.ai_summary.isnot(None),
            func.length(func.trim(PodcastEpisode.ai_summary)) == 0,
        )

    async def _list_window_summarized_episodes(
        self,
        window_start_utc: datetime,
        window_end_utc: datetime,
    ) -> list[PodcastEpisode]:
        reported_exists = (
            select(PodcastDailyReportItem.id)
            .where(
                and_(
                    PodcastDailyReportItem.user_id == self.user_id,
                    PodcastDailyReportItem.episode_id == PodcastEpisode.id,
                )
            )
            .exists()
        )

        stmt = (
            self._base_user_episode_stmt()
            .where(
                and_(
                    PodcastEpisode.published_at >= window_start_utc,
                    PodcastEpisode.published_at < window_end_utc,
                    self._has_summary_expr(),
                    ~reported_exists,
                )
            )
            .order_by(PodcastEpisode.published_at.asc())
        )
        return list((await self.db.execute(stmt)).scalars().all())

    async def _list_window_unsummarized_episodes(
        self,
        window_start_utc: datetime,
        window_end_utc: datetime,
    ) -> list[PodcastEpisode]:
        stmt = (
            self._base_user_episode_stmt()
            .where(
                and_(
                    PodcastEpisode.published_at >= window_start_utc,
                    PodcastEpisode.published_at < window_end_utc,
                    or_(
                        PodcastEpisode.ai_summary.is_(None),
                        self._missing_summary_expr(),
                    ),
                )
            )
            .order_by(PodcastEpisode.published_at.asc())
        )
        return list((await self.db.execute(stmt)).scalars().all())

    async def _append_item_if_needed(
        self,
        report: PodcastDailyReport,
        episode: PodcastEpisode,
        is_carryover: bool,
    ) -> int:
        existing_stmt = select(PodcastDailyReportItem.id).where(
            and_(
                PodcastDailyReportItem.user_id == self.user_id,
                PodcastDailyReportItem.episode_id == episode.id,
            )
        )
        existing_id = (await self.db.execute(existing_stmt)).scalar_one_or_none()
        if existing_id is not None:
            return 0

        summary_line = extract_one_line_summary(episode.ai_summary)
        if not summary_line:
            return 0

        item = PodcastDailyReportItem(
            report_id=report.id,
            user_id=self.user_id,
            episode_id=episode.id,
            subscription_id=episode.subscription_id,
            episode_title_snapshot=episode.title,
            subscription_title_snapshot=episode.subscription.title
            if episode.subscription
            else None,
            one_line_summary=summary_line,
            is_carryover=is_carryover,
            episode_created_at=episode.created_at,
            episode_published_at=episode.published_at,
        )
        self.db.add(item)
        await self.db.flush()
        return 1

    async def _clear_report_items(self, report_id: int) -> None:
        stmt = delete(PodcastDailyReportItem).where(
            PodcastDailyReportItem.report_id == report_id
        )
        await self.db.execute(stmt)
        await self.db.flush()

    async def _count_report_items(self, report_id: int) -> int:
        stmt = select(func.count(PodcastDailyReportItem.id)).where(
            PodcastDailyReportItem.report_id == report_id
        )
        return (await self.db.execute(stmt)).scalar() or 0

    async def _load_report(self, target_date: date | None) -> PodcastDailyReport | None:
        if target_date is None:
            stmt = (
                select(PodcastDailyReport)
                .options(selectinload(PodcastDailyReport.items))
                .where(PodcastDailyReport.user_id == self.user_id)
                .order_by(PodcastDailyReport.report_date.desc())
                .limit(1)
            )
            return (await self.db.execute(stmt)).scalar_one_or_none()

        stmt = (
            select(PodcastDailyReport)
            .options(selectinload(PodcastDailyReport.items))
            .where(
                and_(
                    PodcastDailyReport.user_id == self.user_id,
                    PodcastDailyReport.report_date == target_date,
                )
            )
            .limit(1)
        )
        return (await self.db.execute(stmt)).scalar_one_or_none()

    async def _trigger_episode_processing(self, episode_id: int) -> None:
        try:
            self._task_orchestration_service().enqueue_episode_processing(
                episode_id=episode_id,
                user_id=self.user_id,
            )
        except Exception as exc:
            logger.warning(
                "Failed to dispatch transcription/summary pipeline for episode=%s user=%s: %s",
                episode_id,
                self.user_id,
                exc,
            )
