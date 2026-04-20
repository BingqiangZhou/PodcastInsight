"""Fast tests for subscription repository query optimizations."""

from unittest.mock import AsyncMock, MagicMock

import pytest

from app.domains.podcast.repositories.subscription_repository import (
    SubscriptionRepository,
)


def _build_execute_rows_result(rows):
    result = MagicMock()
    result.all.return_value = rows
    return result


@pytest.mark.asyncio
async def test_get_all_user_items_uses_join_without_prefetching_ids():
    """Query should use a direct JOIN path instead of sub-id prefetch + IN."""
    db = AsyncMock()
    db.execute.return_value = _build_execute_rows_result([("item-a", 2), ("item-b", 2)])
    repo = SubscriptionRepository(db)

    items, total = await repo.get_all_user_items(user_id=7, page=1, size=20)

    assert total == 2
    assert items == ["item-a", "item-b"]
    assert db.scalar.await_count == 0
    assert db.execute.await_count == 1

    executed_query = db.execute.await_args.args[0]
    sql = str(executed_query)
    assert "JOIN user_subscriptions" in sql
    assert "subscription_items.subscription_id IN (" not in sql


@pytest.mark.asyncio
async def test_get_all_user_items_applies_unread_and_bookmark_filters():
    """Unread and bookmark flags should be translated into SQL filters."""
    db = AsyncMock()
    db.execute.return_value = _build_execute_rows_result([("item-only", 1)])
    repo = SubscriptionRepository(db)

    items, total = await repo.get_all_user_items(
        user_id=9,
        page=1,
        size=10,
        unread_only=True,
        bookmarked_only=True,
    )

    assert total == 1
    assert items == ["item-only"]

    executed_query = db.execute.await_args.args[0]
    sql = str(executed_query)
    assert "subscription_items.read_at IS NULL" in sql
    assert "subscription_items.bookmarked IS true" in sql


@pytest.mark.asyncio
async def test_get_user_subscriptions_aggregates_item_counts_in_same_query():
    """Subscription page query should carry item counts without extra execute."""
    db = AsyncMock()

    sub1 = MagicMock()
    sub1.id = 101
    sub2 = MagicMock()
    sub2.id = 202
    db.execute.return_value = _build_execute_rows_result([(sub1, 7, 2), (sub2, 0, 2)])

    repo = SubscriptionRepository(db)
    items, total, item_counts = await repo.get_user_subscriptions(
        user_id=3,
        page=1,
        size=20,
    )

    assert total == 2
    assert items == [sub1, sub2]
    assert item_counts == {101: 7, 202: 0}
    assert db.scalar.await_count == 0
    assert db.execute.await_count == 1

    executed_query = db.execute.await_args.args[0]
    sql = str(executed_query)
    assert "LEFT OUTER JOIN" in sql
    assert "subscription_items" in sql


@pytest.mark.asyncio
async def test_get_all_user_items_uses_count_fallback_for_empty_page():
    """Out-of-range pages should fallback to scalar count to keep total stable."""
    db = AsyncMock()
    db.execute.return_value = _build_execute_rows_result([])
    db.scalar.return_value = 5
    repo = SubscriptionRepository(db)

    items, total = await repo.get_all_user_items(
        user_id=11,
        page=3,
        size=20,
    )

    assert items == []
    assert total == 5
    assert db.execute.await_count == 1
    assert db.scalar.await_count == 1


@pytest.mark.asyncio
async def test_get_user_subscriptions_uses_count_fallback_for_empty_page():
    """Out-of-range pages should fallback to scalar count to keep total stable."""
    db = AsyncMock()
    db.execute.return_value = _build_execute_rows_result([])
    db.scalar.return_value = 4
    repo = SubscriptionRepository(db)

    items, total, item_counts = await repo.get_user_subscriptions(
        user_id=12,
        page=4,
        size=20,
    )

    assert items == []
    assert total == 4
    assert item_counts == {}
    assert db.execute.await_count == 1
    assert db.scalar.await_count == 1


@pytest.mark.asyncio
async def test_get_subscription_items_uses_join_and_window_count():
    """Subscription items should use ownership join and window count path."""
    db = AsyncMock()
    db.execute.return_value = _build_execute_rows_result([("ep-1", 3), ("ep-2", 3)])
    repo = SubscriptionRepository(db)

    items, total = await repo.get_subscription_items(
        subscription_id=88,
        user_id=2,
        page=1,
        size=20,
    )

    assert items == ["ep-1", "ep-2"]
    assert total == 3
    assert db.execute.await_count == 1
    assert db.scalar.await_count == 0

    executed_query = db.execute.await_args.args[0]
    sql = str(executed_query)
    assert "JOIN user_subscriptions" in sql
    assert "count(subscription_items.id) OVER ()" in sql


@pytest.mark.asyncio
async def test_get_subscription_items_uses_count_fallback_for_empty_page():
    """Empty pages should use fallback count while preserving empty items."""
    db = AsyncMock()
    db.execute.return_value = _build_execute_rows_result([])
    db.scalar.return_value = 6
    repo = SubscriptionRepository(db)

    items, total = await repo.get_subscription_items(
        subscription_id=99,
        user_id=4,
        page=9,
        size=20,
    )

    assert items == []
    assert total == 6
    assert db.execute.await_count == 1
    assert db.scalar.await_count == 1
