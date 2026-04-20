"""Application lifespan bootstrap."""

import asyncio
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.core.config import get_settings
from app.core.database import (
    check_db_readiness,
    close_db,
    get_async_session_factory,
    init_db,
)
from app.core.http_client import close_shared_http_session
from app.core.logging_config import setup_logging_from_env
from app.core.redis import close_shared_redis, get_shared_redis
from app.domains.podcast.services.transcription_service import (
    TranscriptionWorkflowService,
)


logger = logging.getLogger(__name__)


async def verify_critical_services() -> dict[str, bool]:
    """Verify all critical services are healthy before accepting traffic.

    Returns:
        Dictionary with service names and their health status.
    """
    checks = {}

    # Database connectivity
    try:
        async with asyncio.timeout(5.0):
            db_status = await check_db_readiness()
            checks["database"] = db_status.get("status") == "healthy"
            if not checks["database"]:
                logger.error(
                    "Database health check failed: %s",
                    db_status.get("error", "Unknown error"),
                )
    except TimeoutError:
        checks["database"] = False
        logger.error("Database health check timed out after 5 seconds")
    except Exception as exc:
        checks["database"] = False
        logger.error("Database health check failed: %s", exc)

    # Redis connectivity
    try:
        async with asyncio.timeout(3.0):
            redis_status = await get_shared_redis().check_health()
            checks["redis"] = redis_status.get("status") == "healthy"
            if not checks["redis"]:
                logger.error(
                    "Redis health check failed: %s",
                    redis_status.get("error", "Unknown error"),
                )
    except TimeoutError:
        checks["redis"] = False
        logger.error("Redis health check timed out after 3 seconds")
    except Exception as exc:
        checks["redis"] = False
        logger.error("Redis health check failed: %s", exc)

    return checks


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

    # Validate production configuration
    config_issues = settings.validate_production_config()
    if config_issues:
        for issue in config_issues:
            logger.warning("Configuration warning: %s", issue)


    if settings.ENVIRONMENT == "production" and settings.DEBUG:
        logger.warning("DEBUG is enabled in production — set DEBUG=false")

    # Initialize database
    await init_db()

    # Verify critical services are healthy
    logger.info("Verifying critical services health...")
    service_health = await verify_critical_services()

    unhealthy_services = [
        service for service, healthy in service_health.items() if not healthy
    ]

    if unhealthy_services:
        logger.error(
            "Critical services unhealthy: %s. "
            "Application will continue with degraded functionality.",
            ", ".join(unhealthy_services),
        )
        # Store health status in app state for graceful degradation
        app.state.degraded_services = unhealthy_services
        app.state.service_health = service_health
    else:
        logger.info("All critical services are healthy")
        app.state.degraded_services = []
        app.state.service_health = service_health

    startup_lock_acquired = False
    try:
        startup_lock_acquired = await get_shared_redis().acquire_lock(
            "startup:reset-stale-transcription-tasks",
            expire=300,
        )
        if startup_lock_acquired:
            session_factory = get_async_session_factory()
            async with session_factory() as session:
                workflow = TranscriptionWorkflowService(session)
                try:
                    async with asyncio.timeout(
                        settings.TRANSCRIPTION_STARTUP_RESET_TIMEOUT_SECONDS,
                    ):
                        await workflow.reset_stale_tasks()
                    logger.info("Reset stale transcription tasks during startup")
                except TimeoutError:
                    logger.warning(
                        "Timed out resetting stale transcription tasks during startup after %.1fs",
                        settings.TRANSCRIPTION_STARTUP_RESET_TIMEOUT_SECONDS,
                    )
        else:
            logger.info(
                "Skipped stale transcription reset; another worker owns startup lock"
            )
    except Exception as exc:
        logger.error("Failed to reset stale tasks during startup: %s", exc)

    logger.info("Service startup completed")
    try:
        yield
    finally:
        if startup_lock_acquired:
            await get_shared_redis().release_lock(
                "startup:reset-stale-transcription-tasks",
            )
        # Shutdown order: DB first (stops new queries),
        # then HTTP (in-flight requests complete),
        # then Redis (last since in-flight HTTP may need cache).
        await close_db()
        await close_shared_http_session()
        await close_shared_redis()
        logger.info("Service shutdown completed")
