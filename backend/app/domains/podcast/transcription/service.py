"""Podcast transcription service - orchestrates the full transcription pipeline."""

import asyncio
import logging
import os
import re
import time
from datetime import UTC, datetime
from typing import Any

import aiofiles
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.exceptions import ValidationError
from app.domains.ai.models import ModelType
from app.domains.ai.repositories import AIModelConfigRepository
from app.domains.podcast.models import (
    PodcastEpisode,
    PodcastEpisodeTranscript,
    TranscriptionStatus,
    TranscriptionStep,
    TranscriptionTask,
)
from app.domains.podcast.transcription_state import _progress_throttle

from .converter import AudioConverter
from .downloader import AudioDownloader
from .models import AudioChunk
from .splitter import AudioSplitter
from .transcriber import SiliconFlowTranscriber
from .utils import _ffmpeg_probe_async, build_chunk_info, log_with_timestamp


logger = logging.getLogger(__name__)


class PodcastTranscriptionService:
    """?"""

    def __init__(self, db: AsyncSession):
        self.db = db
        self._progress_cache: dict[str, dict[str, float | str]] = {}
        self._task_progress_context_cache: dict[int, dict[str, Any]] = {}

        # Get path from settings - use absolute path if configured, otherwise resolve relative path
        temp_dir_config = getattr(
            settings,
            "TRANSCRIPTION_TEMP_DIR",
            "./temp/transcription",
        )
        storage_dir_config = getattr(
            settings,
            "TRANSCRIPTION_STORAGE_DIR",
            "./storage/podcasts",
        )

        # Use configured path directly (supports both absolute and relative)
        # In Docker, these will be absolute paths like /app/temp/transcription
        # In local dev, these will be relative paths that get resolved
        self.temp_dir = os.path.abspath(temp_dir_config)
        self.storage_dir = os.path.abspath(storage_dir_config)

        # Log for debugging (use debug level to reduce noise)
        logger.debug(
            f"[TRANSCRIPTION] temp_dir = {self.temp_dir} (from config: {temp_dir_config})",
        )
        logger.debug(
            f"[TRANSCRIPTION] storage_dir = {self.storage_dir} (from config: {storage_dir_config})",
        )
        logger.debug(f"[TRANSCRIPTION] cwd = {os.getcwd()}")

        self.chunk_size_mb = getattr(settings, "TRANSCRIPTION_CHUNK_SIZE_MB", 10)
        self.max_threads = getattr(settings, "TRANSCRIPTION_MAX_THREADS", 4)
        self.min_chunk_success_ratio = float(
            getattr(settings, "TRANSCRIPTION_MIN_CHUNK_SUCCESS_RATIO", 0.6),
        )
        self.progress_commit_min_delta = float(
            getattr(settings, "TRANSCRIPTION_PROGRESS_COMMIT_MIN_DELTA", 5.0),
        )
        self.progress_commit_min_interval = float(
            getattr(
                settings, "TRANSCRIPTION_PROGRESS_COMMIT_MIN_INTERVAL_SECONDS", 3.0
            ),
        )
        # API configuration is now dynamic, but we keep defaults for fallback
        self.default_api_url = getattr(
            settings,
            "TRANSCRIPTION_API_URL",
            "https://api.siliconflow.cn/v1/audio/transcriptions",
        )
        self.default_api_key = getattr(settings, "TRANSCRIPTION_API_KEY", None)

    def _get_episode_storage_path(self, episode: PodcastEpisode) -> str:
        """Build the storage path for an episode's transcription files."""
        podcast_name = self._sanitize_filename(episode.subscription.title)
        episode_name = self._sanitize_filename(episode.title)

        return os.path.join(self.storage_dir, podcast_name, episode_name)

    def _sanitize_filename(self, filename: str) -> str:
        """Sanitize filename by removing invalid characters and truncating length."""
        filename = re.sub(r'[<>:"/\\|?*]', "", filename)
        filename = filename.replace(" ", "_")
        return filename[:100]

    async def update_task_progress(
        self,
        task_id: int,
        status: TranscriptionStatus,
        progress: float,
        message: str,
        error_message: str | None = None,
    ):
        """Update transcription task progress and status in database."""
        update_data = {
            "status": status,
            "progress_percentage": progress,
            "updated_at": datetime.now(UTC),
        }

        if error_message:
            update_data["error_message"] = error_message

        # Set started_at timestamp when task begins processing
        if status == TranscriptionStatus.IN_PROGRESS and not await self._get_task_field(
            task_id,
            "started_at",
        ):
            update_data["started_at"] = datetime.now(UTC)

        if status in [
            TranscriptionStatus.COMPLETED,
            TranscriptionStatus.FAILED,
            TranscriptionStatus.CANCELLED,
        ]:
            update_data["completed_at"] = datetime.now(UTC)

        stmt = (
            update(TranscriptionTask)
            .where(TranscriptionTask.id == task_id)
            .values(**update_data)
        )

        await self.db.execute(stmt)
        await self.db.commit()

        # ?
        if _progress_throttle.should_log(task_id, str(status), progress):
            logger.info(
                f"Updated task {task_id}: status={status}, progress={progress:.1f}%",
            )

    async def _get_task_field(self, task_id: int, field: str):
        """?"""
        stmt = select(getattr(TranscriptionTask, field)).where(
            TranscriptionTask.id == task_id,
        )
        result = await self.db.execute(stmt)
        return result.scalar()

    async def _update_task_progress_with_session(
        self,
        session: AsyncSession,
        task_id: int,
        step: TranscriptionStep,  # ?????step ?????status
        progress: float,
        message: str,
        error_message: str | None = None,
    ):
        """?????????????????????????????"""
        from app.domains.podcast.models import TranscriptionStatus

        cache_key = f"{task_id}_{step}"
        if cache_key not in self._progress_cache:
            self._progress_cache[cache_key] = {
                "last_db_update": 0.0,
                "last_db_update_at": 0.0,
                "last_log": 0.0,
            }

        cached = self._progress_cache[cache_key]
        progress_delta = abs(progress - cached["last_db_update"])
        now_mono = time.monotonic()
        last_db_update_at = float(cached.get("last_db_update_at", 0.0))
        interval_elapsed = now_mono - last_db_update_at

        if (
            progress_delta < self.progress_commit_min_delta
            and interval_elapsed < self.progress_commit_min_interval
            and int(progress) != 100
        ):
            return

        update_data = {
            "current_step": step,
            "progress_percentage": progress,
            "updated_at": datetime.now(UTC),
        }

        if error_message:
            update_data["error_message"] = error_message

        context = self._task_progress_context_cache.get(task_id)
        if context is None:
            stmt_context = select(
                TranscriptionTask.started_at,
                TranscriptionTask.chunk_info,
            ).where(TranscriptionTask.id == task_id)
            context_row = (await session.execute(stmt_context)).one_or_none()
            started_at = context_row[0] if context_row else None
            chunk_info = context_row[1] if context_row else None
            context = {
                "started": bool(started_at),
                "chunk_info": chunk_info if isinstance(chunk_info, dict) else {},
                "last_debug_message": (
                    chunk_info.get("debug_message")
                    if isinstance(chunk_info, dict)
                    else None
                ),
            }
            self._task_progress_context_cache[task_id] = context

        if not context["started"]:
            update_data["started_at"] = datetime.now(UTC)
            update_data["status"] = TranscriptionStatus.IN_PROGRESS
            context["started"] = True

        if message and message != context.get("last_debug_message"):
            next_chunk_info = dict(context.get("chunk_info") or {})
            next_chunk_info["debug_message"] = message
            update_data["chunk_info"] = next_chunk_info
            context["chunk_info"] = next_chunk_info
            context["last_debug_message"] = message

        stmt = (
            update(TranscriptionTask)
            .where(TranscriptionTask.id == task_id)
            .values(**update_data)
        )

        await session.execute(stmt)
        await session.commit()

        cached["last_db_update"] = progress
        cached["last_db_update_at"] = now_mono

        log_delta = abs(progress - cached["last_log"])
        if log_delta >= 5.0 or int(progress) == 100:
            if int(progress) == 100:
                logger.info(f"??[PROGRESS] Task {task_id}: {step} - COMPLETED")
            else:
                logger.info(f"?? [PROGRESS] Task {task_id}: {step} - {progress:.1f}%")
            cached["last_log"] = progress

    async def _set_task_final_status(
        self,
        session: AsyncSession,
        task_id: int,
        status: TranscriptionStatus,  # COMPLETED ??FAILED
        error_message: str | None = None,
    ):
        """???????????????COMPLETED ??FAILED??"""
        update_data = {"status": status, "updated_at": datetime.now(UTC)}

        if status in [
            TranscriptionStatus.COMPLETED,
            TranscriptionStatus.FAILED,
            TranscriptionStatus.CANCELLED,
        ]:
            update_data["completed_at"] = datetime.now(UTC)

        if error_message:
            update_data["error_message"] = error_message

        stmt = (
            update(TranscriptionTask)
            .where(TranscriptionTask.id == task_id)
            .values(**update_data)
        )

        await session.execute(stmt)
        await session.commit()

        self._task_progress_context_cache.pop(task_id, None)
        for progress_key in [
            key for key in self._progress_cache if key.startswith(f"{task_id}_")
        ]:
            self._progress_cache.pop(progress_key, None)

        logger.info(f"Set task {task_id} final status: {status}")

    async def create_transcription_task_record(
        self,
        episode_id: int,
        model: str | None = None,
        force: bool = False,
    ) -> tuple[TranscriptionTask, int | None]:
        """?

        Returns:
            Tuple[TranscriptionTask, Optional[int]]: (, DB ID)

        """
        logger.info(
            f"[TRANSCRIPTION PREPARE] episode_id={episode_id}, model={model}, force={force}",
        )

        stmt = select(TranscriptionTask).where(
            TranscriptionTask.episode_id == episode_id,
        )
        result = await self.db.execute(stmt)
        existing_task = result.scalar_one_or_none()

        if existing_task:
            logger.info(
                f"[TRANSCRIPTION] Existing task found: id={existing_task.id}, status={existing_task.status}",
            )
            if force:
                # Force mode: delete existing task and create new one (regardless of status)
                logger.info(
                    f"[TRANSCRIPTION] Force mode: deleting existing task {existing_task.id}",
                )
                await self.db.delete(existing_task)
                await self.db.flush()
                await (
                    self.db.commit()
                )  # Commit the delete to release the unique constraint
            elif existing_task.status not in [
                TranscriptionStatus.FAILED,
                TranscriptionStatus.CANCELLED,
            ]:
                # Task exists with non-failed/cancelled status and force=false: raise error
                logger.warning(
                    f"[TRANSCRIPTION] Task already exists with status {existing_task.status}",
                )
                raise ValidationError(
                    f"Transcription task already exists for episode {episode_id} with status {existing_task.status}. Use force=true to retry.",
                )
            else:
                # Task exists with failed/cancelled status and force=false: delete it and create new one
                logger.info(
                    f"[TRANSCRIPTION] Removing failed/cancelled task {existing_task.id} before creating new one",
                )
                await self.db.delete(existing_task)
                await self.db.flush()
                await (
                    self.db.commit()
                )  # Commit the delete to release the unique constraint
                logger.info(
                    "[TRANSCRIPTION] Failed/cancelled task removed, ready to create new one",
                )

        stmt = select(PodcastEpisode).where(PodcastEpisode.id == episode_id)
        result = await self.db.execute(stmt)
        episode = result.scalar_one_or_none()

        if not episode:
            logger.error(f"[TRANSCRIPTION] Episode {episode_id} not found")
            raise ValidationError(f"Episode {episode_id} not found")

        logger.info(
            f"[TRANSCRIPTION] Episode found: title='{episode.title}', audio_url='{episode.audio_url}'",
        )

        # ?
        ai_repo = AIModelConfigRepository(self.db)

        # 1.
        model_config = None
        if model:
            model_config = await ai_repo.get_by_name(model)
            logger.info(
                f"[TRANSCRIPTION] Looking for model by name '{model}': {model_config is not None}",
            )
            if (
                not model_config
                or not model_config.is_active
                or model_config.model_type != ModelType.TRANSCRIPTION
            ):
                raise ValidationError(
                    f"Transcription model '{model}' not found or not active",
                )

        # 2.
        if not model_config:
            active_models = await ai_repo.get_active_models_by_priority(
                ModelType.TRANSCRIPTION,
            )
            if active_models:
                model_config = active_models[0]
                logger.info(
                    f"[TRANSCRIPTION] Using highest priority model: {model_config.model_id} (priority={model_config.priority})",
                )
            else:
                raise ValidationError("No active transcription model found")

        # ID?(APIodel)
        transcription_model = model_config.model_id
        logger.info(f"[TRANSCRIPTION] Final model to use: '{transcription_model}'")

        logger.info("[TRANSCRIPTION] Creating TranscriptionTask in database...")
        task = TranscriptionTask(
            episode_id=episode_id,
            original_audio_url=episode.audio_url,
            chunk_size_mb=self.chunk_size_mb,
            model_used=transcription_model,  # APIID (?whisper-1)ID
        )

        self.db.add(task)
        await self.db.commit()
        # No refresh needed - task.id is auto-populated by SQLAlchemy after flush/commit

        logger.info(
            f"[TRANSCRIPTION] Task created in DB: id={task.id}, status={task.status}",
        )

        config_db_id = model_config.id if model_config else None
        return task, config_db_id

    async def start_transcription(
        self,
        episode_id: int,
        model: str | None = None,
        force: bool = False,
    ) -> TranscriptionTask:
        """"""
        # 1.
        task, config_db_id = await self.create_transcription_task_record(
            episode_id,
            model=model,
            force=force,
        )

        logger.info(
            f"[TRANSCRIPTION] Task {task.id} created successfully. config_db_id={config_db_id}",
        )

        return task

    async def execute_transcription_task(
        self,
        task_id: int,
        session,
        config_db_id: int | None = None,
    ):
        """"""
        log_with_timestamp(
            "INFO",
            "[EXECUTE START] Transcription task starting...",
            task_id,
        )
        log_with_timestamp(
            "INFO",
            f"[EXECUTE] config_db_id={config_db_id}",
            task_id,
        )
        log_with_timestamp(
            "INFO",
            f"[EXECUTE] asyncio event loop running: {asyncio.get_event_loop().is_running()}",
            task_id,
        )

        task: TranscriptionTask | None = None
        try:
            logger.info(
                f"[EXECUTE] Using provided database session for task {task_id}",
            )

            # ?AI
            ai_repo = AIModelConfigRepository(session)
            stmt = select(TranscriptionTask).where(TranscriptionTask.id == task_id)
            result = await session.execute(stmt)
            task = result.scalar_one_or_none()

            if not task:
                logger.error(
                    f"[EXECUTE] Transcription task {task_id} not found in database",
                )
                raise RuntimeError(f"Transcription task {task_id} not found")

            if task.status == TranscriptionStatus.COMPLETED:
                log_with_timestamp(
                    "INFO",
                    f"[SKIP] Task {task_id} already completed, skipping execution",
                    task_id,
                )
                log_with_timestamp(
                    "INFO",
                    f"[SKIP] Transcript has {task.transcript_word_count or 0} words",
                    task_id,
                )
                return

            if task.status == TranscriptionStatus.CANCELLED:
                log_with_timestamp(
                    "WARNING",
                    f"[SKIP] Task {task_id} was cancelled, skipping execution",
                    task_id,
                )
                return

            #  (ubscriptionazy load)
            from sqlalchemy.orm import selectinload

            stmt = (
                select(PodcastEpisode)
                .options(selectinload(PodcastEpisode.subscription))
                .where(PodcastEpisode.id == task.episode_id)
            )
            result = await session.execute(stmt)
            episode = result.scalar_one_or_none()

            if not episode:
                logger.error(
                    f"transcription._execute_transcription: Episode {task.episode_id} not found for task {task_id}",
                )
                await self._set_task_final_status(
                    session,
                    task_id,
                    TranscriptionStatus.FAILED,
                    "Episode not found",
                )
                raise RuntimeError(f"Episode {task.episode_id} not found")

            api_url = self.default_api_url
            api_key = self.default_api_key

            if config_db_id:
                logger.info(
                    f"transcription._execute_transcription: Using custom model config {config_db_id}",
                )
                model_config = await ai_repo.get_by_id(config_db_id)
                if model_config and model_config.is_active:
                    api_url = model_config.api_url
                    # API Key -
                    if (
                        model_config.is_system
                        and model_config.provider == "siliconflow"
                    ):
                        api_key = (
                            getattr(settings, "TRANSCRIPTION_API_KEY", None)
                            or model_config.api_key
                        )
                    elif model_config.is_system and model_config.provider == "openai":
                        api_key = (
                            getattr(settings, "OPENAI_API_KEY", None)
                            or model_config.api_key
                        )
                    # ?- ?
                    elif model_config.api_key_encrypted and model_config.api_key:
                        from app.core.security import decrypt_data

                        try:
                            api_key = decrypt_data(model_config.api_key)
                            logger.debug("API key decrypted for model %s", model_config.name)
                        except Exception as e:
                            logger.error("Failed to decrypt API key for model %s: %s", model_config.name, e)
                            api_key = model_config.api_key
                    else:
                        api_key = model_config.api_key

            if not api_key:
                logger.error(
                    f"transcription._execute_transcription: API Key missing for task {task_id}",
                )
                await self._set_task_final_status(
                    session,
                    task_id,
                    TranscriptionStatus.FAILED,
                    "Transcription API Key not found",
                )
                raise RuntimeError("Transcription API key not found")

            temp_episode_dir = os.path.join(self.temp_dir, f"episode_{task.episode_id}")
            os.makedirs(temp_episode_dir, exist_ok=True)
            logger.info(
                f"transcription._execute_transcription: Created temp dir {temp_episode_dir}",
            )

            # === ?current_step ?===
            start_step = task.current_step
            log_with_timestamp(
                "INFO",
                f"[RESUME] Current step: {start_step}, will resume from this step",
                task_id,
            )

            # OWNLOADING -> CONVERTING -> SPLITTING -> TRANSCRIBING -> MERGING
            #  current_step ?

            # === 1?===
            download_start = time.time()
            download_time = 0
            original_file = os.path.join(
                temp_episode_dir,
                f"original{os.path.splitext(task.original_audio_url)[-1]}",
            )
            file_size = 0

            if os.path.exists(original_file) and os.path.getsize(original_file) > 0:
                file_size = os.path.getsize(original_file)
                log_with_timestamp(
                    "INFO",
                    f"[STEP 1/6 DOWNLOAD] Skip! File already exists: {original_file} ({file_size / 1024 / 1024:.2f} MB)",
                    task_id,
                )
                log_with_timestamp(
                    "INFO",
                    "[STEP 1/6 DOWNLOAD] Using existing downloaded file",
                    task_id,
                )
            else:
                log_with_timestamp(
                    "INFO",
                    "[STEP 1/6 DOWNLOAD] Starting audio download with fallback...",
                    task_id,
                )
                log_with_timestamp(
                    "INFO",
                    f"[STEP 1/6 DOWNLOAD] Source URL: {task.original_audio_url[:100]}...",
                    task_id,
                )
                await self._update_task_progress_with_session(
                    session,
                    task_id,
                    "downloading",
                    5,
                    "Downloading audio file...",
                )

                logger.info(f"[STEP 1 DOWNLOAD] Target path: {original_file}")

                async with AudioDownloader() as downloader:
                    # ?
                    last_dl_progress = 0.0

                    async def download_progress(progress):
                        nonlocal last_dl_progress

                        # ?0%?
                        if int(progress) // 10 > int(last_dl_progress) // 10:
                            logger.info(
                                f"[STEP 1 DOWNLOAD] Progress: {progress:.1f}%",
                            )
                            last_dl_progress = progress

                        await self._update_task_progress_with_session(
                            session,
                            task_id,
                            "downloading",
                            5 + (progress * 0.15),  # 5-20%
                            f"Downloading... {progress:.1f}%",
                        )

                    # ?
                    file_path, file_size = await downloader.download_file_with_fallback(
                        task.original_audio_url,
                        original_file,
                        download_progress,
                    )

                log_with_timestamp(
                    "INFO",
                    f"[STEP 1/6 DOWNLOAD] Download complete! Size: {file_size} bytes ({file_size / 1024 / 1024:.2f} MB)",
                    task_id,
                )
                download_time = time.time() - download_start
                log_with_timestamp(
                    "INFO",
                    f"[STEP 1/6 DOWNLOAD] Time taken: {download_time:.2f}s",
                    task_id,
                )

            file_path = original_file  # file_path?

            # === 2MP3 ===
            conversion_time = 0
            converted_file = os.path.join(temp_episode_dir, "converted.mp3")

            log_with_timestamp(
                "INFO",
                f"[STEP 2/6 CONVERT] Checking conversion status: {converted_file}",
                task_id,
            )
            log_with_timestamp(
                "INFO",
                f"[STEP 2/6 CONVERT] File exists: {os.path.exists(converted_file)}",
                task_id,
            )

            skip_conversion = False
            if os.path.exists(converted_file):
                converted_size = os.path.getsize(converted_file)
                log_with_timestamp(
                    "INFO",
                    f"[STEP 2/6 CONVERT] Found existing file: {converted_size} bytes",
                    task_id,
                )
                # ?0KB
                if converted_size > 10240:  # 10KB
                    # fmpegMP3
                    try:
                        probe = await _ffmpeg_probe_async(converted_file)
                        log_with_timestamp(
                            "INFO",
                            f"[STEP 2/6 CONVERT] FFmpeg probe result: {probe}",
                            task_id,
                        )
                        duration = (
                            probe.get("format", {}).get("duration") if probe else None
                        )
                        if duration:
                            skip_conversion = True
                            log_with_timestamp(
                                "INFO",
                                f"[STEP 2/6 CONVERT] Skip! Valid MP3 file already exists: {converted_file} ({converted_size / 1024 / 1024:.2f} MB, {duration}s)",
                                task_id,
                            )
                            log_with_timestamp(
                                "INFO",
                                "[STEP 2/6 CONVERT] Using existing converted file",
                                task_id,
                            )
                        else:
                            log_with_timestamp(
                                "WARNING",
                                f"[STEP 2/6 CONVERT] File exists but invalid (no duration), re-converting: {converted_file}",
                                task_id,
                            )
                    except Exception as e:
                        log_with_timestamp(
                            "WARNING",
                            f"[STEP 2/6 CONVERT] File exists but validation failed ({e!s}), re-converting",
                            task_id,
                        )
                    else:
                        log_with_timestamp(
                            "WARNING",
                            f"[STEP 2/6 CONVERT] File exists but too small ({converted_size} bytes), re-converting",
                            task_id,
                        )
                else:
                    log_with_timestamp(
                        "INFO",
                        "[STEP 2/6 CONVERT] File does not exist, will convert",
                        task_id,
                    )

            if not skip_conversion:
                log_with_timestamp(
                    "INFO",
                    "[STEP 2/6 CONVERT] Starting MP3 conversion...",
                    task_id,
                )
                await self._update_task_progress_with_session(
                    session,
                    task_id,
                    "converting",
                    20,
                    "Converting to MP3...",
                )

                async def convert_progress(progress):
                    await self._update_task_progress_with_session(
                        session,
                        task_id,
                        "converting",
                        20 + (progress * 0.15),  # 20-35%
                        f"Converting... {progress:.1f}%",
                    )

                _, conversion_time = await AudioConverter.convert_to_mp3(
                    file_path,
                    converted_file,
                    convert_progress,
                )

                # Verify the converted file was actually created
                if not os.path.exists(converted_file):
                    error_msg = f"Conversion completed but output file not found: {converted_file}"
                    logger.error(f"[STEP 2/6 CONVERT] {error_msg}")
                    logger.error(
                        f"[STEP 2/6 CONVERT] Input file: {file_path}, exists: {os.path.exists(file_path)}",
                    )
                    await self._set_task_final_status(
                        session,
                        task_id,
                        TranscriptionStatus.FAILED,
                        "MP3 conversion failed - output file not created",
                    )
                    raise RuntimeError(
                        "MP3 conversion failed - output file not created",
                    )

                converted_size = os.path.getsize(converted_file)
                log_with_timestamp(
                    "INFO",
                    f"[STEP 2/6 CONVERT] Conversion complete! Output: {converted_file} ({converted_size / 1024 / 1024:.2f} MB), Time: {conversion_time:.2f}s",
                    task_id,
                )

            # Final verification before moving to STEP 3
            log_with_timestamp(
                "INFO",
                f"[STEP 2->3] Final check: converted_file exists = {os.path.exists(converted_file)}, size = {os.path.getsize(converted_file) if os.path.exists(converted_file) else 0}",
                task_id,
            )

            # === 3?===
            # converted_file?
            log_with_timestamp(
                "INFO",
                "[STEP 3/6 SPLIT] Starting split verification...",
                task_id,
            )

            if not os.path.exists(converted_file):
                error_msg = f"Converted file not found: {converted_file}. Cannot proceed with split."
                logger.error(f"[STEP 3/6 SPLIT] {error_msg}")
                logger.error(f"[STEP 3/6 SPLIT] Working directory: {os.getcwd()}")
                logger.error(
                    f"[STEP 3/6 SPLIT] Temp dir exists: {os.path.exists(temp_episode_dir)}",
                )
                if os.path.exists(temp_episode_dir):
                    files = os.listdir(temp_episode_dir)
                    logger.error(f"[STEP 3/6 SPLIT] Files in temp dir: {files}")
                await self._set_task_final_status(
                    session,
                    task_id,
                    TranscriptionStatus.FAILED,
                    "Converted audio file missing, cannot split",
                )
                raise RuntimeError("Converted audio file missing, cannot split")

            converted_file_size = os.path.getsize(converted_file)
            if converted_file_size == 0:
                error_msg = f"Converted file is empty: {converted_file}. Cannot proceed with split."
                logger.error(f"[STEP 3/6 SPLIT] {error_msg}")
                await self._set_task_final_status(
                    session,
                    task_id,
                    TranscriptionStatus.FAILED,
                    "Converted audio file is empty, cannot split",
                )
                raise RuntimeError("Converted audio file is empty, cannot split")

            log_with_timestamp(
                "INFO",
                f"[STEP 3/6 SPLIT] Verified converted file exists: {converted_file} ({converted_file_size / 1024 / 1024:.2f} MB)",
                task_id,
            )

            split_dir = os.path.join(temp_episode_dir, "chunks")

            if os.path.exists(split_dir) and os.path.isdir(split_dir):
                # chunk
                chunk_file_pattern = re.compile(r".+_chunk_(\d+)\.mp3$")
                existing_chunks: list[tuple[int, str]] = []
                for file_name in os.listdir(split_dir):
                    match = chunk_file_pattern.fullmatch(file_name)
                    if match:
                        existing_chunks.append((int(match.group(1)), file_name))

                if existing_chunks:
                    log_with_timestamp(
                        "INFO",
                        f"[STEP 3/6 SPLIT] Skip! Chunks already exist: {len(existing_chunks)} files found",
                        task_id,
                    )
                    log_with_timestamp(
                        "INFO",
                        "[STEP 3/6 SPLIT] Using existing chunks",
                        task_id,
                    )
                    # chunks
                    chunks = []
                    for index, chunk_file in sorted(
                        existing_chunks,
                        key=lambda item: item[0],
                    ):
                        chunk_path = os.path.join(split_dir, chunk_file)
                        file_size = os.path.getsize(chunk_path)
                        chunks.append(
                            AudioChunk(
                                index=index,
                                file_path=chunk_path,
                                start_time=0,  # ?
                                duration=0,
                                file_size=file_size,
                                transcript=None,
                            ),
                        )
                else:
                    # ?
                    log_with_timestamp(
                        "INFO",
                        f"[STEP 3/6 SPLIT] Starting audio split with chunk_size_mb={task.chunk_size_mb}...",
                        task_id,
                    )
                    await self._update_task_progress_with_session(
                        session,
                        task_id,
                        "splitting",
                        35,
                        "Splitting audio file...",
                    )

                    async def split_progress(progress):
                        await self._update_task_progress_with_session(
                            session,
                            task_id,
                            "splitting",
                            35 + (progress * 0.10),  # 35-45%
                            f"Splitting... {progress:.1f}%",
                        )

                    chunks = await AudioSplitter.split_mp3(
                        converted_file,
                        split_dir,
                        task.chunk_size_mb,
                        split_progress,
                    )
                    log_with_timestamp(
                        "INFO",
                        f"[STEP 3/6 SPLIT] Split complete! Created {len(chunks)} chunks",
                        task_id,
                    )
            else:
                # ?
                log_with_timestamp(
                    "INFO",
                    f"[STEP 3/6 SPLIT] Starting audio split with chunk_size_mb={task.chunk_size_mb}...",
                    task_id,
                )
                await self._update_task_progress_with_session(
                    session,
                    task_id,
                    "splitting",
                    35,
                    "Splitting audio file...",
                )

                async def split_progress(progress):
                    await self._update_task_progress_with_session(
                        session,
                        task_id,
                        "splitting",
                        35 + (progress * 0.10),  # 35-45%
                        f"Splitting... {progress:.1f}%",
                    )

                chunks = await AudioSplitter.split_mp3(
                    converted_file,
                    split_dir,
                    task.chunk_size_mb,
                    split_progress,
                )
                log_with_timestamp(
                    "INFO",
                    f"[STEP 3/6 SPLIT] Split complete! Created {len(chunks)} chunks",
                    task_id,
                )

            # === 4?===
            #
            chunks_to_transcribe = []
            already_transcribed = []
            for chunk in chunks:
                transcript_file = chunk.file_path.replace(".mp3", ".txt")
                if (
                    os.path.exists(transcript_file)
                    and os.path.getsize(transcript_file) > 0
                ):
                    # ?
                    async with aiofiles.open(transcript_file, encoding="utf-8") as f:
                        content = await f.read()
                    if content.strip():
                        chunk.transcript = content
                        already_transcribed.append(chunk)
                else:
                    chunks_to_transcribe.append(chunk)

            if already_transcribed:
                log_with_timestamp(
                    "INFO",
                    f"[STEP 4/6 TRANSCRIBE] Found {len(already_transcribed)} already transcribed chunks, skipping",
                    task_id,
                )

            log_with_timestamp(
                "INFO",
                f"[STEP 4/6 TRANSCRIBE] Starting transcription of {len(chunks_to_transcribe)} remaining chunks...",
                task_id,
            )
            log_with_timestamp(
                "INFO",
                f"[STEP 4/6 TRANSCRIBE] Model: {task.model_used}",
                task_id,
            )

            if chunks_to_transcribe:
                await self._update_task_progress_with_session(
                    session,
                    task_id,
                    "transcribing",
                    45,
                    f"Transcribing {len(chunks_to_transcribe)} audio chunks...",
                )

                transcription_start = time.time()

                # ?
                last_trans_progress = 0.0

                async def transcribe_progress(progress):
                    nonlocal last_trans_progress

                    # ?0%?
                    if int(progress) // 10 > int(last_trans_progress) // 10:
                        logger.info(
                            f"[STEP 4 TRANSCRIBE] Progress: {progress:.1f}%",
                        )
                        last_trans_progress = progress

                    await self._update_task_progress_with_session(
                        session,
                        task_id,
                        "transcribing",
                        45 + (progress * 0.50),  # 45-95%
                        f"Transcribing... {progress:.1f}%",
                    )

                async with SiliconFlowTranscriber(
                    api_key,
                    api_url,
                    self.max_threads,
                ) as transcriber:
                    transcribed_chunks = await transcriber.transcribe_chunks(
                        chunks_to_transcribe,
                        task.model_used,
                        transcribe_progress,
                        ai_repo=ai_repo,
                        config_db_id=config_db_id,
                    )

                all_chunks = already_transcribed + transcribed_chunks

                log_with_timestamp(
                    "INFO",
                    "[STEP 4/6 TRANSCRIBE] Transcription chunks finished!",
                    task_id,
                )

                # Log transcription results summary
                success_count = sum(1 for c in all_chunks if c.transcript)
                failed_count = len(all_chunks) - success_count
                log_with_timestamp(
                    "INFO",
                    f"[STEP 4/6 TRANSCRIBE] Results: {success_count} succeeded, {failed_count} failed out of {len(all_chunks)} total",
                    task_id,
                )

                transcription_time = time.time() - transcription_start
                log_with_timestamp(
                    "INFO",
                    f"[STEP 4/6 TRANSCRIBE] Time taken: {transcription_time:.2f}s",
                    task_id,
                )
            else:
                # ?
                all_chunks = already_transcribed
                log_with_timestamp(
                    "INFO",
                    "[STEP 4/6 TRANSCRIBE] All chunks already transcribed! Skipping transcription",
                    task_id,
                )
                success_count = len(all_chunks)
                failed_count = 0
                transcription_time = 0

            total_chunks = len(all_chunks)
            success_ratio = (success_count / total_chunks) if total_chunks else 0.0
            if success_count == 0 or success_ratio < self.min_chunk_success_ratio:
                threshold = self.min_chunk_success_ratio
                error_message = (
                    "Insufficient successful chunks for transcript merge: "
                    f"success={success_count}, failed={failed_count}, "
                    f"total={total_chunks}, ratio={success_ratio:.2f}, "
                    f"required_ratio={threshold:.2f}"
                )
                await self._set_task_final_status(
                    session,
                    task_id,
                    TranscriptionStatus.FAILED,
                    error_message,
                )
                raise RuntimeError(error_message)

            # 5?
            log_with_timestamp(
                "INFO",
                "[STEP 5/6 MERGE] Merging transcription results...",
                task_id,
            )
            await self._update_task_progress_with_session(
                session,
                task_id,
                "merging",
                95,
                "Merging transcription results...",
            )

            # ?
            sorted_chunks = sorted(all_chunks, key=lambda x: x.index)
            full_transcript = "\n\n".join(
                [
                    chunk.transcript.strip()
                    for chunk in sorted_chunks
                    if chunk.transcript and chunk.transcript.strip()
                ],
            )

            log_with_timestamp(
                "INFO",
                f"[STEP 5/6 MERGE] Merged transcript: {len(full_transcript)} chars, {len(full_transcript.split())} words",
                task_id,
            )
            log_with_timestamp(
                "INFO",
                f"[STEP 5/6 MERGE] Preview: {full_transcript[:150]}...",
                task_id,
            )

            # 6
            storage_path = self._get_episode_storage_path(episode)
            os.makedirs(storage_path, exist_ok=True)

            final_audio_path = os.path.join(storage_path, "original.mp3")

            # Verify converted file exists before copying
            if not os.path.exists(converted_file):
                error_msg = f"Converted audio file not found: {converted_file}"
                logger.error(f"[STEP 6 SAVE] {error_msg}")
                logger.error(f"[STEP 6 SAVE] Working directory: {os.getcwd()}")
                logger.error(
                    f"[STEP 6 SAVE] Absolute path: {os.path.abspath(converted_file)}",
                )
                # List files in temp directory for debugging
                if os.path.exists(temp_episode_dir):
                    files = os.listdir(temp_episode_dir)
                    logger.error(f"[STEP 6 SAVE] Files in temp dir: {files}")
                else:
                    logger.error(
                        f"[STEP 6 SAVE] Temp directory does not exist: {temp_episode_dir}",
                    )
                raise FileNotFoundError(error_msg)

            # Move audio file to permanent storage
            # Use shutil.move instead of os.replace to handle cross-device moves (e.g., Docker volumes)
            #  shutil.move  os.replace?Docker
            import shutil

            try:
                shutil.move(converted_file, final_audio_path)
            except OSError as e:
                logger.warning(
                    f"[STEP 6 SAVE] shutil.move failed ({e}), trying copy + delete",
                )
                shutil.copy2(converted_file, final_audio_path)
                try:
                    os.remove(converted_file)
                except OSError:
                    logger.warning(
                        f"[STEP 6 SAVE] Could not remove source file: {converted_file}",
                    )

            transcript_path = os.path.join(storage_path, "transcript.txt")
            async with aiofiles.open(transcript_path, "w", encoding="utf-8") as f:
                await f.write(full_transcript)

            log_with_timestamp(
                "INFO",
                f"[STEP 6/6 SAVE] Transcript saved to: {transcript_path}",
                task_id,
            )

            task_update = {
                "status": TranscriptionStatus.COMPLETED,
                "current_step": "merging",
                "progress_percentage": 100.0,
                "transcript_content": full_transcript,
                "transcript_word_count": len(full_transcript.split()),
                "original_file_path": final_audio_path,
                "original_file_size": file_size,
                "download_time": download_time,
                "conversion_time": conversion_time,
                "transcription_time": transcription_time,
                "chunk_info": build_chunk_info(sorted_chunks),
                "completed_at": datetime.now(UTC),
            }

            stmt = (
                update(TranscriptionTask)
                .where(TranscriptionTask.id == task_id)
                .values(**task_update)
            )
            await session.execute(stmt)

            # ?
            # Create or update transcript record in dedicated table
            transcript_stmt = select(PodcastEpisodeTranscript).where(
                PodcastEpisodeTranscript.episode_id == task.episode_id
            )
            transcript_row_result = await session.execute(transcript_stmt)
            transcript_row = transcript_row_result.scalar_one_or_none()
            word_count = len(full_transcript.split())
            if transcript_row:
                transcript_row.transcript_content = full_transcript
                transcript_row.transcript_word_count = word_count
            else:
                session.add(
                    PodcastEpisodeTranscript(
                        episode_id=task.episode_id,
                        transcript_content=full_transcript,
                        transcript_word_count=word_count,
                    )
                )

            episode_update = {
                "transcript_url": f"file://{transcript_path}",
                "status": "pending_summary",
            }

            stmt = (
                update(PodcastEpisode)
                .where(PodcastEpisode.id == task.episode_id)
                .values(**episode_update)
            )
            await session.execute(stmt)

            await session.commit()

            total_time = time.time() - download_start
            log_with_timestamp(
                "INFO",
                f"[TRANSCRIPTION COMPLETE] Successfully completed transcription for episode {task.episode_id}",
                task_id,
            )
            log_with_timestamp(
                "INFO",
                f"[TRANSCRIPTION COMPLETE] Total time: {total_time:.2f}s (download:{download_time:.2f}s, convert:{conversion_time:.2f}s, transcribe:{transcription_time:.2f}s)",
                task_id,
            )
            log_with_timestamp(
                "INFO",
                f"[TRANSCRIPTION COMPLETE] Transcript: {len(full_transcript)} chars, {len(full_transcript.split())} words",
                task_id,
            )

            # AI
            log_with_timestamp(
                "INFO",
                f"[AI SUMMARY] Scheduling AI summary for episode {task.episode_id}",
                task_id,
            )
            await self._schedule_ai_summary(session, task_id)

            # Highlight extraction
            log_with_timestamp(
                "INFO",
                f"[HIGHLIGHT] Scheduling highlight extraction for episode {task.episode_id}",
                task_id,
            )
            await self._schedule_highlight_extraction(session, task_id)
        except Exception as e:
            import traceback

            error_trace = traceback.format_exc()
            logger.error(
                f"[EXECUTE ERROR] Transcription failed for task {task_id}: {e!s}",
            )
            logger.error(f"[EXECUTE ERROR] Traceback:\n{error_trace}")
            status_stmt = select(TranscriptionTask.status).where(
                TranscriptionTask.id == task_id,
            )
            status_result = await session.execute(status_stmt)
            current_status = status_result.scalar()
            if current_status not in {
                TranscriptionStatus.COMPLETED,
                TranscriptionStatus.FAILED,
                TranscriptionStatus.CANCELLED,
                "completed",
                "failed",
                "cancelled",
            }:
                await self._set_task_final_status(
                    session,
                    task_id,
                    TranscriptionStatus.FAILED,
                    f"Transcription failed: {e!s}",
                )
            raise
        finally:
            # Only clean up temporary files if the task completed successfully
            # Failed or interrupted tasks should keep their temp files for incremental recovery
            try:
                # Re-fetch task status to see if it completed successfully
                stmt_check = select(TranscriptionTask.status).where(
                    TranscriptionTask.id == task_id,
                )
                result_check = await session.execute(stmt_check)
                final_status = result_check.scalar()

                if final_status == TranscriptionStatus.COMPLETED and task is not None:
                    import shutil

                    temp_episode_dir = os.path.join(
                        self.temp_dir,
                        f"episode_{task.episode_id}",
                    )
                    if os.path.exists(temp_episode_dir):
                        shutil.rmtree(temp_episode_dir)
                        logger.info(
                            f"[CLEANUP] Cleaned up temporary directory for successful task {task_id}: {temp_episode_dir}",
                        )
                elif task is not None:
                    temp_episode_dir = os.path.join(
                        self.temp_dir,
                        f"episode_{task.episode_id}",
                    )
                    if os.path.exists(temp_episode_dir):
                        logger.info(
                            f"[CLEANUP] Preserving temporary directory for task {task_id} (status={final_status}): {temp_episode_dir}",
                        )
            except Exception as e:
                logger.error(f"[CLEANUP] Error during cleanup: {e!s}")

    async def get_transcription_status(self, task_id: int) -> TranscriptionTask | None:
        """?"""
        stmt = select(TranscriptionTask).where(TranscriptionTask.id == task_id)
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def get_episode_transcription(
        self,
        episode_id: int,
    ) -> TranscriptionTask | None:
        """?"""
        stmt = select(TranscriptionTask).where(
            TranscriptionTask.episode_id == episode_id,
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def _schedule_ai_summary(self, session: AsyncSession, task_id: int):
        """AI"""
        task: TranscriptionTask | None = None
        try:
            log_with_timestamp(
                "INFO",
                f"[AI SUMMARY] Getting transcription task {task_id}",
                task_id,
            )
            stmt = select(TranscriptionTask).where(TranscriptionTask.id == task_id)
            result = await session.execute(stmt)
            task = result.scalar_one_or_none()

            if not task:
                log_with_timestamp(
                    "ERROR",
                    f"[AI SUMMARY] Transcription task {task_id} not found",
                    task_id,
                )
                return

            log_with_timestamp(
                "INFO",
                f"[AI SUMMARY] Found transcription task {task_id} for episode {task.episode_id}",
                task_id,
            )

            from app.domains.podcast.services.content_service import (
                PodcastSummaryGenerationService,
            )

            summary_service = PodcastSummaryGenerationService(session)
            log_with_timestamp(
                "INFO",
                f"[AI SUMMARY] Starting AI summary generation for episode {task.episode_id}",
                task_id,
            )

            # AI
            summary_result = await summary_service.generate_summary(task.episode_id)

            word_count = len(summary_result["summary_content"].split())

            log_with_timestamp(
                "INFO",
                f"[AI SUMMARY] Successfully generated summary for episode {task.episode_id}",
                task_id,
            )
            log_with_timestamp(
                "INFO",
                f"[AI SUMMARY] Summary: {len(summary_result['summary_content'])} chars, {word_count} words",
                task_id,
            )
            log_with_timestamp(
                "INFO",
                f"[AI SUMMARY] Processing time: {summary_result['processing_time']:.2f}s, Model: {summary_result['model_name']}",
                task_id,
            )

            #  : sessiontaskI
            #  summary_service.generate_summary() db session
            # essiontask
            try:
                await session.refresh(task)
                log_with_timestamp(
                    "INFO",
                    "[AI SUMMARY] Refreshed task object from database, summary_content is now available",
                    task_id,
                )
            except Exception as refresh_error:
                log_with_timestamp(
                    "WARNING",
                    f"[AI SUMMARY] Failed to refresh task: {refresh_error}",
                    task_id,
                )

        except Exception as e:
            import traceback

            error_trace = traceback.format_exc()
            error_msg = str(e)
            log_with_timestamp(
                "ERROR",
                f"[AI SUMMARY] Failed to generate summary for task {task_id}: {error_msg}",
                task_id,
            )
            logger.error(f"[AI SUMMARY] Traceback: {error_trace}")

            if task is None:
                return

            episode_meta_stmt = select(PodcastEpisode.metadata_json).where(
                PodcastEpisode.id == task.episode_id,
            )
            episode_meta_result = await session.execute(episode_meta_stmt)
            metadata_json = episode_meta_result.scalar_one_or_none() or {}
            metadata_json["summary_error"] = error_msg
            metadata_json["summary_failed_at"] = datetime.now(UTC).isoformat()

            await session.execute(
                update(PodcastEpisode)
                .where(PodcastEpisode.id == task.episode_id)
                .values(
                    status="summary_failed",
                    metadata_json=metadata_json,
                    updated_at=datetime.now(UTC),
                ),
            )
            await session.execute(
                update(TranscriptionTask)
                .where(TranscriptionTask.id == task_id)
                .values(
                    summary_error_message=error_msg,
                    updated_at=datetime.now(UTC),
                ),
            )
            await session.commit()

    async def _schedule_highlight_extraction(self, session: AsyncSession, task_id: int):
        """Trigger highlight extraction after successful transcription."""
        try:
            stmt = select(TranscriptionTask).where(TranscriptionTask.id == task_id)
            result = await session.execute(stmt)
            task = result.scalar_one_or_none()

            if not task:
                log_with_timestamp(
                    "ERROR",
                    f"[HIGHLIGHT] Transcription task {task_id} not found for highlight extraction",
                    task_id,
                )
                return

            from app.domains.podcast.services.content_service import (
                HighlightExtractionService,
            )

            highlight_service = HighlightExtractionService(session)
            log_with_timestamp(
                "INFO",
                f"[HIGHLIGHT] Starting highlight extraction for episode {task.episode_id}",
                task_id,
            )

            highlight_result = await highlight_service.extract_highlights_for_episode(
                task.episode_id
            )

            log_with_timestamp(
                "INFO",
                f"[HIGHLIGHT] Highlight extraction result for episode {task.episode_id}: "
                f"status={highlight_result.get('status')}, "
                f"count={highlight_result.get('highlights_count', 0)}, "
                f"time={highlight_result.get('processing_time', 0):.2f}s",
                task_id,
            )

        except Exception as e:
            import traceback

            error_trace = traceback.format_exc()
            log_with_timestamp(
                "ERROR",
                f"[HIGHLIGHT] Failed to extract highlights for task {task_id}: {e}",
                task_id,
            )
            logger.error(f"[HIGHLIGHT] Traceback: {error_trace}")

    async def cancel_transcription(self, task_id: int) -> bool:
        """"""
        task = await self.get_transcription_status(task_id)
        if not task:
            return False

        if task.status in [
            TranscriptionStatus.COMPLETED,
            TranscriptionStatus.FAILED,
            TranscriptionStatus.CANCELLED,
        ]:
            return False

        await self.update_task_progress(
            task_id,
            TranscriptionStatus.CANCELLED,
            task.progress_percentage,
            "Transcription cancelled by user",
        )

        return True
