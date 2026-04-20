"""SiliconFlow API transcription service."""

import asyncio
import logging
import os
import time
from typing import Any

import aiofiles
import aiohttp

from app.shared.retry_utils import calculate_backoff

from .models import AudioChunk


logger = logging.getLogger(__name__)


class SiliconFlowTranscriber:
    """SiliconFlow API transcription service."""

    def __init__(self, api_key: str, api_url: str, max_concurrent: int = 4):
        self.api_key = api_key
        self.api_url = api_url
        self.max_concurrent = max_concurrent
        self.semaphore = asyncio.Semaphore(max_concurrent)
        self.session: aiohttp.ClientSession | None = None
        self._usage_stats = {"success": 0, "failure": 0}
        self._usage_stats_lock = asyncio.Lock()

    async def _record_usage(self, *, success: bool) -> None:
        key = "success" if success else "failure"
        async with self._usage_stats_lock:
            self._usage_stats[key] += 1

    async def __aenter__(self):
        """Async context manager entry."""
        connector = aiohttp.TCPConnector(limit=self.max_concurrent)
        timeout = aiohttp.ClientTimeout(total=600)
        self.session = aiohttp.ClientSession(
            connector=connector,
            timeout=timeout,
            headers={"Authorization": f"Bearer {self.api_key}"},
        )
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Async context manager exit."""
        if self.session:
            await self.session.close()

    async def _request_chunk_transcription(
        self,
        chunk: AudioChunk,
        model: str,
    ) -> tuple[int, dict[str, Any] | None, str | None]:
        """Post one chunk while keeping the file handle open for the whole request."""
        if not self.session:
            raise RuntimeError("Transcriber must be used as async context manager")

        data = aiohttp.FormData()
        data.add_field("model", model)
        try:
            async with aiofiles.open(chunk.file_path, "rb") as f:
                file_content = await f.read()
            data.add_field(
                "file",
                file_content,
                filename=os.path.basename(chunk.file_path),
                content_type="audio/mpeg",
            )
            async with self.session.post(self.api_url, data=data) as response:
                if response.status != 200:
                    return response.status, None, await response.text()
                return response.status, await response.json(), None
        except Exception:
            logger.exception(
                "Chunk %s upload request failed for %s",
                chunk.index,
                chunk.file_path,
            )
            raise

    async def transcribe_chunk(
        self,
        chunk: AudioChunk,
        model: str = "FunAudioLLM/SenseVoiceSmall",
    ) -> AudioChunk:
        """Transcribe a single audio chunk with retries."""
        async with self.semaphore:
            if not self.session:
                raise RuntimeError("Transcriber must be used as async context manager")

            max_retries = 3
            base_delay = 2

            for attempt in range(max_retries):
                chunk_start = time.time()
                try:
                    (
                        status_code,
                        result,
                        error_text,
                    ) = await self._request_chunk_transcription(
                        chunk,
                        model,
                    )
                    if status_code != 200:
                        await self._record_usage(success=False)
                        logger.error(
                            "Chunk %s API error on attempt %s: status=%s body=%s",
                            chunk.index,
                            attempt + 1,
                            status_code,
                            error_text,
                        )
                        if attempt < max_retries - 1:
                            await asyncio.sleep(calculate_backoff(attempt, base_delay))
                            continue
                        chunk.transcript = None
                        return chunk

                    transcript = (result or {}).get("text", "")
                    await self._record_usage(success=True)
                    chunk.transcript = transcript

                    transcript_file = chunk.file_path.replace(".mp3", ".txt")
                    try:
                        async with aiofiles.open(
                            transcript_file,
                            "w",
                            encoding="utf-8",
                        ) as file_obj:
                            await file_obj.write(transcript)
                    except Exception as save_error:
                        logger.warning(
                            "Failed to persist transcript chunk %s: %s",
                            chunk.index,
                            save_error,
                        )

                    logger.info(
                        "Chunk %s completed in %.2fs",
                        chunk.index,
                        time.time() - chunk_start,
                    )
                    return chunk
                except Exception as exc:
                    await self._record_usage(success=False)
                    logger.error(
                        "Chunk %s attempt %s failed: %s",
                        chunk.index,
                        attempt + 1,
                        exc,
                    )
                    if attempt < max_retries - 1:
                        await asyncio.sleep(calculate_backoff(attempt, base_delay))
                    else:
                        chunk.transcript = None
                        return chunk

            return chunk

    async def transcribe_chunks(
        self,
        chunks: list[AudioChunk],
        model: str = "FunAudioLLM/SenseVoiceSmall",
        progress_callback=None,
        ai_repo=None,
        config_db_id: int | None = None,
    ) -> list[AudioChunk]:
        """Transcribe chunks concurrently and persist usage in one DB commit."""
        if not chunks:
            return []

        start_time = time.time()
        self._usage_stats = {"success": 0, "failure": 0}
        max_in_flight = max(1, self.max_concurrent)
        pending_chunks = iter(chunks)

        def _schedule_next() -> asyncio.Task[AudioChunk] | None:
            next_chunk = next(pending_chunks, None)
            if next_chunk is None:
                return None
            return asyncio.create_task(self.transcribe_chunk(next_chunk, model))

        in_flight: set[asyncio.Task[AudioChunk]] = set()
        for _ in range(min(len(chunks), max_in_flight)):
            task = _schedule_next()
            if task is not None:
                in_flight.add(task)

        results: list[AudioChunk] = []
        completed = 0
        while in_flight:
            done, _pending = await asyncio.wait(
                in_flight,
                return_when=asyncio.FIRST_COMPLETED,
            )
            for task in done:
                in_flight.remove(task)
                try:
                    results.append(await task)
                    completed += 1
                    if progress_callback:
                        await progress_callback((completed / len(chunks)) * 100)
                except Exception as exc:
                    logger.error("Unexpected chunk coroutine error: %s", exc)

                next_task = _schedule_next()
                if next_task is not None:
                    in_flight.add(next_task)

        results.sort(key=lambda item: item.index)

        if ai_repo and config_db_id:
            try:
                await ai_repo.increment_usage_bulk(
                    config_db_id,
                    success_count=self._usage_stats["success"],
                    error_count=self._usage_stats["failure"],
                )
            except Exception as stats_error:
                logger.warning(
                    "Failed to persist aggregated usage stats: %s",
                    stats_error,
                )

        success_count = sum(1 for item in results if item.transcript is not None)
        logger.info(
            "Completed transcription of %s/%s chunks in %.2fs",
            success_count,
            len(chunks),
            time.time() - start_time,
        )
        return results
