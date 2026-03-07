"""Subscription/feed repository entrypoints."""

from app.domains.podcast.repositories.base import BasePodcastRepository
from app.domains.podcast.repositories.content import PodcastContentRepositoryMixin
from app.domains.podcast.repositories.feed import PodcastFeedRepositoryMixin
from app.domains.podcast.repositories.playback_queue import (
    PodcastPlaybackQueueRepositoryMixin,
)


class PodcastSubscriptionRepository(
    BasePodcastRepository,
    PodcastContentRepositoryMixin,
    PodcastFeedRepositoryMixin,
    PodcastPlaybackQueueRepositoryMixin,
):
    """Repository used by subscription management and feed sync flows."""
