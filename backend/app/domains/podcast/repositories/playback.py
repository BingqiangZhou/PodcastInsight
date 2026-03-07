"""Playback repository entrypoints."""

from app.domains.podcast.repositories.analytics import PodcastAnalyticsRepositoryMixin
from app.domains.podcast.repositories.base import BasePodcastRepository
from app.domains.podcast.repositories.content import PodcastContentRepositoryMixin
from app.domains.podcast.repositories.playback_queue import (
    PodcastPlaybackQueueRepositoryMixin,
)


class PodcastPlaybackRepository(
    BasePodcastRepository,
    PodcastContentRepositoryMixin,
    PodcastPlaybackQueueRepositoryMixin,
    PodcastAnalyticsRepositoryMixin,
):
    """Repository used by playback preference and history flows."""
