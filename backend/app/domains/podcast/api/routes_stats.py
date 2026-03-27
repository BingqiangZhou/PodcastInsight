"""Podcast stats routes."""

from fastapi import APIRouter, Depends, Request

from app.core.etag import build_conditional_etag_response
from app.core.providers import get_podcast_stats_service
from app.domains.podcast.api.response_assemblers import (
    build_podcast_profile_stats_response,
    build_podcast_stats_response,
)
from app.domains.podcast.schemas import (
    PodcastProfileStatsResponse,
    PodcastStatsResponse,
)
from app.domains.podcast.services.stats_service import PodcastStatsService


router = APIRouter(prefix="")


@router.get(
    "/stats",
    response_model=PodcastStatsResponse,
    summary="Get podcast statistics",
)
async def get_podcast_stats(
    request: Request,
    service: PodcastStatsService = Depends(get_podcast_stats_service),
):
    """Get podcast listening statistics for the user."""
    stats = await service.get_user_stats()
    response_data = build_podcast_stats_response(stats)

    return build_conditional_etag_response(
        request=request,
        content=response_data,
        max_age=300,
        weak=True,
        cache_control="private, max-age=300",
    )


@router.get(
    "/stats/profile",
    response_model=PodcastProfileStatsResponse,
    summary="Get lightweight profile stats",
)
async def get_profile_stats(
    request: Request,
    service: PodcastStatsService = Depends(get_podcast_stats_service),
):
    """Get lightweight profile statistics for profile cards."""
    stats = await service.get_profile_stats()
    response_data = build_podcast_profile_stats_response(stats)

    return build_conditional_etag_response(
        request=request,
        content=response_data,
        max_age=300,
        weak=True,
        cache_control="private, max-age=300",
    )
