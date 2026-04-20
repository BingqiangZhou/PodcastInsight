"""Shared runtime helpers for podcast Celery tasks."""

from __future__ import annotations

import asyncio
import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from sqlalchemy.ext.asyncio import AsyncSession


_logger = logging.getLogger(__name__)

from app.core.database import (
    get_async_session_factory,
    register_orm_models,
)


def ensure_orm_models_registered() -> None:
    """Register ORM models when the worker runtime first needs them."""
    register_orm_models()


@asynccontextmanager
async def worker_session(application_name: str) -> AsyncIterator[AsyncSession]:
    """Create an isolated worker DB session."""
    ensure_orm_models_registered()
    session_factory = get_async_session_factory()
    async with session_factory() as session:
        yield session


def run_async(coro):
    """Run async code from sync Celery workers safely."""
    return asyncio.run(coro)
