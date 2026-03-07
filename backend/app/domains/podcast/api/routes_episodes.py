"""Podcast episode route aggregator."""

from fastapi import APIRouter

from .routes_episode_actions import router as episode_actions_router
from .routes_episode_catalog import router as episode_catalog_router


router = APIRouter(prefix="")
router.include_router(episode_catalog_router)
router.include_router(episode_actions_router)

__all__ = ["router"]
