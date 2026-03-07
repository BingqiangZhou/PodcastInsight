"""Centralized dependency providers for request-scoped services."""

from __future__ import annotations

import logging

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.database import get_db_session
from app.core.redis import PodcastRedis
from app.core.security import get_token_from_request, verify_token
from app.domains.ai.services import AIModelConfigService
from app.domains.podcast.conversation_service import ConversationService
from app.domains.podcast.integration.secure_rss_parser import SecureRSSParser
from app.domains.podcast.repositories import (
    PodcastEpisodeRepository,
    PodcastPlaybackRepository,
    PodcastQueueRepository,
    PodcastSearchRepository,
    PodcastStatsRepository,
    PodcastSubscriptionRepository,
    PodcastSummaryRepository,
)
from app.domains.podcast.services.daily_report_service import DailyReportService
from app.domains.podcast.services.episode_service import PodcastEpisodeService
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
from app.domains.subscription.repositories import SubscriptionRepository
from app.domains.subscription.services import SubscriptionService
from app.domains.user.models import User
from app.domains.user.repositories import UserRepository
from app.domains.user.services import AuthenticationService


logger = logging.getLogger(__name__)

oauth2_scheme = OAuth2PasswordBearer(tokenUrl=f"{get_settings().API_V1_STR}/auth/login")


def get_settings_dependency() -> Settings:
    """Provide cached application settings."""
    return get_settings()


async def get_db_session_dependency(
    db: AsyncSession = Depends(get_db_session),
) -> AsyncSession:
    """Provide the request-scoped DB session through the provider layer."""
    return db


def get_redis_client() -> PodcastRedis:
    """Provide a request-scoped Redis helper."""
    return PodcastRedis()


def get_user_repository(
    db: AsyncSession = Depends(get_db_session_dependency),
) -> UserRepository:
    """Provide a user repository for auth-oriented dependencies."""
    return UserRepository(db)


async def get_current_user(
    token: str = Depends(oauth2_scheme),
    user_repo: UserRepository = Depends(get_user_repository),
) -> User:
    """Resolve the current authenticated user."""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )

    try:
        payload = verify_token(token)
        user_id_str: str | None = payload.get("sub")
        if user_id_str is None:
            raise credentials_exception
        user_id = int(user_id_str)
    except HTTPException:
        raise
    except (JWTError, ValueError) as exc:
        logger.error("Exception in token verification: %s", exc)
        raise credentials_exception from exc

    user = await user_repo.get_by_id(user_id)
    if user is None:
        raise credentials_exception

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Inactive user",
        )

    return user


async def get_current_active_user(
    current_user: User = Depends(get_current_user),
) -> User:
    """Resolve the current active user."""
    if not current_user.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Inactive user",
        )
    return current_user


async def get_current_superuser(
    current_user: User = Depends(get_current_user),
) -> User:
    """Resolve the current superuser."""
    if not current_user.is_superuser:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not enough permissions",
        )
    return current_user


async def get_token_user_id(user=Depends(get_token_from_request)) -> int:
    """Get current authenticated user id from token payload."""
    return int(user["sub"])


def get_authentication_service(
    db: AsyncSession = Depends(get_db_session_dependency),
) -> AuthenticationService:
    """Provide request-scoped authentication service."""
    return AuthenticationService(db)


def get_ai_model_config_service(
    db: AsyncSession = Depends(get_db_session_dependency),
) -> AIModelConfigService:
    """Provide request-scoped AI model config service."""
    return AIModelConfigService(db)


def get_subscription_service(
    db: AsyncSession = Depends(get_db_session_dependency),
    current_user: User = Depends(get_current_active_user),
) -> SubscriptionService:
    """Provide request-scoped generic subscription service."""
    return SubscriptionService(db, current_user.id)


def get_subscription_repository(
    db: AsyncSession = Depends(get_db_session_dependency),
) -> SubscriptionRepository:
    """Provide the generic subscription repository."""
    return SubscriptionRepository(db)


def get_podcast_subscription_repository(
    db: AsyncSession = Depends(get_db_session_dependency),
) -> PodcastSubscriptionRepository:
    """Provide the podcast subscription/feed repository."""
    return PodcastSubscriptionRepository(db)


def get_podcast_episode_repository(
    db: AsyncSession = Depends(get_db_session_dependency),
) -> PodcastEpisodeRepository:
    """Provide the podcast episode-query repository."""
    return PodcastEpisodeRepository(db)


def get_podcast_playback_repository(
    db: AsyncSession = Depends(get_db_session_dependency),
) -> PodcastPlaybackRepository:
    """Provide the podcast playback repository."""
    return PodcastPlaybackRepository(db)


def get_podcast_queue_repository(
    db: AsyncSession = Depends(get_db_session_dependency),
) -> PodcastQueueRepository:
    """Provide the podcast queue repository."""
    return PodcastQueueRepository(db)


def get_podcast_search_repository(
    db: AsyncSession = Depends(get_db_session_dependency),
) -> PodcastSearchRepository:
    """Provide the podcast search repository."""
    return PodcastSearchRepository(db)


def get_podcast_stats_repository(
    db: AsyncSession = Depends(get_db_session_dependency),
) -> PodcastStatsRepository:
    """Provide the podcast stats repository."""
    return PodcastStatsRepository(db)


def get_podcast_summary_repository(
    db: AsyncSession = Depends(get_db_session_dependency),
) -> PodcastSummaryRepository:
    """Provide the podcast summary/transcription repository."""
    return PodcastSummaryRepository(db)


def get_podcast_parser(
    user_id: int = Depends(get_token_user_id),
) -> SecureRSSParser:
    """Provide the podcast RSS parser for the current user."""
    return SecureRSSParser(user_id)


def get_podcast_subscription_service(
    db: AsyncSession = Depends(get_db_session_dependency),
    user_id: int = Depends(get_token_user_id),
    repo: PodcastSubscriptionRepository = Depends(get_podcast_subscription_repository),
    subscription_repo: SubscriptionRepository = Depends(get_subscription_repository),
    redis: PodcastRedis = Depends(get_redis_client),
    parser: SecureRSSParser = Depends(get_podcast_parser),
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
    repo: PodcastEpisodeRepository = Depends(get_podcast_episode_repository),
    redis: PodcastRedis = Depends(get_redis_client),
) -> PodcastEpisodeService:
    """Provide request-scoped podcast episode service."""
    return PodcastEpisodeService(db, user_id, repo=repo, redis=redis)


def get_podcast_playback_service(
    db: AsyncSession = Depends(get_db_session_dependency),
    user_id: int = Depends(get_token_user_id),
    repo: PodcastPlaybackRepository = Depends(get_podcast_playback_repository),
    redis: PodcastRedis = Depends(get_redis_client),
) -> PodcastPlaybackService:
    """Provide request-scoped podcast playback service."""
    return PodcastPlaybackService(db, user_id, repo=repo, redis=redis)


def get_podcast_queue_service(
    db: AsyncSession = Depends(get_db_session_dependency),
    user_id: int = Depends(get_token_user_id),
    repo: PodcastQueueRepository = Depends(get_podcast_queue_repository),
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
    repo: PodcastSearchRepository = Depends(get_podcast_search_repository),
    redis: PodcastRedis = Depends(get_redis_client),
) -> PodcastSearchService:
    """Provide request-scoped podcast search service."""
    return PodcastSearchService(db, user_id, repo=repo, redis=redis)


def get_podcast_stats_service(
    db: AsyncSession = Depends(get_db_session_dependency),
    user_id: int = Depends(get_token_user_id),
    repo: PodcastStatsRepository = Depends(get_podcast_stats_repository),
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


def get_admin_dashboard_service(
    db: AsyncSession = Depends(get_db_session_dependency),
) -> object:
    """Provide request-scoped admin dashboard service."""
    from app.admin.services import AdminDashboardService

    return AdminDashboardService(db)


def get_admin_apikeys_service(
    db: AsyncSession = Depends(get_db_session_dependency),
) -> object:
    """Provide request-scoped admin API-keys service."""
    from app.admin.services import AdminApiKeysService

    return AdminApiKeysService(db)


def get_admin_subscriptions_service(
    db: AsyncSession = Depends(get_db_session_dependency),
) -> object:
    """Provide request-scoped admin subscriptions service."""
    from app.admin.services import AdminSubscriptionsService

    return AdminSubscriptionsService(db)


def get_admin_settings_service(
    db: AsyncSession = Depends(get_db_session_dependency),
) -> object:
    """Provide request-scoped admin settings service."""
    from app.admin.services import AdminSettingsService

    return AdminSettingsService(db)


def get_admin_setup_auth_service(
    db: AsyncSession = Depends(get_db_session_dependency),
) -> object:
    """Provide request-scoped admin setup/auth service."""
    from app.admin.services import AdminSetupAuthService

    return AdminSetupAuthService(db)


def get_admin_users_audit_service(
    db: AsyncSession = Depends(get_db_session_dependency),
) -> object:
    """Provide request-scoped admin users/audit service."""
    from app.admin.services import AdminUsersAuditService

    return AdminUsersAuditService(db)


__all__ = [
    "get_admin_apikeys_service",
    "get_admin_dashboard_service",
    "get_admin_settings_service",
    "get_admin_setup_auth_service",
    "get_admin_subscriptions_service",
    "get_admin_users_audit_service",
    "get_ai_model_config_service",
    "get_authentication_service",
    "get_conversation_service",
    "get_current_active_user",
    "get_current_superuser",
    "get_current_user",
    "get_daily_report_service",
    "get_db_session_dependency",
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
    "get_redis_client",
    "get_settings_dependency",
    "get_subscription_service",
    "get_summary_workflow_service",
    "get_subscription_repository",
    "get_token_user_id",
    "get_transcription_workflow_service",
    "get_user_repository",
]
