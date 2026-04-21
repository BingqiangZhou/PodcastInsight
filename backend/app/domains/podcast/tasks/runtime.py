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

# Persistent event loop for the worker process lifetime.
# asyncio.run() creates (and closes) a new loop on every call, which breaks
# SQLAlchemy async connection pools — pooled asyncpg connections are bound to
# the loop where they were created, so a fresh loop can't reuse them.
_worker_loop: asyncio.AbstractEventLoop | None = None


def _get_worker_loop() -> asyncio.AbstractEventLoop:
    """Return a long-lived event loop for this Celery worker process."""
    global _worker_loop
    if _worker_loop is None or _worker_loop.is_closed():
        _worker_loop = asyncio.new_event_loop()
        asyncio.set_event_loop(_worker_loop)
    return _worker_loop


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
    """Run async code from sync Celery workers safely.

    Uses a persistent event loop instead of asyncio.run() so that
    SQLAlchemy async connection pool entries remain valid across tasks.
    """
    loop = _get_worker_loop()
    return loop.run_until_complete(coro)
