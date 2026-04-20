from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app.admin.services.subscriptions_service import (
    SUBSCRIPTION_TEST_PREVIEW_LIMIT,
    AdminSubscriptionsService,
)
from app.domains.podcast.parsers.feed_schemas import (
    FeedEntry,
    FeedInfo,
    FeedParseResult,
)


class _ScalarOneOrNoneResult:
    def __init__(self, value):
        self._value = value

    def scalar_one_or_none(self):
        return self._value


class _ExecuteResult:
    def __init__(self, *, rowcount: int):
        self.rowcount = rowcount


@pytest.mark.asyncio
async def test_update_frequency_uses_bulk_update(monkeypatch):
    db = AsyncMock()
    existing_setting = SimpleNamespace(value={})
    db.execute = AsyncMock(
        side_effect=[
            _ScalarOneOrNoneResult(existing_setting),
            _ExecuteResult(rowcount=7),
        ],
    )

    service = AdminSubscriptionsService(db)
    result = await service.update_frequency(
        request=SimpleNamespace(),
        user=SimpleNamespace(id=1, username="admin"),
        update_frequency="DAILY",
        update_time="09:30",
        update_day=None,
    )

    assert result["success"] is True
    assert "7 user subscriptions" in result["message"]
    update_stmt = db.execute.await_args_list[1].args[0]
    assert str(update_stmt).lower().startswith("update ")


@pytest.mark.asyncio
async def test_test_subscription_url_returns_preview_and_total_counts(monkeypatch):
    result = FeedParseResult(
        feed_info=FeedInfo(title="Test Feed", description="Example"),
        entries=[
            FeedEntry(id=str(index), title=f"Entry {index}", content="Preview")
            for index in range(SUBSCRIPTION_TEST_PREVIEW_LIMIT)
        ],
    )
    result.total_entries = 100

    parse_feed = AsyncMock(return_value=result)
    close = AsyncMock(return_value=None)
    fake_parser = SimpleNamespace(parse_feed=parse_feed, close=close)
    monkeypatch.setattr(
        "app.domains.subscription.parsers.feed_parser.FeedParser",
        lambda config: fake_parser,
    )

    service = AdminSubscriptionsService(AsyncMock())
    payload, status_code = await service.test_subscription_url(
        source_url="https://example.com/feed.xml",
        username="admin",
    )

    assert status_code == 200
    assert payload["entry_count"] == SUBSCRIPTION_TEST_PREVIEW_LIMIT
    assert payload["total_entry_count"] == 100
