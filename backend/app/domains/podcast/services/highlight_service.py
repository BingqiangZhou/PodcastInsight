"""Highlight service for podcast episode insights."""

from __future__ import annotations

import logging
from datetime import date

from sqlalchemy import and_, desc, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.domains.podcast.models import (
    EpisodeHighlight,
    PodcastEpisode,
)
from app.domains.subscription.models import Subscription, UserSubscription


logger = logging.getLogger(__name__)


class HighlightService:
    """Service for managing podcast episode highlights."""

    def __init__(
        self,
        db: AsyncSession,
        user_id: int,
    ):
        self.db = db
        self.user_id = user_id

    async def get_highlights(
        self,
        page: int = 1,
        per_page: int = 20,
        episode_id: int | None = None,
        min_score: float | None = None,
        date_from: date | None = None,
        date_to: date | None = None,
        favorited_only: bool = False,
    ) -> dict:
        """Get highlights with pagination and filtering."""
        # Build base query - only highlights from user's subscriptions
        base_query = (
            select(EpisodeHighlight)
            .join(PodcastEpisode, EpisodeHighlight.episode_id == PodcastEpisode.id)
            .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
            .join(UserSubscription, Subscription.id == UserSubscription.subscription_id)
            .where(
                and_(
                    UserSubscription.user_id == self.user_id,
                    EpisodeHighlight.status == "active",
                )
            )
        )

        # Apply filters
        if episode_id is not None:
            base_query = base_query.where(EpisodeHighlight.episode_id == episode_id)

        if min_score is not None:
            base_query = base_query.where(EpisodeHighlight.overall_score >= min_score)

        if date_from is not None:
            base_query = base_query.where(
                func.date(EpisodeHighlight.created_at) >= date_from
            )

        if date_to is not None:
            base_query = base_query.where(
                func.date(EpisodeHighlight.created_at) <= date_to
            )

        if favorited_only:
            base_query = base_query.where(EpisodeHighlight.is_user_favorited)

        # Get total count
        count_query = select(func.count()).select_from(base_query.subquery())
        total_result = await self.db.execute(count_query)
        total = total_result.scalar() or 0

        # Get paginated results with eager loading
        query = (
            base_query
            .options(
                selectinload(EpisodeHighlight.episode).selectinload(
                    PodcastEpisode.subscription
                )
            )
            .order_by(desc(EpisodeHighlight.overall_score))
            .offset((page - 1) * per_page)
            .limit(per_page)
        )

        result = await self.db.execute(query)
        highlights = result.scalars().all()

        # Build response items
        items = []
        for highlight in highlights:
            episode = highlight.episode
            subscription = episode.subscription if episode else None

            items.append({
                "id": highlight.id,
                "episode_id": highlight.episode_id,
                "episode_title": episode.title if episode else "Unknown Episode",
                "subscription_title": subscription.title if subscription else None,
                "original_text": highlight.original_text,
                "context_before": highlight.context_before,
                "context_after": highlight.context_after,
                "insight_score": highlight.insight_score,
                "novelty_score": highlight.novelty_score,
                "actionability_score": highlight.actionability_score,
                "overall_score": highlight.overall_score,
                "speaker_hint": highlight.speaker_hint,
                "timestamp_hint": highlight.timestamp_hint,
                "topic_tags": highlight.topic_tags or [],
                "is_user_favorited": highlight.is_user_favorited,
                "created_at": highlight.created_at,
            })

        has_more = page * per_page < total

        return {
            "items": items,
            "total": total,
            "page": page,
            "per_page": per_page,
            "has_more": has_more,
        }

    async def get_highlight_dates(self) -> dict:
        """Get list of dates that have highlights for calendar component."""
        # Query for distinct dates where user has highlights
        query = (
            select(func.date(EpisodeHighlight.created_at).label("highlight_date"))
            .join(PodcastEpisode, EpisodeHighlight.episode_id == PodcastEpisode.id)
            .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
            .join(UserSubscription, Subscription.id == UserSubscription.subscription_id)
            .where(
                and_(
                    UserSubscription.user_id == self.user_id,
                    EpisodeHighlight.status == "active",
                )
            )
            .distinct()
            .order_by(desc("highlight_date"))
        )

        result = await self.db.execute(query)
        dates = [row[0] for row in result.all()]

        return {"dates": dates}

    async def get_stats(self) -> dict:
        """Get highlight statistics for Profile card."""
        # Count total highlights
        count_query = (
            select(func.count(EpisodeHighlight.id))
            .join(PodcastEpisode, EpisodeHighlight.episode_id == PodcastEpisode.id)
            .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
            .join(UserSubscription, Subscription.id == UserSubscription.subscription_id)
            .where(
                and_(
                    UserSubscription.user_id == self.user_id,
                    EpisodeHighlight.status == "active",
                )
            )
        )
        count_result = await self.db.execute(count_query)
        total_highlights = count_result.scalar() or 0

        # Calculate average score
        avg_query = (
            select(func.avg(EpisodeHighlight.overall_score))
            .join(PodcastEpisode, EpisodeHighlight.episode_id == PodcastEpisode.id)
            .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
            .join(UserSubscription, Subscription.id == UserSubscription.subscription_id)
            .where(
                and_(
                    UserSubscription.user_id == self.user_id,
                    EpisodeHighlight.status == "active",
                )
            )
        )
        avg_result = await self.db.execute(avg_query)
        avg_score = avg_result.scalar() or 0.0

        # Get latest extraction date
        latest_query = (
            select(func.max(EpisodeHighlight.created_at))
            .join(PodcastEpisode, EpisodeHighlight.episode_id == PodcastEpisode.id)
            .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
            .join(UserSubscription, Subscription.id == UserSubscription.subscription_id)
            .where(
                and_(
                    UserSubscription.user_id == self.user_id,
                    EpisodeHighlight.status == "active",
                )
            )
        )
        latest_result = await self.db.execute(latest_query)
        latest_created_at = latest_result.scalar()

        latest_extraction_date = None
        if latest_created_at:
            latest_extraction_date = latest_created_at.date()

        return {
            "total_highlights": total_highlights,
            "avg_score": round(avg_score, 2),
            "latest_extraction_date": latest_extraction_date,
        }

    async def toggle_favorite(
        self,
        highlight_id: int,
        favorited: bool,
    ) -> dict:
        """Toggle favorite status for a highlight."""
        # Get highlight with ownership check
        query = (
            select(EpisodeHighlight)
            .join(PodcastEpisode, EpisodeHighlight.episode_id == PodcastEpisode.id)
            .join(Subscription, PodcastEpisode.subscription_id == Subscription.id)
            .join(UserSubscription, Subscription.id == UserSubscription.subscription_id)
            .where(
                and_(
                    EpisodeHighlight.id == highlight_id,
                    UserSubscription.user_id == self.user_id,
                    EpisodeHighlight.status == "active",
                )
            )
        )

        result = await self.db.execute(query)
        highlight = result.scalar_one_or_none()

        if not highlight:
            return {
                "success": False,
                "message": "Highlight not found or access denied",
                "message_en": "Highlight not found or access denied",
                "message_zh": "高光观点未找到或无权访问",
            }

        # Update favorite status
        highlight.is_user_favorited = favorited
        await self.db.commit()

        return {
            "success": True,
            "id": highlight.id,
            "is_user_favorited": highlight.is_user_favorited,
        }
