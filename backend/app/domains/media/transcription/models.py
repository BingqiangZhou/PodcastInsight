"""Transcription data models."""

from dataclasses import dataclass


@dataclass
class AudioChunk:
    """Metadata for one audio chunk."""

    index: int
    file_path: str
    start_time: float  # seconds
    duration: float  # seconds
    file_size: int  # bytes
    transcript: str | None = None  # transcription result for this chunk
