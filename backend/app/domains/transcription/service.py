import asyncio
import logging
from pathlib import Path
from uuid import UUID

import aiohttp
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.domains.podcast.models import ProcessingStatus
from app.domains.podcast.repository import EpisodeRepository
from app.domains.transcription.models import Transcript
from app.domains.transcription.repository import TranscriptRepository

logger = logging.getLogger(__name__)
settings = get_settings()


class TranscriptionService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.repo = TranscriptRepository(session)
        self.episode_repo = EpisodeRepository(session)

    async def download_audio(self, url: str, episode_id: UUID) -> str:
        """Download audio file to the configured audio storage directory.

        Files are stored as {episode_id}.mp3 for predictable naming
        and easy cleanup.

        Args:
            url: The audio file URL.
            episode_id: The episode UUID, used as the filename.

        Returns:
            Local file path of the downloaded audio.
        """
        audio_dir = Path(settings.AUDIO_STORAGE_DIR)
        audio_dir.mkdir(parents=True, exist_ok=True)

        dest_path = audio_dir / f"{episode_id}.mp3"

        if dest_path.exists() and dest_path.stat().st_size > 0:
            logger.info(f"Audio file already exists: {dest_path}")
            return str(dest_path)

        async with aiohttp.ClientSession() as http_session:
            async with http_session.get(
                url, timeout=aiohttp.ClientTimeout(total=300)
            ) as resp:
                if resp.status != 200:
                    raise RuntimeError(
                        f"Failed to download audio: HTTP {resp.status}"
                    )
                with open(dest_path, "wb") as f:
                    async for chunk in resp.content.iter_chunked(8192):
                        f.write(chunk)

        logger.info(f"Downloaded audio to {dest_path}")
        return str(dest_path)

    async def transcribe_episode(self, episode_id: UUID) -> Transcript:
        """Full pipeline: download audio, transcribe with faster-whisper, save.

        Args:
            episode_id: The episode ID to transcribe.

        Returns:
            The Transcript record.
        """
        episode = await self.episode_repo.get(episode_id)
        if episode is None:
            raise ValueError(f"Episode {episode_id} not found")

        if not episode.audio_url:
            raise ValueError(f"Episode {episode_id} has no audio URL")

        # Get or create transcript record
        transcript = await self.repo.get_by_episode(episode_id)
        if transcript is None:
            transcript = await self.repo.create({
                "episode_id": episode_id,
                "status": ProcessingStatus.PROCESSING,
            })
        else:
            await self.repo.update(
                transcript.id, {"status": ProcessingStatus.PROCESSING}
            )

        # Update episode status
        await self.episode_repo.update_status(
            episode_id, transcript_status=ProcessingStatus.PROCESSING
        )

        try:
            # Download audio
            audio_path = await self.download_audio(
                episode.audio_url, episode_id
            )

            # Run transcription in thread pool (CPU-bound, blocks the event loop)
            result = await asyncio.to_thread(
                self._transcribe_sync, audio_path
            )

            # Update transcript
            transcript = await self.repo.update(transcript.id, {
                "content": result["text"],
                "segments": result["segments"],
                "language": result["language"],
                "duration": result["duration"],
                "word_count": result["word_count"],
                "model_used": settings.WHISPER_MODEL_SIZE,
                "status": ProcessingStatus.COMPLETED,
            })

            # Update episode status
            await self.episode_repo.update_status(
                episode_id, transcript_status=ProcessingStatus.COMPLETED
            )

            await self.session.flush()
            return transcript

        except Exception as e:
            logger.error(
                f"Transcription failed for episode {episode_id}: {e}"
            )
            await self.repo.update(
                transcript.id, {"status": ProcessingStatus.FAILED}
            )
            await self.episode_repo.update_status(
                episode_id, transcript_status=ProcessingStatus.FAILED
            )
            await self.session.flush()
            raise

    def _transcribe_sync(self, audio_path: str) -> dict:
        """Synchronous transcription using faster-whisper pipeline.

        This method is CPU-bound and MUST be called via asyncio.to_thread()
        to avoid blocking the event loop.

        Args:
            audio_path: Path to the audio file.

        Returns:
            Dict with 'text', 'language', 'duration', 'word_count'.
        """
        from app.core.whisper import get_whisper_pipeline

        pipeline = get_whisper_pipeline()

        segments, info = pipeline.transcribe(
            audio_path,
            batch_size=settings.WHISPER_BATCH_SIZE,
            vad_filter=True,
        )

        segment_list = list(segments)

        full_text = "".join(seg.text for seg in segment_list).strip()
        word_count = len(full_text) if full_text else 0

        segment_data = [
            {"start": seg.start, "end": seg.end, "text": seg.text}
            for seg in segment_list
        ]

        return {
            "text": full_text,
            "segments": segment_data,
            "language": info.language,
            "duration": int(info.duration) if info.duration else None,
            "word_count": word_count,
        }

    async def get_transcript(self, episode_id: UUID) -> Transcript | None:
        """Get transcript for an episode."""
        return await self.repo.get_by_episode(episode_id)
