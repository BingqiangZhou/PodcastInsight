"""Analytics and search repository mixin."""

import logging
from datetime import date, datetime, timedelta, timezone
from inspect import isawaitable
from typing import Any

from sqlalchemy import and_, case, desc, func, or_, select
from sqlalchemy.exc import DBAPIError
from sqlalchemy.orm import joinedload

from app.core.datetime_utils import sanitize_published_date
from app.domains.podcast.models import (
    PodcastDailyReport,
    PodcastEpisode,
    PodcastPlaybackState,
)
from app.domains.subscription.models import Subscription, UserSubscription


logger = logging.getLogger(__name__)


class PodcastAnalyticsRepositoryMixin:
    """Search, recent activity, and aggregated stats."""

    async def search_episodes(
        self,
        user_id: int,
        query: str,
        search_in: str = "all",
        page: int = 1,
        size: int = 20,
    ) -> tuple[list[PodcastEpisode], int]:
        keyword = query.strip()
        if not keyword:
            return [], 0

        like_pattern = f"%{keyword}%"
        bind: Any = None
        try:
            bind = self.db.get_bind()
            if isawaitable(bind):
                bind = await bind
        except Exception:
            bind = getattr(self.db, "bind", None)
        is_postgresql = bool(bind and bind.dialect.name == "postgresql")

        def _coalesced_text(column: Any) -> Any:
            return func.coalesce(column, "")

        def _build_text_match_condition(column: Any, enable_pg_trgm: bool) -> Any:
            coalesced = _coalesced_text(column)
            ilike_condition = coalesced.ilike(like_pattern)
            if not enable_pg_trgm:
                return ilike_condition
            return or_(coalesced.op("%")(keyword), ilike_condition)

        def _build_relevance_term(
            column: Any, weight: float, enable_pg_trgm: bool
        ) -> Any:
            coalesced = _coalesced_text(column)
            if enable_pg_trgm:
                return func.similarity(coalesced, keyword) * weight
            return case((coalesced.ilike(like_pattern), weight), else_=0.0)

        async def _execute_search(
            enable_pg_trgm: bool,
        ) -> tuple[list[PodcastEpisode], int]:
            search_conditions: list[Any] = []
            relevance_terms: list[Any] = []

            if search_in in {"title", "all"}:
                search_conditions.append(
                    _build_text_match_condition(PodcastEpisode.title, enable_pg_trgm)
                )
                relevance_terms.append(
                    _build_relevance_term(PodcastEpisode.title, 1.0, enable_pg_trgm)
                )
            if search_in in {"description", "all"}:
                search_conditions.append(
                    _build_text_match_condition(
                        PodcastEpisode.description, enable_pg_trgm
                    )
                )
                relevance_terms.append(
                    _build_relevance_term(
                        PodcastEpisode.description, 0.7, enable_pg_trgm
                    )
                )
            if search_in in {"summary", "all"}:
                search_conditions.append(
                    _build_text_match_condition(
                        PodcastEpisode.ai_summary, enable_pg_trgm
                    )
                )
                relevance_terms.append(
                    _build_relevance_term(
                        PodcastEpisode.ai_summary, 0.9, enable_pg_trgm
                    )
                )

            if not search_conditions:
                search_conditions.append(
                    _build_text_match_condition(PodcastEpisode.title, enable_pg_trgm)
                )
                relevance_terms.append(
                    _build_relevance_term(PodcastEpisode.title, 1.0, enable_pg_trgm)
                )

            relevance_score = relevance_terms[0]
            for term in relevance_terms[1:]:
                relevance_score = relevance_score + term
            relevance_score = relevance_score.label("relevance_score")

            base_query = (
                select(PodcastEpisode, relevance_score)
                .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
                .join(
                    UserSubscription,
                    UserSubscription.subscription_id == Subscription.id,
                )
                .options(joinedload(PodcastEpisode.subscription))
                .where(
                    and_(
                        *self._active_user_subscription_filters(user_id),
                        or_(*search_conditions),
                    )
                )
            )

            paged_query = (
                base_query.add_columns(
                    func.count(PodcastEpisode.id).over().label("total_count")
                )
                .order_by(
                    desc(relevance_score),
                    desc(PodcastEpisode.published_at),
                    desc(PodcastEpisode.id),
                )
                .offset((page - 1) * size)
                .limit(size)
            )
            result = await self.db.execute(paged_query)
            rows = list(result.unique().all())
            if rows:
                total = int(rows[0][2] or 0)
            else:
                total = int(
                    await self.db.scalar(
                        select(func.count()).select_from(base_query.subquery())
                    )
                    or 0
                )

            episodes: list[PodcastEpisode] = []
            for episode, score, _ in rows:
                try:
                    episode.relevance_score = float(score or 0.0)
                except Exception:
                    episode.relevance_score = 0.0
                episodes.append(episode)
            return episodes, total

        try:
            return await _execute_search(enable_pg_trgm=is_postgresql)
        except DBAPIError as exc:
            message = str(getattr(exc, "orig", exc)).lower()
            pg_trgm_error = (
                "similarity(" in message
                or "operator does not exist" in message
                or "pg_trgm" in message
            )
            if is_postgresql and pg_trgm_error:
                logger.warning(
                    "pg_trgm unavailable for search query; fallback to ILIKE path: %s",
                    exc,
                )
                await self.db.rollback()
                return await _execute_search(enable_pg_trgm=False)
            raise

    async def update_subscription_fetch_time(
        self, subscription_id: int, fetch_time: datetime | None = None
    ):
        stmt = select(Subscription).where(Subscription.id == subscription_id)
        result = await self.db.execute(stmt)
        subscription = result.scalar_one_or_none()

        if subscription:
            time_to_set = sanitize_published_date(
                fetch_time or datetime.now(timezone.utc)
            )
            subscription.last_fetched_at = time_to_set
            await self.db.commit()

    async def update_subscription_metadata(self, subscription_id: int, metadata: dict):
        stmt = select(Subscription).where(Subscription.id == subscription_id)
        result = await self.db.execute(stmt)
        subscription = result.scalar_one_or_none()

        if subscription:
            current_config = dict(subscription.config or {})
            current_config.update(metadata)
            subscription.config = current_config
            from sqlalchemy.orm import attributes

            attributes.flag_modified(subscription, "config")
            subscription.updated_at = datetime.now(timezone.utc)
            await self.db.commit()

    async def get_recently_played(
        self, user_id: int, limit: int = 5
    ) -> list[dict[str, Any]]:
        stmt = (
            select(
                PodcastEpisode,
                PodcastPlaybackState.current_position,
                PodcastPlaybackState.last_updated_at,
            )
            .join(PodcastPlaybackState)
            .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .options(joinedload(PodcastEpisode.subscription))
            .where(
                and_(
                    *self._active_user_subscription_filters(user_id),
                    PodcastPlaybackState.last_updated_at
                    >= datetime.now(timezone.utc) - timedelta(days=7),
                )
            )
            .order_by(PodcastPlaybackState.last_updated_at.desc())
            .limit(limit)
        )

        result = await self.db.execute(stmt)
        rows = result.unique().all()
        recently_played = []
        for episode, position, last_played in rows:
            sub_title = episode.subscription.title if episode.subscription else None
            recently_played.append(
                {
                    "episode_id": episode.id,
                    "title": episode.title,
                    "subscription_title": sub_title,
                    "position": position,
                    "last_played": last_played,
                    "duration": episode.audio_duration,
                }
            )
        return recently_played

    async def get_liked_episodes(
        self, user_id: int, limit: int = 20
    ) -> list[PodcastEpisode]:
        stmt = (
            select(PodcastEpisode)
            .join(PodcastPlaybackState)
            .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .where(
                and_(
                    *self._active_user_subscription_filters(user_id),
                    PodcastEpisode.audio_duration > 0,
                    PodcastPlaybackState.current_position
                    >= PodcastEpisode.audio_duration * 0.8,
                )
            )
            .order_by(PodcastPlaybackState.play_count.desc())
            .limit(limit)
        )

        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def get_recent_play_dates(self, user_id: int, days: int = 30) -> set[date]:
        stmt = (
            select(PodcastPlaybackState.last_updated_at)
            .where(
                and_(
                    PodcastPlaybackState.user_id == user_id,
                    PodcastPlaybackState.last_updated_at
                    >= datetime.now(timezone.utc) - timedelta(days=days),
                )
            )
            .distinct()
        )

        result = await self.db.execute(stmt)
        dates = set()
        for (last_updated,) in result:
            dates.add(last_updated.date())
        return dates

    def _subscription_count_stmt(self, user_id: int) -> Any:
        return (
            select(func.count(Subscription.id))
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .where(and_(*self._active_user_subscription_filters(user_id)))
        )

    def _episode_stats_stmt(
        self,
        user_id: int,
        *,
        include_played_episodes: bool = False,
        include_total_playtime: bool = False,
    ) -> Any:
        columns: list[Any] = [
            func.count(PodcastEpisode.id).label("total_episodes"),
            func.sum(case((PodcastEpisode.ai_summary.isnot(None), 1), else_=0)).label(
                "summaries_generated"
            ),
            func.sum(case((PodcastEpisode.ai_summary.is_(None), 1), else_=0)).label(
                "pending_summaries"
            ),
        ]

        if include_played_episodes:
            columns.append(
                func.count(func.distinct(PodcastPlaybackState.episode_id)).label(
                    "played_episodes"
                )
            )
        if include_total_playtime:
            columns.append(
                func.coalesce(func.sum(PodcastPlaybackState.current_position), 0).label(
                    "total_playtime"
                )
            )

        return select(*columns).select_from(
            PodcastEpisode.__table__.join(
                Subscription.__table__,
                PodcastEpisode.subscription_id == Subscription.id,
            )
            .join(
                UserSubscription.__table__,
                and_(
                    UserSubscription.subscription_id == Subscription.id,
                    *self._active_user_subscription_filters(user_id),
                ),
            )
            .outerjoin(
                PodcastPlaybackState.__table__,
                and_(
                    PodcastPlaybackState.episode_id == PodcastEpisode.id,
                    PodcastPlaybackState.user_id == user_id,
                ),
            )
        )

    async def get_profile_stats_aggregated(self, user_id: int) -> dict[str, Any]:
        total_subscriptions = (
            await self.db.scalar(self._subscription_count_stmt(user_id)) or 0
        )
        episode_stats_result = await self.db.execute(
            self._episode_stats_stmt(user_id, include_played_episodes=True)
        )
        episode_stats = episode_stats_result.one()

        latest_report_stmt = (
            select(PodcastDailyReport.report_date)
            .where(PodcastDailyReport.user_id == user_id)
            .order_by(PodcastDailyReport.report_date.desc())
            .limit(1)
        )
        latest_report_result = await self.db.execute(latest_report_stmt)
        latest_report_date = latest_report_result.scalar_one_or_none()

        return {
            "total_subscriptions": total_subscriptions,
            "total_episodes": episode_stats.total_episodes or 0,
            "summaries_generated": episode_stats.summaries_generated or 0,
            "pending_summaries": episode_stats.pending_summaries or 0,
            "played_episodes": episode_stats.played_episodes or 0,
            "latest_daily_report_date": latest_report_date.isoformat()
            if latest_report_date
            else None,
        }

    async def get_user_stats_aggregated(self, user_id: int) -> dict[str, Any]:
        total_subscriptions = (
            await self.db.scalar(self._subscription_count_stmt(user_id)) or 0
        )
        episode_stats_result = await self.db.execute(
            self._episode_stats_stmt(user_id, include_total_playtime=True)
        )
        episode_stats = episode_stats_result.one()

        active_check_stmt = (
            select(func.count(Subscription.id))
            .join(UserSubscription, UserSubscription.subscription_id == Subscription.id)
            .where(
                and_(
                    *self._active_user_subscription_filters(user_id),
                    Subscription.status == "active",
                )
            )
        )
        active_check_result = await self.db.execute(active_check_stmt)
        has_active_plus = (active_check_result.scalar() or 0) > 0

        return {
            "total_subscriptions": total_subscriptions,
            "total_episodes": episode_stats.total_episodes or 0,
            "total_playtime": episode_stats.total_playtime or 0,
            "summaries_generated": episode_stats.summaries_generated or 0,
            "pending_summaries": episode_stats.pending_summaries or 0,
            "has_active_plus": has_active_plus,
        }
