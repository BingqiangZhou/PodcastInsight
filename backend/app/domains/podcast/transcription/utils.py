"""Transcription utility functions."""

import asyncio
import logging
from datetime import datetime
from typing import Any

import ffmpeg

from .models import AudioChunk


logger = logging.getLogger(__name__)


def log_with_timestamp(level: str, message: str, task_id: int = None):
    """Emit a log line with timestamp and optional task context.

    Args:
        level: Log level (INFO, WARNING, ERROR, DEBUG).
        message: Log message.
        task_id: Optional task ID.

    """
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    task_info = f"[Task:{task_id}] " if task_id is not None else ""
    formatted_message = f"{timestamp} {task_info}{message}"

    if level == "INFO":
        logger.info(formatted_message)
    elif level == "WARNING":
        logger.warning(formatted_message)
    elif level == "ERROR":
        logger.error(formatted_message)
    elif level == "DEBUG":
        logger.debug(formatted_message)
    else:
        logger.info(formatted_message)


async def _ffmpeg_probe_async(input_path: str) -> dict[str, Any]:
    return await asyncio.to_thread(ffmpeg.probe, input_path)


async def _run_ffmpeg_sync(command_builder) -> None:
    await asyncio.to_thread(command_builder)


def build_chunk_info(chunks: list[AudioChunk]) -> dict[str, Any]:
    """Build lightweight persisted metadata for chunk execution state."""
    ordered_chunks = sorted(chunks, key=lambda item: item.index)
    return {
        "total_chunks": len(ordered_chunks),
        "chunks": [
            {
                "index": chunk.index,
                "start_time": chunk.start_time,
                "duration": chunk.duration,
                "status": "completed" if chunk.transcript else "failed",
            }
            for chunk in ordered_chunks
        ],
    }
