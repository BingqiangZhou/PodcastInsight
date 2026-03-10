from datetime import UTC, datetime
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

import pytest

from app.domains.subscription.parsers.feed_schemas import (
    FeedEntry,
    FeedInfo,
    FeedParseResult,
)
from app.domains.subscription.services import SubscriptionService


def _build_feed_result(entries):
    return FeedParseResult(feed_info=FeedInfo(title="Feed"), entries=entries)


@pytest.mark.asyncio
async def test_fetch_subscription_uses_batch_upsert_and_single_commit():
    db = AsyncMock()
    service = SubscriptionService(db, user_id=11)
    sub = SimpleNamespace(
        id=5,
        source_type="rss",
        source_url="https://example.com/feed.xml",
        status=None,
        error_message=None,
        last_fetched_at=None,
        latest_item_published_at=None,
    )
    service.repo.get_subscription_by_id = AsyncMock(return_value=sub)
    service.repo.create_or_update_items_batch = AsyncMock(
        return_value=([object(), object()], [object()])
    )
    service.repo.update_fetch_status = AsyncMock()

    entries = [
        FeedEntry(
            id="post-1",
            title="Post 1",
            content="one",
            link="https://example.com/post-1",
            published_at=datetime.now(UTC),
        ),
        FeedEntry(
            id="post-2",
            title="Post 2",
            content="two",
            link="https://example.com/post-2",
            published_at=datetime.now(UTC),
        ),
    ]

    parser = AsyncMock()
    parser.parse_feed = AsyncMock(return_value=_build_feed_result(entries))
    parser.close = AsyncMock()

    with patch(
        "app.domains.subscription.services.subscription_service.FeedParser",
        return_value=parser,
    ):
        result = await service.fetch_subscription(5)

    batch_call = service.repo.create_or_update_items_batch.await_args
    assert batch_call.args[0] == 5
    assert len(batch_call.args[1]) == 2
    assert batch_call.kwargs == {"commit": False}
    assert result["new_items"] == 1
    assert result["updated_items"] == 1
    db.commit.assert_awaited_once()
    service.repo.update_fetch_status.assert_not_called()
    parser.close.assert_awaited_once()


@pytest.mark.asyncio
async def test_fetch_subscription_skips_invalid_entries_and_keeps_batch_commit():
    db = AsyncMock()
    service = SubscriptionService(db, user_id=11)
    sub = SimpleNamespace(
        id=7,
        source_type="rss",
        source_url="https://example.com/feed.xml",
        status=None,
        error_message=None,
        last_fetched_at=None,
        latest_item_published_at=None,
    )
    service.repo.get_subscription_by_id = AsyncMock(return_value=sub)
    service.repo.create_or_update_items_batch = AsyncMock(
        return_value=([object()], [object()])
    )

    class BrokenEntry:
        id = "broken"
        link = "https://example.com/broken"
        content = "bad"
        summary = None
        author = None
        image_url = None
        tags = []
        published_at = None

        @property
        def title(self):
            raise RuntimeError("broken entry")

    result_payload = _build_feed_result(
        [
            FeedEntry(
                id="good",
                title="Good",
                content="ok",
                link="https://example.com/good",
                published_at=datetime.now(UTC),
            )
        ]
    )
    result_payload.entries.append(BrokenEntry())

    parser = AsyncMock()
    parser.parse_feed = AsyncMock(return_value=result_payload)
    parser.close = AsyncMock()

    with patch(
        "app.domains.subscription.services.subscription_service.FeedParser",
        return_value=parser,
    ):
        result = await service.fetch_subscription(7)

    batch_call = service.repo.create_or_update_items_batch.await_args
    assert len(batch_call.args[1]) == 1
    assert result["total_items"] == 1
    db.commit.assert_awaited_once()
