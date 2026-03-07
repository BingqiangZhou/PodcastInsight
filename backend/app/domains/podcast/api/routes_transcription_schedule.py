"""Podcast transcription scheduling and transcript retrieval routes."""

import logging

from fastapi import APIRouter, Body, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db_session
from app.domains.podcast.api.dependencies import (
    get_episode_service,
    get_scheduler,
    get_subscription_service,
)
from app.domains.podcast.services.episode_service import PodcastEpisodeService
from app.domains.podcast.services.subscription_service import PodcastSubscriptionService
from app.domains.podcast.transcription_scheduler import (
    ScheduleFrequency,
    TranscriptionScheduler,
    batch_transcribe_subscription,
    get_episode_transcript,
)


router = APIRouter(prefix="")
logger = logging.getLogger(__name__)


@router.post(
    "/episodes/{episode_id}/transcribe/schedule",
    status_code=201,
    summary="Schedule episode transcription",
    description="Schedule transcription task with frequency settings",
)
async def schedule_episode_transcription_endpoint(
    episode_id: int,
    force: bool = Body(False, description="Force retranscription"),
    frequency: str = Body("manual", description="hourly, daily, weekly, manual"),
    episode_service: PodcastEpisodeService = Depends(get_episode_service),
    scheduler: TranscriptionScheduler = Depends(get_scheduler),
):
    """Schedule episode transcription with dedupe behavior."""
    try:
        episode = await episode_service.get_episode_by_id(episode_id)
        if not episode:
            raise HTTPException(status_code=404, detail=f"Episode {episode_id} not found")

        return await scheduler.schedule_transcription(
            episode_id=episode_id,
            frequency=ScheduleFrequency(frequency),
            force=force,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to schedule transcription for episode %s: %s", episode_id, exc)
        raise HTTPException(
            status_code=500,
            detail=f"Failed to schedule transcription: {exc}",
        ) from exc


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
            raise HTTPException(status_code=404, detail=f"Episode {episode_id} not found")

        transcript = await get_episode_transcript(db, episode_id)
        if not transcript:
            raise HTTPException(
                status_code=404,
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
            status_code=500,
            detail=f"Failed to get transcript: {exc}",
        ) from exc


@router.post(
    "/subscriptions/{subscription_id}/transcribe/batch",
    status_code=201,
    summary="Batch transcribe subscription episodes",
    description="Schedule transcription for all episodes in a subscription",
)
async def batch_transcribe_subscription_endpoint(
    subscription_id: int,
    skip_existing: bool = Body(True, description="Skip episodes already transcribed"),
    subscription_service: PodcastSubscriptionService = Depends(get_subscription_service),
    db: AsyncSession = Depends(get_db_session),
):
    """Batch schedule transcription for a subscription."""
    try:
        subscription = await subscription_service.get_subscription_details(subscription_id)
        if not subscription:
            raise HTTPException(
                status_code=404,
                detail=f"Subscription {subscription_id} not found",
            )

        return await batch_transcribe_subscription(
            db,
            subscription_id,
            skip_existing=skip_existing,
        )
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to batch transcribe subscription %s: %s", subscription_id, exc)
        raise HTTPException(
            status_code=500,
            detail=f"Failed to batch transcribe: {exc}",
        ) from exc


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
            raise HTTPException(status_code=404, detail=f"Episode {episode_id} not found")
        return await scheduler.get_transcription_status(episode_id)
    except HTTPException:
        raise
    except Exception as exc:
        logger.error(
            "Failed to get transcription status for episode %s: %s", episode_id, exc
        )
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get transcription status: {exc}",
        ) from exc


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
            raise HTTPException(status_code=404, detail=f"Episode {episode_id} not found")

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
        logger.error("Failed to cancel transcription for episode %s: %s", episode_id, exc)
        raise HTTPException(
            status_code=500,
            detail=f"Failed to cancel transcription: {exc}",
        ) from exc


@router.post(
    "/subscriptions/{subscription_id}/check-new-episodes",
    summary="Check and transcribe new episodes",
    description="Check recently published episodes and schedule transcription",
)
async def check_and_transcribe_new_episodes(
    subscription_id: int,
    hours_since_published: int = Body(24, description="Hours window for new episodes"),
    subscription_service: PodcastSubscriptionService = Depends(get_subscription_service),
    scheduler: TranscriptionScheduler = Depends(get_scheduler),
):
    """Check recent episodes and schedule transcription."""
    try:
        subscription = await subscription_service.get_subscription_details(subscription_id)
        if not subscription:
            raise HTTPException(
                status_code=404,
                detail=f"Subscription {subscription_id} not found",
            )

        return await scheduler.check_and_transcribe_new_episodes(
            subscription_id=subscription_id,
            hours_since_published=hours_since_published,
        )
    except HTTPException:
        raise
    except Exception as exc:
        logger.error("Failed to check new episodes for subscription %s: %s", subscription_id, exc)
        raise HTTPException(
            status_code=500,
            detail=f"Failed to check new episodes: {exc}",
        ) from exc


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
            status_code=500,
            detail=f"Failed to get pending transcriptions: {exc}",
        ) from exc
