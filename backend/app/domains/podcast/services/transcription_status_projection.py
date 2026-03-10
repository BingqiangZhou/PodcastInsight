"""Projection helpers for transcription task status payloads."""

from __future__ import annotations

from datetime import UTC, datetime
from typing import Any


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


def build_transcription_status_payload(task, *, status_key: str) -> dict[str, Any]:
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
