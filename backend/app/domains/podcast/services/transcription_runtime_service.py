"""Database-backed transcription runtime services."""

import asyncio
import logging
import os
import shutil
from datetime import UTC, datetime, timedelta
from typing import Any

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import ValidationError
from app.domains.ai.models import ModelType
from app.domains.ai.repositories import AIModelConfigRepository
from app.domains.podcast.ai_key_resolver import resolve_api_key_with_fallback
from app.domains.podcast.transcription import (
    PodcastTranscriptionService,
    SiliconFlowTranscriber,
)
from app.domains.podcast.transcription_state import get_transcription_state_manager


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
        import shutil

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
