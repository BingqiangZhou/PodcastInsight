"""Shared transcription orchestration service for routes and task handlers."""

from __future__ import annotations

import logging
from collections.abc import Awaitable, Callable
from datetime import datetime, timezone
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.redis import PodcastRedis
from app.domains.podcast.models import (
    PodcastEpisode,
    TranscriptionStatus,
    TranscriptionTask,
)
from app.domains.podcast.services.sync_service import PodcastSyncService
from app.domains.podcast.services.transcription_runtime_service import (
    PodcastTranscriptionRuntimeService,
)
from app.domains.podcast.services.transcription_schedule_service import (
    PodcastTranscriptionScheduleService,
    batch_transcribe_subscription,
    get_episode_transcript,
)
from app.domains.podcast.transcription_state import get_transcription_state_manager
from app.domains.podcast.transcription_types import ScheduleFrequency


logger = logging.getLogger(__name__)


class TranscriptionWorkflowService:
    """Coordinate transcription task orchestration across routes and workers."""

    def __init__(
        self,
        db: AsyncSession,
        *,
        transcription_service_factory: Callable[
            [AsyncSession], PodcastTranscriptionRuntimeService
        ] = PodcastTranscriptionRuntimeService,
        scheduler_factory: Callable[[AsyncSession], PodcastTranscriptionScheduleService] = PodcastTranscriptionScheduleService,
        sync_service_factory: Callable[[AsyncSession, int], PodcastSyncService] = PodcastSyncService,
        state_manager_factory: Callable[[], Awaitable[Any]] = get_transcription_state_manager,
        redis_factory: Callable[[], PodcastRedis] = PodcastRedis,
        claim_dispatched: Callable[[AsyncSession, int], Awaitable[bool]] | None = None,
        clear_dispatched: Callable[[int], Awaitable[None]] | None = None,
    ):
        self.db = db
        self.transcription_service_factory = transcription_service_factory
        self.scheduler_factory = scheduler_factory
        self.sync_service_factory = sync_service_factory
        self.state_manager_factory = state_manager_factory
        self.redis_factory = redis_factory
        self.claim_dispatched = claim_dispatched
        self.clear_dispatched = clear_dispatched

    async def start_episode_transcription(
        self,
        episode_id: int,
        *,
        transcription_model: str | None = None,
        force_regenerate: bool = False,
        episode_lookup: Callable[[int], Awaitable[PodcastEpisode | None]],
    ) -> dict[str, Any]:
        """Start or reuse a transcription task and update redis state."""
        state_manager = await self.state_manager_factory()
        episode = await episode_lookup(episode_id)
        if not episode:
            raise ValueError(f"Episode {episode_id} not found")

        transcription_service = self.transcription_service_factory(self.db)
        start_result = await transcription_service.start_transcription(
            episode_id,
            transcription_model,
            force_regenerate,
        )
        task = start_result["task"]
        action = start_result["action"]

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

        return {"task": task, "action": action, "episode": episode}

    async def dispatch_pending_transcriptions(
        self,
        episode_ids: list[int],
    ) -> dict[str, Any]:
        """Start backlog transcriptions through the shared service entrypoint."""
        transcription_service = self.transcription_service_factory(self.db)
        dispatched_count = 0
        skipped_count = 0
        failed_count = 0
        skipped_reasons: dict[str, int] = {}

        for episode_id in episode_ids:
            try:
                result = await transcription_service.start_transcription(
                    episode_id,
                    force=False,
                )
                action = result.get("action", "unknown")
                if action in {
                    "created",
                    "redispatched_pending",
                    "redispatched_failed_with_temp",
                }:
                    dispatched_count += 1
                    continue

                skipped_count += 1
                skipped_reasons[action] = skipped_reasons.get(action, 0) + 1
            except Exception:
                failed_count += 1
                logger.exception(
                    "Failed to dispatch backlog transcription for episode %s",
                    episode_id,
                )

        return {
            "checked": len(episode_ids),
            "dispatched": dispatched_count,
            "skipped": skipped_count,
            "failed": failed_count,
            "skipped_reasons": skipped_reasons,
        }

    async def delete_episode_transcription(
        self,
        episode_id: int,
        *,
        episode_lookup: Callable[[int], Awaitable[PodcastEpisode | None]],
    ) -> dict[str, Any]:
        """Delete transcription task and cleanup redis state."""
        state_manager = await self.state_manager_factory()
        episode = await episode_lookup(episode_id)
        if not episode:
            raise ValueError(f"Episode {episode_id} not found")

        transcription_service = self.transcription_service_factory(self.db)
        task_id = await transcription_service.delete_episode_transcription(episode_id)
        if task_id:
            try:
                await state_manager.clear_episode_task(episode_id)
                await state_manager.release_task_lock(episode_id, task_id)
                await state_manager.clear_task_progress(task_id)
            except Exception as redis_error:
                logger.warning("[DELETE] Failed to cleanup redis: %s", redis_error)
        else:
            try:
                await state_manager.clear_episode_task(episode_id)
                locked_task_id = await state_manager.is_episode_locked(episode_id)
                if locked_task_id:
                    await state_manager.release_task_lock(episode_id, locked_task_id)
                    await state_manager.clear_task_progress(locked_task_id)
            except Exception as redis_error:
                logger.warning("[DELETE] Failed to cleanup stale locks: %s", redis_error)

        return {"task_id": task_id, "episode": episode}

    async def get_transcription_task_status(
        self,
        task_id: int,
        *,
        episode_lookup: Callable[[int], Awaitable[PodcastEpisode | None]],
    ) -> dict[str, Any]:
        """Get task status and enforce episode access."""
        transcription_service = self.transcription_service_factory(self.db)
        task = await transcription_service.get_transcription_status(task_id)
        if not task:
            raise ValueError("Transcription task not found")

        episode = await episode_lookup(task.episode_id)
        if not episode:
            raise PermissionError("You don't have permission to access this transcription task")

        status_key = self._status_value(task.status)
        status_messages = {
            "pending": "Waiting to start",
            "downloading": "Downloading audio file",
            "converting": "Converting audio format",
            "splitting": "Splitting audio into chunks",
            "transcribing": "Transcribing audio",
            "merging": "Merging transcription output",
            "completed": "Transcription completed",
            "failed": "Transcription failed",
            "cancelled": "Transcription cancelled",
        }

        current_chunk = 0
        total_chunks = 0
        if task.chunk_info and "chunks" in task.chunk_info:
            total_chunks = len(task.chunk_info["chunks"])
            if status_key == "transcribing" and task.progress_percentage > 45:
                current_chunk = int(((task.progress_percentage - 45) / 50) * total_chunks)

        eta_seconds = None
        if task.started_at and status_key not in {"completed", "failed", "cancelled"}:
            elapsed = (datetime.now(timezone.utc) - task.started_at).total_seconds()
            if task.progress_percentage > 0:
                estimated_total = elapsed / (task.progress_percentage / 100)
                eta_seconds = int(estimated_total - elapsed)

        return {
            "task_id": task.id,
            "episode_id": task.episode_id,
            "status": status_key,
            "progress": task.progress_percentage,
            "message": status_messages.get(status_key, "Unknown status"),
            "current_chunk": current_chunk,
            "total_chunks": total_chunks,
            "eta_seconds": eta_seconds,
        }

    async def schedule_episode_transcription(
        self,
        episode_id: int,
        *,
        frequency: ScheduleFrequency,
        force: bool,
        episode_lookup: Callable[[int], Awaitable[PodcastEpisode | None]],
    ) -> dict[str, Any]:
        episode = await episode_lookup(episode_id)
        if not episode:
            raise ValueError(f"Episode {episode_id} not found")
        scheduler = self.scheduler_factory(self.db)
        return await scheduler.schedule_transcription(
            episode_id=episode_id,
            frequency=frequency,
            force=force,
        )

    async def get_episode_transcript_payload(
        self,
        episode_id: int,
        *,
        episode_lookup: Callable[[int], Awaitable[PodcastEpisode | None]],
    ) -> dict[str, Any]:
        episode = await episode_lookup(episode_id)
        if not episode:
            raise ValueError(f"Episode {episode_id} not found")

        transcript = await get_episode_transcript(self.db, episode_id)
        if not transcript:
            raise LookupError(
                "No transcription found for this episode. Please schedule transcription first."
            )

        return {
            "episode_id": episode_id,
            "episode_title": episode.title,
            "transcript_length": len(transcript),
            "transcript": transcript,
            "status": "success",
        }

    async def batch_transcribe_subscription(
        self,
        subscription_id: int,
        *,
        skip_existing: bool,
        subscription_lookup: Callable[[int], Awaitable[Any | None]],
    ) -> dict[str, Any]:
        subscription = await subscription_lookup(subscription_id)
        if not subscription:
            raise ValueError(f"Subscription {subscription_id} not found")
        return await batch_transcribe_subscription(
            self.db,
            subscription_id,
            skip_existing=skip_existing,
        )

    async def get_schedule_status(
        self,
        episode_id: int,
        *,
        episode_lookup: Callable[[int], Awaitable[PodcastEpisode | None]],
    ) -> dict[str, Any]:
        episode = await episode_lookup(episode_id)
        if not episode:
            raise ValueError(f"Episode {episode_id} not found")
        scheduler = self.scheduler_factory(self.db)
        return await scheduler.get_transcription_status(episode_id)

    async def cancel_episode_transcription(
        self,
        episode_id: int,
        *,
        episode_lookup: Callable[[int], Awaitable[PodcastEpisode | None]],
    ) -> dict[str, Any]:
        episode = await episode_lookup(episode_id)
        if not episode:
            raise ValueError(f"Episode {episode_id} not found")
        scheduler = self.scheduler_factory(self.db)
        success = await scheduler.cancel_transcription(episode_id)
        return {
            "success": success,
            "message": "Transcription cancelled"
            if success
            else "No active transcription to cancel",
        }

    async def check_and_transcribe_new_episodes(
        self,
        subscription_id: int,
        *,
        hours_since_published: int,
        subscription_lookup: Callable[[int], Awaitable[Any | None]],
    ) -> dict[str, Any]:
        subscription = await subscription_lookup(subscription_id)
        if not subscription:
            raise ValueError(f"Subscription {subscription_id} not found")
        scheduler = self.scheduler_factory(self.db)
        return await scheduler.check_and_transcribe_new_episodes(
            subscription_id=subscription_id,
            hours_since_published=hours_since_published,
        )

    async def list_pending_transcriptions(
        self,
        *,
        episode_lookup: Callable[[int], Awaitable[PodcastEpisode | None]],
    ) -> dict[str, Any]:
        scheduler = self.scheduler_factory(self.db)
        tasks = await scheduler.get_pending_transcriptions()
        user_tasks = []
        for task in tasks:
            episode = await episode_lookup(task["episode_id"])
            if episode:
                user_tasks.append(task)
        return {"total": len(user_tasks), "tasks": user_tasks}

    async def cleanup_old_temp_files(self, *, days: int = 7) -> dict[str, Any]:
        """Cleanup stale transcription temporary files via the shared service."""
        transcription_service = self.transcription_service_factory(self.db)
        return await transcription_service.cleanup_old_temp_files(days=days)

    async def reset_stale_tasks(self) -> None:
        """Reset stale in-progress tasks at application startup."""
        transcription_service = self.transcription_service_factory(self.db)
        await transcription_service.reset_stale_tasks()

    async def execute_transcription_task(
        self,
        task_id: int,
        *,
        config_db_id: int | None,
    ) -> dict[str, Any]:
        """Worker-side transcription execution flow with redis lock/progress state."""
        dispatch_claimed = await self._claim_dispatched(task_id)
        if not dispatch_claimed:
            return {
                "status": "skipped",
                "reason": "task_already_dispatched",
                "task_id": task_id,
            }

        state_manager = await self.state_manager_factory()
        stmt = select(TranscriptionTask).where(TranscriptionTask.id == task_id)
        result = await self.db.execute(stmt)
        task = result.scalar_one_or_none()
        if task is None:
            await self._clear_dispatched(task_id)
            return {"status": "error", "reason": "task_not_found", "task_id": task_id}

        episode_id = task.episode_id
        lock_acquired = await state_manager.acquire_task_lock(
            episode_id, task_id, expire_seconds=3600
        )
        if not lock_acquired:
            locked_task_id = await state_manager.is_episode_locked(episode_id)
            await self._clear_dispatched(task_id)
            lock_owner = str(locked_task_id) if locked_task_id is not None else "unknown_owner"
            raise RuntimeError(
                f"Episode {episode_id} is locked by task {lock_owner}, retry later"
            )

        service = self.transcription_service_factory(self.db)
        original_update = service._update_task_progress_with_session

        async def redis_update_progress(
            db_session, internal_task_id, status, progress, message, error_message=None
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
                self._status_value(status),
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
            await service.execute_transcription_task(task_id, self.db, config_db_id)
            await state_manager.clear_task_state(task_id, episode_id)
            return {
                "status": "success",
                "task_id": task_id,
                "config_db_id": config_db_id,
                "processed_at": datetime.now(timezone.utc).isoformat(),
            }
        except Exception as exc:
            await state_manager.fail_task_state(task_id, episode_id, str(exc))
            logger.exception("Transcription task failed for task_id=%s", task_id)
            raise
        finally:
            await state_manager.release_task_lock(episode_id, task_id)
            await self._clear_dispatched(task_id)

    async def trigger_episode_pipeline(
        self,
        episode_id: int,
        *,
        user_id: int,
        episode_lookup: Callable[[int], Awaitable[PodcastEpisode | None]],
    ) -> dict[str, Any]:
        """Dispatch transcription pipeline for one episode."""
        episode = await episode_lookup(episode_id)
        if episode is None:
            return {
                "status": "error",
                "message": "Episode not found",
                "episode_id": episode_id,
            }

        sync_service = self.sync_service_factory(self.db, user_id)
        transcription_task = await sync_service.trigger_transcription(episode_id)
        if not transcription_task:
            raise RuntimeError(
                f"Failed to trigger transcription for episode={episode_id}, user={user_id}"
            )

        return {
            "status": "queued",
            "episode_id": episode_id,
            "transcription_task_id": transcription_task["task_id"],
            "processed_at": datetime.now(timezone.utc).isoformat(),
        }

    async def _claim_dispatched(self, task_id: int) -> bool:
        if self.claim_dispatched is not None:
            return await self.claim_dispatched(self.db, task_id)
        redis = self.redis_factory()
        key = f"podcast:transcription:dispatched:{task_id}"
        client = await redis._get_client()
        result = await client.set(key, "1", nx=True, ex=7200)
        if result is not None:
            return True

        status_stmt = select(TranscriptionTask.status).where(TranscriptionTask.id == task_id)
        status_result = await self.db.execute(status_stmt)
        task_status_value = self._status_value(status_result.scalar_one_or_none())
        if task_status_value in {"completed", "failed", "cancelled"}:
            return False
        raise RuntimeError(
            f"Task {task_id} dispatch key exists while task status={task_status_value}"
        )

    async def _clear_dispatched(self, task_id: int) -> None:
        if self.clear_dispatched is not None:
            await self.clear_dispatched(task_id)
            return
        redis = self.redis_factory()
        key = f"podcast:transcription:dispatched:{task_id}"
        client = await redis._get_client()
        await client.delete(key)

    @staticmethod
    def _status_value(status: object) -> str:
        return status.value if hasattr(status, "value") else str(status)
