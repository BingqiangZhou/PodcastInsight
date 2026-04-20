"""Parser lifecycle tests for podcast task orchestration."""

from __future__ import annotations

from contextlib import asynccontextmanager
from datetime import UTC, datetime, timedelta
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

import pytest

from app.domains.podcast.services.task_orchestration_service import (
    PodcastTaskOrchestrationService,
)


class _ScalarListResult:
    def __init__(self, values):
        self._values = values

    def scalars(self):
        return self

    def all(self):
        return self._values


class _SequenceSession:
    def __init__(self, results):
        self._results = iter(results)

    async def execute(self, _stmt):
        return next(self._results)


@asynccontextmanager
async def _fake_worker_db_session(_application_name: str):
    yield AsyncMock()


def _build_feed(*, published_at: datetime) -> SimpleNamespace:
    episode = SimpleNamespace(
        title="Episode",
        description="Description",
        audio_url="https://example.com/audio.mp3",
        published_at=published_at,
        duration=120,
        transcript_url=None,
        link="https://example.com/episode",
    )
    return SimpleNamespace(
        title="Feed",
        author=None,
        language=None,
        categories=[],
        explicit=None,
        image_url=None,
        podcast_type=None,
        link="https://example.com/feed",
        total_episodes=1,
        platform="generic",
        last_fetched=datetime.now(UTC),
        episodes=[episode],
    )


@pytest.mark.asyncio
async def test_refresh_all_podcast_feeds_closes_parser_after_success() -> None:
    now = datetime.now(UTC)
    subscription = SimpleNamespace(
        id=1,
        title="Feed",
        source_url="https://example.com/feed.xml",
        last_fetched_at=now - timedelta(hours=1),
    )
    user_subscription = SimpleNamespace(
        subscription_id=1,
        user_id=7,
        should_update_now=lambda: True,
    )
    session = _SequenceSession(
        [
            _ScalarListResult([subscription]),
            _ScalarListResult([user_subscription]),
        ]
    )
    parser = AsyncMock()
    parser.fetch_and_parse_feed.return_value = (
        True,
        _build_feed(published_at=now),
        None,
    )
    repo = AsyncMock()
    repo.get_subscription_by_id_direct.return_value = subscription
    repo.create_or_update_episodes_batch.return_value = (
        [],
        [SimpleNamespace(id=11, published_at=now)],
    )

    with (
        patch(
            "app.domains.podcast.services.task_orchestration_service.PodcastSubscriptionRepository",
            return_value=repo,
        ),
        patch(
            "app.domains.podcast.services.task_orchestration_service.SecureRSSParser",
            return_value=parser,
        ),
    ):
        result = await PodcastTaskOrchestrationService(
            session
        ).refresh_all_podcast_feeds()

    assert result["status"] == "success"
    parser.close.assert_awaited_once()


@pytest.mark.asyncio
async def test_refresh_all_podcast_feeds_closes_parser_after_exception() -> None:
    subscription = SimpleNamespace(
        id=1,
        title="Feed",
        source_url="https://example.com/feed.xml",
        last_fetched_at=datetime.now(UTC),
    )
    user_subscription = SimpleNamespace(
        subscription_id=1,
        user_id=7,
        should_update_now=lambda: True,
    )
    session = _SequenceSession(
        [
            _ScalarListResult([subscription]),
            _ScalarListResult([user_subscription]),
        ]
    )
    parser = AsyncMock()
    parser.fetch_and_parse_feed.side_effect = RuntimeError("parse boom")
    repo = AsyncMock()
    repo.get_subscription_by_id_direct.return_value = subscription

    with (
        patch(
            "app.domains.podcast.services.task_orchestration_service.PodcastSubscriptionRepository",
            return_value=repo,
        ),
        patch(
            "app.domains.podcast.services.task_orchestration_service.SecureRSSParser",
            return_value=parser,
        ),
    ):
        result = await PodcastTaskOrchestrationService(
            session
        ).refresh_all_podcast_feeds()

    assert result["status"] == "success"
    assert result["refreshed_subscriptions"] == 0
    parser.close.assert_awaited_once()


@pytest.mark.asyncio
async def test_process_opml_subscription_episodes_closes_parser_on_failure() -> None:
    parser = AsyncMock()
    parser.fetch_and_parse_feed.return_value = (False, None, "parse failed")
    repo = AsyncMock()

    with (
        patch(
            "app.domains.podcast.services.task_orchestration_service.PodcastSubscriptionRepository",
            return_value=repo,
        ),
        patch(
            "app.domains.podcast.services.task_orchestration_service.SecureRSSParser",
            return_value=parser,
        ),
    ):
        result = await PodcastTaskOrchestrationService(
            session=AsyncMock()
        ).process_opml_subscription_episodes(
            subscription_id=1,
            user_id=1,
            source_url="https://example.com/feed.xml",
        )

    assert result["status"] == "error"
    parser.close.assert_awaited_once()


@pytest.mark.asyncio
async def test_process_opml_subscription_episodes_closes_parser_on_exception() -> None:
    parser = AsyncMock()
    parser.fetch_and_parse_feed.side_effect = RuntimeError("parse boom")
    repo = AsyncMock()

    with (
        patch(
            "app.domains.podcast.services.task_orchestration_service.PodcastSubscriptionRepository",
            return_value=repo,
        ),
        patch(
            "app.domains.podcast.services.task_orchestration_service.SecureRSSParser",
            return_value=parser,
        ),
        pytest.raises(RuntimeError, match="parse boom"),
    ):
        await PodcastTaskOrchestrationService(
            session=AsyncMock()
        ).process_opml_subscription_episodes(
            subscription_id=1,
            user_id=1,
            source_url="https://example.com/feed.xml",
        )

    parser.close.assert_awaited_once()
