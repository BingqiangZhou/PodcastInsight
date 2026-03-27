"""Podcast highlights API routes."""

from datetime import date

from fastapi import APIRouter, Depends, Query

from app.core.providers import get_highlight_service
from app.domains.podcast.api.response_assemblers import (
    build_highlight_dates_response,
    build_highlight_list_response,
    build_highlight_stats_response,
)
from app.domains.podcast.schemas import (
    HighlightDatesResponse,
    HighlightFavoriteRequest,
    HighlightListResponse,
    HighlightStatsResponse,
)
from app.domains.podcast.services.highlight_service import HighlightService


router = APIRouter(prefix="")


@router.get(
    "/highlights",
    response_model=HighlightListResponse,
    summary="Get highlights list",
)
async def list_highlights(
    page: int = Query(1, ge=1, description="Page number"),
    size: int = Query(20, ge=1, le=100, description="Items per page"),
    episode_id: int | None = Query(None, description="Filter by episode ID"),
    min_score: float | None = Query(None, ge=0, le=10, description="Minimum overall score"),
    date_from: date | None = Query(None, description="Filter from date (YYYY-MM-DD)"),
    date_to: date | None = Query(None, description="Filter to date (YYYY-MM-DD)"),
    favorited_only: bool = Query(False, description="Show only favorited"),
    service: HighlightService = Depends(get_highlight_service),
):
    """Get highlights list with pagination and filtering."""
    result = await service.get_highlights(
        page=page,
        per_page=size,
        episode_id=episode_id,
        min_score=min_score,
        date_from=date_from,
        date_to=date_to,
        favorited_only=favorited_only,
    )
    return build_highlight_list_response(result)


@router.get(
    "/highlights/dates",
    response_model=HighlightDatesResponse,
    summary="Get available highlight dates",
)
async def get_highlight_dates(
    service: HighlightService = Depends(get_highlight_service),
):
    """Get list of dates that have highlights (for calendar component)."""
    result = await service.get_highlight_dates()
    return build_highlight_dates_response(result)


@router.get(
    "/highlights/stats",
    response_model=HighlightStatsResponse,
    summary="Get highlight statistics",
)
async def get_highlight_stats(
    service: HighlightService = Depends(get_highlight_service),
):
    """Get highlight statistics (for Profile card)."""
    result = await service.get_stats()
    return build_highlight_stats_response(result)


@router.post(
    "/episodes/{episode_id}/highlights/extract",
    summary="Trigger highlight extraction for an episode",
)
async def trigger_episode_extraction(
    episode_id: int,
    service: HighlightService = Depends(get_highlight_service),
):
    """Manually trigger highlight extraction for a single episode."""
    from app.domains.podcast.tasks.highlight_extraction import (
        extract_episode_highlights,
    )

    task = extract_episode_highlights.delay(episode_id)
    return {"task_id": task.id, "status": "queued"}


@router.patch(
    "/highlights/{highlight_id}/favorite",
    summary="Toggle highlight favorite status",
)
async def toggle_favorite(
    highlight_id: int,
    request: HighlightFavoriteRequest,
    service: HighlightService = Depends(get_highlight_service),
):
    """Toggle favorite status for a highlight."""
    result = await service.toggle_favorite(highlight_id, request.favorited)
    return result
