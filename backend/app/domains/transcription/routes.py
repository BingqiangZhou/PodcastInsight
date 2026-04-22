import logging
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.domains.podcast.models import ProcessingStatus
from app.domains.podcast.repository import EpisodeRepository
from app.domains.podcast.schemas import SyncResponse
from app.domains.transcription.schemas import TranscriptDetail
from app.domains.transcription.service import TranscriptionService

router = APIRouter(tags=["transcription"])
logger = logging.getLogger(__name__)


@router.post("/episodes/{episode_id}/transcribe", response_model=SyncResponse)
async def transcribe_episode(
    episode_id: UUID,
    db: AsyncSession = Depends(get_db),
) -> SyncResponse:
    """Transcribe an episode. Runs inline (no Celery required)."""
    episode_repo = EpisodeRepository(db)
    episode = await episode_repo.get(episode_id)
    if episode is None:
        raise HTTPException(status_code=404, detail="Episode not found")

    if not episode.audio_url:
        raise HTTPException(status_code=400, detail="Episode has no audio URL")

    if episode.transcript_status == ProcessingStatus.PROCESSING:
        raise HTTPException(
            status_code=409, detail="Transcription already in progress"
        )

    service = TranscriptionService(db)
    try:
        await service.transcribe_episode(episode_id)
        await db.commit()
        return SyncResponse(message="Transcription complete", task_id=None)
    except Exception as e:
        await db.rollback()
        logger.error(f"Inline transcription failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/episodes/{episode_id}/transcript", response_model=TranscriptDetail)
async def get_transcript(
    episode_id: UUID,
    db: AsyncSession = Depends(get_db),
) -> TranscriptDetail:
    """Get transcript for an episode."""
    service = TranscriptionService(db)
    transcript = await service.get_transcript(episode_id)
    if transcript is None:
        raise HTTPException(status_code=404, detail="Transcript not found")
    return TranscriptDetail.model_validate(transcript)


@router.post("/episodes/{episode_id}/transcribe/retry", response_model=SyncResponse)
async def retry_transcription(
    episode_id: UUID,
    db: AsyncSession = Depends(get_db),
) -> SyncResponse:
    """Retry failed transcription for an episode."""
    episode_repo = EpisodeRepository(db)
    episode = await episode_repo.get(episode_id)
    if episode is None:
        raise HTTPException(status_code=404, detail="Episode not found")

    if episode.transcript_status != ProcessingStatus.FAILED:
        raise HTTPException(
            status_code=400,
            detail="Can only retry failed transcriptions",
        )

    service = TranscriptionService(db)
    try:
        await service.transcribe_episode(episode_id)
        await db.commit()
        return SyncResponse(message="Transcription retry complete", task_id=None)
    except Exception as e:
        await db.rollback()
        logger.error(f"Transcription retry failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))
