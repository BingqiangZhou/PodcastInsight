"""Base dependency providers for core application services."""

from __future__ import annotations

from collections.abc import AsyncGenerator

from app.core.config import Settings, get_settings
from app.core.database import get_db_session
from app.core.redis import PodcastRedis


async def get_db_session_dependency() -> AsyncGenerator:
    """Provide the request-scoped DB session through the provider layer."""
    async for db in get_db_session():
        yield db


async def get_redis_client() -> AsyncGenerator[PodcastRedis, None]:
    """Provide a request-scoped Redis helper and close it after the request."""
    redis = PodcastRedis()
    try:
        yield redis
    finally:
        await redis.close()


def get_settings_dependency() -> Settings:
    """Provide cached application settings."""
    return get_settings()


__all__ = [
    "get_db_session_dependency",
    "get_redis_client",
    "get_settings_dependency",
]
