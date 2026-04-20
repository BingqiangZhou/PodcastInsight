"""Podcast architecture end-to-end simulation checks (mocked, no external deps)."""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest


@pytest.mark.asyncio
async def test_routes_aggregator_exports_endpoints() -> None:
    from app.domains.podcast.routes.routes import router

    paths = {route.path for route in router.routes}
    assert any("/episodes" in path for path in paths)
    assert any("/reports" in path for path in paths)
    assert any("/queue" in path for path in paths)


@pytest.mark.asyncio
async def test_subscription_service_mocked_add_subscription() -> None:
    from sqlalchemy.ext.asyncio import AsyncSession

    from app.domains.podcast.services.subscription_service import (
        PodcastSubscriptionService,
    )

    with (
        patch(
            "app.domains.podcast.services.subscription_service.PodcastSubscriptionRepository"
        ) as mock_repo_cls,
        patch(
            "app.domains.podcast.services.subscription_service.SecureRSSParser"
        ) as mock_parser_cls,
    ):
        repo = AsyncMock()
        repo.get_user_subscriptions.return_value = []
        sub = MagicMock()
        sub.id = 1
        repo.create_or_update_subscription.return_value = sub
        repo.create_or_update_episodes_batch.return_value = ([], [])
        mock_repo_cls.return_value = repo

        parser = AsyncMock()
        feed = MagicMock()
        feed.title = "Test"
        feed.description = "Desc"
        feed.link = "https://example.com"
        feed.author = "Author"
        feed.language = "en"
        feed.categories = []
        feed.explicit = False
        feed.image_url = None
        feed.podcast_type = "episodic"
        feed.platform = "generic"
        feed.episodes = []
        parser.fetch_and_parse_feed.return_value = (True, feed, None)
        mock_parser_cls.return_value = parser

        service = PodcastSubscriptionService(AsyncMock(spec=AsyncSession), user_id=1)
        subscription, episodes = await service.add_subscription(
            "https://example.com/feed.xml"
        )
        assert subscription.id == 1
        assert episodes == []
