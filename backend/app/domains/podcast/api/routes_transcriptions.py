"""Podcast transcription route aggregator."""

from fastapi import APIRouter

from .routes_transcription_schedule import router as transcription_schedule_router
from .routes_transcription_tasks import router as transcription_tasks_router


router = APIRouter(prefix="")
router.include_router(transcription_tasks_router)
router.include_router(transcription_schedule_router)

__all__ = ["router"]
