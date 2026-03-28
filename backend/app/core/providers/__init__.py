"""Centralized dependency providers for request-scoped services.

This package organizes providers by domain to improve maintainability
and reduce circular dependency risks.
"""

from typing import Annotated

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.providers.admin_providers import (
    get_admin_apikeys_service,
    get_admin_dashboard_context,
    get_admin_settings_service,
    get_admin_setup_auth_service,
    get_admin_subscriptions_service,
    get_admin_users_audit_service,
)
from app.core.providers.ai_providers import get_ai_model_config_service
from app.core.providers.auth_providers import (
    get_authentication_service,
    get_current_active_user,
    get_current_superuser,
    get_current_user,
    get_token_user_id,
    get_user_repository,
    oauth2_scheme,
)
from app.core.providers.base_providers import (
    get_db_session_dependency,
    get_redis_client,
    get_settings_dependency,
)
from app.core.providers.podcast_providers import (
    get_conversation_service,
    get_daily_report_service,
    get_highlight_service,
    get_podcast_episode_repository,
    get_podcast_episode_service,
    get_podcast_parser,
    get_podcast_playback_repository,
    get_podcast_playback_service,
    get_podcast_queue_repository,
    get_podcast_queue_service,
    get_podcast_schedule_service,
    get_podcast_search_repository,
    get_podcast_search_service,
    get_podcast_stats_repository,
    get_podcast_stats_service,
    get_podcast_subscription_repository,
    get_podcast_subscription_service,
    get_podcast_summary_repository,
    get_podcast_task_orchestration_service,
    get_summary_workflow_service,
    get_transcription_workflow_service,
)
from app.core.providers.subscription_providers import (
    get_subscription_repository,
    get_subscription_service,
)
from app.domains.user.models import User as _User


# ── Annotated type aliases for concise injection ────────────────────────────
# Usage: def my_route(db: CurrentDb, user: CurrentActiveUser):
#   instead of: def my_route(db: AsyncSession = Depends(get_db_session_dependency), user: User = Depends(get_current_active_user)):

CurrentDb = Annotated[AsyncSession, Depends(get_db_session_dependency)]
CurrentUser = Annotated[_User, Depends(get_current_user)]
CurrentActiveUser = Annotated[_User, Depends(get_current_active_user)]

__all__ = [
    # Annotated aliases
    "CurrentDb",
    "CurrentUser",
    "CurrentActiveUser",
    # Base providers
    "get_db_session_dependency",
    "get_redis_client",
    "get_settings_dependency",
    # Auth providers
    "get_authentication_service",
    "get_current_active_user",
    "get_current_superuser",
    "get_current_user",
    "get_token_user_id",
    "get_user_repository",
    "oauth2_scheme",
    # Admin providers
    "get_admin_apikeys_service",
    "get_admin_dashboard_context",
    "get_admin_settings_service",
    "get_admin_setup_auth_service",
    "get_admin_subscriptions_service",
    "get_admin_users_audit_service",
    # AI providers
    "get_ai_model_config_service",
    # Subscription providers
    "get_subscription_repository",
    "get_subscription_service",
    # Podcast providers
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
    "get_transcription_workflow_service",
]
