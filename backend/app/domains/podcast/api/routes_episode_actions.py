"""Podcast summary, playback, search, and recommendation routes."""

import logging

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.core.providers import (
    get_podcast_episode_service,
    get_podcast_playback_service,
    get_podcast_search_service,
    get_summary_workflow_service,
    get_token_user_id,
)
from app.domains.podcast.api.response_assemblers import (
    build_effective_playback_rate_response,
    build_episode_list_response,
    build_existing_playback_state_response,
    build_pending_summaries_response,
    build_playback_state_response,
    build_summary_models_response,
    build_summary_response,
)
from app.domains.podcast.schemas import (
    PlaybackRateApplyRequest,
    PlaybackRateEffectiveResponse,
    PodcastEpisodeListResponse,
    PodcastPlaybackStateResponse,
    PodcastPlaybackUpdate,
    PodcastSummaryPendingResponse,
    PodcastSummaryRequest,
    PodcastSummaryResponse,
    SummaryModelsResponse,
)
from app.domains.podcast.services.episode_service import PodcastEpisodeService
from app.domains.podcast.services.playback_service import PodcastPlaybackService
from app.domains.podcast.services.search_service import PodcastSearchService
from app.domains.podcast.services.summary_workflow_service import SummaryWorkflowService
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
    service: PodcastEpisodeService = Depends(get_podcast_episode_service),
    summary_workflow: SummaryWorkflowService = Depends(get_summary_workflow_service),
):
    try:
        episode = await service.get_episode_by_id(episode_id)
        if not episode:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Episode {episode_id} not found",
            )

        summary_result = await summary_workflow.generate_episode_summary(
            episode_id,
            summary_model=request.summary_model,
            custom_prompt=request.custom_prompt,
        )
        return build_summary_response(
            episode_id=episode_id,
            summary_result=summary_result,
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
            episode_id=episode_id,
            payload=result,
        )
    except ValueError as exc:
        if str(exc) == "Episode not found":
            raise bilingual_http_exception(
                "Episode not found",
                "未找到该单集",
                status.HTTP_404_NOT_FOUND,
            ) from exc
        raise bilingual_http_exception(
            "Failed to update playback progress",
            "更新播放进度失败",
            status.HTTP_400_BAD_REQUEST,
        ) from exc
    except Exception as exc:
        raise bilingual_http_exception(
            "Failed to update playback progress",
            "更新播放进度失败",
            status.HTTP_500_INTERNAL_SERVER_ERROR,
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
        return build_existing_playback_state_response(playback)
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
    service: PodcastPlaybackService = Depends(get_podcast_playback_service),
):
    result = await service.get_effective_playback_rate(subscription_id=subscription_id)
    return build_effective_playback_rate_response(result)


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
        return build_effective_playback_rate_response(result)
    except ValueError as exc:
        code = str(exc)
        if code == "SUBSCRIPTION_ID_REQUIRED":
            raise bilingual_http_exception(
                "subscription_id is required when apply_to_subscription is true",
                "当 apply_to_subscription 为 true 时必须提供 subscription_id",
                status.HTTP_400_BAD_REQUEST,
            ) from exc
        if code == "SUBSCRIPTION_NOT_FOUND":
            raise bilingual_http_exception(
                "Subscription not found",
                "未找到订阅",
                status.HTTP_404_NOT_FOUND,
            ) from exc
        if code == "USER_NOT_FOUND":
            raise bilingual_http_exception(
                "User not found",
                "未找到用户",
                status.HTTP_404_NOT_FOUND,
            ) from exc
        raise bilingual_http_exception(
            "Failed to apply playback preference",
            "应用播放偏好失败",
            status.HTTP_400_BAD_REQUEST,
        ) from exc
    except Exception as exc:
        logger.error("Failed to apply playback rate preference: %s", exc)
        raise bilingual_http_exception(
            "Failed to apply playback preference",
            "应用播放偏好失败",
            status.HTTP_500_INTERNAL_SERVER_ERROR,
        ) from exc


@router.get(
    "/summaries/pending",
    response_model=PodcastSummaryPendingResponse,
    summary="List pending summaries",
)
async def get_pending_summaries(
    user_id: int = Depends(get_token_user_id),
    summary_workflow: SummaryWorkflowService = Depends(get_summary_workflow_service),
):
    pending = await summary_workflow.list_pending_summaries_for_user(user_id)
    return build_pending_summaries_response(pending)


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
        raise bilingual_http_exception(
            "q is required",
            "必须提供 q 查询参数",
            status.HTTP_422_UNPROCESSABLE_ENTITY,
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


@router.get(
    "/recommendations",
    response_model=list[dict],
    summary="Get podcast recommendations",
)
async def get_recommendations(
    limit: int = Query(10, ge=1, le=50, description="Recommendation count"),
    service: PodcastSearchService = Depends(get_podcast_search_service),
):
    return await service.get_recommendations(limit=limit)
