"""Base dependency providers for core application services."""

from __future__ import annotations

from collections.abc import AsyncGenerator

from app.core.config import Settings, get_settings
from app.core.database import get_db_session, get_read_db_session
from app.core.redis import PodcastRedis, get_shared_redis


async def get_db_session_dependency() -> AsyncGenerator:
    """Provide the request-scoped DB session through the provider layer."""
    async for db in get_db_session():
        yield db


async def get_read_db_session_dependency() -> AsyncGenerator:
    """Provide the request-scoped DB session from the read replica.

    Falls back to the primary database when no read replica is configured.
    Use for read-only GET endpoints that don't require write consistency.
    """
    async for db in get_read_db_session():
        yield db


async def get_redis_client() -> PodcastRedis:
    """Provide the shared Redis helper (process-level singleton with connection pooling).

    The shared instance lives for the process lifetime and is closed on shutdown
    via close_shared_redis() in the application lifecycle.
    """
    return get_shared_redis()


def get_settings_dependency() -> Settings:
    """Provide cached application settings."""
    return get_settings()


__all__ = [
    "get_db_session_dependency",
    "get_read_db_session_dependency",
    "get_redis_client",
    "get_settings_dependency",
]
