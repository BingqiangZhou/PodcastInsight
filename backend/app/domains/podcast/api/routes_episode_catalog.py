"""Podcast feed, listing, and detail routes."""


from fastapi import APIRouter, Depends, HTTPException, Query, Request, status

from app.core.config import settings
from app.domains.podcast.api.dependencies import get_episode_service
from app.domains.podcast.api.episode_route_common import (
    decode_cursor,
    encode_keyset_cursor,
)
from app.domains.podcast.schemas import (
    PodcastEpisodeDetailResponse,
    PodcastEpisodeFilter,
    PodcastEpisodeListResponse,
    PodcastEpisodeResponse,
    PodcastFeedResponse,
    PodcastPlaybackHistoryItemResponse,
    PodcastPlaybackHistoryListResponse,
)
from app.domains.podcast.services.episode_service import PodcastEpisodeService
from app.http.errors import bilingual_http_exception
from app.http.responses import build_etag_response


router = APIRouter(prefix="")


@router.get(
    "/episodes/feed",
    response_model=PodcastFeedResponse,
    summary="Get podcast feed",
)
async def get_podcast_feed(
    request: Request,
    page: int = Query(1, ge=1, description="Page number"),
    cursor: str | None = Query(None, description="Cursor token for pagination"),
    page_size: int = Query(10, ge=1, le=50, description="Page size"),
    size: int | None = Query(
        None,
        ge=1,
        le=50,
        description="Optional alias for page_size",
    ),
    service: PodcastEpisodeService = Depends(get_episode_service),
):
    """Return all subscribed episodes ordered by publish date desc."""
    resolved_size = size or page_size
    decoded_cursor = decode_cursor(cursor) if cursor else None

    should_use_first_page_keyset = (
        settings.PODCAST_FEED_LIGHTWEIGHT_ENABLED and cursor is None and page == 1
    )
    if should_use_first_page_keyset:
        episodes, total, has_more, next_cursor_values = await service.list_feed_by_cursor(
            size=resolved_size
        )
        next_page = None
        next_cursor = (
            encode_keyset_cursor("feed", next_cursor_values[0], next_cursor_values[1])
            if next_cursor_values
            else None
        )
    elif decoded_cursor:
        if decoded_cursor["type"] != "feed":
            raise bilingual_http_exception(
                "Cursor is not valid for this endpoint",
                "璇ユ父鏍囦笉閫傜敤浜庡綋鍓嶆帴鍙?",
                status.HTTP_400_BAD_REQUEST,
            )

        episodes, total, has_more, next_cursor_values = await service.list_feed_by_cursor(
            size=resolved_size,
            cursor_published_at=decoded_cursor["ts"],
            cursor_episode_id=decoded_cursor["id"],
        )
        next_page = None
        next_cursor = (
            encode_keyset_cursor("feed", next_cursor_values[0], next_cursor_values[1])
            if next_cursor_values
            else None
        )
    else:
        episodes, total = await service.list_feed_by_page(page=page, size=resolved_size)
        has_more = (page * resolved_size) < total
        next_page = page + 1 if has_more else None
        next_cursor = None

    response_data = PodcastFeedResponse(
        items=[PodcastEpisodeResponse(**ep) for ep in episodes],
        has_more=has_more,
        next_page=next_page,
        next_cursor=next_cursor,
        total=total,
    )
    return build_etag_response(
        request=request,
        content=response_data,
        max_age=30 if settings.PODCAST_FEED_LIGHTWEIGHT_ENABLED else 600,
        cache_control=(
            "private, max-age=30"
            if settings.PODCAST_FEED_LIGHTWEIGHT_ENABLED
            else "private, max-age=600"
        ),
    )


@router.get(
    "/episodes",
    response_model=PodcastEpisodeListResponse,
    summary="List podcast episodes",
)
async def list_episodes(
    subscription_id: int | None = Query(None, description="Subscription ID filter"),
    page: int = Query(1, ge=1, description="Page number"),
    size: int = Query(20, ge=1, le=100, description="Page size"),
    has_summary: bool | None = Query(None, description="Has AI summary"),
    is_played: bool | None = Query(None, description="Played status"),
    service: PodcastEpisodeService = Depends(get_episode_service),
):
    filters = PodcastEpisodeFilter(
        subscription_id=subscription_id,
        has_summary=has_summary,
        is_played=is_played,
    )
    episodes, total = await service.list_episodes(filters=filters, page=page, size=size)
    pages = (total + size - 1) // size
    return PodcastEpisodeListResponse(
        episodes=[PodcastEpisodeResponse(**ep) for ep in episodes],
        total=total,
        page=page,
        size=size,
        pages=pages,
        subscription_id=subscription_id or 0,
    )


@router.get(
    "/episodes/history",
    response_model=PodcastEpisodeListResponse,
    summary="List playback history",
)
async def list_playback_history(
    request: Request,
    page: int = Query(1, ge=1, description="Page number"),
    cursor: str | None = Query(None, description="Cursor token for pagination"),
    size: int = Query(20, ge=1, le=100, description="Page size"),
    service: PodcastEpisodeService = Depends(get_episode_service),
):
    decoded_cursor = decode_cursor(cursor) if cursor else None

    if decoded_cursor:
        if decoded_cursor["type"] != "history":
            raise bilingual_http_exception(
                "Cursor is not valid for this endpoint",
                "璇ユ父鏍囦笉閫傜敤浜庡綋鍓嶆帴鍙?",
                status.HTTP_400_BAD_REQUEST,
            )

        episodes, total, _, next_cursor_values = await service.list_playback_history_by_cursor(
            size=size,
            cursor_last_updated_at=decoded_cursor["ts"],
            cursor_episode_id=decoded_cursor["id"],
        )
        resolved_page = page
        next_cursor = (
            encode_keyset_cursor("history", next_cursor_values[0], next_cursor_values[1])
            if next_cursor_values
            else None
        )
    else:
        episodes, total = await service.list_playback_history(page=page, size=size)
        resolved_page = page
        next_cursor = None

    response_data = PodcastEpisodeListResponse(
        episodes=[PodcastEpisodeResponse(**ep) for ep in episodes],
        total=total,
        page=resolved_page,
        size=size,
        pages=(total + size - 1) // size,
        subscription_id=0,
        next_cursor=next_cursor,
    )
    return build_etag_response(
        request=request,
        content=response_data,
        max_age=300,
        cache_control="private, max-age=300",
    )


@router.get(
    "/episodes/history-lite",
    response_model=PodcastPlaybackHistoryListResponse,
    summary="List lightweight playback history",
)
async def list_playback_history_lite(
    page: int = Query(1, ge=1, description="Page number"),
    size: int = Query(20, ge=1, le=100, description="Page size"),
    service: PodcastEpisodeService = Depends(get_episode_service),
):
    episodes, total = await service.list_playback_history_lite(page=page, size=size)
    return PodcastPlaybackHistoryListResponse(
        episodes=[PodcastPlaybackHistoryItemResponse(**ep) for ep in episodes],
        total=total,
        page=page,
        size=size,
        pages=(total + size - 1) // size,
    )


@router.get(
    "/episodes/{episode_id}",
    response_model=PodcastEpisodeDetailResponse,
    summary="Get episode detail",
)
async def get_episode(
    request: Request,
    episode_id: int,
    service: PodcastEpisodeService = Depends(get_episode_service),
):
    episode = await service.get_episode_with_summary(episode_id)
    if not episode:
        raise HTTPException(status_code=404, detail="Episode not found or no permission")

    return build_etag_response(
        request=request,
        content=PodcastEpisodeDetailResponse(**episode),
        max_age=1800,
        cache_control="private, max-age=1800",
    )
