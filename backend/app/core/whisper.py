import logging
import threading
from datetime import datetime, timezone
from pathlib import Path

from app.core.config import get_settings

logger = logging.getLogger(__name__)

_pipeline = None
_lock = threading.Lock()


def get_whisper_pipeline():
    """Get or initialize the singleton BatchedInferencePipeline.

    Thread-safe: uses a lock so concurrent requests do not double-load.
    """
    global _pipeline
    if _pipeline is not None:
        return _pipeline

    with _lock:
        if _pipeline is not None:
            return _pipeline

        settings = get_settings()
        model_dir = Path(settings.WHISPER_MODEL_DIR)
        model_dir.mkdir(parents=True, exist_ok=True)

        logger.info(
            f"Loading faster-whisper model '{settings.WHISPER_MODEL_SIZE}' "
            f"on {settings.WHISPER_DEVICE} with {settings.WHISPER_COMPUTE_TYPE}..."
        )

        from faster_whisper import BatchedInferencePipeline, WhisperModel

        model = WhisperModel(
            settings.WHISPER_MODEL_SIZE,
            device=settings.WHISPER_DEVICE,
            compute_type=settings.WHISPER_COMPUTE_TYPE,
            download_root=str(model_dir),
        )
        _pipeline = BatchedInferencePipeline(model=model)
        logger.info("faster-whisper pipeline loaded successfully.")
        return _pipeline


def unload_whisper_model() -> None:
    """Unload the model to free memory. Called during shutdown."""
    global _pipeline
    _pipeline = None
    logger.info("faster-whisper model unloaded.")


def cleanup_old_audio_files(active_episode_ids: set[str] | None = None) -> int:
    """Remove audio files older than AUDIO_CLEANUP_AGE_HOURS.

    Args:
        active_episode_ids: Set of episode IDs whose audio files should NOT
            be deleted (e.g. episodes currently being transcribed).

    Returns:
        Number of files removed.
    """
    settings = get_settings()
    audio_dir = Path(settings.AUDIO_STORAGE_DIR)
    if not audio_dir.exists():
        return 0

    protected = active_episode_ids or set()
    now = datetime.now(timezone.utc)
    max_age_seconds = settings.AUDIO_CLEANUP_AGE_HOURS * 3600
    removed = 0

    for file_path in audio_dir.iterdir():
        if not file_path.is_file():
            continue

        # Skip files belonging to episodes with active transcriptions
        episode_id = file_path.stem
        if episode_id in protected:
            logger.debug(f"Skipping audio file for active transcription: {file_path.name}")
            continue

        file_mtime = datetime.fromtimestamp(
            file_path.stat().st_mtime, tz=timezone.utc
        )
        age_seconds = (now - file_mtime).total_seconds()
        if age_seconds > max_age_seconds:
            file_path.unlink()
            removed += 1
            logger.info(f"Cleaned up old audio file: {file_path.name}")

    return removed
