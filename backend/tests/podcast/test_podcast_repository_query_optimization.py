"""Fast tests for podcast repository query optimizations."""

from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.domains.podcast.repositories import PodcastEpisodeRepository


class _RowsResult:
    def __init__(self, rows):
        self._rows = rows

    def all(self):
        return self._rows


class _ScalarRowsResult:
    def __init__(self, values):
        self._values = values

    def scalars(self):
        return self

    def all(self):
        return self._values


@pytest.mark.asyncio
async def test_subscription_episodes_batch_uses_topn_window_query():
    db = AsyncMock()
    redis = AsyncMock()
    episode_a = MagicMock(subscription_id=1)
    episode_b = MagicMock(subscription_id=1)
    episode_c = MagicMock(subscription_id=2)
    db.execute.return_value = _ScalarRowsResult([episode_a, episode_b, episode_c])

    repo = PodcastEpisodeRepository(db=db, redis=redis)
    result = await repo.get_subscription_episodes_batch(
        [1, 2], limit_per_subscription=2
    )

    assert result == {1: [episode_a, episode_b], 2: [episode_c]}
    executed_query = db.execute.await_args.args[0]
    sql = str(executed_query).lower()
    assert "row_number()" in sql
    assert "partition by" in sql


@pytest.mark.asyncio
async def test_user_subscriptions_paginated_returns_counts_without_fallback():
    db = AsyncMock()
    redis = AsyncMock()

    sub1 = MagicMock()
    sub1.id = 101
    sub2 = MagicMock()
    sub2.id = 202
    db.execute.return_value = _RowsResult([(sub1, 7, 2), (sub2, 3, 2)])

    repo = PodcastEpisodeRepository(db=db, redis=redis)
    items, total, counts = await repo.get_user_subscriptions_paginated(
        user_id=1, page=1, size=20
    )

    assert items == [sub1, sub2]
    assert total == 2
    assert counts == {101: 7, 202: 3}
    assert db.scalar.await_count == 0


@pytest.mark.asyncio
async def test_user_subscriptions_paginated_uses_fallback_on_empty_page():
    db = AsyncMock()
    redis = AsyncMock()
    db.execute.return_value = _RowsResult([])
    db.scalar.return_value = 5

    repo = PodcastEpisodeRepository(db=db, redis=redis)
    items, total, counts = await repo.get_user_subscriptions_paginated(
        user_id=1, page=3, size=20
    )

    assert items == []
    assert total == 5
    assert counts == {}
    assert db.scalar.await_count == 1


@pytest.mark.asyncio
async def test_feed_cursor_paginated_reuses_feed_total_cache_path():
    db = AsyncMock()
    redis = AsyncMock()
    db.execute.return_value = _ScalarRowsResult([])

    repo = PodcastEpisodeRepository(db=db, redis=redis)
    repo._get_feed_total_count = AsyncMock(return_value=9)

    episodes, total, has_more, next_cursor = await repo.get_feed_cursor_paginated(
        user_id=1,
        size=20,
        cursor_published_at=datetime.now(UTC),
        cursor_episode_id=999,
    )

    assert episodes == []
    assert total == 9
    assert has_more is False
    assert next_cursor is None
    repo._get_feed_total_count.assert_awaited_once_with(1)
    assert db.execute.await_count == 1


@pytest.mark.asyncio
async def test_playback_history_cursor_paginated_uses_window_total():
    db = AsyncMock()
    redis = AsyncMock()
    episode = MagicMock()
    now = datetime.now(UTC)
    db.execute.return_value = _RowsResult([(episode, now, 4)])

    repo = PodcastEpisodeRepository(db=db, redis=redis)
    (
        items,
        total,
        has_more,
        next_cursor,
    ) = await repo.get_playback_history_cursor_paginated(
        user_id=1,
        size=20,
    )

    assert items == [episode]
    assert total == 4
    assert has_more is False
    assert next_cursor is None
    assert db.scalar.await_count == 0

    executed_query = db.execute.await_args.args[0]
    sql = str(executed_query)
    assert "count(podcast_episodes.id) OVER ()" in sql


@pytest.mark.asyncio
async def test_playback_history_cursor_paginated_uses_fallback_on_empty_result():
    db = AsyncMock()
    redis = AsyncMock()
    db.execute.return_value = _RowsResult([])
    db.scalar.return_value = 6

    repo = PodcastEpisodeRepository(db=db, redis=redis)
    (
        items,
        total,
        has_more,
        next_cursor,
    ) = await repo.get_playback_history_cursor_paginated(
        user_id=1,
        size=20,
    )

    assert items == []
    assert total == 6
    assert has_more is False
    assert next_cursor is None
    assert db.scalar.await_count == 1
