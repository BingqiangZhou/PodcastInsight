"""Subscription-related FastAPI dependency providers."""

from __future__ import annotations

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import get_current_active_user, get_db_session_dependency
from app.domains.subscription.repositories import SubscriptionRepository
from app.domains.subscription.services import SubscriptionService


def get_subscription_repository(
    db: AsyncSession = Depends(get_db_session_dependency),
) -> SubscriptionRepository:
    """Provide the generic subscription repository."""
    return SubscriptionRepository(db)


def get_subscription_service(
    db: AsyncSession = Depends(get_db_session_dependency),
    current_user=Depends(get_current_active_user),
) -> SubscriptionService:
    """Provide request-scoped generic subscription service."""
    return SubscriptionService(db, current_user.id)


__all__ = [
    "get_subscription_repository",
    "get_subscription_service",
]
