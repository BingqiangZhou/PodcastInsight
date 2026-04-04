"""Podcast transcription task, scheduling, and transcript retrieval routes."""

import logging

from fastapi import APIRouter, Body, Depends, HTTPException, Query, status

from app.core.exceptions import (
    EpisodeNotFoundError,
    SubscriptionNotFoundError,
    TranscriptionTaskNotFoundError,
)
from app.domains.podcast.api.dependencies import (
    get_podcast_episode_service,
    get_podcast_subscription_service,
    get_transcription_workflow_service,
)
from app.domains.podcast.api.response_assemblers import (
    build_batch_transcription_response,
    build_check_new_episodes_response,
    build_episode_transcript_response,
    build_pending_transcriptions_response,
    build_transcription_cancel_response,
    build_transcription_schedule_response,
    build_transcription_schedule_status_response,
)
from app.domains.podcast.api.transcription_route_common import (
    build_transcription_response,
    status_value,
)
from app.domains.podcast.schemas import (
    PodcastBatchTranscriptionResponse,
    PodcastCheckNewEpisodesResponse,
    PodcastEpisodeTranscriptResponse,
    PodcastPendingTranscriptionsResponse,
    PodcastTranscriptionCancelResponse,
    PodcastTranscriptionDetailResponse,
    PodcastTranscriptionRequest,
    PodcastTranscriptionResponse,
    PodcastTranscriptionScheduleResponse,
    PodcastTranscriptionScheduleStatusResponse,
    PodcastTranscriptionStatusResponse,
)
from app.domains.podcast.services.episode_service import PodcastEpisodeService
from app.domains.podcast.services.subscription_service import PodcastSubscriptionService
from app.domains.podcast.services.transcription_workflow_service import (
    TranscriptionWorkflowService,
)
from app.domains.podcast.transcription_types import ScheduleFrequency


router = APIRouter(prefix="")
logger = logging.getLogger(__name__)


# ── Task lifecycle ─────────────────────────────────────────────────────────


@router.post(
    "/episodes/{episode_id}/transcribe",
    status_code=status.HTTP_201_CREATED,
    response_model=PodcastTranscriptionResponse,
    summary="Start episode transcription",
    description="Start transcription for a podcast episode",
)
async def start_transcription(
    episode_id: int,
    transcription_request: PodcastTranscriptionRequest,
    episode_service: PodcastEpisodeService = Depends(get_podcast_episode_service),
    transcription_workflow: TranscriptionWorkflowService = Depends(
        get_transcription_workflow_service,
    ),
):
    """Start transcription task via shared workflow service."""
    try:
        start_result = await transcription_workflow.start_episode_transcription(
            episode_id,
            transcription_model=transcription_request.transcription_model,
            force_regenerate=transcription_request.force_regenerate,
            episode_lookup=episode_service.get_episode_by_id,
        )
        return build_transcription_response(
            start_result["task"],
            start_result["episode"],
        )
    except EpisodeNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Episode not found",
        )
    except Exception as exc:
        logger.error(
            "Failed to start transcription for episode %s: %s", episode_id, exc
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to start transcription: {exc}",
        ) from exc


@router.get(
    "/episodes/{episode_id}/transcription",
    response_model=PodcastTranscriptionDetailResponse,
    summary="Get transcription detail",
    description="Get transcription status and result for an episode",
)
async def get_transcription(
    episode_id: int,
    include_content: bool = Query(
        True,
        description="Whether to include full transcript",
    ),
    episode_service: PodcastEpisodeService = Depends(get_podcast_episode_service),
    transcription_workflow: TranscriptionWorkflowService = Depends(
        get_transcription_workflow_service,
    ),
):
    """Get detailed transcription info for one episode."""
    try:
        episode = await episode_service.get_episode_by_id(episode_id)
        if not episode:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Episode {episode_id} not found",
            )

        transcription_service = transcription_workflow.transcription_service_factory(
            transcription_workflow.db,
        )
        task = await transcription_service.get_episode_transcription(episode_id)
        if not task:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No transcription task found for this episode",
            )

        response_data = {
            "id": task.id,
            "episode_id": task.episode_id,
            "status": status_value(task.status),
            "progress_percentage": task.progress_percentage,
            "original_audio_url": task.original_audio_url,
            "original_file_size": task.original_file_size,
            "transcript_word_count": task.transcript_word_count,
            "transcript_duration": task.transcript_duration,
            "error_message": task.error_message,
            "error_code": task.error_code,
            "download_time": task.download_time,
            "conversion_time": task.conversion_time,
            "transcription_time": task.transcription_time,
            "chunk_size_mb": task.chunk_size_mb,
            "model_used": task.model_used,
            "created_at": task.created_at,
            "started_at": task.started_at,
            "completed_at": task.completed_at,
            "updated_at": task.updated_at,
            "duration_seconds": task.duration_seconds,
            "total_processing_time": task.total_processing_time,
            "chunk_info": task.chunk_info,
            "original_file_path": task.original_file_path,
            "episode": {
                "id": episode.id,
                "title": episode.title,
                "audio_url": episode.audio_url,
                "audio_duration": episode.audio_duration,
            },
            "debug_message": (task.chunk_info or {}).get("debug_message"),
        }

        if include_content:
            response_data["transcript_content"] = task.transcript_content
        if task.duration_seconds:
            hours = task.duration_seconds // 3600
            minutes = (task.duration_seconds % 3600) // 60
            seconds = task.duration_seconds % 60
            response_data["formatted_duration"] = (
                f"{hours:02d}:{minutes:02d}:{seconds:02d}"
            )
        if task.total_processing_time:
            response_data["formatted_processing_time"] = (
                f"{task.total_processing_time:.2f} seconds"
            )

        response_data["formatted_created_at"] = task.created_at.strftime(
            "%Y-%m-%d %H:%M:%S",
        )
        if task.started_at:
            response_data["formatted_started_at"] = task.started_at.strftime(
                "%Y-%m-%d %H:%M:%S",
            )
        if task.completed_at:
            response_data["formatted_completed_at"] = task.completed_at.strftime(
                "%Y-%m-%d %H:%M:%S",
            )

        return PodcastTranscriptionDetailResponse(**response_data)
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to get transcription for episode %s: %s", episode_id, exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get transcription: {exc}",
        ) from exc


@router.delete(
    "/episodes/{episode_id}/transcription",
    summary="Delete transcription task",
    description="Delete episode transcription task and clean lock/cache",
)
async def delete_transcription(
    episode_id: int,
    episode_service: PodcastEpisodeService = Depends(get_podcast_episode_service),
    transcription_workflow: TranscriptionWorkflowService = Depends(
        get_transcription_workflow_service,
    ),
):
    """Delete transcription task and cleanup redis state."""
    try:
        await transcription_workflow.delete_episode_transcription(
            episode_id,
            episode_lookup=episode_service.get_episode_by_id,
        )
        return {
            "message": "Transcription task deleted successfully",
            "episode_id": episode_id,
        }
    except TranscriptionTaskNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transcription task not found",
        )
    except Exception as exc:
        logger.error(
            "Failed to delete transcription for episode %s: %s", episode_id, exc
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete transcription: {exc}",
        ) from exc


@router.get(
    "/transcriptions/{task_id}/status",
    response_model=PodcastTranscriptionStatusResponse,
    summary="Get transcription task status",
    description="Get real-time status for one transcription task",
)
async def get_transcription_status(
    task_id: int,
    episode_service: PodcastEpisodeService = Depends(get_podcast_episode_service),
    transcription_workflow: TranscriptionWorkflowService = Depends(
        get_transcription_workflow_service,
    ),
):
    """Get real-time task status."""
    try:
        payload = await transcription_workflow.get_transcription_task_status(
            task_id,
            episode_lookup=episode_service.get_episode_by_id,
        )
        return PodcastTranscriptionStatusResponse(**payload)
    except TranscriptionTaskNotFoundError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transcription task not found",
        )
    except PermissionError as exc:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=str(exc),
        ) from exc
    except Exception as exc:
        logger.error("Failed to get transcription status for task %s: %s", task_id, exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get transcription status: {exc}",
        ) from exc


# ── Scheduling ─────────────────────────────────────────────────────────────


@router.post(
    "/episodes/{episode_id}/transcribe/schedule",
    status_code=201,
    response_model=PodcastTranscriptionScheduleResponse,
    summary="Schedule episode transcription",
    description="Schedule transcription task with frequency settings",
)
async def schedule_episode_transcription_endpoint(
    episode_id: int,
    force: bool = Body(False, description="Force retranscription"),
    frequency: str = Body("manual", description="hourly, daily, weekly, manual"),
    episode_service: PodcastEpisodeService = Depends(get_podcast_episode_service),
    transcription_workflow: TranscriptionWorkflowService = Depends(
        get_transcription_workflow_service,
    ),
):
    try:
        result = await transcription_workflow.schedule_episode_transcription(
            episode_id=episode_id,
            frequency=ScheduleFrequency(frequency),
            force=force,
            episode_lookup=episode_service.get_episode_by_id,
        )
        return build_transcription_schedule_response(result)
    except EpisodeNotFoundError:
        raise HTTPException(status_code=404, detail="Episode not found")
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except HTTPException:
        raise
    except Exception as exc:
        logger.error(
            "Failed to schedule transcription for episode %s: %s", episode_id, exc
        )
        raise HTTPException(
            status_code=500,
            detail=f"Failed to schedule transcription: {exc}",
        ) from exc


@router.get(
    "/episodes/{episode_id}/transcript",
    response_model=PodcastEpisodeTranscriptResponse,
    summary="Get existing transcript",
    description="Return transcript if already available",
)
async def get_episode_transcript_endpoint(
    episode_id: int,
    episode_service: PodcastEpisodeService = Depends(get_podcast_episode_service),
    transcription_workflow: TranscriptionWorkflowService = Depends(
        get_transcription_workflow_service,
    ),
):
    try:
        result = await transcription_workflow.get_episode_transcript_payload(
            episode_id=episode_id,
            episode_lookup=episode_service.get_episode_by_id,
        )
        return build_episode_transcript_response(result)
    except EpisodeNotFoundError:
        raise HTTPException(status_code=404, detail="Episode not found")
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except Exception as exc:
        logger.error("Failed to get transcript for episode %s: %s", episode_id, exc)
        raise HTTPException(
            status_code=500, detail=f"Failed to get transcript: {exc}"
        ) from exc


@router.post(
    "/subscriptions/{subscription_id}/transcribe/batch",
    status_code=201,
    response_model=PodcastBatchTranscriptionResponse,
    summary="Batch transcribe subscription episodes",
    description="Schedule transcription for all episodes in a subscription",
)
async def batch_transcribe_subscription_endpoint(
    subscription_id: int,
    skip_existing: bool = Body(True, description="Skip episodes already transcribed"),
    max_episodes: int = Body(50, ge=1, le=200, description="Maximum episodes to transcribe in batch"),
    subscription_service: PodcastSubscriptionService = Depends(
        get_podcast_subscription_service
    ),
    transcription_workflow: TranscriptionWorkflowService = Depends(
        get_transcription_workflow_service,
    ),
):
    try:
        result = await transcription_workflow.batch_transcribe_subscription(
            subscription_id=subscription_id,
            skip_existing=skip_existing,
            max_episodes=max_episodes,
            subscription_lookup=subscription_service.get_subscription_details,
        )
        return build_batch_transcription_response(result)
    except SubscriptionNotFoundError:
        raise HTTPException(status_code=404, detail="Subscription not found")
    except Exception as exc:
        logger.error(
            "Failed to batch transcribe subscription %s: %s", subscription_id, exc
        )
        raise HTTPException(
            status_code=500, detail=f"Failed to batch transcribe: {exc}"
        ) from exc


@router.get(
    "/episodes/{episode_id}/transcription/schedule-status",
    response_model=PodcastTranscriptionScheduleStatusResponse,
    summary="Get transcription schedule status",
    description="Get scheduling status for an episode",
)
async def get_transcription_schedule_status(
    episode_id: int,
    episode_service: PodcastEpisodeService = Depends(get_podcast_episode_service),
    transcription_workflow: TranscriptionWorkflowService = Depends(
        get_transcription_workflow_service,
    ),
):
    try:
        result = await transcription_workflow.get_schedule_status(
            episode_id=episode_id,
            episode_lookup=episode_service.get_episode_by_id,
        )
        return build_transcription_schedule_status_response(result)
    except EpisodeNotFoundError:
        raise HTTPException(status_code=404, detail="Episode not found")
    except Exception as exc:
        logger.error(
            "Failed to get transcription status for episode %s: %s",
            episode_id,
            exc,
        )
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get transcription status: {exc}",
        ) from exc


@router.post(
    "/episodes/{episode_id}/transcription/cancel",
    response_model=PodcastTranscriptionCancelResponse,
    summary="Cancel transcription task",
    description="Cancel active transcription task for an episode",
)
async def cancel_transcription_endpoint(
    episode_id: int,
    episode_service: PodcastEpisodeService = Depends(get_podcast_episode_service),
    transcription_workflow: TranscriptionWorkflowService = Depends(
        get_transcription_workflow_service,
    ),
):
    try:
        result = await transcription_workflow.cancel_episode_transcription(
            episode_id=episode_id,
            episode_lookup=episode_service.get_episode_by_id,
        )
        return build_transcription_cancel_response(result)
    except EpisodeNotFoundError:
        raise HTTPException(status_code=404, detail="Episode not found")
    except Exception as exc:
        logger.error(
            "Failed to cancel transcription for episode %s: %s", episode_id, exc
        )
        raise HTTPException(
            status_code=500, detail=f"Failed to cancel transcription: {exc}"
        ) from exc


@router.post(
    "/subscriptions/{subscription_id}/check-new-episodes",
    response_model=PodcastCheckNewEpisodesResponse,
    summary="Check and transcribe new episodes",
    description="Check recently published episodes and schedule transcription",
)
async def check_and_transcribe_new_episodes(
    subscription_id: int,
    hours_since_published: int = Body(24, description="Hours window for new episodes"),
    subscription_service: PodcastSubscriptionService = Depends(
        get_podcast_subscription_service
    ),
    transcription_workflow: TranscriptionWorkflowService = Depends(
        get_transcription_workflow_service,
    ),
):
    try:
        result = await transcription_workflow.check_and_transcribe_new_episodes(
            subscription_id=subscription_id,
            hours_since_published=hours_since_published,
            subscription_lookup=subscription_service.get_subscription_details,
        )
        return build_check_new_episodes_response(result)
    except SubscriptionNotFoundError:
        raise HTTPException(status_code=404, detail="Subscription not found")
    except Exception as exc:
        logger.error(
            "Failed to check new episodes for subscription %s: %s", subscription_id, exc
        )
        raise HTTPException(
            status_code=500, detail=f"Failed to check new episodes: {exc}"
        ) from exc


@router.get(
    "/transcriptions/pending",
    response_model=PodcastPendingTranscriptionsResponse,
    summary="Get pending transcription tasks",
    description="Get all pending tasks for current user",
)
async def get_pending_transcriptions(
    episode_service: PodcastEpisodeService = Depends(get_podcast_episode_service),
    transcription_workflow: TranscriptionWorkflowService = Depends(
        get_transcription_workflow_service,
    ),
):
    try:
        result = await transcription_workflow.list_pending_transcriptions(
            episode_lookup=episode_service.get_episode_by_id,
        )
        return build_pending_transcriptions_response(result)
    except Exception as exc:
        logger.error("Failed to get pending transcriptions: %s", exc)
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get pending transcriptions: {exc}",
        ) from exc


__all__ = ["router"]
