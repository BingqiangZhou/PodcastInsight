"""Backward-compatible transcription manager aliases."""

from app.domains.podcast.services.transcription_runtime_service import (
    DatabaseBackedTranscriptionService,
    PodcastTranscriptionRuntimeService,
)


__all__ = [
    "DatabaseBackedTranscriptionService",
    "PodcastTranscriptionRuntimeService",
]
