from unittest.mock import AsyncMock, MagicMock

import pytest

from app.domains.podcast.repositories import PodcastEpisodeRepository


def _scalars_result(rows):
    result = MagicMock()
    scalar_result = MagicMock()
    scalar_result.all.return_value = rows
    result.scalars.return_value = scalar_result
    return result


def _scalar_result(value):
    result = MagicMock()
    result.scalar.return_value = value
    return result


@pytest.mark.asyncio
async def test_get_user_subscriptions_keeps_active_subscription_filters():
    db = AsyncMock()
    db.execute.return_value = _scalars_result([])
    repo = PodcastEpisodeRepository(db=db, redis=AsyncMock())

    items = await repo.get_user_subscriptions(user_id=42)

    assert items == []
    sql = str(db.execute.await_args.args[0])
    assert "user_subscriptions.user_id" in sql
    assert "user_subscriptions.is_archived IS false" in sql
    assert "subscriptions.source_type IN" in sql


@pytest.mark.asyncio
async def test_get_episodes_paginated_keeps_active_subscription_filters():
    db = AsyncMock()
    db.execute.side_effect = [
        _scalar_result(0),
        _scalars_result([]),
    ]
    repo = PodcastEpisodeRepository(db=db, redis=AsyncMock())

    episodes, total = await repo.get_episodes_paginated(
        user_id=42,
        page=1,
        size=20,
        filters=None,
    )

    assert episodes == []
    assert total == 0
    assert db.execute.await_count == 2

    count_sql = str(db.execute.await_args_list[0].args[0])
    page_sql = str(db.execute.await_args_list[1].args[0])
    assert "user_subscriptions.user_id" in count_sql
    assert "user_subscriptions.user_id" in page_sql
    assert "user_subscriptions.is_archived IS false" in count_sql
    assert "user_subscriptions.is_archived IS false" in page_sql
