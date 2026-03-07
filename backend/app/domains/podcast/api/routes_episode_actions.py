"""Podcast summary, playback, search, and recommendation routes."""

import logging
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.domains.podcast.api.dependencies import (
    get_current_user_id,
    get_episode_service,
    get_playback_service,
    get_search_service,
    get_summary_service,
)
from app.domains.podcast.repositories import PodcastRepository
from app.domains.podcast.schemas import (
    PlaybackRateApplyRequest,
    PlaybackRateEffectiveResponse,
    PodcastEpisodeListResponse,
    PodcastEpisodeResponse,
    PodcastPlaybackStateResponse,
    PodcastPlaybackUpdate,
    PodcastSummaryPendingResponse,
    PodcastSummaryRequest,
    PodcastSummaryResponse,
    SummaryModelInfo,
    SummaryModelsResponse,
)
from app.domains.podcast.services.episode_service import PodcastEpisodeService
from app.domains.podcast.services.playback_service import PodcastPlaybackService
from app.domains.podcast.services.search_service import PodcastSearchService
from app.domains.podcast.summary_manager import DatabaseBackedAISummaryService
from app.http.errors import bilingual_http_exception


router = APIRouter(prefix="")
logger = logging.getLogger(__name__)


@router.post(
    "/episodes/{episode_id}/summary",
    response_model=PodcastSummaryResponse,
    summary="Generate or regenerate AI summary",
)
async def generate_summary(
    episode_id: int,
    request: PodcastSummaryRequest,
    service: PodcastEpisodeService = Depends(get_episode_service),
    ai_summary_service: DatabaseBackedAISummaryService = Depends(get_summary_service),
):
    try:
        episode = await service.get_episode_by_id(episode_id)
        if not episode:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Episode {episode_id} not found",
            )

        summary_result = await ai_summary_service.generate_summary(
            episode_id,
            request.summary_model,
            request.custom_prompt,
        )

        episode_detail = await service.get_episode_with_summary(episode_id)
        final_summary = ""
        final_version = "1.0"
        if episode_detail:
            final_summary = episode_detail.get("ai_summary") or ""
            final_version = episode_detail.get("summary_version") or "1.0"

        return PodcastSummaryResponse(
            episode_id=episode_id,
            summary=final_summary,
            version=final_version,
            confidence_score=None,
            transcript_used=True,
            generated_at=datetime.now(timezone.utc),
            word_count=len(final_summary.split()),
            model_used=summary_result["model_name"],
            processing_time=summary_result["processing_time"],
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except Exception as exc:
        logger.error("Failed to generate summary for episode %s: %s", episode_id, exc)
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.put(
    "/episodes/{episode_id}/playback",
    response_model=PodcastPlaybackStateResponse,
    summary="Update playback progress",
)
async def update_playback_progress(
    episode_id: int,
    playback_data: PodcastPlaybackUpdate,
    service: PodcastPlaybackService = Depends(get_playback_service),
):
    try:
        result = await service.update_playback_progress(
            episode_id,
            playback_data.position,
            playback_data.is_playing,
            playback_data.playback_rate,
        )
        return PodcastPlaybackStateResponse(
            episode_id=episode_id,
            current_position=result["progress"],
            is_playing=result["is_playing"],
            playback_rate=result["playback_rate"],
            play_count=result["play_count"],
            last_updated_at=result["last_updated_at"],
            progress_percentage=result["progress_percentage"],
            remaining_time=result["remaining_time"],
        )
    except ValueError as exc:
        if str(exc) == "Episode not found":
            raise bilingual_http_exception(
                "Episode not found",
                "鏈壘鍒拌鍗曢泦",
                status.HTTP_404_NOT_FOUND,
            ) from exc
        raise bilingual_http_exception(
            "Failed to update playback progress",
            "鏇存柊鎾斁杩涘害澶辫触",
            status.HTTP_400_BAD_REQUEST,
        ) from exc
    except Exception as exc:
        raise bilingual_http_exception(
            "Failed to update playback progress",
            "鏇存柊鎾斁杩涘害澶辫触",
            status.HTTP_500_INTERNAL_SERVER_ERROR,
        ) from exc


@router.get(
    "/episodes/{episode_id}/playback",
    response_model=PodcastPlaybackStateResponse,
    summary="Get playback state",
)
async def get_playback_state(
    episode_id: int,
    service: PodcastPlaybackService = Depends(get_playback_service),
):
    try:
        playback = await service.get_playback_state(episode_id)
        if not playback:
            raise HTTPException(status_code=404, detail="Playback record not found")
        return PodcastPlaybackStateResponse(**playback)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


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
    service: PodcastPlaybackService = Depends(get_playback_service),
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
    service: PodcastPlaybackService = Depends(get_playback_service),
):
    try:
        result = await service.apply_playback_rate_preference(
            playback_rate=request.playback_rate,
            apply_to_subscription=request.apply_to_subscription,
            subscription_id=request.subscription_id,
        )
        return PlaybackRateEffectiveResponse(**result)
    except ValueError as exc:
        code = str(exc)
        if code == "SUBSCRIPTION_ID_REQUIRED":
            raise bilingual_http_exception(
                "subscription_id is required when apply_to_subscription is true",
                "subscription_id is required",
                status.HTTP_400_BAD_REQUEST,
            ) from exc
        if code == "SUBSCRIPTION_NOT_FOUND":
            raise bilingual_http_exception(
                "Subscription not found",
                "鏈壘鍒拌璁㈤槄",
                status.HTTP_404_NOT_FOUND,
            ) from exc
        if code == "USER_NOT_FOUND":
            raise bilingual_http_exception(
                "User not found",
                "User not found",
                status.HTTP_404_NOT_FOUND,
            ) from exc
        raise bilingual_http_exception(
            "Failed to apply playback preference",
            "搴旂敤鎾斁鍋忓ソ澶辫触",
            status.HTTP_400_BAD_REQUEST,
        ) from exc
    except Exception as exc:
        logger.error("Failed to apply playback rate preference: %s", exc)
        raise bilingual_http_exception(
            "Failed to apply playback preference",
            "搴旂敤鎾斁鍋忓ソ澶辫触",
            status.HTTP_500_INTERNAL_SERVER_ERROR,
        ) from exc


@router.get(
    "/summaries/pending",
    response_model=PodcastSummaryPendingResponse,
    summary="List pending summaries",
)
async def get_pending_summaries(
    user_id: int = Depends(get_current_user_id),
    ai_summary_service: DatabaseBackedAISummaryService = Depends(get_summary_service),
):
    pending = await PodcastRepository(
        ai_summary_service.db
    ).get_pending_summaries_for_user(user_id)
    return PodcastSummaryPendingResponse(count=len(pending), episodes=pending)


@router.get(
    "/summaries/models",
    response_model=SummaryModelsResponse,
    summary="List available summary models",
)
async def get_summary_models(
    ai_summary_service: DatabaseBackedAISummaryService = Depends(get_summary_service),
):
    try:
        models = await ai_summary_service.get_summary_models()
        model_infos = [
            SummaryModelInfo(
                id=model["id"],
                name=model["name"],
                display_name=model["display_name"],
                provider=model["provider"],
                model_id=model["model_id"],
                is_default=model["is_default"],
            )
            for model in models
        ]
        return SummaryModelsResponse(models=model_infos, total=len(model_infos))
    except Exception as exc:
        logger.error("Failed to get summary models: %s", exc)
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@router.get(
    "/search",
    response_model=PodcastEpisodeListResponse,
    summary="Search podcast content",
)
async def search_podcasts(
    q: str | None = Query(None, min_length=1, description="Search keyword"),
    search_in: str | None = Query(
        "all", description="Search scope: title, description, summary, all"
    ),
    page: int = Query(1, ge=1, description="Page number"),
    size: int = Query(20, ge=1, le=100, description="Page size"),
    service: PodcastSearchService = Depends(get_search_service),
):
    keyword = (q or "").strip()
    if not keyword:
        raise bilingual_http_exception(
            "q is required",
            "蹇呴』鎻愪緵 q 鍙傛暟",
            status.HTTP_422_UNPROCESSABLE_ENTITY,
        )

    episodes, total = await service.search_podcasts(
        query=keyword,
        search_in=search_in,
        page=page,
        size=size,
    )
    return PodcastEpisodeListResponse(
        episodes=[PodcastEpisodeResponse(**ep) for ep in episodes],
        total=total,
        page=page,
        size=size,
        pages=(total + size - 1) // size,
        subscription_id=0,
    )


@router.get(
    "/recommendations",
    response_model=list[dict],
    summary="Get podcast recommendations",
)
async def get_recommendations(
    limit: int = Query(10, ge=1, le=50, description="Recommendation count"),
    service: PodcastSearchService = Depends(get_search_service),
):
    return await service.get_recommendations(limit=limit)
