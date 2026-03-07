"""Queue repository entrypoints."""

from app.domains.podcast.repositories.base import BasePodcastRepository
from app.domains.podcast.repositories.content import PodcastContentRepositoryMixin
from app.domains.podcast.repositories.playback_queue import (
    PodcastPlaybackQueueRepositoryMixin,
)


class PodcastQueueRepository(
    BasePodcastRepository,
    PodcastContentRepositoryMixin,
    PodcastPlaybackQueueRepositoryMixin,
):
    """Repository used by queue mutation flows."""
