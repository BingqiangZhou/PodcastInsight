"""Podcast-related FastAPI dependency providers.

This module provides all podcast domain services and repositories
using lazy imports to avoid circular dependencies.
"""

from __future__ import annotations

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import get_db_session_dependency, get_redis_client, get_token_user_id
from app.core.redis import PodcastRedis
from app.domains.podcast.conversation_service import ConversationService
from app.domains.podcast.services.daily_report_service import DailyReportService
from app.domains.podcast.services.episode_service import PodcastEpisodeService
from app.domains.podcast.services.highlight_service import HighlightService
from app.domains.podcast.services.playback_service import PodcastPlaybackService
from app.domains.podcast.services.queue_service import PodcastQueueService
from app.domains.podcast.services.schedule_service import PodcastScheduleService
from app.domains.podcast.services.search_service import PodcastSearchService
from app.domains.podcast.services.stats_service import PodcastStatsService
from app.domains.podcast.services.subscription_service import PodcastSubscriptionService
from app.domains.podcast.services.summary_workflow_service import SummaryWorkflowService
from app.domains.podcast.services.task_orchestration_service import (
    PodcastTaskOrchestrationService,
)
from app.domains.podcast.services.transcription_workflow_service import (
    TranscriptionWorkflowService,
)
from app.domains.subscription.api.dependencies import get_subscription_repository


# Cached repository classes (populated on first call)
_cached_repos: dict | None = None


def _get_repositories():
    """Lazy import repositories to avoid circular dependencies.

    Results are cached after the first call to avoid repeated imports.
    """
    global _cached_repos
    if _cached_repos is not None:
        return _cached_repos
    from app.domains.podcast.repositories import (
        PodcastEpisodeRepository,
        PodcastPlaybackRepository,
        PodcastQueueRepository,
        PodcastSearchRepository,
        PodcastStatsRepository,
        PodcastSubscriptionRepository,
        PodcastSummaryRepository,
    )

    _cached_repos = {
        "episode": PodcastEpisodeRepository,
        "playback": PodcastPlaybackRepository,
        "queue": PodcastQueueRepository,
        "search": PodcastSearchRepository,
        "stats": PodcastStatsRepository,
        "subscription": PodcastSubscriptionRepository,
        "summary": PodcastSummaryRepository,
    }
    return _cached_repos


def get_podcast_subscription_repository(
    db: AsyncSession = Depends(get_db_session_dependency),
):
    """Provide the podcast subscription/feed repository."""
    repos = _get_repositories()
    return repos["subscription"](db)


def get_podcast_episode_repository(
    db: AsyncSession = Depends(get_db_session_dependency),
):
    """Provide the podcast episode-query repository."""
    repos = _get_repositories()
    return repos["episode"](db)


def get_podcast_playback_repository(
    db: AsyncSession = Depends(get_db_session_dependency),
):
    """Provide the podcast playback repository."""
    repos = _get_repositories()
    return repos["playback"](db)


def get_podcast_queue_repository(
    db: AsyncSession = Depends(get_db_session_dependency),
):
    """Provide the podcast queue repository."""
    repos = _get_repositories()
    return repos["queue"](db)


def get_podcast_search_repository(
    db: AsyncSession = Depends(get_db_session_dependency),
):
    """Provide the podcast search repository."""
    repos = _get_repositories()
    return repos["search"](db)


def get_podcast_stats_repository(
    db: AsyncSession = Depends(get_db_session_dependency),
):
    """Provide the podcast stats repository."""
    repos = _get_repositories()
    return repos["stats"](db)


def get_podcast_summary_repository(
    db: AsyncSession = Depends(get_db_session_dependency),
):
    """Provide the podcast summary/transcription repository."""
    repos = _get_repositories()
    return repos["summary"](db)


def get_podcast_parser(
    user_id: int = Depends(get_token_user_id),
):
    """Provide the podcast RSS parser for the current user."""
    from app.domains.podcast.integration.secure_rss_parser import SecureRSSParser

    return SecureRSSParser(user_id)


def get_podcast_subscription_service(
    db: AsyncSession = Depends(get_db_session_dependency),
    user_id: int = Depends(get_token_user_id),
    repo=Depends(get_podcast_subscription_repository),
    subscription_repo=Depends(get_subscription_repository),
    redis: PodcastRedis = Depends(get_redis_client),
    parser=Depends(get_podcast_parser),
) -> PodcastSubscriptionService:
    """Provide request-scoped podcast subscription service."""
    return PodcastSubscriptionService(
        db,
        user_id,
        repo=repo,
        subscription_repo=subscription_repo,
        redis=redis,
        parser=parser,
    )


def get_podcast_episode_service(
    db: AsyncSession = Depends(get_db_session_dependency),
    user_id: int = Depends(get_token_user_id),
    repo=Depends(get_podcast_episode_repository),
    redis: PodcastRedis = Depends(get_redis_client),
) -> PodcastEpisodeService:
    """Provide request-scoped podcast episode service."""
    return PodcastEpisodeService(db, user_id, repo=repo, redis=redis)


def get_podcast_playback_service(
    db: AsyncSession = Depends(get_db_session_dependency),
    user_id: int = Depends(get_token_user_id),
    repo=Depends(get_podcast_playback_repository),
    redis: PodcastRedis = Depends(get_redis_client),
) -> PodcastPlaybackService:
    """Provide request-scoped podcast playback service."""
    return PodcastPlaybackService(db, user_id, repo=repo, redis=redis)


def get_podcast_queue_service(
    db: AsyncSession = Depends(get_db_session_dependency),
    user_id: int = Depends(get_token_user_id),
    repo=Depends(get_podcast_queue_repository),
) -> PodcastQueueService:
    """Provide request-scoped podcast queue service."""
    return PodcastQueueService(db, user_id, repo=repo)


def get_podcast_schedule_service(
    db: AsyncSession = Depends(get_db_session_dependency),
    user_id: int = Depends(get_token_user_id),
) -> PodcastScheduleService:
    """Provide request-scoped podcast schedule service."""
    return PodcastScheduleService(db, user_id)


def get_podcast_search_service(
    db: AsyncSession = Depends(get_db_session_dependency),
    user_id: int = Depends(get_token_user_id),
    repo=Depends(get_podcast_search_repository),
    redis: PodcastRedis = Depends(get_redis_client),
) -> PodcastSearchService:
    """Provide request-scoped podcast search service."""
    return PodcastSearchService(db, user_id, repo=repo, redis=redis)


def get_podcast_stats_service(
    db: AsyncSession = Depends(get_db_session_dependency),
    user_id: int = Depends(get_token_user_id),
    repo=Depends(get_podcast_stats_repository),
    redis: PodcastRedis = Depends(get_redis_client),
    playback_service: PodcastPlaybackService = Depends(get_podcast_playback_service),
) -> PodcastStatsService:
    """Provide request-scoped podcast stats service."""
    return PodcastStatsService(
        db,
        user_id,
        repo=repo,
        redis=redis,
        playback_service=playback_service,
    )


def get_daily_report_service(
    db: AsyncSession = Depends(get_db_session_dependency),
    user_id: int = Depends(get_token_user_id),
) -> DailyReportService:
    """Provide request-scoped podcast daily report service."""
    return DailyReportService(db, user_id)


def get_highlight_service(
    db: AsyncSession = Depends(get_db_session_dependency),
    user_id: int = Depends(get_token_user_id),
) -> HighlightService:
    """Provide request-scoped podcast highlight service."""
    return HighlightService(db, user_id)


def get_summary_workflow_service(
    db: AsyncSession = Depends(get_db_session_dependency),
) -> SummaryWorkflowService:
    """Provide request-scoped summary orchestration service."""
    return SummaryWorkflowService(db)


def get_transcription_workflow_service(
    db: AsyncSession = Depends(get_db_session_dependency),
) -> TranscriptionWorkflowService:
    """Provide request-scoped transcription orchestration service."""
    return TranscriptionWorkflowService(db)


def get_podcast_task_orchestration_service(
    db: AsyncSession = Depends(get_db_session_dependency),
) -> PodcastTaskOrchestrationService:
    """Provide request-scoped background-task orchestration service."""
    return PodcastTaskOrchestrationService(db)


def get_conversation_service(
    db: AsyncSession = Depends(get_db_session_dependency),
) -> ConversationService:
    """Provide request-scoped conversation service."""
    return ConversationService(db)


__all__ = [
    "get_conversation_service",
    "get_daily_report_service",
    "get_highlight_service",
    "get_podcast_episode_repository",
    "get_podcast_episode_service",
    "get_podcast_parser",
    "get_podcast_playback_repository",
    "get_podcast_playback_service",
    "get_podcast_queue_repository",
    "get_podcast_queue_service",
    "get_podcast_schedule_service",
    "get_podcast_search_repository",
    "get_podcast_search_service",
    "get_podcast_stats_repository",
    "get_podcast_stats_service",
    "get_podcast_subscription_repository",
    "get_podcast_subscription_service",
    "get_podcast_summary_repository",
    "get_podcast_task_orchestration_service",
    "get_summary_workflow_service",
    "get_token_user_id",
    "get_transcription_workflow_service",
]
