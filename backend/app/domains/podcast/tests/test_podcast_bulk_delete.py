"""Focused tests for podcast bulk-delete behavior."""

from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.domains.podcast.models import Subscription
from app.domains.podcast.repositories.subscription_repository import (
    SubscriptionRepository,
)
from app.domains.podcast.services.episode_service import PodcastSubscriptionService


@pytest.fixture
def mock_db() -> AsyncMock:
    """Mock async DB session."""
    return AsyncMock(spec=AsyncSession)


@pytest.fixture
def service(mock_db: AsyncMock) -> PodcastSubscriptionService:
    """Create service with mocked cache operations."""
    svc = PodcastSubscriptionService(mock_db, user_id=1)
    svc.redis.invalidate_episode_list = AsyncMock(return_value=None)
    svc.redis.invalidate_subscription_list = AsyncMock(return_value=None)
    return svc


def _subscription(subscription_id: int = 1) -> Subscription:
    """Create lightweight subscription test object."""
    return SimpleNamespace(
        id=subscription_id,
        user_id=1,
        source_type="podcast-rss",
        title=f"sub-{subscription_id}",
    )


@pytest.mark.asyncio
async def test_remove_subscriptions_bulk_all_success(
    service: PodcastSubscriptionService,
):
    service.remove_subscription = AsyncMock(return_value=True)

    result = await service.remove_subscriptions_bulk([1, 2, 3])

    assert result["success_count"] == 3
    assert result["failed_count"] == 0
    assert result["errors"] == []
    assert result["deleted_subscription_ids"] == [1, 2, 3]


@pytest.mark.asyncio
async def test_remove_subscriptions_bulk_partial_not_found(
    service: PodcastSubscriptionService,
):
    service.remove_subscription = AsyncMock(side_effect=[True, False, True])

    result = await service.remove_subscriptions_bulk([1, 2, 3])

    assert result["success_count"] == 2
    assert result["failed_count"] == 1
    assert result["deleted_subscription_ids"] == [1, 3]
    assert result["errors"][0]["subscription_id"] == 2


@pytest.mark.asyncio
async def test_remove_subscriptions_bulk_continues_on_exception(
    service: PodcastSubscriptionService,
):
    service.remove_subscription = AsyncMock(
        side_effect=[True, RuntimeError("db down"), True],
    )

    result = await service.remove_subscriptions_bulk([1, 2, 3])

    assert result["success_count"] == 2
    assert result["failed_count"] == 1
    assert result["deleted_subscription_ids"] == [1, 3]
    assert "db down" in result["errors"][0]["error"]


@pytest.mark.asyncio
async def test_remove_subscription_returns_false_when_not_found(
    service: PodcastSubscriptionService,
):
    service._validate_and_get_subscription = AsyncMock(return_value=None)

    removed = await service.remove_subscription(1)

    assert removed is False


@pytest.mark.asyncio
async def test_remove_subscription_returns_false_when_delete_fails(
    service: PodcastSubscriptionService,
):
    service._validate_and_get_subscription = AsyncMock(return_value=_subscription(1))
    delete_mock = AsyncMock(return_value=False)

    with pytest.MonkeyPatch.context() as mp:
        mp.setattr(SubscriptionRepository, "delete_subscription", delete_mock)
        removed = await service.remove_subscription(1)

    assert removed is False


@pytest.mark.asyncio
async def test_remove_subscription_succeeds_and_invalidates_cache(
    service: PodcastSubscriptionService,
):
    service._validate_and_get_subscription = AsyncMock(return_value=_subscription(1))
    delete_mock = AsyncMock(return_value=True)

    with pytest.MonkeyPatch.context() as mp:
        mp.setattr(SubscriptionRepository, "delete_subscription", delete_mock)
        removed = await service.remove_subscription(1)

    assert removed is True
    service.redis.invalidate_episode_list.assert_awaited_once_with(1)
    service.redis.invalidate_subscription_list.assert_awaited_once_with(1)


@pytest.mark.asyncio
async def test_remove_subscription_succeeds_when_redis_unavailable(
    service: PodcastSubscriptionService,
):
    service._validate_and_get_subscription = AsyncMock(return_value=_subscription(1))
    service.redis.invalidate_episode_list = AsyncMock(
        side_effect=RuntimeError("redis unavailable"),
    )
    service.redis.invalidate_subscription_list = AsyncMock(
        side_effect=RuntimeError("redis unavailable"),
    )
    delete_mock = AsyncMock(return_value=True)

    with pytest.MonkeyPatch.context() as mp:
        mp.setattr(SubscriptionRepository, "delete_subscription", delete_mock)
        removed = await service.remove_subscription(1)

    assert removed is True


@pytest.mark.asyncio
async def test_bulk_delete_succeeds_when_redis_unavailable(
    service: PodcastSubscriptionService,
):
    service._validate_and_get_subscription = AsyncMock(return_value=_subscription(1))
    service.redis.invalidate_episode_list = AsyncMock(
        side_effect=RuntimeError("redis unavailable"),
    )
    service.redis.invalidate_subscription_list = AsyncMock(
        side_effect=RuntimeError("redis unavailable"),
    )
    delete_mock = AsyncMock(return_value=True)

    with pytest.MonkeyPatch.context() as mp:
        mp.setattr(SubscriptionRepository, "delete_subscription", delete_mock)
        result = await service.remove_subscriptions_bulk([1, 2, 3])

    assert result["success_count"] == 3
    assert result["failed_count"] == 0
    assert result["deleted_subscription_ids"] == [1, 2, 3]
