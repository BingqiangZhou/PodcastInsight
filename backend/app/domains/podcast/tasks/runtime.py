"""Shared runtime helpers for podcast Celery tasks."""

from __future__ import annotations

import asyncio
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from datetime import datetime
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import (
    create_isolated_session_factory,
    register_orm_models,
    worker_db_session,
)
from app.core.redis import get_shared_redis
from app.domains.podcast.tasks._runlog import _insert_run_async


def ensure_orm_models_registered() -> None:
    """Register ORM models when the worker runtime first needs them."""
    register_orm_models()


def _new_session_factory(application_name: str):
    """Compatibility wrapper around the centralized worker-session runtime."""
    ensure_orm_models_registered()
    return create_isolated_session_factory(application_name)


@asynccontextmanager
async def worker_session(application_name: str) -> AsyncIterator[AsyncSession]:
    """Create an isolated worker DB session and always dispose its engine."""
    ensure_orm_models_registered()
    async with worker_db_session(application_name) as session:
        yield session


def run_async(coro):
    """Run async code from sync Celery workers safely."""
    return asyncio.run(coro)


def log_task_run(
    *,
    task_name: str,
    queue_name: str,
    status: str,
    started_at: datetime,
    finished_at: datetime | None = None,
    error_message: str | None = None,
    metadata: dict[str, Any] | None = None,
) -> None:
    run_async(
        _insert_run_async(
            task_name=task_name,
            queue_name=queue_name,
            status=status,
            started_at=started_at,
            finished_at=finished_at,
            error_message=error_message,
            metadata=metadata,
        )
    )


@asynccontextmanager
async def single_instance_task_lock(
    lock_name: str,
    *,
    ttl_seconds: int,
) -> AsyncIterator[bool]:
    """Guard a periodic task so only one worker instance runs it at a time."""
    redis = get_shared_redis()
    token = await redis.acquire_owned_lock(lock_name, expire=ttl_seconds)
    try:
        yield token is not None
    finally:
        if token is not None:
            await redis.release_owned_lock(lock_name, token)
