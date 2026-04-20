"""Podcast queue routes."""

from fastapi import APIRouter, Depends, HTTPException, status

from app.core.exceptions import (
    EpisodeNotFoundError,
    EpisodeNotInQueueError,
    InvalidReorderPayloadError,
    QueueLimitExceededError,
)
from app.domains.podcast.routes.dependencies import get_podcast_queue_service
from app.domains.podcast.routes.response_assemblers import build_queue_response
from app.domains.podcast.schemas import (
    PodcastQueueActivateRequest,
    PodcastQueueCurrentCompleteRequest,
    PodcastQueueItemAddRequest,
    PodcastQueueReorderRequest,
    PodcastQueueResponse,
    PodcastQueueSetCurrentRequest,
)
from app.domains.podcast.services.playback_service import PodcastQueueService


router = APIRouter(prefix="")


@router.get("/queue", response_model=PodcastQueueResponse, summary="Get playback queue")
async def get_queue(
    service: PodcastQueueService = Depends(get_podcast_queue_service),
):
    return build_queue_response(await service.get_queue())


@router.post(
    "/queue/items",
    response_model=PodcastQueueResponse,
    summary="Add episode to queue",
)
async def add_queue_item(
    request: PodcastQueueItemAddRequest,
    service: PodcastQueueService = Depends(get_podcast_queue_service),
):
    try:
        return build_queue_response(await service.add_to_queue(request.episode_id))
    except EpisodeNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Episode not found",
        ) from None
    except QueueLimitExceededError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Queue has reached its limit",
        ) from None


@router.delete(
    "/queue/items/{episode_id}",
    response_model=PodcastQueueResponse,
    summary="Remove episode from queue",
)
async def remove_queue_item(
    episode_id: int,
    service: PodcastQueueService = Depends(get_podcast_queue_service),
):
    return build_queue_response(await service.remove_from_queue(episode_id))


@router.put(
    "/queue/items/reorder",
    response_model=PodcastQueueResponse,
    summary="Reorder queue",
)
async def reorder_queue_items(
    request: PodcastQueueReorderRequest,
    service: PodcastQueueService = Depends(get_podcast_queue_service),
):
    try:
        return build_queue_response(await service.reorder_queue(request.episode_ids))
    except InvalidReorderPayloadError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid reorder payload",
        ) from None


@router.post(
    "/queue/current",
    response_model=PodcastQueueResponse,
    summary="Set current queue episode",
)
async def set_queue_current(
    request: PodcastQueueSetCurrentRequest,
    service: PodcastQueueService = Depends(get_podcast_queue_service),
):
    try:
        return build_queue_response(await service.set_current(request.episode_id))
    except EpisodeNotInQueueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Episode not in queue",
        ) from None


@router.post(
    "/queue/activate",
    response_model=PodcastQueueResponse,
    summary="Activate queue episode (ensure in queue + move to head + set current)",
)
async def activate_queue_episode(
    request: PodcastQueueActivateRequest,
    service: PodcastQueueService = Depends(get_podcast_queue_service),
):
    try:
        return build_queue_response(await service.activate_episode(request.episode_id))
    except EpisodeNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Episode not found",
        ) from None
    except QueueLimitExceededError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Queue has reached its limit",
        ) from None


@router.post(
    "/queue/current/complete",
    response_model=PodcastQueueResponse,
    summary="Complete current queue episode and advance",
)
async def complete_queue_current(
    _request: PodcastQueueCurrentCompleteRequest,
    service: PodcastQueueService = Depends(get_podcast_queue_service),
):
    return build_queue_response(await service.complete_current())
