"""Podcast transcription scheduling and transcript retrieval routes."""

import logging

from fastapi import APIRouter, Body, Depends, HTTPException

from app.domains.podcast.api.dependencies import (
    get_episode_service,
    get_subscription_service,
    get_transcription_workflow_service,
)
from app.domains.podcast.services.episode_service import PodcastEpisodeService
from app.domains.podcast.services.subscription_service import PodcastSubscriptionService
from app.domains.podcast.services.transcription_workflow_service import (
    TranscriptionWorkflowService,
)
from app.domains.podcast.transcription_scheduler import ScheduleFrequency


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
    transcription_workflow: TranscriptionWorkflowService = Depends(
        get_transcription_workflow_service
    ),
):
    try:
        return await transcription_workflow.schedule_episode_transcription(
            episode_id,
            frequency=ScheduleFrequency(frequency),
            force=force,
            episode_lookup=episode_service.get_episode_by_id,
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
    transcription_workflow: TranscriptionWorkflowService = Depends(
        get_transcription_workflow_service
    ),
):
    try:
        return await transcription_workflow.get_episode_transcript_payload(
            episode_id,
            episode_lookup=episode_service.get_episode_by_id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except Exception as exc:
        logger.error("Failed to get transcript for episode %s: %s", episode_id, exc)
        raise HTTPException(status_code=500, detail=f"Failed to get transcript: {exc}") from exc


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
    transcription_workflow: TranscriptionWorkflowService = Depends(
        get_transcription_workflow_service
    ),
):
    try:
        return await transcription_workflow.batch_transcribe_subscription(
            subscription_id,
            skip_existing=skip_existing,
            subscription_lookup=subscription_service.get_subscription_details,
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except Exception as exc:
        logger.error("Failed to batch transcribe subscription %s: %s", subscription_id, exc)
        raise HTTPException(status_code=500, detail=f"Failed to batch transcribe: {exc}") from exc


@router.get(
    "/episodes/{episode_id}/transcription/schedule-status",
    summary="Get transcription schedule status",
    description="Get scheduling status for an episode",
)
async def get_transcription_schedule_status(
    episode_id: int,
    episode_service: PodcastEpisodeService = Depends(get_episode_service),
    transcription_workflow: TranscriptionWorkflowService = Depends(
        get_transcription_workflow_service
    ),
):
    try:
        return await transcription_workflow.get_schedule_status(
            episode_id,
            episode_lookup=episode_service.get_episode_by_id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
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
    transcription_workflow: TranscriptionWorkflowService = Depends(
        get_transcription_workflow_service
    ),
):
    try:
        return await transcription_workflow.cancel_episode_transcription(
            episode_id,
            episode_lookup=episode_service.get_episode_by_id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except Exception as exc:
        logger.error("Failed to cancel transcription for episode %s: %s", episode_id, exc)
        raise HTTPException(status_code=500, detail=f"Failed to cancel transcription: {exc}") from exc


@router.post(
    "/subscriptions/{subscription_id}/check-new-episodes",
    summary="Check and transcribe new episodes",
    description="Check recently published episodes and schedule transcription",
)
async def check_and_transcribe_new_episodes(
    subscription_id: int,
    hours_since_published: int = Body(24, description="Hours window for new episodes"),
    subscription_service: PodcastSubscriptionService = Depends(get_subscription_service),
    transcription_workflow: TranscriptionWorkflowService = Depends(
        get_transcription_workflow_service
    ),
):
    try:
        return await transcription_workflow.check_and_transcribe_new_episodes(
            subscription_id,
            hours_since_published=hours_since_published,
            subscription_lookup=subscription_service.get_subscription_details,
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except Exception as exc:
        logger.error("Failed to check new episodes for subscription %s: %s", subscription_id, exc)
        raise HTTPException(status_code=500, detail=f"Failed to check new episodes: {exc}") from exc


@router.get(
    "/transcriptions/pending",
    summary="Get pending transcription tasks",
    description="Get all pending tasks for current user",
)
async def get_pending_transcriptions(
    episode_service: PodcastEpisodeService = Depends(get_episode_service),
    transcription_workflow: TranscriptionWorkflowService = Depends(
        get_transcription_workflow_service
    ),
):
    try:
        return await transcription_workflow.list_pending_transcriptions(
            episode_lookup=episode_service.get_episode_by_id,
        )
    except Exception as exc:
        logger.error("Failed to get pending transcriptions: %s", exc)
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get pending transcriptions: {exc}",
        ) from exc
