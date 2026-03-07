"""Podcast transcription task lifecycle routes."""

import logging
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.domains.podcast.api.dependencies import (
    get_episode_service,
    get_transcription_service,
)
from app.domains.podcast.api.transcription_route_common import (
    build_transcription_response,
    status_value,
    validate_episode_and_permission,
)
from app.domains.podcast.schemas import (
    PodcastTranscriptionDetailResponse,
    PodcastTranscriptionRequest,
    PodcastTranscriptionResponse,
    PodcastTranscriptionStatusResponse,
)
from app.domains.podcast.services.episode_service import PodcastEpisodeService
from app.domains.podcast.transcription_manager import DatabaseBackedTranscriptionService
from app.domains.podcast.transcription_state import get_transcription_state_manager


router = APIRouter(prefix="")
logger = logging.getLogger(__name__)


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
    episode_service: PodcastEpisodeService = Depends(get_episode_service),
    transcription_service: DatabaseBackedTranscriptionService = Depends(
        get_transcription_service
    ),
):
    """Start transcription task via centralized service dedupe."""
    state_manager = await get_transcription_state_manager()

    try:
        episode = await validate_episode_and_permission(episode_id, episode_service)
        start_result = await transcription_service.start_transcription(
            episode_id,
            transcription_request.transcription_model,
            transcription_request.force_regenerate,
        )
        task = start_result["task"]
        action = start_result["action"]

        await state_manager.set_episode_task(episode_id, task.id)
        if action in {
            "created",
            "redispatched_pending",
            "redispatched_failed_with_temp",
        }:
            await state_manager.set_task_progress(
                task.id,
                "pending",
                task.progress_percentage or 0,
                "Transcription task queued",
            )
        elif action == "reused_in_progress":
            await state_manager.set_task_progress(
                task.id,
                "in_progress",
                task.progress_percentage or 0,
                "Transcription task already in progress",
            )

        return build_transcription_response(task, episode)
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to start transcription for episode %s: %s", episode_id, exc)
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
    include_content: bool = Query(True, description="Whether to include full transcript"),
    episode_service: PodcastEpisodeService = Depends(get_episode_service),
    transcription_service: DatabaseBackedTranscriptionService = Depends(
        get_transcription_service
    ),
):
    """Get detailed transcription info for one episode."""
    try:
        episode = await validate_episode_and_permission(episode_id, episode_service)
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
            response_data["formatted_duration"] = f"{hours:02d}:{minutes:02d}:{seconds:02d}"
        if task.total_processing_time:
            response_data["formatted_processing_time"] = (
                f"{task.total_processing_time:.2f} seconds"
            )

        response_data["formatted_created_at"] = task.created_at.strftime("%Y-%m-%d %H:%M:%S")
        if task.started_at:
            response_data["formatted_started_at"] = task.started_at.strftime("%Y-%m-%d %H:%M:%S")
        if task.completed_at:
            response_data["formatted_completed_at"] = task.completed_at.strftime("%Y-%m-%d %H:%M:%S")

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
    episode_service: PodcastEpisodeService = Depends(get_episode_service),
    transcription_service: DatabaseBackedTranscriptionService = Depends(
        get_transcription_service
    ),
):
    """Delete transcription task and cleanup redis state."""
    state_manager = await get_transcription_state_manager()

    try:
        await validate_episode_and_permission(episode_id, episode_service)
        task_id = await transcription_service.delete_episode_transcription(episode_id)

        if task_id:
            logger.info("[DELETE] Deleted transcription task %s for episode %s", task_id, episode_id)
            try:
                await state_manager.clear_episode_task(episode_id)
                await state_manager.release_task_lock(episode_id, task_id)
                await state_manager.clear_task_progress(task_id)
            except Exception as redis_error:
                logger.warning("[DELETE] Failed to cleanup redis: %s", redis_error)
        else:
            logger.info("[DELETE] No DB task found for episode %s, cleaning stale lock", episode_id)
            try:
                await state_manager.clear_episode_task(episode_id)
                locked_task_id = await state_manager.is_episode_locked(episode_id)
                if locked_task_id:
                    await state_manager.release_task_lock(episode_id, locked_task_id)
                    await state_manager.clear_task_progress(locked_task_id)
            except Exception as redis_error:
                logger.warning("[DELETE] Failed to cleanup stale locks: %s", redis_error)

        return {
            "message": "Transcription task deleted successfully",
            "episode_id": episode_id,
        }
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to delete transcription for episode %s: %s", episode_id, exc)
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
    episode_service: PodcastEpisodeService = Depends(get_episode_service),
    transcription_service: DatabaseBackedTranscriptionService = Depends(
        get_transcription_service
    ),
):
    """Get real-time task status."""
    try:
        task = await transcription_service.get_transcription_status(task_id)
        if not task:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Transcription task not found",
            )

        episode = await episode_service.get_episode_by_id(task.episode_id)
        if not episode:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You don't have permission to access this transcription task",
            )

        status_key = status_value(task.status)
        status_messages = {
            "pending": "Waiting to start",
            "downloading": "Downloading audio file",
            "converting": "Converting audio format",
            "splitting": "Splitting audio into chunks",
            "transcribing": "Transcribing audio",
            "merging": "Merging transcription output",
            "completed": "Transcription completed",
            "failed": "Transcription failed",
            "cancelled": "Transcription cancelled",
        }

        current_chunk = 0
        total_chunks = 0
        if task.chunk_info and "chunks" in task.chunk_info:
            total_chunks = len(task.chunk_info["chunks"])
            if status_key == "transcribing" and task.progress_percentage > 45:
                current_chunk = int(((task.progress_percentage - 45) / 50) * total_chunks)

        eta_seconds = None
        if task.started_at and status_key not in ["completed", "failed", "cancelled"]:
            elapsed = (datetime.now(timezone.utc) - task.started_at).total_seconds()
            if task.progress_percentage > 0:
                estimated_total = elapsed / (task.progress_percentage / 100)
                eta_seconds = int(estimated_total - elapsed)

        return PodcastTranscriptionStatusResponse(
            task_id=task.id,
            episode_id=task.episode_id,
            status=status_key,
            progress=task.progress_percentage,
            message=status_messages.get(status_key, "Unknown status"),
            current_chunk=current_chunk,
            total_chunks=total_chunks,
            eta_seconds=eta_seconds,
        )
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to get transcription status for task %s: %s", task_id, exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get transcription status: {exc}",
        ) from exc
