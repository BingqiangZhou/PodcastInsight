"""Redis/state coordination helpers for transcription workflows."""

from __future__ import annotations

import logging
from collections.abc import Awaitable, Callable
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.domains.podcast.models import TranscriptionStatus, TranscriptionTask
from app.domains.podcast.services.transcription_dispatch_guard import (
    TranscriptionDispatchGuard,
)


logger = logging.getLogger(__name__)


class TranscriptionStateCoordinator:
    """Coordinate redis state for route and worker transcription flows."""

    def __init__(self, *, state_manager_factory: Callable[[], Awaitable[Any]]):
        self.state_manager_factory = state_manager_factory

    async def mark_start_result(self, episode_id: int, task, action: str) -> None:
        state_manager = await self.state_manager_factory()
        await state_manager.set_episode_task(episode_id, task.id)
        if action in {
            "created",
            "redispatched_pending",
            "redispatched_failed_with_temp",
        }:
            await state_manager.set_task_progress(
                task.id,
                TranscriptionStatus.PENDING.value,
                task.progress_percentage or 0,
                "Transcription task queued",
            )
        elif action == "reused_in_progress":
            await state_manager.set_task_progress(
                task.id,
                TranscriptionStatus.IN_PROGRESS.value,
                task.progress_percentage or 0,
                "Transcription task already in progress",
            )

    async def cleanup_deleted_task(self, episode_id: int, task_id: int | None) -> None:
        state_manager = await self.state_manager_factory()
        if task_id:
            try:
                await state_manager.clear_episode_task(episode_id)
                await state_manager.release_task_lock(episode_id, task_id)
                await state_manager.clear_task_progress(task_id)
                return
            except Exception as redis_error:
                logger.warning("[DELETE] Failed to cleanup redis: %s", redis_error)
                return

        try:
            await state_manager.clear_episode_task(episode_id)
            locked_task_id = await state_manager.is_episode_locked(episode_id)
            if locked_task_id:
                await state_manager.release_task_lock(episode_id, locked_task_id)
                await state_manager.clear_task_progress(locked_task_id)
        except Exception as redis_error:
            logger.warning("[DELETE] Failed to cleanup stale locks: %s", redis_error)

    async def execute_task_with_state(
        self,
        *,
        db: AsyncSession,
        task_id: int,
        config_db_id: int | None,
        transcription_service_factory,
        dispatch_guard: TranscriptionDispatchGuard,
        status_value: Callable[[object], str],
    ) -> dict[str, Any]:
        dispatch_claimed = await dispatch_guard.claim(task_id)
        if not dispatch_claimed:
            return {
                "status": "skipped",
                "reason": "task_already_dispatched",
                "task_id": task_id,
            }

        state_manager = await self.state_manager_factory()
        stmt = select(TranscriptionTask).where(TranscriptionTask.id == task_id)
        result = await db.execute(stmt)
        task = result.scalar_one_or_none()
        if task is None:
            await dispatch_guard.clear(task_id)
            return {"status": "error", "reason": "task_not_found", "task_id": task_id}

        episode_id = task.episode_id
        lock_acquired = await state_manager.acquire_task_lock(
            episode_id, task_id, expire_seconds=3600
        )
        if not lock_acquired:
            locked_task_id = await state_manager.is_episode_locked(episode_id)
            await dispatch_guard.clear(task_id)
            lock_owner = (
                str(locked_task_id) if locked_task_id is not None else "unknown_owner"
            )
            raise RuntimeError(
                f"Episode {episode_id} is locked by task {lock_owner}, retry later"
            )

        service = transcription_service_factory(db)
        original_update = service._update_task_progress_with_session

        async def redis_update_progress(
            db_session,
            internal_task_id,
            status,
            progress,
            message,
            error_message=None,
        ):
            await original_update(
                db_session,
                internal_task_id,
                status,
                progress,
                message,
                error_message,
            )
            await state_manager.set_task_progress(
                internal_task_id,
                status_value(status),
                progress,
                message,
            )

        service._update_task_progress_with_session = redis_update_progress

        try:
            await state_manager.set_task_progress(
                task_id,
                "pending",
                0,
                "Worker starting transcription process...",
            )
            await service.execute_transcription_task(task_id, db, config_db_id)
            await state_manager.clear_task_state(task_id, episode_id)
            return {
                "status": "success",
                "task_id": task_id,
                "config_db_id": config_db_id,
                "processed_at": datetime.now(UTC).isoformat(),
            }
        except Exception as exc:
            await state_manager.fail_task_state(task_id, episode_id, str(exc))
            logger.exception("Transcription task failed for task_id=%s", task_id)
            raise
        finally:
            await state_manager.release_task_lock(episode_id, task_id)
            await dispatch_guard.clear(task_id)
