"""Shared interfaces and types for domain boundaries.

This module provides protocol-based interfaces and type hints that allow
domains to interact without direct model imports, maintaining clean
domain boundaries.

Using protocols instead of concrete models allows:
1. Domain isolation - domains don't depend on each other's models
2. Flexibility - implementations can change without affecting other domains
3. Testability - easy to create mock implementations
"""

from __future__ import annotations

from datetime import datetime
from typing import Any, Protocol


class ISubscription(Protocol):
    """Protocol for subscription model interface.

    This allows podcast domain to work with subscriptions without
    importing from subscription domain.
    """

    id: int
    title: str
    description: str | None
    source_type: str
    source_url: str
    image_url: str | None
    config: dict[str, Any]
    status: str
    last_fetched_at: datetime | None
    latest_item_published_at: datetime | None
    error_message: str | None
    fetch_interval: int
    created_at: datetime
    updated_at: datetime


class IUserSubscription(Protocol):
    """Protocol for user-subscription mapping interface.

    This allows podcast domain to work with user subscriptions
    without importing from subscription domain.
    """

    id: int
    user_id: int
    subscription_id: int
    update_frequency: str | None
    update_time: str | None
    update_day_of_week: int | None
    is_archived: bool
    is_pinned: bool
    playback_rate_preference: float | None
    created_at: datetime
    updated_at: datetime

    @property
    def computed_next_update_at(self) -> datetime | None: ...

    def should_update_now(self) -> bool: ...


class ISubscriptionRepository(Protocol):
    """Protocol for subscription repository operations.

    Defines the minimum interface needed by other domains
    to interact with subscriptions.
    """

    async def get_by_id(self, subscription_id: int) -> ISubscription | None: ...

    async def get_user_subscription(
        self, user_id: int, subscription_id: int
    ) -> IUserSubscription | None: ...

    async def get_active_user_subscriptions(
        self, user_id: int
    ) -> list[IUserSubscription]: ...

    async def update_last_fetched(
        self, subscription_id: int, timestamp: datetime
    ) -> None: ...


# Type aliases for backward compatibility during migration
SubscriptionLike = ISubscription
UserSubscriptionLike = IUserSubscription


__all__ = [
    "ISubscription",
    "IUserSubscription",
    "ISubscriptionRepository",
    "SubscriptionLike",
    "UserSubscriptionLike",
]
