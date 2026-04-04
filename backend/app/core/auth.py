"""Authentication and user-related FastAPI dependencies.

Consolidates all auth-oriented dependency functions that were previously
spread across ``app.core.providers.auth_providers`` and
``app.core.providers.base_providers``.
"""

from __future__ import annotations

import logging
from collections.abc import AsyncGenerator

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.database import get_db_session
from app.core.security import get_token_from_request, verify_token
from app.domains.user.models import User
from app.domains.user.repositories import UserRepository


logger = logging.getLogger(__name__)

oauth2_scheme = OAuth2PasswordBearer(tokenUrl=f"{get_settings().API_V1_STR}/auth/login")


# ── Base dependencies ────────────────────────────────────────────────────────


async def get_db_session_dependency() -> AsyncGenerator[AsyncSession, None]:
    """Provide the request-scoped DB session through the provider layer."""
    async for db in get_db_session():
        yield db


async def get_redis_client():
    """Provide the shared Redis helper (process-level singleton with connection pooling).

    The shared instance lives for the process lifetime and is closed on shutdown
    via close_shared_redis() in the application lifecycle.
    """
    from app.core.redis import get_shared_redis

    return get_shared_redis()


def get_settings_dependency() -> Settings:
    """Provide cached application settings."""
    return get_settings()


# ── Auth dependencies ────────────────────────────────────────────────────────


def get_user_repository(
    db: AsyncSession = Depends(get_db_session_dependency),
) -> UserRepository:
    """Provide a user repository for auth-oriented dependencies."""
    return UserRepository(db)


async def get_token_user_id(user=Depends(get_token_from_request)) -> int:
    """Resolve the authenticated user id for podcast routes."""
    return int(user["sub"])


async def get_current_user(
    token: str = Depends(oauth2_scheme),
    user_repo: UserRepository = Depends(get_user_repository),
) -> User:
    """Resolve the current authenticated user."""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )

    try:
        payload = await verify_token(token)
        user_id_str: str | None = payload.get("sub")
        if user_id_str is None:
            raise credentials_exception
        user_id = int(user_id_str)
    except HTTPException:
        raise
    except (JWTError, ValueError) as exc:
        logger.error("Exception in token verification: %s", exc)
        raise credentials_exception from exc

    user = await user_repo.get_by_id(user_id)
    if user is None:
        raise credentials_exception

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Inactive user",
        )

    return user


async def get_current_active_user(
    current_user: User = Depends(get_current_user),
) -> User:
    """Resolve the current active user."""
    if not current_user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Inactive user",
        )
    return current_user


async def get_current_superuser(
    current_user: User = Depends(get_current_user),
) -> User:
    """Resolve the current superuser."""
    if not current_user.is_superuser:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions",
        )
    return current_user


def get_authentication_service(
    db: AsyncSession = Depends(get_db_session_dependency),
):
    """Provide request-scoped authentication service."""
    from app.domains.user.services import AuthenticationService

    return AuthenticationService(db)
