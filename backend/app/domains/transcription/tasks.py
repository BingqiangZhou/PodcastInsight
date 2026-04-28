import logging
from uuid import UUID

from app.core.celery_app import celery_app
from app.core.database import async_session_factory

logger = logging.getLogger(__name__)


@celery_app.task(
    name="app.domains.transcription.tasks.transcribe_episode_task",
    bind=True,
    max_retries=3,
    default_retry_delay=120,
)
def transcribe_episode_task(self, episode_id: str) -> dict:
    """Celery task: transcribe an episode using local faster-whisper.

    Args:
        episode_id: The episode UUID as string.

    Returns:
        Dict with transcription result status.
    """
    import asyncio

    from app.domains.transcription.service import TranscriptionService

    async def _run() -> dict:
        async with async_session_factory() as session:
            try:
                service = TranscriptionService(session)
                transcript = await service.transcribe_episode(
                    UUID(episode_id)
                )
                await session.commit()
                return {
                    "episode_id": episode_id,
                    "transcript_id": str(transcript.id),
                    "status": transcript.status.value,
                    "word_count": transcript.word_count,
                }
            except Exception:
                await session.rollback()
                raise

    try:
        result = asyncio.run(_run())
    except Exception as exc:
        logger.error(
            f"Transcription task failed for episode {episode_id}: {exc}"
        )
        raise self.retry(exc=exc, countdown=120)

    # Quality gate: skip summarization for low-quality transcripts
    if result.get("status") == "completed":
        word_count = result.get("word_count") or 0
        min_words = 100
        if word_count < min_words:
            logger.warning(
                f"Transcript for episode {episode_id} has only {word_count} words "
                f"(minimum {min_words}). Skipping summarization."
            )
        else:
            celery_app.send_task(
                "app.domains.summary.tasks.summarize_episode_task",
                args=[episode_id],
            )
            logger.info(f"Dispatched summarization task for episode {episode_id}")

    return result


@celery_app.task(
    name="app.domains.transcription.tasks.cleanup_audio_task",
)
def cleanup_audio_task() -> dict:
    """Celery task: remove audio files older than configured age.

    Skips files belonging to episodes with active (PROCESSING) transcriptions
    to avoid deleting files that are currently being used.
    """
    import asyncio

    from app.core.whisper import cleanup_old_audio_files

    async def _get_active_ids() -> set[str]:
        from app.core.database import async_session_factory
        from app.domains.podcast.models import ProcessingStatus
        from app.domains.transcription.models import Transcript
        from sqlalchemy import select

        async with async_session_factory() as session:
            result = await session.execute(
                select(Transcript.episode_id).where(
                    Transcript.status == ProcessingStatus.PROCESSING
                )
            )
            return {str(row[0]) for row in result.all()}

    active_ids = asyncio.run(_get_active_ids())
    from app.core.whisper import cleanup_old_audio_files

    removed = cleanup_old_audio_files(active_episode_ids=active_ids)
    logger.info(f"Audio cleanup removed {removed} files (protected {len(active_ids)} active)")
    return {"removed": removed}
