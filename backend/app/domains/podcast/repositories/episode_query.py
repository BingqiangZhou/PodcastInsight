"""Episode-query repository entrypoints."""

from app.domains.podcast.repositories.analytics import PodcastAnalyticsRepositoryMixin
from app.domains.podcast.repositories.base import BasePodcastRepository
from app.domains.podcast.repositories.content import PodcastContentRepositoryMixin
from app.domains.podcast.repositories.feed import PodcastFeedRepositoryMixin
from app.domains.podcast.repositories.playback_queue import (
    PodcastPlaybackQueueRepositoryMixin,
)


class PodcastEpisodeRepository(
    BasePodcastRepository,
    PodcastContentRepositoryMixin,
    PodcastFeedRepositoryMixin,
    PodcastPlaybackQueueRepositoryMixin,
    PodcastAnalyticsRepositoryMixin,
):
    """Repository used by episode query and feed flows."""
