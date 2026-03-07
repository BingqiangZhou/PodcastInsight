"""Daily report repository entrypoints."""

from app.domains.podcast.repositories.base import BasePodcastRepository
from app.domains.podcast.repositories.content import PodcastContentRepositoryMixin


class PodcastDailyReportRepository(
    BasePodcastRepository,
    PodcastContentRepositoryMixin,
):
    """Repository used by daily report orchestration."""
