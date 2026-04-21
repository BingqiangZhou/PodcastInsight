"""Authentication and request-level FastAPI dependencies.

Single-user mode: API key authentication via Authorization header or
X-API-Key header. User ID is hardcoded to 1.
"""

from __future__ import annotations

import logging
import secrets
from collections.abc import AsyncGenerator

from fastapi import HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.database import get_db_session


logger = logging.getLogger(__name__)

# Hardcoded single-user ID
SINGLE_USER_ID = 1


# ── Auth dependency ──────────────────────────────────────────────────────────


def _extract_api_key(request: Request) -> str | None:
    """Extract API key from Authorization: Bearer <key> or X-API-Key header."""
    authorization = request.headers.get("Authorization")
    if authorization:
        if authorization.startswith("Bearer "):
            return authorization[7:]
        return authorization

    x_api_key = request.headers.get("X-API-Key")
    if x_api_key:
        return x_api_key

    return None


async def require_api_key(request: Request) -> int:
    """Validate API key and return the hardcoded single-user ID.

    Raises HTTPException 401 if the key is missing or invalid.
    """
    settings = get_settings()

    # If no API_KEY configured (development), allow all requests
    if not settings.API_KEY:
        return SINGLE_USER_ID

    api_key = _extract_api_key(request)
    if api_key is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required",
        )

    if not secrets.compare_digest(api_key, settings.API_KEY):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid API key",
        )

    return SINGLE_USER_ID


# ── Base dependencies ────────────────────────────────────────────────────────


async def get_db_session_dependency() -> AsyncGenerator[AsyncSession, None]:
    """Provide the request-scoped DB session through the provider layer."""
    async for db in get_db_session():
        yield db


async def get_redis_client():
    """Provide the shared Redis helper (process-level singleton)."""
    from app.core.redis import get_shared_redis

    return get_shared_redis()


def get_settings_dependency() -> Settings:
    """Provide cached application settings."""
    return get_settings()
