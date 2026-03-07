"""Centralized dependency providers for request-scoped services."""

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.database import get_db_session
from app.core.dependencies import get_current_active_user
from app.core.security import get_token_from_request
from app.domains.ai.services import AIModelConfigService
from app.domains.podcast.conversation_service import ConversationService
from app.domains.podcast.services.daily_report_service import DailyReportService
from app.domains.podcast.services.episode_service import PodcastEpisodeService
from app.domains.podcast.services.playback_service import PodcastPlaybackService
from app.domains.podcast.services.queue_service import PodcastQueueService
from app.domains.podcast.services.schedule_service import PodcastScheduleService
from app.domains.podcast.services.search_service import PodcastSearchService
from app.domains.podcast.services.stats_service import PodcastStatsService
from app.domains.podcast.services.subscription_service import PodcastSubscriptionService
from app.domains.podcast.services.summary_workflow_service import SummaryWorkflowService
from app.domains.podcast.services.transcription_workflow_service import (
    TranscriptionWorkflowService,
)
from app.domains.podcast.summary_manager import DatabaseBackedAISummaryService
from app.domains.podcast.transcription_manager import DatabaseBackedTranscriptionService
from app.domains.podcast.transcription_scheduler import TranscriptionScheduler
from app.domains.subscription.services import SubscriptionService
from app.domains.user.models import User
from app.domains.user.services import AuthenticationService


def get_settings_dependency() -> Settings:
    """Provide cached application settings."""
    return get_settings()


async def get_token_user_id(user=Depends(get_token_from_request)) -> int:
    """Get current authenticated user id from token payload."""
    return int(user["sub"])


def get_authentication_service(
    db: AsyncSession = Depends(get_db_session),
) -> AuthenticationService:
    """Provide request-scoped authentication service."""
    return AuthenticationService(db)


def get_ai_model_config_service(
    db: AsyncSession = Depends(get_db_session),
) -> AIModelConfigService:
    """Provide request-scoped AI model config service."""
    return AIModelConfigService(db)


def get_subscription_service(
    db: AsyncSession = Depends(get_db_session),
    current_user: User = Depends(get_current_active_user),
) -> SubscriptionService:
    """Provide request-scoped generic subscription service."""
    return SubscriptionService(db, current_user.id)


def get_podcast_subscription_service(
    db: AsyncSession = Depends(get_db_session),
    user_id: int = Depends(get_token_user_id),
) -> PodcastSubscriptionService:
    """Provide request-scoped podcast subscription service."""
    return PodcastSubscriptionService(db, user_id)


def get_podcast_episode_service(
    db: AsyncSession = Depends(get_db_session),
    user_id: int = Depends(get_token_user_id),
) -> PodcastEpisodeService:
    """Provide request-scoped podcast episode service."""
    return PodcastEpisodeService(db, user_id)


def get_podcast_playback_service(
    db: AsyncSession = Depends(get_db_session),
    user_id: int = Depends(get_token_user_id),
) -> PodcastPlaybackService:
    """Provide request-scoped podcast playback service."""
    return PodcastPlaybackService(db, user_id)


def get_podcast_queue_service(
    db: AsyncSession = Depends(get_db_session),
    user_id: int = Depends(get_token_user_id),
) -> PodcastQueueService:
    """Provide request-scoped podcast queue service."""
    return PodcastQueueService(db, user_id)


def get_podcast_schedule_service(
    db: AsyncSession = Depends(get_db_session),
    user_id: int = Depends(get_token_user_id),
) -> PodcastScheduleService:
    """Provide request-scoped podcast schedule service."""
    return PodcastScheduleService(db, user_id)


def get_podcast_search_service(
    db: AsyncSession = Depends(get_db_session),
    user_id: int = Depends(get_token_user_id),
) -> PodcastSearchService:
    """Provide request-scoped podcast search service."""
    return PodcastSearchService(db, user_id)


def get_podcast_stats_service(
    db: AsyncSession = Depends(get_db_session),
    user_id: int = Depends(get_token_user_id),
) -> PodcastStatsService:
    """Provide request-scoped podcast stats service."""
    return PodcastStatsService(db, user_id)


def get_daily_report_service(
    db: AsyncSession = Depends(get_db_session),
    user_id: int = Depends(get_token_user_id),
) -> DailyReportService:
    """Provide request-scoped podcast daily report service."""
    return DailyReportService(db, user_id)


def get_transcription_service(
    db: AsyncSession = Depends(get_db_session),
) -> DatabaseBackedTranscriptionService:
    """Provide request-scoped transcription service."""
    return DatabaseBackedTranscriptionService(db)


def get_summary_service(
    db: AsyncSession = Depends(get_db_session),
) -> DatabaseBackedAISummaryService:
    """Provide request-scoped summary service."""
    return DatabaseBackedAISummaryService(db)


def get_summary_workflow_service(
    db: AsyncSession = Depends(get_db_session),
) -> SummaryWorkflowService:
    """Provide request-scoped summary orchestration service."""
    return SummaryWorkflowService(db)


def get_transcription_scheduler(
    db: AsyncSession = Depends(get_db_session),
) -> TranscriptionScheduler:
    """Provide request-scoped transcription scheduler."""
    return TranscriptionScheduler(db)


def get_transcription_workflow_service(
    db: AsyncSession = Depends(get_db_session),
) -> TranscriptionWorkflowService:
    """Provide request-scoped transcription orchestration service."""
    return TranscriptionWorkflowService(db)


def get_conversation_service(
    db: AsyncSession = Depends(get_db_session),
) -> ConversationService:
    """Provide request-scoped conversation service."""
    return ConversationService(db)
