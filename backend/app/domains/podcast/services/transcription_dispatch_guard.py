"""Dispatch guard helpers for transcription tasks."""

from __future__ import annotations

from collections.abc import Awaitable, Callable

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.redis import PodcastRedis
from app.domains.podcast.models import TranscriptionTask


class TranscriptionDispatchGuard:
    """Ensure worker dispatch happens once per transcription task."""

    def __init__(
        self,
        db: AsyncSession,
        *,
        redis_factory: Callable[[], PodcastRedis],
        claim_dispatched: Callable[[AsyncSession, int], Awaitable[bool]] | None = None,
        clear_dispatched: Callable[[int], Awaitable[None]] | None = None,
    ):
        self.db = db
        self.redis_factory = redis_factory
        self.claim_dispatched_callback = claim_dispatched
        self.clear_dispatched_callback = clear_dispatched

    async def claim(self, task_id: int) -> bool:
        if self.claim_dispatched_callback is not None:
            return await self.claim_dispatched_callback(self.db, task_id)

        redis = self.redis_factory()
        key = f"podcast:transcription:dispatched:{task_id}"
        client = await redis._get_client()
        result = await client.set(key, "1", nx=True, ex=7200)
        if result is not None:
            return True

        status_stmt = select(TranscriptionTask.status).where(
            TranscriptionTask.id == task_id
        )
        status_result = await self.db.execute(status_stmt)
        task_status_value = _status_value(status_result.scalar_one_or_none())
        if task_status_value in {"completed", "failed", "cancelled"}:
            return False
        raise RuntimeError(
            f"Task {task_id} dispatch key exists while task status={task_status_value}"
        )

    async def clear(self, task_id: int) -> None:
        if self.clear_dispatched_callback is not None:
            await self.clear_dispatched_callback(task_id)
            return

        redis = self.redis_factory()
        key = f"podcast:transcription:dispatched:{task_id}"
        client = await redis._get_client()
        await client.delete(key)


def _status_value(status: object) -> str:
    return status.value if hasattr(status, "value") else str(status)
