from unittest.mock import AsyncMock

import pytest

from app.domains.podcast.repositories import PodcastEpisodeRepository


class _ScalarResult:
    def __init__(self, value):
        self._value = value

    def scalar(self):
        return self._value


@pytest.mark.asyncio
async def test_feed_total_count_uses_cache_hit_without_db():
    db = AsyncMock()
    redis = AsyncMock()
    redis.get = AsyncMock(return_value="11")
    redis.set = AsyncMock()

    repo = PodcastEpisodeRepository(db=db, redis=redis)
    total = await repo._get_feed_total_count(user_id=99)

    assert total == 11
    db.execute.assert_not_awaited()
    redis.set.assert_not_awaited()


@pytest.mark.asyncio
async def test_feed_total_count_caches_db_result_on_miss():
    db = AsyncMock()
    db.execute = AsyncMock(return_value=_ScalarResult(5))
    redis = AsyncMock()
    redis.get = AsyncMock(return_value=None)
    redis.set = AsyncMock()

    repo = PodcastEpisodeRepository(db=db, redis=redis)
    total = await repo._get_feed_total_count(user_id=2)

    assert total == 5
    db.execute.assert_awaited_once()
    redis.set.assert_awaited_once_with("podcast:feed:count:2", "5", ttl=120)
