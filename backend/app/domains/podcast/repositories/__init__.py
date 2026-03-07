"""Specialized podcast repository exports."""

from app.domains.podcast.repositories.base import BasePodcastRepository
from app.domains.podcast.repositories.daily_report import PodcastDailyReportRepository
from app.domains.podcast.repositories.episode_query import PodcastEpisodeRepository
from app.domains.podcast.repositories.playback import PodcastPlaybackRepository
from app.domains.podcast.repositories.queue import PodcastQueueRepository
from app.domains.podcast.repositories.stats_search import (
    PodcastSearchRepository,
    PodcastStatsRepository,
)
from app.domains.podcast.repositories.subscription_feed import (
    PodcastSubscriptionRepository,
)
from app.domains.podcast.repositories.transcription import PodcastSummaryRepository


class PodcastRepository(PodcastEpisodeRepository):
    """Backward-compatible aggregate repository for legacy paths and tests."""


__all__ = [
    "BasePodcastRepository",
    "PodcastDailyReportRepository",
    "PodcastEpisodeRepository",
    "PodcastRepository",
    "PodcastPlaybackRepository",
    "PodcastQueueRepository",
    "PodcastSearchRepository",
    "PodcastStatsRepository",
    "PodcastSubscriptionRepository",
    "PodcastSummaryRepository",
]
