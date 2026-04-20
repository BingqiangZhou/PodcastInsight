"""Admin-related FastAPI dependency providers.

Uses lazy imports to avoid circular dependencies with admin services.
"""

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import get_db_session_dependency


def get_admin_dashboard_context(
    db: AsyncSession = Depends(get_db_session_dependency),
) -> dict:
    """Provide admin dashboard context directly."""
    from app.admin.services.dashboard_service import get_dashboard_context

    return get_dashboard_context(db)


def get_admin_apikeys_service(
    db: AsyncSession = Depends(get_db_session_dependency),
):
    """Provide request-scoped admin API-keys service."""
    from app.admin.services.apikeys_service import AdminApiKeysService

    return AdminApiKeysService(db)


def get_admin_subscriptions_service(
    db: AsyncSession = Depends(get_db_session_dependency),
):
    """Provide request-scoped admin subscriptions service."""
    from app.admin.services.subscriptions_service import AdminSubscriptionsService

    return AdminSubscriptionsService(db)


def get_admin_settings_service(
    db: AsyncSession = Depends(get_db_session_dependency),
):
    """Provide request-scoped admin settings service."""
    from app.admin.services.settings_service import AdminSettingsService

    return AdminSettingsService(db)


def get_admin_setup_auth_service(
    db: AsyncSession = Depends(get_db_session_dependency),
):
    """Provide request-scoped admin setup/auth service."""
    from app.admin.services.setup_auth_service import AdminSetupAuthService

    return AdminSetupAuthService(db)


__all__ = [
    "get_admin_apikeys_service",
    "get_admin_dashboard_context",
    "get_admin_settings_service",
    "get_admin_setup_auth_service",
    "get_admin_subscriptions_service",
]
