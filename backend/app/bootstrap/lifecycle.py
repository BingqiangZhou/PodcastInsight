"""Application lifespan bootstrap."""

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.core.config import get_settings
from app.core.database import close_db, get_async_session_factory, init_db
from app.core.logging_config import setup_logging_from_env
from app.core.redis import close_shared_redis, get_shared_redis
from app.domains.podcast.services.transcription_workflow_service import (
    TranscriptionWorkflowService,
)


logger = logging.getLogger(__name__)


@asynccontextmanager
async def application_lifespan(app: FastAPI):
    """Manage startup and shutdown lifecycle hooks."""
    setup_logging_from_env()
    settings = get_settings()

    logger.info(
        "Starting %s v%s - environment: %s",
        settings.PROJECT_NAME,
        settings.VERSION,
        settings.ENVIRONMENT,
    )
    await init_db()

    startup_lock_token: str | None = None
    try:
        startup_lock_token = await get_shared_redis().acquire_owned_lock(
            "startup:reset-stale-transcription-tasks",
            expire=300,
        )
        if startup_lock_token:
            session_factory = get_async_session_factory()
            async with session_factory() as session:
                workflow = TranscriptionWorkflowService(session)
                await workflow.reset_stale_tasks()
                logger.info("Reset stale transcription tasks during startup")
        else:
            logger.info("Skipped stale transcription reset; another worker owns startup lock")
    except Exception as exc:
        logger.error("Failed to reset stale tasks during startup: %s", exc)

    logger.info("Service startup completed")
    try:
        yield
    finally:
        if startup_lock_token:
            await get_shared_redis().release_owned_lock(
                "startup:reset-stale-transcription-tasks",
                startup_lock_token,
            )
        await close_shared_redis()
        await close_db()
        logger.info("Service shutdown completed")
