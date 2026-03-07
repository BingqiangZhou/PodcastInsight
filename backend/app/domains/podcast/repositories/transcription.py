"""Transcription/summary repository entrypoints."""

from app.domains.podcast.repositories.base import BasePodcastRepository
from app.domains.podcast.repositories.content import PodcastContentRepositoryMixin


class PodcastSummaryRepository(
    BasePodcastRepository,
    PodcastContentRepositoryMixin,
):
    """Repository used by summary and transcription orchestration."""
