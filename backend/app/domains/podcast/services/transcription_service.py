"""Transcription services - workflow, runtime, scheduling."""

from __future__ import annotations

import asyncio
import logging
import os
import shutil
from collections.abc import Awaitable, Callable
from datetime import UTC, datetime, timedelta
from typing import Any

from sqlalchemy import and_, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.exceptions import ValidationError
from app.core.redis import CacheTTL, PodcastRedis, get_shared_redis
from app.domains.ai.models import ModelType
from app.domains.ai.repositories import AIModelConfigRepository
from app.domains.podcast.ai_key_resolver import resolve_api_key_with_fallback
from app.domains.podcast.models import (
    PodcastEpisode,
    PodcastEpisodeTranscript,
    TranscriptionStatus,
    TranscriptionTask,
)
from app.domains.podcast.transcription import (
    PodcastTranscriptionService,
    SiliconFlowTranscriber,
)
from app.domains.podcast.transcription_state import get_transcription_state_manager
from app.domains.podcast.transcription_types import ScheduleFrequency
from app.domains.podcast.utils.status_helpers import status_value


logger = logging.getLogger(__name__)


# ── Transcription state coordination (merged from transcription_state_coordinator.py) ──


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
        claim_dispatch: Callable[[int], Awaitable[bool]],
        clear_dispatch: Callable[[int], Awaitable[None]],
        status_value: Callable[[object], str],
    ) -> dict[str, Any]:
        dispatch_claimed = await claim_dispatch(task_id)
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
            await clear_dispatch(task_id)
            return {"status": "error", "reason": "task_not_found", "task_id": task_id}

        episode_id = task.episode_id
        lock_acquired = await state_manager.acquire_task_lock(
            episode_id,
            task_id,
            expire_seconds=3600,
        )
        if not lock_acquired:
            locked_task_id = await state_manager.is_episode_locked(episode_id)
            await clear_dispatch(task_id)
            lock_owner = (
                str(locked_task_id) if locked_task_id is not None else "unknown_owner"
            )
            raise RuntimeError(
                f"Episode {episode_id} is locked by task {lock_owner}, retry later",
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
            await clear_dispatch(task_id)


# ── Status helpers (inlined from transcription_status_projection.py) ──

STATUS_MESSAGES = {
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


def _build_transcription_status_payload(task, *, status_key: str) -> dict[str, Any]:
    """Build the route payload for a transcription task status."""
    current_chunk = 0
    total_chunks = 0
    if task.chunk_info and "chunks" in task.chunk_info:
        total_chunks = len(task.chunk_info["chunks"])
        if status_key == "transcribing" and task.progress_percentage > 45:
            current_chunk = int(((task.progress_percentage - 45) / 50) * total_chunks)

    eta_seconds = None
    if task.started_at and status_key not in {"completed", "failed", "cancelled"}:
        elapsed = (datetime.now(UTC) - task.started_at).total_seconds()
        if task.progress_percentage > 0:
            estimated_total = elapsed / (task.progress_percentage / 100)
            eta_seconds = int(estimated_total - elapsed)

    return {
        "task_id": task.id,
        "episode_id": task.episode_id,
        "status": status_key,
        "progress": task.progress_percentage,
        "message": STATUS_MESSAGES.get(status_key, "Unknown status"),
        "current_chunk": current_chunk,
        "total_chunks": total_chunks,
        "eta_seconds": eta_seconds,
    }


class TranscriptionWorkflowService:
    """Coordinate transcription task orchestration across routes and workers."""

    def __init__(
        self,
        db: AsyncSession,
        *,
        transcription_service_factory: Callable[
            [AsyncSession],
            PodcastTranscriptionRuntimeService,
        ] | None = None,
        scheduler_factory: Callable[
            [AsyncSession],
            PodcastTranscriptionScheduleService,
        ] | None = None,
        state_manager_factory: Callable[
            [],
            Awaitable[Any],
        ] = get_transcription_state_manager,
        redis_factory: Callable[[], PodcastRedis] = get_shared_redis,
        claim_dispatched: Callable[[AsyncSession, int], Awaitable[bool]] | None = None,
        clear_dispatched: Callable[[int], Awaitable[None]] | None = None,
    ):
        self.db = db
        if transcription_service_factory is None:
            transcription_service_factory = PodcastTranscriptionRuntimeService
        if scheduler_factory is None:
            scheduler_factory = PodcastTranscriptionScheduleService
        self.transcription_service_factory = transcription_service_factory
        self.scheduler_factory = scheduler_factory
        self.state_manager_factory = state_manager_factory
        self.redis_factory = redis_factory
        self._claim_dispatched_callback = claim_dispatched
        self._clear_dispatched_callback = clear_dispatched
        self.state_coordinator = TranscriptionStateCoordinator(
            state_manager_factory=state_manager_factory,
        )

    # ── Dispatch Guard Methods (inlined from transcription_dispatch_guard.py) ──

    async def _claim_dispatch(self, task_id: int) -> bool:
        """Claim dispatch right for a task. Returns True if claimed successfully."""
        if self._claim_dispatched_callback is not None:
            return await self._claim_dispatched_callback(self.db, task_id)

        redis = self.redis_factory()
        key = f"podcast:transcription:dispatched:{task_id}"
        if await redis.set_if_not_exists(key, "1", ttl=CacheTTL.hours(2)):
            return True

        status_stmt = select(TranscriptionTask.status).where(
            TranscriptionTask.id == task_id,
        )
        status_result = await self.db.execute(status_stmt)
        task_status_value = status_value(status_result.scalar_one_or_none())
        if task_status_value in {"completed", "failed", "cancelled"}:
            return False
        raise RuntimeError(
            f"Task {task_id} dispatch key exists while task status={task_status_value}",
        )

    async def _clear_dispatch(self, task_id: int) -> None:
        """Clear dispatch flag for a task."""
        if self._clear_dispatched_callback is not None:
            await self._clear_dispatched_callback(task_id)
            return

        redis = self.redis_factory()
        key = f"podcast:transcription:dispatched:{task_id}"
        await redis.delete_keys(key)

    async def start_episode_transcription(
        self,
        episode_id: int,
        *,
        transcription_model: str | None = None,
        force_regenerate: bool = False,
        episode_lookup: Callable[[int], Awaitable[PodcastEpisode | None]],
    ) -> dict[str, Any]:
        """Start or reuse a transcription task and update redis state."""
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

        await self.state_coordinator.mark_start_result(episode_id, task, action)

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
            except (ValueError, RuntimeError, OSError):
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
        episode = await episode_lookup(episode_id)
        if not episode:
            raise ValueError(f"Episode {episode_id} not found")

        transcription_service = self.transcription_service_factory(self.db)
        task_id = await transcription_service.delete_episode_transcription(episode_id)
        await self.state_coordinator.cleanup_deleted_task(episode_id, task_id)

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
            raise PermissionError(
                "You don't have permission to access this transcription task",
            )

        return _build_transcription_status_payload(
            task,
            status_key=status_value(task.status),
        )

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
                "No transcription found for this episode. Please schedule transcription first.",
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
        max_episodes: int = 50,
        subscription_lookup: Callable[[int], Awaitable[Any | None]],
    ) -> dict[str, Any]:
        subscription = await subscription_lookup(subscription_id)
        if not subscription:
            raise ValueError(f"Subscription {subscription_id} not found")
        return await batch_transcribe_subscription(
            self.db,
            subscription_id,
            skip_existing=skip_existing,
            max_episodes=max_episodes,
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
            "message": (
                "Transcription cancelled"
                if success
                else "No active transcription to cancel"
            ),
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
        return await self.state_coordinator.execute_task_with_state(
            db=self.db,
            task_id=task_id,
            config_db_id=config_db_id,
            transcription_service_factory=self.transcription_service_factory,
            claim_dispatch=self._claim_dispatch,
            clear_dispatch=self._clear_dispatch,
            status_value=status_value,
        )

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

        # Directly use transcription service instead of sync_service wrapper
        transcription_service = self.transcription_service_factory(self.db)
        result = await transcription_service.start_transcription(episode_id)
        if not result or not result.get("task"):
            raise RuntimeError(
                f"Failed to trigger transcription for episode={episode_id}, user={user_id}",
            )

        logger.info(
            "Triggered transcription task %s for episode %s (action=%s)",
            result["task"].id,
            episode_id,
            result.get("action"),
        )

        return {
            "status": "queued",
            "episode_id": episode_id,
            "transcription_task_id": result["task"].id,
            "processed_at": datetime.now(UTC).isoformat(),
        }


logger = logging.getLogger(__name__)


async def _directory_has_files_async(path: str) -> bool:
    """Check if directory has any files (async wrapper)."""
    return await asyncio.to_thread(_directory_has_files, path)


def _directory_has_files(path: str) -> bool:
    """Synchronous implementation of directory check."""
    return any(files for _, _, files in os.walk(path))


async def _directory_size_bytes_async(path: str) -> int:
    """Get directory size in bytes (async wrapper)."""
    return await asyncio.to_thread(_directory_size_bytes, path)


def _directory_size_bytes(path: str) -> int:
    """Synchronous implementation of directory size calculation."""
    return sum(
        os.path.getsize(os.path.join(dirpath, filename))
        for dirpath, _, filenames in os.walk(path)
        for filename in filenames
        if os.path.isfile(os.path.join(dirpath, filename))
    )


async def _rmtree_async(path: str) -> None:
    """Remove directory tree asynchronously."""
    await asyncio.to_thread(shutil.rmtree, path)


class TranscriptionModelManager:
    """Resolve transcription model configs and transcribers."""

    def __init__(self, db: AsyncSession):
        self.db = db
        self.ai_model_repo = AIModelConfigRepository(db)

    async def get_active_transcription_model(self, model_name: str | None = None):
        if model_name:
            model = await self.ai_model_repo.get_by_name(model_name)
            if (
                not model
                or not model.is_active
                or model.model_type != ModelType.TRANSCRIPTION
            ):
                raise ValidationError(
                    f"Transcription model '{model_name}' not found or not active",
                )
            return model

        active_models = await self.ai_model_repo.get_active_models_by_priority(
            ModelType.TRANSCRIPTION,
        )
        if not active_models:
            raise ValidationError("No active transcription model found")
        return active_models[0]

    async def create_transcriber(self, model_name: str | None = None):
        model_config = await self.get_active_transcription_model(model_name)
        api_key = await self._get_api_key(model_config)

        api_url = model_config.api_url
        if not api_url or api_url.strip() == "":
            from app.core.config import settings

            api_url = getattr(
                settings,
                "TRANSCRIPTION_API_URL",
                "https://api.siliconflow.cn/v1/audio/transcriptions",
            )

        return SiliconFlowTranscriber(
            api_key=api_key,
            api_url=api_url,
            max_concurrent=model_config.max_concurrent_requests,
        )

    async def list_available_models(self):
        active_models = await self.ai_model_repo.get_active_models(
            ModelType.TRANSCRIPTION,
        )
        return [
            {
                "id": model.id,
                "name": model.name,
                "display_name": model.display_name,
                "provider": model.provider,
                "model_id": model.model_id,
                "is_default": model.is_default,
            }
            for model in active_models
        ]

    async def _get_api_key(self, model_config) -> str:
        system_key = None
        if model_config.is_system:
            from app.core.config import settings

            if model_config.provider == "openai":
                system_key = getattr(settings, "OPENAI_API_KEY", "")
            elif model_config.provider == "siliconflow":
                system_key = getattr(settings, "TRANSCRIPTION_API_KEY", "")

        active_models = await self.ai_model_repo.get_active_models(
            ModelType.TRANSCRIPTION,
        )
        try:
            return resolve_api_key_with_fallback(
                primary_model=model_config,
                fallback_models=active_models,
                logger=logger,
                invalid_message=(
                    f"No valid API key found. Model '{model_config.name}' has a "
                    "placeholder/invalid API key, and no alternative models with "
                    "valid API keys were found. Please configure a valid API key "
                    "for at least one TRANSCRIPTION model."
                ),
                provider_key_prefix={"siliconflow": "sk-"},
                system_key=system_key,
            )
        except ValueError as exc:
            raise ValidationError(str(exc)) from exc


class PodcastTranscriptionRuntimeService(PodcastTranscriptionService):
    """Transcription runtime that resolves models from DB configuration."""

    def __init__(
        self,
        db: AsyncSession,
        task_orchestration_service_factory=None,
    ):
        super().__init__(db)
        self.model_manager = TranscriptionModelManager(db)
        self._task_orchestration_service_factory = task_orchestration_service_factory

    def _task_orchestration_service(self):
        factory = self._task_orchestration_service_factory
        if factory is None:
            from app.domains.podcast.services.task_orchestration_service import (
                PodcastTaskOrchestrationService,
            )

            factory = PodcastTaskOrchestrationService
        return factory(self.db)

    async def start_transcription(
        self,
        episode_id: int,
        model_name: str | None = None,
        force: bool = False,
    ) -> dict[str, Any]:
        if model_name:
            await self.model_manager.get_active_transcription_model(model_name)

        state_manager = await get_transcription_state_manager()
        existing_task = await self._load_existing_task(episode_id)
        if existing_task and not force:
            status_value = (
                existing_task.status.value
                if hasattr(existing_task.status, "value")
                else str(existing_task.status)
            )

            if status_value == "completed":
                return {"task": existing_task, "action": "reused_completed"}

            if status_value == "in_progress":
                await state_manager.set_episode_task(episode_id, existing_task.id)
                return {"task": existing_task, "action": "reused_in_progress"}

            if status_value == "pending":
                locked_task_id = await state_manager.is_episode_locked(episode_id)
                if locked_task_id == existing_task.id:
                    await state_manager.set_episode_task(episode_id, existing_task.id)
                    return {"task": existing_task, "action": "reused_pending"}
                if locked_task_id is not None:
                    return {"task": existing_task, "action": "locked_by_other_task"}

                config_db_id = await self._resolve_transcription_config_db_id(
                    model_name
                )
                self._task_orchestration_service().enqueue_audio_transcription(
                    task_id=existing_task.id,
                    config_db_id=config_db_id,
                )
                return {"task": existing_task, "action": "redispatched_pending"}

            if status_value in {"failed", "cancelled"}:
                temp_episode_dir = os.path.join(self.temp_dir, f"episode_{episode_id}")
                has_temp_files = os.path.exists(
                    temp_episode_dir
                ) and await asyncio.to_thread(
                    _directory_has_files,
                    temp_episode_dir,
                )

                if has_temp_files:
                    locked_task_id = await state_manager.is_episode_locked(episode_id)
                    if locked_task_id is None:
                        existing_task.status = "pending"
                        existing_task.error_message = None
                        existing_task.started_at = None
                        existing_task.completed_at = None
                        existing_task.progress_percentage = 0
                        existing_task.current_step = "not_started"
                        await self.db.commit()
                        # No refresh needed - existing_task is already in session with updated values

                        config_db_id = await self._resolve_transcription_config_db_id(
                            model_name,
                        )
                        self._task_orchestration_service().enqueue_audio_transcription(
                            task_id=existing_task.id,
                            config_db_id=config_db_id,
                        )
                        return {
                            "task": existing_task,
                            "action": "redispatched_failed_with_temp",
                        }
                    return {"task": existing_task, "action": "locked_by_other_task"}

        if force:
            task, config_db_id = await super().create_transcription_task_record(
                episode_id,
                model_name,
                force,
            )
            self._task_orchestration_service().enqueue_audio_transcription(
                task_id=task.id,
                config_db_id=config_db_id,
            )
            return {"task": task, "action": "created"}

        task, config_db_id, created = await self._create_or_get_task_record(
            episode_id,
            model_name,
        )
        if not created:
            status_value = (
                task.status.value if hasattr(task.status, "value") else str(task.status)
            )
            if status_value == "completed":
                return {"task": task, "action": "reused_completed"}
            if status_value in {"pending", "in_progress"}:
                await state_manager.set_episode_task(episode_id, task.id)
                action = (
                    "reused_in_progress"
                    if status_value == "in_progress"
                    else "reused_pending"
                )
                return {"task": task, "action": action}
            return {"task": task, "action": "locked_by_other_task"}

        self._task_orchestration_service().enqueue_audio_transcription(
            task_id=task.id,
            config_db_id=config_db_id,
        )
        return {"task": task, "action": "created"}

    async def _load_existing_task(self, episode_id: int):
        from app.domains.podcast.models import TranscriptionTask

        stmt = (
            select(TranscriptionTask)
            .where(TranscriptionTask.episode_id == episode_id)
            .order_by(TranscriptionTask.created_at.desc())
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def _create_or_get_task_record(
        self,
        episode_id: int,
        model_name: str | None,
    ) -> tuple[Any, int | None, bool]:
        from app.domains.podcast.models import TranscriptionTask

        episode = await self._load_episode_for_task_creation(episode_id)
        model_config = await self.model_manager.get_active_transcription_model(
            model_name
        )
        task_values = {
            "episode_id": episode_id,
            "original_audio_url": episode.audio_url,
            "chunk_size_mb": self.chunk_size_mb,
            "model_used": model_config.model_id,
        }

        bind = self.db.get_bind()
        dialect_name = bind.dialect.name if bind is not None else None
        if dialect_name == "postgresql":
            from sqlalchemy.dialects.postgresql import insert as postgresql_insert

            stmt = (
                postgresql_insert(TranscriptionTask)
                .values(**task_values)
                .on_conflict_do_nothing(index_elements=[TranscriptionTask.episode_id])
                .returning(TranscriptionTask.id)
            )
            result = await self.db.execute(stmt)
            task_id = result.scalar_one_or_none()
            await self.db.commit()
            if task_id is not None:
                return await self._load_task_by_id(task_id), model_config.id, True

            existing_task = await self._load_existing_task(episode_id)
            if existing_task is None:
                raise RuntimeError(
                    f"Task creation conflicted but no existing task found for episode {episode_id}",
                )
            return existing_task, None, False

        task = TranscriptionTask(**task_values)
        try:
            self.db.add(task)
            await self.db.commit()
            # No refresh needed - task.id is auto-populated by SQLAlchemy after flush/commit
            return task, model_config.id, True
        except IntegrityError:
            await self.db.rollback()
            existing_task = await self._load_existing_task(episode_id)
            if existing_task is None:
                raise
            return existing_task, None, False

    async def _load_episode_for_task_creation(self, episode_id: int):
        from app.domains.podcast.models import PodcastEpisode

        stmt = select(PodcastEpisode).where(PodcastEpisode.id == episode_id)
        result = await self.db.execute(stmt)
        episode = result.scalar_one_or_none()
        if not episode:
            logger.error("[TRANSCRIPTION] Episode %s not found", episode_id)
            raise ValidationError(f"Episode {episode_id} not found")
        return episode

    async def _load_task_by_id(self, task_id: int):
        from app.domains.podcast.models import TranscriptionTask

        stmt = select(TranscriptionTask).where(TranscriptionTask.id == task_id)
        result = await self.db.execute(stmt)
        task = result.scalar_one_or_none()
        if task is None:
            raise RuntimeError(f"Transcription task {task_id} not found after insert")
        return task

    async def _resolve_transcription_config_db_id(
        self,
        model_name: str | None,
    ) -> int | None:
        ai_repo = AIModelConfigRepository(self.db)
        model_config = None
        if model_name:
            model_config = await ai_repo.get_by_name(model_name)
        if not model_config:
            active_models = await ai_repo.get_active_models_by_priority(
                ModelType.TRANSCRIPTION,
            )
            model_config = active_models[0] if active_models else None
        return model_config.id if model_config else None

    async def get_transcription_models(self):
        return await self.model_manager.list_available_models()

    async def delete_episode_transcription(self, episode_id: int) -> int | None:
        task = await self.get_episode_transcription(episode_id)
        if not task:
            return None
        task_id = task.id
        await self.db.delete(task)
        await self.db.commit()
        return task_id

    async def reset_stale_tasks(self):
        from sqlalchemy import and_, update

        from app.domains.podcast.models import TranscriptionTask

        stale_threshold = datetime.now(UTC) - timedelta(minutes=5)
        in_progress_statuses = ["in_progress"]

        try:
            stmt = (
                update(TranscriptionTask)
                .where(
                    and_(
                        TranscriptionTask.status.in_(in_progress_statuses),
                        TranscriptionTask.started_at.isnot(None),
                        TranscriptionTask.updated_at < stale_threshold,
                    ),
                )
                .values(
                    status="failed",
                    error_message="Task interrupted by server restart",
                    updated_at=datetime.now(UTC),
                    completed_at=datetime.now(UTC),
                )
            )

            result = await self.db.execute(stmt)
            await self.db.commit()
            if result.rowcount > 0:
                logger.warning(
                    "Reset %s stale transcription tasks to FAILED", result.rowcount
                )

            pending_stale_threshold = datetime.now(UTC) - timedelta(hours=1)
            stmt2 = (
                update(TranscriptionTask)
                .where(
                    and_(
                        TranscriptionTask.status == "pending",
                        TranscriptionTask.started_at.is_(None),
                        TranscriptionTask.created_at < pending_stale_threshold,
                    ),
                )
                .values(
                    status="failed",
                    error_message="Task was never scheduled for execution",
                    updated_at=datetime.now(UTC),
                    completed_at=datetime.now(UTC),
                )
            )

            result2 = await self.db.execute(stmt2)
            await self.db.commit()
            if result2.rowcount > 0:
                logger.warning(
                    "Reset %s stale PENDING tasks to FAILED", result2.rowcount
                )
        except Exception as exc:  # noqa: BLE001
            logger.error("Failed to reset stale tasks: %s", exc)

    async def cleanup_old_temp_files(self, days: int = 7):
        import os

        from sqlalchemy import and_

        from app.core.config import settings
        from app.domains.podcast.models import TranscriptionTask

        temp_dir = getattr(settings, "TRANSCRIPTION_TEMP_DIR", "./temp/transcription")
        temp_dir_abs = os.path.abspath(temp_dir)

        if not os.path.exists(temp_dir_abs):
            return {"cleaned": 0, "freed_bytes": 0}

        stale_threshold = datetime.now(UTC) - timedelta(days=days)
        stmt = (
            select(TranscriptionTask.episode_id)
            .where(
                and_(
                    TranscriptionTask.status.in_(["failed", "cancelled"]),
                    TranscriptionTask.completed_at < stale_threshold,
                ),
            )
            .distinct()
        )

        result = await self.db.execute(stmt)
        episode_ids_to_cleanup = [row[0] for row in result.all()]

        cleaned_count = 0
        freed_bytes = 0
        for episode_id in episode_ids_to_cleanup:
            temp_episode_dir = os.path.join(temp_dir_abs, f"episode_{episode_id}")
            if not os.path.exists(temp_episode_dir):
                continue

            dir_size = await asyncio.to_thread(_directory_size_bytes, temp_episode_dir)
            await _rmtree_async(temp_episode_dir)
            cleaned_count += 1
            freed_bytes += dir_size

        return {
            "cleaned": cleaned_count,
            "freed_bytes": freed_bytes,
            "freed_mb": round(freed_bytes / 1024 / 1024, 2),
        }


DatabaseBackedTranscriptionService = PodcastTranscriptionRuntimeService


logger = logging.getLogger(__name__)


class PodcastTranscriptionScheduleService:
    """Scheduler facade for podcast transcription tasks."""

    def __init__(self, db: AsyncSession):
        self.db = db
        self.transcription_service = PodcastTranscriptionRuntimeService(db)

    async def schedule_transcription(
        self,
        episode_id: int,
        frequency: ScheduleFrequency = ScheduleFrequency.MANUAL,
        custom_interval: int | None = None,
        force: bool = False,
    ) -> dict[str, Any]:
        del frequency, custom_interval
        episode = await self._get_episode(episode_id)
        if not episode:
            raise ValidationError(f"Episode {episode_id} not found")
        start_result = await self.transcription_service.start_transcription(
            episode_id,
            force=force,
        )
        task = start_result["task"]
        action = start_result["action"]

        if action == "reused_completed":
            return {
                "status": "skipped",
                "message": "Transcription already exists",
                "task_id": task.id,
                "transcript_content": (
                    task.transcript_content[:100] + "..."
                    if task.transcript_content
                    else None
                ),
                "reason": "Already transcribed, use force=true to regenerate",
                "action": action,
            }
        if action in {"reused_in_progress", "reused_pending", "locked_by_other_task"}:
            return {
                "status": "processing",
                "message": "Transcription task already in progress",
                "task_id": task.id,
                "progress": task.progress_percentage,
                "current_status": status_value(task.status),
                "action": action,
            }

        return {
            "status": "scheduled",
            "message": "Transcription task started",
            "task_id": task.id,
            "episode_id": episode_id,
            "scheduled_at": datetime.now(UTC),
            "action": action,
        }

    async def batch_schedule_transcription(
        self,
        subscription_id: int,
        frequency: ScheduleFrequency = ScheduleFrequency.DAILY,
        limit: int | None = None,
        skip_existing: bool = True,
        max_episodes: int = 50,
    ) -> list[dict[str, Any]]:
        stmt = (
            select(PodcastEpisode)
            .where(PodcastEpisode.subscription_id == subscription_id)
            .order_by(PodcastEpisode.published_at.desc())
        )
        if limit:
            stmt = stmt.limit(limit)

        episodes = (await self.db.execute(stmt)).scalars().all()

        # Enforce batch limit to prevent unbounded Celery task creation
        max_episodes = min(max_episodes, settings.TRANSCRIPTION_BATCH_MAX_EPISODES)
        if len(episodes) > max_episodes:
            logger.warning(
                "Batch transcription limited: %d -> %d episodes (max: %d)",
                len(episodes),
                max_episodes,
                settings.TRANSCRIPTION_BATCH_MAX_EPISODES,
            )
            episodes = episodes[:max_episodes]
        if not episodes:
            return []

        results: list[dict[str, Any]] = []
        for episode in episodes:
            try:
                schedule_result = await self.schedule_transcription(
                    episode_id=episode.id,
                    frequency=frequency,
                    force=False,
                )
                if (
                    not skip_existing
                    and schedule_result["status"] == "skipped"
                    and schedule_result["action"] == "reused_completed"
                ):
                    schedule_result = await self.schedule_transcription(
                        episode_id=episode.id,
                        frequency=frequency,
                        force=True,
                    )
                results.append(
                    {
                        "episode_id": episode.id,
                        "episode_title": episode.title,
                        **schedule_result,
                    }
                )
            except Exception as exc:  # noqa: BLE001
                results.append(
                    {
                        "episode_id": episode.id,
                        "episode_title": episode.title,
                        "status": "error",
                        "error": str(exc),
                    }
                )
        return results

    async def check_and_transcribe_new_episodes(
        self,
        subscription_id: int,
        hours_since_published: int = 24,
    ) -> dict[str, Any]:
        cutoff_time = datetime.now(UTC) - timedelta(
            hours=hours_since_published,
        )

        stmt = (
            select(PodcastEpisode)
            .where(
                and_(
                    PodcastEpisode.subscription_id == subscription_id,
                    PodcastEpisode.published_at >= cutoff_time,
                    or_(
                        ~PodcastEpisode.transcript.has(
                            PodcastEpisodeTranscript.transcript_content.is_not(None),
                        ),
                        PodcastEpisode.transcript.has(
                            PodcastEpisodeTranscript.transcript_content == "",
                        ),
                    ),
                ),
            )
            .order_by(PodcastEpisode.published_at.desc())
        )

        new_episodes = (await self.db.execute(stmt)).scalars().all()
        if not new_episodes:
            return {
                "status": "completed",
                "message": "No new episodes found",
                "processed": 0,
                "skipped": 0,
            }

        detail_results: list[dict[str, Any]] = []
        for episode in new_episodes:
            try:
                schedule_result = await self.schedule_transcription(
                    episode_id=episode.id,
                    frequency=ScheduleFrequency.MANUAL,
                    force=False,
                )
                detail_results.append(
                    {
                        "episode_id": episode.id,
                        "status": "scheduled",
                        "task_id": schedule_result["task_id"],
                    }
                )
            except Exception as exc:  # noqa: BLE001
                detail_results.append(
                    {
                        "episode_id": episode.id,
                        "status": "error",
                        "error": str(exc),
                    }
                )

        scheduled = sum(1 for item in detail_results if item["status"] == "scheduled")
        errors = sum(1 for item in detail_results if item["status"] == "error")
        return {
            "status": "completed",
            "message": f"Scheduled {scheduled} new episodes for transcription",
            "processed": len(new_episodes),
            "scheduled": scheduled,
            "errors": errors,
            "details": detail_results,
        }

    async def get_transcription_status(
        self,
        episode_id: int,
    ) -> dict[str, Any]:
        episode = await self._get_episode(episode_id)
        if not episode:
            raise ValidationError(f"Episode {episode_id} not found")

        task = await self._get_existing_transcription_task(episode_id)
        if not task:
            return {
                "episode_id": episode_id,
                "episode_title": episode.title,
                "status": "not_started",
                "has_transcript": (
                    episode.transcript is not None
                    and episode.transcript.transcript_content is not None
                ),
                "transcript_preview": (
                    episode.transcript.transcript_content[:100] + "..."
                    if episode.transcript and episode.transcript.transcript_content
                    else None
                ),
            }

        return {
            "episode_id": episode_id,
            "episode_title": episode.title,
            "task_id": task.id,
            "status": status_value(task.status),
            "progress": task.progress_percentage,
            "created_at": task.created_at,
            "updated_at": task.updated_at,
            "completed_at": task.completed_at,
            "has_transcript": task.transcript_content is not None,
            "transcript_preview": (
                task.transcript_content[:100] + "..."
                if status_value(task.status) == TranscriptionStatus.COMPLETED.value
                and task.transcript_content
                else None
            ),
            "transcript_word_count": task.transcript_word_count,
            "has_summary": task.summary_content is not None,
            "summary_word_count": task.summary_word_count,
            "error_message": task.error_message,
        }

    async def get_pending_transcriptions(
        self,
    ) -> list[dict[str, Any]]:
        stmt = (
            select(TranscriptionTask)
            .where(
                TranscriptionTask.status.in_(
                    [
                        TranscriptionStatus.PENDING.value,
                        TranscriptionStatus.IN_PROGRESS.value,
                    ],
                ),
            )
            .order_by(TranscriptionTask.created_at.desc())
        )

        tasks = (await self.db.execute(stmt)).scalars().all()
        return [
            {
                "task_id": task.id,
                "episode_id": task.episode_id,
                "status": status_value(task.status),
                "progress": task.progress_percentage,
                "created_at": task.created_at,
                "updated_at": task.updated_at,
            }
            for task in tasks
        ]

    async def cancel_transcription(self, episode_id: int) -> bool:
        task = await self._get_existing_transcription_task(episode_id)
        if not task:
            return False
        return await self.transcription_service.cancel_transcription(task.id)

    async def get_transcript_from_existing(self, episode_id: int) -> str | None:
        episode = await self._get_episode(episode_id)
        if episode and episode.transcript and episode.transcript.transcript_content:
            return episode.transcript.transcript_content

        task = await self._get_existing_transcription_task(episode_id)
        if (
            task
            and status_value(task.status) == TranscriptionStatus.COMPLETED.value
            and task.transcript_content
        ):
            return task.transcript_content
        return None

    async def _get_episode(self, episode_id: int) -> PodcastEpisode | None:
        stmt = select(PodcastEpisode).where(PodcastEpisode.id == episode_id)
        return (await self.db.execute(stmt)).scalar_one_or_none()

    async def _get_existing_transcription_task(
        self,
        episode_id: int,
    ) -> TranscriptionTask | None:
        stmt = select(TranscriptionTask).where(
            TranscriptionTask.episode_id == episode_id,
        )
        return (await self.db.execute(stmt)).scalar_one_or_none()


async def get_episode_transcript(db: AsyncSession, episode_id: int) -> str | None:
    scheduler = PodcastTranscriptionScheduleService(db)
    return await scheduler.get_transcript_from_existing(episode_id)


async def batch_transcribe_subscription(
    db: AsyncSession,
    subscription_id: int,
    skip_existing: bool = True,
    max_episodes: int = 50,
) -> dict[str, Any]:
    scheduler = PodcastTranscriptionScheduleService(db)
    results = await scheduler.batch_schedule_transcription(
        subscription_id=subscription_id,
        skip_existing=skip_existing,
        max_episodes=max_episodes,
    )

    return {
        "subscription_id": subscription_id,
        "total": len(results),
        "scheduled": sum(1 for item in results if item.get("status") == "scheduled"),
        "skipped": sum(1 for item in results if item.get("status") == "skipped"),
        "errors": sum(1 for item in results if item.get("status") == "error"),
        "details": results,
    }


TranscriptionScheduler = PodcastTranscriptionScheduleService