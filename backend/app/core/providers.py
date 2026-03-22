"""Centralized dependency providers for request-scoped services.

DEPRECATED: This module is now a package. Import from app.core.providers instead.

This file maintains backward compatibility by re-exporting all providers
from the new modular structure in app.core.providers.*.

For new code, import directly from the submodules:
- app.core.providers.auth_providers
- app.core.providers.base_providers
- app.core.providers.podcast_providers
- app.core.providers.subscription_providers
- app.core.providers.admin_providers
- app.core.providers.ai_providers
"""

# Re-export everything from the new package structure
from app.core.providers import (
    get_admin_apikeys_service,
    get_admin_dashboard_context,
    get_admin_settings_service,
    get_admin_setup_auth_service,
    get_admin_subscriptions_service,
    get_admin_users_audit_service,
    get_ai_model_config_service,
    get_authentication_service,
    get_conversation_service,
    get_current_active_user,
    get_current_superuser,
    get_current_user,
    get_daily_report_service,
    get_db_session_dependency,
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
    get_redis_client,
    get_settings_dependency,
    get_subscription_repository,
    get_subscription_service,
    get_summary_workflow_service,
    get_token_user_id,
    get_transcription_workflow_service,
    get_user_repository,
    oauth2_scheme,
)

__all__ = [
    "get_admin_apikeys_service",
    "get_admin_dashboard_context",
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
    "get_redis_client",
    "get_settings_dependency",
    "get_subscription_repository",
    "get_subscription_service",
    "get_summary_workflow_service",
    "get_token_user_id",
    "get_transcription_workflow_service",
    "get_user_repository",
    "oauth2_scheme",
]
