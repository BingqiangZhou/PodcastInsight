"""Podcast episode, playback, summary, and search routes."""

import logging
from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.core.auth import require_api_key
from app.core.config import settings
from app.core.exceptions import (
    EpisodeNotFoundError,
    SubscriptionNotFoundError,
    ValidationError,
)
from app.domains.podcast.routes.dependencies import (
    get_podcast_episode_service,
    get_podcast_playback_service,
    get_podcast_search_service,
    get_summary_workflow_service,
)
from app.domains.podcast.routes.episode_route_common import (
    decode_cursor,
    encode_keyset_cursor,
)
from app.domains.podcast.routes.response_assemblers import (
    build_episode_list_response,
    build_feed_response,
    build_playback_history_list_response,
    build_playback_state_response,
    build_summary_models_response,
)
from app.domains.podcast.schemas import (
    PlaybackRateApplyRequest,
    PlaybackRateEffectiveResponse,
    PodcastEpisodeDetailResponse,
    PodcastEpisodeFilter,
    PodcastEpisodeListResponse,
    PodcastFeedResponse,
    PodcastPlaybackHistoryListResponse,
    PodcastPlaybackStateResponse,
    PodcastPlaybackUpdate,
    PodcastSummaryPendingResponse,
    PodcastSummaryRequest,
    PodcastSummaryStartResponse,
    SummaryModelsResponse,
)
from app.domains.podcast.services.content_service import SummaryWorkflowService
from app.domains.podcast.services.episode_service import PodcastEpisodeService
from app.domains.podcast.services.playback_service import PodcastPlaybackService
from app.domains.podcast.services.search_service import PodcastSearchService
from app.domains.podcast.tasks.tasks_summary import (
    generate_episode_summary as generate_episode_summary_task,
)


router = APIRouter(prefix="")
logger = logging.getLogger(__name__)


# ── Feed & episode listing ─────────────────────────────────────────────────


@router.get(
    "/episodes/feed",
    response_model=PodcastFeedResponse,
    summary="Get podcast feed",
)
async def get_podcast_feed(
    page: int = Query(1, ge=1, description="Page number"),
    cursor: str | None = Query(None, description="Cursor token for pagination"),
    page_size: int = Query(10, ge=1, le=50, description="Page size"),
    size: int | None = Query(
        None,
        ge=1,
        le=50,
        description="Optional alias for page_size",
    ),
    service: PodcastEpisodeService = Depends(get_podcast_episode_service),
):
    """Return all subscribed episodes ordered by publish date desc."""
    resolved_size = size or page_size
    decoded_cursor = decode_cursor(cursor) if cursor else None

    should_use_first_page_keyset = (
        settings.PODCAST_FEED_LIGHTWEIGHT_ENABLED and cursor is None and page == 1
    )
    if should_use_first_page_keyset:
        (
            episodes,
            total,
            has_more,
            next_cursor_values,
        ) = await service.list_feed_by_cursor(
            size=resolved_size,
        )
        next_page = None
        next_cursor = (
            encode_keyset_cursor("feed", next_cursor_values[0], next_cursor_values[1])
            if next_cursor_values
            else None
        )
    elif decoded_cursor:
        if decoded_cursor["type"] != "feed":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cursor is not valid for this endpoint",
            )

        (
            episodes,
            total,
            has_more,
            next_cursor_values,
        ) = await service.list_feed_by_cursor(
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

    response_data = build_feed_response(
        episodes,
        has_more=has_more,
        next_page=next_page,
        next_cursor=next_cursor,
        total=total,
    )
    return response_data


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
    service: PodcastEpisodeService = Depends(get_podcast_episode_service),
):
    filters = PodcastEpisodeFilter(
        subscription_id=subscription_id,
        has_summary=has_summary,
        is_played=is_played,
    )
    episodes, total = await service.list_episodes(filters=filters, page=page, size=size)
    return build_episode_list_response(
        episodes,
        total=total,
        page=page,
        size=size,
        subscription_id=subscription_id or 0,
    )


@router.get(
    "/episodes/history",
    response_model=PodcastEpisodeListResponse,
    summary="List playback history",
)
async def list_playback_history(
    page: int = Query(1, ge=1, description="Page number"),
    cursor: str | None = Query(None, description="Cursor token for pagination"),
    size: int = Query(20, ge=1, le=100, description="Page size"),
    service: PodcastEpisodeService = Depends(get_podcast_episode_service),
):
    decoded_cursor = decode_cursor(cursor) if cursor else None

    if decoded_cursor:
        if decoded_cursor["type"] != "history":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cursor is not valid for this endpoint",
            )

        (
            episodes,
            total,
            _,
            next_cursor_values,
        ) = await service.list_playback_history_by_cursor(
            size=size,
            cursor_last_updated_at=decoded_cursor["ts"],
            cursor_episode_id=decoded_cursor["id"],
        )
        resolved_page = page
        next_cursor = (
            encode_keyset_cursor(
                "history", next_cursor_values[0], next_cursor_values[1]
            )
            if next_cursor_values
            else None
        )
    else:
        episodes, total = await service.list_playback_history(page=page, size=size)
        resolved_page = page
        next_cursor = None

    response_data = build_episode_list_response(
        episodes,
        total=total,
        page=resolved_page,
        size=size,
        subscription_id=0,
        next_cursor=next_cursor,
    )
    return response_data


@router.get(
    "/episodes/history-lite",
    response_model=PodcastPlaybackHistoryListResponse,
    summary="List lightweight playback history",
)
async def list_playback_history_lite(
    page: int = Query(1, ge=1, description="Page number"),
    size: int = Query(20, ge=1, le=100, description="Page size"),
    service: PodcastEpisodeService = Depends(get_podcast_episode_service),
):
    episodes, total = await service.list_playback_history_lite(page=page, size=size)
    return build_playback_history_list_response(
        episodes,
        total=total,
        page=page,
        size=size,
    )


@router.get(
    "/episodes/{episode_id}",
    response_model=PodcastEpisodeDetailResponse,
    summary="Get episode detail",
)
async def get_episode(
    episode_id: int,
    service: PodcastEpisodeService = Depends(get_podcast_episode_service),
):
    episode = await service.get_episode_with_summary(episode_id)
    if not episode:
        raise HTTPException(
            status_code=404, detail="Episode not found or no permission"
        )

    return PodcastEpisodeDetailResponse(**episode)


# ── Summary & playback actions ─────────────────────────────────────────────


@router.post(
    "/episodes/{episode_id}/summary",
    response_model=PodcastSummaryStartResponse,
    status_code=status.HTTP_202_ACCEPTED,
    summary="Queue AI summary generation",
)
async def generate_summary(
    episode_id: int,
    request: PodcastSummaryRequest,
    service: PodcastEpisodeService = Depends(get_podcast_episode_service),
    summary_workflow: SummaryWorkflowService = Depends(get_summary_workflow_service),
):
    try:
        episode = await service.get_episode_by_id(episode_id)
        if not episode:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Episode not found",
            )

        accepted = await summary_workflow.accept_episode_summary_generation(
            episode_id,
        )

        if not accepted["already_queued"]:
            generate_episode_summary_task.delay(
                episode_id,
                request.summary_model,
                request.custom_prompt,
            )

        return PodcastSummaryStartResponse(
            episode_id=episode_id,
            summary_status=accepted["summary_status"],
            accepted_at=accepted.get("accepted_at", datetime.now(UTC)),
            message=(
                "Summary generation already in progress"
                if accepted["already_queued"]
                else "Summary generation accepted"
            ),
        )
    except ValidationError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Transcript is required before generating summary",
        ) from exc
    except EpisodeNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Episode not found",
        ) from None
    except Exception as exc:
        logger.error("Failed to queue summary for episode %s: %s", episode_id, exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to queue summary generation",
        ) from exc


@router.put(
    "/episodes/{episode_id}/playback",
    response_model=PodcastPlaybackStateResponse,
    summary="Update playback progress",
)
async def update_playback_progress(
    episode_id: int,
    playback_data: PodcastPlaybackUpdate,
    service: PodcastPlaybackService = Depends(get_podcast_playback_service),
):
    try:
        result = await service.update_playback_progress(
            episode_id,
            playback_data.position,
            playback_data.is_playing,
            playback_data.playback_rate,
        )
        return build_playback_state_response(
            payload=result,
        )
    except EpisodeNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Episode not found",
        ) from None
    except Exception as exc:
        logger.error(
            "Failed to update playback progress for episode %s: %s",
            episode_id,
            exc,
            exc_info=True,
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update playback progress",
        ) from exc


@router.get(
    "/episodes/{episode_id}/playback",
    response_model=PodcastPlaybackStateResponse,
    summary="Get playback state",
)
async def get_playback_state(
    episode_id: int,
    service: PodcastPlaybackService = Depends(get_podcast_playback_service),
):
    try:
        playback = await service.get_playback_state(episode_id)
        if not playback:
            raise HTTPException(status_code=404, detail="Playback record not found")
        return PodcastPlaybackStateResponse(**playback)
    except EpisodeNotFoundError:
        raise HTTPException(status_code=404, detail="Episode not found") from None


@router.get(
    "/playback/rate/effective",
    response_model=PlaybackRateEffectiveResponse,
    summary="Get effective playback rate preference",
)
async def get_effective_playback_rate(
    subscription_id: int | None = Query(
        None,
        ge=1,
        description="Subscription ID (optional)",
    ),
    service: PodcastPlaybackService = Depends(get_podcast_playback_service),
):
    result = await service.get_effective_playback_rate(subscription_id=subscription_id)
    return PlaybackRateEffectiveResponse(**result)


@router.put(
    "/playback/rate/apply",
    response_model=PlaybackRateEffectiveResponse,
    summary="Apply playback rate preference",
)
async def apply_playback_rate_preference(
    request: PlaybackRateApplyRequest,
    service: PodcastPlaybackService = Depends(get_podcast_playback_service),
):
    try:
        result = await service.apply_playback_rate_preference(
            playback_rate=request.playback_rate,
            apply_to_subscription=request.apply_to_subscription,
            subscription_id=request.subscription_id,
        )
        return PlaybackRateEffectiveResponse(**result)
    except SubscriptionNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Subscription not found",
        ) from None
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Failed to apply playback preference",
        ) from None
    except Exception as exc:
        logger.error("Failed to apply playback rate preference: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to apply playback preference",
        ) from exc


@router.get(
    "/summaries/pending",
    response_model=PodcastSummaryPendingResponse,
    summary="List pending summaries",
)
async def get_pending_summaries(
    user_id: int = Depends(require_api_key),
    summary_workflow: SummaryWorkflowService = Depends(get_summary_workflow_service),
):
    pending = await summary_workflow.list_pending_summaries_for_user(user_id)
    return PodcastSummaryPendingResponse(count=len(pending), episodes=pending)


@router.get(
    "/summaries/models",
    response_model=SummaryModelsResponse,
    summary="List available summary models",
)
async def get_summary_models(
    summary_workflow: SummaryWorkflowService = Depends(get_summary_workflow_service),
):
    try:
        models = await summary_workflow.get_summary_models()
        return build_summary_models_response(models)
    except Exception as exc:
        logger.error("Failed to get summary models: %s", exc)
        raise HTTPException(status_code=500, detail=str(exc)) from exc


# ── Search ──────────────────────────────────────────────────────────────────


@router.get(
    "/search",
    response_model=PodcastEpisodeListResponse,
    summary="Search podcast content",
)
async def search_podcasts(
    q: str | None = Query(None, min_length=1, description="Search keyword"),
    search_in: str | None = Query(
        "all",
        description="Search scope: title, description, summary, all",
    ),
    page: int = Query(1, ge=1, description="Page number"),
    size: int = Query(20, ge=1, le=100, description="Page size"),
    service: PodcastSearchService = Depends(get_podcast_search_service),
):
    keyword = (q or "").strip()
    if not keyword:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="q is required",
        )

    episodes, total = await service.search_podcasts(
        query=keyword,
        search_in=search_in,
        page=page,
        size=size,
    )
    return build_episode_list_response(
        episodes,
        total=total,
        page=page,
        size=size,
        subscription_id=0,
    )


__all__ = ["generate_summary", "router"]
