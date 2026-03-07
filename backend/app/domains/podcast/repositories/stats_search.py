"""Stats/search repository entrypoints."""

from app.domains.podcast.repositories.analytics import PodcastAnalyticsRepositoryMixin
from app.domains.podcast.repositories.base import BasePodcastRepository
from app.domains.podcast.repositories.playback_queue import (
    PodcastPlaybackQueueRepositoryMixin,
)


class PodcastSearchRepository(
    BasePodcastRepository,
    PodcastAnalyticsRepositoryMixin,
    PodcastPlaybackQueueRepositoryMixin,
):
    """Repository used by search and recommendations."""


class PodcastStatsRepository(
    BasePodcastRepository,
    PodcastAnalyticsRepositoryMixin,
):
    """Repository used by stats aggregation flows."""
