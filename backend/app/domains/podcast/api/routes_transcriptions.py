"""Podcast transcription routes."""
# ruff: noqa

import logging
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Body, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db_session
from app.domains.podcast.api.dependencies import (
    get_episode_service,
    get_scheduler,
    get_subscription_service,
    get_transcription_service,
)
from app.domains.podcast.models import PodcastEpisode, TranscriptionStatus
from app.domains.podcast.schemas import (
    PodcastTranscriptionDetailResponse,
    PodcastTranscriptionRequest,
    PodcastTranscriptionResponse,
    PodcastTranscriptionStatusResponse,
)
from app.domains.podcast.services.episode_service import PodcastEpisodeService
from app.domains.podcast.services.subscription_service import PodcastSubscriptionService
from app.domains.podcast.transcription_manager import DatabaseBackedTranscriptionService
from app.domains.podcast.transcription_scheduler import (
    ScheduleFrequency,
    TranscriptionScheduler,
    batch_transcribe_subscription,
    get_episode_transcript,
)
from app.domains.podcast.transcription_state import get_transcription_state_manager


router = APIRouter(prefix="")
logger = logging.getLogger(__name__)


def _status_value(status_obj) -> str:
    return status_obj.value if hasattr(status_obj, "value") else str(status_obj)


async def _validate_episode_and_permission(
    episode_id: int,
    episode_service: PodcastEpisodeService,
) -> PodcastEpisode:
    """Validate episode existence and user ownership."""
    episode = await episode_service.get_episode_by_id(episode_id)
    if not episode:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Episode {episode_id} not found",
        )
    return episode


async def _check_redis_cached_task(
    episode_id: int,
    state_manager,
    transcription_service: DatabaseBackedTranscriptionService,
    episode: PodcastEpisode,
) -> Optional[PodcastTranscriptionResponse]:
    """Return in-progress task from cache when available."""
    redis_task_id = await state_manager.get_episode_task(episode_id)
    if not redis_task_id:
        return None

    cached_progress = await state_manager.get_task_progress(redis_task_id)
    if cached_progress and cached_progress.get("status") not in ["completed", "failed"]:
        logger.info(
            "[REDIS] Returning cached in-progress task %s for episode %s",
            redis_task_id,
            episode_id,
        )
        task = await transcription_service.get_transcription_status(redis_task_id)
        if task:
            return _build_transcription_response(task, episode)
    return None


async def _check_existing_db_task(
    episode_id: int,
    force_regenerate: bool,
    transcription_service: DatabaseBackedTranscriptionService,
    episode: PodcastEpisode,
) -> Optional[PodcastTranscriptionResponse]:
    """Return existing DB task when it can be reused."""
    existing_task = await transcription_service.get_episode_transcription(episode_id)
    if not existing_task:
        return None

    existing_status = _status_value(existing_task.status)
    if existing_status == "completed" and not force_regenerate:
        logger.info(
            "[DB] Returning existing completed task %s for episode %s",
            existing_task.id,
            episode_id,
        )
        return _build_transcription_response(existing_task, episode)

    if existing_status == "in_progress" and not force_regenerate:
        state_manager = await get_transcription_state_manager()
        await state_manager.set_episode_task(episode_id, existing_task.id)
        logger.info(
            "[DB] Returning existing in-progress task %s for episode %s",
            existing_task.id,
            episode_id,
        )
        return _build_transcription_response(existing_task, episode)

    return None


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
    """Start transcription task with lock and dedupe behavior."""
    state_manager = await get_transcription_state_manager()

    try:
        episode = await _validate_episode_and_permission(
            episode_id,
            episode_service,
        )

        cached_response = await _check_redis_cached_task(
            episode_id,
            state_manager,
            transcription_service,
            episode,
        )
        if cached_response:
            return cached_response

        db_response = await _check_existing_db_task(
            episode_id,
            transcription_request.force_regenerate,
            transcription_service,
            episode,
        )
        if db_response:
            return db_response

        if transcription_request.force_regenerate:
            existing_task = await transcription_service.get_episode_transcription(
                episode_id
            )
            if existing_task:
                logger.info(
                    "[FORCE] Deleting existing task %s for regeneration",
                    existing_task.id,
                )
                await transcription_service.delete_episode_transcription(episode_id)

        return await _handle_lock_and_create_task(
            episode_id,
            episode,
            transcription_request,
            state_manager,
            transcription_service,
        )

    except HTTPException:
        raise
    except Exception as exc:
        logger.error(
            "Failed to start transcription for episode %s: %s", episode_id, exc
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to start transcription: {exc}",
        )


async def _handle_lock_and_create_task(
    episode_id: int,
    episode: PodcastEpisode,
    transcription_request: PodcastTranscriptionRequest,
    state_manager,
    transcription_service: DatabaseBackedTranscriptionService,
) -> PodcastTranscriptionResponse:
    """Acquire lock and create a new transcription task."""
    lock_acquired = await state_manager.acquire_task_lock(episode_id, 0)

    if not lock_acquired and not transcription_request.force_regenerate:
        return await _handle_locked_episode(
            episode_id,
            episode,
            state_manager,
            transcription_service,
        )

    task = None
    try:
        task = await transcription_service.start_transcription(
            episode_id,
            transcription_request.transcription_model,
        )
    finally:
        await state_manager.release_task_lock(episode_id, 0)

    if task is None:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create transcription task for episode {episode_id}",
        )

    await state_manager.acquire_task_lock(episode_id, task.id)
    await state_manager.set_episode_task(episode_id, task.id)

    await state_manager.set_task_progress(
        task.id,
        TranscriptionStatus.PENDING.value,
        0,
        "Transcription task created, waiting for worker to start...",
    )

    logger.info(
        "[CREATED] New transcription task %s for episode %s", task.id, episode_id
    )
    return _build_transcription_response(task, episode)


async def _handle_locked_episode(
    episode_id: int,
    episode: PodcastEpisode,
    state_manager,
    transcription_service: DatabaseBackedTranscriptionService,
) -> PodcastTranscriptionResponse:
    """Handle a currently locked episode."""
    locked_task_id = await state_manager.is_episode_locked(episode_id)

    if locked_task_id:
        logger.info(
            "[LOCK] Episode %s already locked by task %s", episode_id, locked_task_id
        )
        try:
            existing_task = await transcription_service.get_transcription_status(
                locked_task_id
            )
            if existing_task:
                logger.info(
                    "[LOCK] Returning existing task %s (status: %s)",
                    existing_task.id,
                    _status_value(existing_task.status),
                )
                return _build_transcription_response(existing_task, episode)

            logger.warning(
                "[LOCK] Locked task %s not found in DB, cleaning stale lock",
                locked_task_id,
            )
            await _cleanup_stale_lock(state_manager, episode_id, locked_task_id)
        except Exception as exc:
            logger.error(
                "[LOCK] Error fetching locked task %s: %s", locked_task_id, exc
            )
            await _cleanup_stale_lock(state_manager, episode_id, locked_task_id)
    else:
        logger.warning(
            "[LOCK] Episode %s is locked but no task_id found, cleaning up",
            episode_id,
        )
        await _cleanup_stale_lock(state_manager, episode_id, None)

    raise HTTPException(
        status_code=status.HTTP_409_CONFLICT,
        detail=f"Episode {episode_id} is currently being processed by another task",
    )


async def _cleanup_stale_lock(
    state_manager, episode_id: int, task_id: Optional[int]
) -> None:
    """Safely clean stale lock data."""
    try:
        if task_id:
            await state_manager.release_task_lock(episode_id, task_id)
        await state_manager.clear_episode_task(episode_id)
        logger.info("[LOCK] Cleaned stale lock for episode %s", episode_id)
    except Exception as cleanup_error:
        logger.error(
            "[LOCK] Failed to clean stale lock for episode %s: %s",
            episode_id,
            cleanup_error,
        )


def _build_transcription_response(task, episode) -> PodcastTranscriptionResponse:
    """Build standard transcription response."""
    return PodcastTranscriptionResponse(
        id=task.id,
        episode_id=task.episode_id,
        status=_status_value(task.status),
        progress_percentage=task.progress_percentage,
        original_audio_url=task.original_audio_url,
        original_file_size=task.original_file_size,
        transcript_word_count=task.transcript_word_count,
        transcript_duration=task.transcript_duration,
        transcript_content=task.transcript_content,
        error_message=task.error_message,
        error_code=task.error_code,
        download_time=task.download_time,
        conversion_time=task.conversion_time,
        transcription_time=task.transcription_time,
        chunk_size_mb=task.chunk_size_mb,
        model_used=task.model_used,
        created_at=task.created_at,
        started_at=task.started_at,
        completed_at=task.completed_at,
        updated_at=task.updated_at,
        duration_seconds=task.duration_seconds,
        total_processing_time=task.total_processing_time,
        summary_content=task.summary_content,
        summary_model_used=task.summary_model_used,
        summary_word_count=task.summary_word_count,
        summary_processing_time=task.summary_processing_time,
        summary_error_message=task.summary_error_message,
        debug_message=(task.chunk_info or {}).get("debug_message"),
        episode={
            "id": episode.id,
            "title": episode.title,
            "audio_url": episode.audio_url,
            "audio_duration": episode.audio_duration,
        },
    )


@router.get(
    "/episodes/{episode_id}/transcription",
    response_model=PodcastTranscriptionDetailResponse,
    summary="Get transcription detail",
    description="Get transcription status and result for an episode",
)
async def get_transcription(
    episode_id: int,
    include_content: bool = Query(
        True, description="Whether to include full transcript"
    ),
    episode_service: PodcastEpisodeService = Depends(get_episode_service),
    transcription_service: DatabaseBackedTranscriptionService = Depends(
        get_transcription_service
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

        task = await transcription_service.get_episode_transcription(episode_id)
        if not task:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No transcription task found for this episode",
            )

        response_data = {
            "id": task.id,
            "episode_id": task.episode_id,
            "status": _status_value(task.status),
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
            "%Y-%m-%d %H:%M:%S"
        )
        if task.started_at:
            response_data["formatted_started_at"] = task.started_at.strftime(
                "%Y-%m-%d %H:%M:%S"
            )
        if task.completed_at:
            response_data["formatted_completed_at"] = task.completed_at.strftime(
                "%Y-%m-%d %H:%M:%S"
            )

        return PodcastTranscriptionDetailResponse(**response_data)

    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to get transcription for episode %s: %s", episode_id, exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get transcription: {exc}",
        )


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
        episode = await episode_service.get_episode_by_id(episode_id)
        if not episode:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Episode {episode_id} not found",
            )

        task_id = await transcription_service.delete_episode_transcription(episode_id)

        if task_id:
            logger.info(
                "[DELETE] Deleted transcription task %s for episode %s",
                task_id,
                episode_id,
            )
            try:
                await state_manager.clear_episode_task(episode_id)
                await state_manager.release_task_lock(episode_id, task_id)
                await state_manager.clear_task_progress(task_id)
            except Exception as redis_error:
                logger.warning("[DELETE] Failed to cleanup redis: %s", redis_error)
        else:
            logger.info(
                "[DELETE] No DB task found for episode %s, cleaning stale lock",
                episode_id,
            )
            try:
                await state_manager.clear_episode_task(episode_id)
                locked_task_id = await state_manager.is_episode_locked(episode_id)
                if locked_task_id:
                    await state_manager.release_task_lock(episode_id, locked_task_id)
                    await state_manager.clear_task_progress(locked_task_id)
            except Exception as redis_error:
                logger.warning(
                    "[DELETE] Failed to cleanup stale locks: %s", redis_error
                )

        return {
            "message": "Transcription task deleted successfully",
            "episode_id": episode_id,
        }

    except HTTPException:
        raise
    except Exception as exc:
        logger.error(
            "Failed to delete transcription for episode %s: %s", episode_id, exc
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to delete transcription: {exc}",
        )


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

        status_key = _status_value(task.status)
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
                current_chunk = int(
                    ((task.progress_percentage - 45) / 50) * total_chunks
                )

        eta_seconds = None
        if task.started_at and status_key not in ["completed", "failed", "cancelled"]:
            elapsed = (datetime.now(timezone.utc) - task.started_at).total_seconds()
            if task.progress_percentage > 0:
                estimated_total = elapsed / (task.progress_percentage / 100)
                eta_seconds = int(estimated_total - elapsed)

        response_data = {
            "task_id": task.id,
            "episode_id": task.episode_id,
            "status": status_key,
            "progress": task.progress_percentage,
            "message": status_messages.get(status_key, "Unknown status"),
            "current_chunk": current_chunk,
            "total_chunks": total_chunks,
            "eta_seconds": eta_seconds,
        }

        return PodcastTranscriptionStatusResponse(**response_data)

    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to get transcription status for task %s: %s", task_id, exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get transcription status: {exc}",
        )


@router.post(
    "/episodes/{episode_id}/transcribe/schedule",
    status_code=status.HTTP_201_CREATED,
    summary="Schedule episode transcription",
    description="Schedule transcription task with frequency settings",
)
async def schedule_episode_transcription_endpoint(
    episode_id: int,
    force: bool = Body(False, description="Force retranscription"),
    frequency: str = Body("manual", description="hourly, daily, weekly, manual"),
    episode_service: PodcastEpisodeService = Depends(get_episode_service),
    scheduler: TranscriptionScheduler = Depends(get_scheduler),
    db: AsyncSession = Depends(get_db_session),
):
    """Schedule episode transcription with dedupe behavior."""
    try:
        episode = await episode_service.get_episode_by_id(episode_id)
        if not episode:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Episode {episode_id} not found",
            )

        existing_transcript = await get_episode_transcript(db, episode_id)
        if existing_transcript and not force:
            return {
                "status": "skipped",
                "message": "Transcription already exists. Use force=true to re-transcribe.",
                "episode_id": episode_id,
                "transcript_preview": (
                    existing_transcript[:100] + "..."
                    if len(existing_transcript) > 100
                    else existing_transcript
                ),
            }

        result = await scheduler.schedule_transcription(
            episode_id=episode_id,
            frequency=ScheduleFrequency(frequency),
            force=force,
        )
        return result

    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except HTTPException:
        raise
    except Exception as exc:
        logger.error(
            "Failed to schedule transcription for episode %s: %s", episode_id, exc
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to schedule transcription: {exc}",
        )


@router.get(
    "/episodes/{episode_id}/transcript",
    summary="Get existing transcript",
    description="Return transcript if already available",
)
async def get_episode_transcript_endpoint(
    episode_id: int,
    episode_service: PodcastEpisodeService = Depends(get_episode_service),
    db: AsyncSession = Depends(get_db_session),
):
    """Fetch transcript content without scheduling new task."""
    try:
        episode = await episode_service.get_episode_by_id(episode_id)
        if not episode:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Episode {episode_id} not found",
            )

        transcript = await get_episode_transcript(db, episode_id)
        if not transcript:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No transcription found for this episode. Please schedule transcription first.",
            )

        return {
            "episode_id": episode_id,
            "episode_title": episode.title,
            "transcript_length": len(transcript),
            "transcript": transcript,
            "status": "success",
        }

    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to get transcript for episode %s: %s", episode_id, exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get transcript: {exc}",
        )


@router.post(
    "/subscriptions/{subscription_id}/transcribe/batch",
    status_code=status.HTTP_201_CREATED,
    summary="Batch transcribe subscription episodes",
    description="Schedule transcription for all episodes in a subscription",
)
async def batch_transcribe_subscription_endpoint(
    subscription_id: int,
    skip_existing: bool = Body(True, description="Skip episodes already transcribed"),
    subscription_service: PodcastSubscriptionService = Depends(
        get_subscription_service
    ),
    db: AsyncSession = Depends(get_db_session),
):
    """Batch schedule transcription for a subscription."""
    try:
        subscription = await subscription_service.get_subscription_details(
            subscription_id
        )
        if not subscription:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Subscription {subscription_id} not found",
            )

        result = await batch_transcribe_subscription(
            db,
            subscription_id,
            skip_existing=skip_existing,
        )
        return result

    except HTTPException:
        raise
    except Exception as exc:
        logger.error(
            "Failed to batch transcribe subscription %s: %s",
            subscription_id,
            exc,
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to batch transcribe: {exc}",
        )


@router.get(
    "/episodes/{episode_id}/transcription/schedule-status",
    summary="Get transcription schedule status",
    description="Get scheduling status for an episode",
)
async def get_transcription_schedule_status(
    episode_id: int,
    episode_service: PodcastEpisodeService = Depends(get_episode_service),
    scheduler: TranscriptionScheduler = Depends(get_scheduler),
):
    """Get detailed schedule status for an episode."""
    try:
        episode = await episode_service.get_episode_by_id(episode_id)
        if not episode:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Episode {episode_id} not found",
            )

        return await scheduler.get_transcription_status(episode_id)

    except HTTPException:
        raise
    except Exception as exc:
        logger.error(
            "Failed to get transcription status for episode %s: %s", episode_id, exc
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get transcription status: {exc}",
        )


@router.post(
    "/episodes/{episode_id}/transcription/cancel",
    summary="Cancel transcription task",
    description="Cancel active transcription task for an episode",
)
async def cancel_transcription_endpoint(
    episode_id: int,
    episode_service: PodcastEpisodeService = Depends(get_episode_service),
    scheduler: TranscriptionScheduler = Depends(get_scheduler),
):
    """Cancel active transcription task."""
    try:
        episode = await episode_service.get_episode_by_id(episode_id)
        if not episode:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Episode {episode_id} not found",
            )

        success = await scheduler.cancel_transcription(episode_id)
        return {
            "success": success,
            "message": "Transcription cancelled"
            if success
            else "No active transcription to cancel",
        }

    except HTTPException:
        raise
    except Exception as exc:
        logger.error(
            "Failed to cancel transcription for episode %s: %s", episode_id, exc
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to cancel transcription: {exc}",
        )


@router.post(
    "/subscriptions/{subscription_id}/check-new-episodes",
    summary="Check and transcribe new episodes",
    description="Check recently published episodes and schedule transcription",
)
async def check_and_transcribe_new_episodes(
    subscription_id: int,
    hours_since_published: int = Body(24, description="Hours window for new episodes"),
    subscription_service: PodcastSubscriptionService = Depends(
        get_subscription_service
    ),
    scheduler: TranscriptionScheduler = Depends(get_scheduler),
):
    """Check recent episodes and schedule transcription."""
    try:
        subscription = await subscription_service.get_subscription_details(
            subscription_id
        )
        if not subscription:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Subscription {subscription_id} not found",
            )

        return await scheduler.check_and_transcribe_new_episodes(
            subscription_id=subscription_id,
            hours_since_published=hours_since_published,
        )

    except HTTPException:
        raise
    except Exception as exc:
        logger.error(
            "Failed to check new episodes for subscription %s: %s",
            subscription_id,
            exc,
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to check new episodes: {exc}",
        )


@router.get(
    "/transcriptions/pending",
    summary="Get pending transcription tasks",
    description="Get all pending tasks for current user",
)
async def get_pending_transcriptions(
    episode_service: PodcastEpisodeService = Depends(get_episode_service),
    scheduler: TranscriptionScheduler = Depends(get_scheduler),
):
    """List pending tasks filtered to current user episodes."""
    try:
        tasks = await scheduler.get_pending_transcriptions()

        user_tasks = []
        for task in tasks:
            episode = await episode_service.get_episode_by_id(task["episode_id"])
            if episode:
                user_tasks.append(task)

        return {"total": len(user_tasks), "tasks": user_tasks}

    except Exception as exc:
        logger.error("Failed to get pending transcriptions: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to get pending transcriptions: {exc}",
        )
