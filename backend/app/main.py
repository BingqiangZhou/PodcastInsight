import logging
from contextlib import asynccontextmanager
from collections.abc import AsyncGenerator

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import get_settings
from app.core.database import Base, engine
from app.core.redis import close_redis

# Import all models so they are registered with Base.metadata before create_all
import app.domains.podcast.models  # noqa: F401
import app.domains.transcription.models  # noqa: F401
import app.domains.summary.models  # noqa: F401
import app.domains.settings.models  # noqa: F401

settings = get_settings()

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Application lifespan: startup and shutdown events."""
    logger.info(f"Starting {settings.APP_NAME}...")
    # Create database tables
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    logger.info("Database tables created/verified")

    # Clean up old audio files on startup
    from app.core.whisper import cleanup_old_audio_files
    removed = cleanup_old_audio_files()
    if removed:
        logger.info(f"Startup audio cleanup: removed {removed} old files")

    yield

    # Shutdown
    logger.info("Shutting down...")
    from app.core.whisper import unload_whisper_model
    unload_whisper_model()
    await close_redis()
    await engine.dispose()
    logger.info("Shutdown complete")


app = FastAPI(
    title=settings.APP_NAME,
    description="Podcast Knowledge Hub — ranking, transcription, and AI summarization",
    version="1.0.0",
    lifespan=lifespan,
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Import and include routers
from app.domains.podcast.routes import router as podcast_router
from app.domains.transcription.routes import router as transcription_router
from app.domains.summary.routes import router as summary_router
from app.domains.settings.routes import router as settings_router

app.include_router(podcast_router, prefix="/api/v1")
app.include_router(transcription_router, prefix="/api/v1")
app.include_router(summary_router, prefix="/api/v1")
app.include_router(settings_router, prefix="/api/v1")


@app.get("/api/v1/health")
async def health_check() -> dict[str, str]:
    return {"status": "ok", "app": settings.APP_NAME}
