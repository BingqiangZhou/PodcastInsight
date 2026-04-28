import logging
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.domains.podcast.models import ProcessingStatus
from app.domains.podcast.schemas import (
    EpisodeDetail,
    EpisodeListResponse,
    PodcastDetail,
    PodcastListResponse,
    PodcastTrackResponse,
)
from app.domains.podcast.service import EpisodeService, PodcastService

router = APIRouter(tags=["podcasts"])
logger = logging.getLogger(__name__)


@router.get("/podcasts", response_model=PodcastListResponse)
async def list_podcasts(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    category: str | None = Query(None),
    is_tracked: bool | None = Query(None),
    search: str | None = Query(None),
    db: AsyncSession = Depends(get_db),
) -> PodcastListResponse:
    service = PodcastService(db)
    return await service.list_podcasts(
        page=page,
        page_size=page_size,
        category=category,
        is_tracked=is_tracked,
        search=search,
    )


@router.get("/podcasts/{podcast_id}", response_model=PodcastDetail)
async def get_podcast(
    podcast_id: UUID,
    db: AsyncSession = Depends(get_db),
) -> PodcastDetail:
    service = PodcastService(db)
    podcast = await service.get_podcast(podcast_id)
    if podcast is None:
        raise HTTPException(status_code=404, detail="Podcast not found")
    return podcast


@router.post("/podcasts/{podcast_id}/track", response_model=PodcastTrackResponse)
async def toggle_track_podcast(
    podcast_id: UUID,
    db: AsyncSession = Depends(get_db),
) -> PodcastTrackResponse:
    service = PodcastService(db)
    podcast = await service.get_podcast(podcast_id)
    if podcast is None:
        raise HTTPException(status_code=404, detail="Podcast not found")

    if podcast.is_tracked:
        result = await service.untrack_podcast(podcast_id)
    else:
        result = await service.track_podcast(podcast_id)

    if result is None:
        raise HTTPException(status_code=404, detail="Podcast not found")
    return result


class PriorityRequest(BaseModel):
    priority: int


@router.patch("/podcasts/{podcast_id}/priority")
async def set_podcast_priority(
    podcast_id: UUID,
    data: PriorityRequest,
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Set priority for a podcast (0=normal, 5=high, 9=urgent)."""
    service = PodcastService(db)
    from app.domains.podcast.repository import PodcastRepository
    repo = PodcastRepository(db)
    podcast = await repo.get(podcast_id)
    if podcast is None:
        raise HTTPException(status_code=404, detail="Podcast not found")

    await repo.update(podcast_id, {"priority": max(0, min(9, data.priority))})
    await db.commit()
    return {"message": "Priority updated", "priority": data.priority}


@router.post("/podcasts/sync")
async def sync_podcasts(
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Sync podcast rankings from xyzrank.com. Runs inline (no Celery required)."""
    service = PodcastService(db)
    try:
        result = await service.sync_rankings()
        await db.commit()
        return {"message": "Ranking sync complete", **result}
    except Exception as e:
        await db.rollback()
        logger.error(f"Ranking sync failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/episodes/sync")
async def sync_episodes(
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Sync episodes from RSS feeds for tracked podcasts. Runs inline."""
    service = EpisodeService(db)
    try:
        result = await service.sync_episodes()
        await db.commit()

        # Dispatch transcription tasks for new episodes with priority
        new_episode_ids = result.get("new_episode_ids", [])
        if new_episode_ids:
            import asyncio
            from app.domains.podcast.tasks import _get_episode_priorities, dispatch_transcription_tasks

            priorities = await _get_episode_priorities(new_episode_ids)
            dispatch_transcription_tasks(new_episode_ids, priorities)
            logger.info(f"Dispatched transcription for {len(new_episode_ids)} new episodes")

        return {"message": "Episode sync complete", **result}
    except Exception as e:
        await db.rollback()
        logger.error(f"Episode sync failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/stats/production")
async def get_production_stats(
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Get content production statistics."""
    service = PodcastService(db)
    return await service.get_production_stats()


@router.get("/episodes", response_model=EpisodeListResponse)
async def list_episodes(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    podcast_id: UUID | None = Query(None),
    transcript_status: ProcessingStatus | None = Query(None),
    summary_status: ProcessingStatus | None = Query(None),
    db: AsyncSession = Depends(get_db),
) -> EpisodeListResponse:
    service = EpisodeService(db)
    return await service.list_episodes(
        page=page,
        page_size=page_size,
        podcast_id=podcast_id,
        transcript_status=transcript_status,
        summary_status=summary_status,
    )


@router.get("/episodes/{episode_id}", response_model=EpisodeDetail)
async def get_episode(
    episode_id: UUID,
    db: AsyncSession = Depends(get_db),
) -> EpisodeDetail:
    service = EpisodeService(db)
    episode = await service.get_episode(episode_id)
    if episode is None:
        raise HTTPException(status_code=404, detail="Episode not found")
    return episode


@router.get("/podcasts/{podcast_id}/episodes", response_model=EpisodeListResponse)
async def get_podcast_episodes(
    podcast_id: UUID,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
) -> EpisodeListResponse:
    service = EpisodeService(db)
    return await service.list_episodes(
        page=page,
        page_size=page_size,
        podcast_id=podcast_id,
    )
