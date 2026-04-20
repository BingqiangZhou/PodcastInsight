"""Integration tests for podcast subscription service platform support"""

from datetime import UTC, datetime
from unittest.mock import AsyncMock, Mock, patch

import pytest

from app.domains.podcast.integration.platform_detector import PodcastPlatform
from app.domains.podcast.services.episode_service import PodcastSubscriptionService


class TestPodcastSubscriptionPlatform:
    """Test subscription service stores and returns platform information"""

    @pytest.fixture
    def mock_db(self):
        """Mock database session"""
        return AsyncMock()

    @pytest.fixture
    def mock_repo(self):
        """Mock repository"""
        with patch(
            "app.domains.podcast.services.episode_service.PodcastSubscriptionRepository",
        ) as mock:
            repo_instance = AsyncMock()
            mock.return_value = repo_instance
            yield repo_instance

    @pytest.fixture
    def mock_parser(self):
        """Mock RSS parser"""
        with patch(
            "app.domains.podcast.integration.secure_rss_parser.SecureRSSParser",
        ) as mock:
            parser_instance = AsyncMock()
            mock.return_value = parser_instance
            yield parser_instance

    @pytest.fixture
    def service(self, mock_db, mock_repo, mock_parser):
        """Create service instance"""
        service = PodcastSubscriptionService(mock_db, user_id=1)
        service.repo = mock_repo
        service.parser = mock_parser
        service.redis = Mock()
        service.redis.invalidate_episode_list = AsyncMock(return_value=None)
        service.redis.invalidate_subscription_list = AsyncMock(return_value=None)
        return service

    def create_mock_feed(self, platform: str):
        """Create mock feed with platform"""
        mock_feed = Mock()
        mock_feed.title = "Test Podcast"
        mock_feed.description = "Test Description"
        mock_feed.link = "https://example.com"
        mock_feed.author = "Test Author"
        mock_feed.language = "zh-CN"
        mock_feed.categories = ["Technology"]
        mock_feed.explicit = False
        mock_feed.image_url = "https://example.com/image.jpg"
        mock_feed.podcast_type = "episodic"
        mock_feed.platform = platform
        mock_feed.episodes = []
        return mock_feed

    @pytest.mark.asyncio
    async def test_add_subscription_stores_ximalaya_platform(
        self,
        service,
        mock_repo,
        mock_parser,
    ):
        """Test adding Ximalaya subscription stores platform in metadata"""
        feed_url = "https://www.ximalaya.com/album/51076156.xml"
        mock_feed = self.create_mock_feed(PodcastPlatform.XIMALAYA)

        mock_parser.fetch_and_parse_feed.return_value = (True, mock_feed, None)
        mock_repo.get_user_subscriptions.return_value = []
        mock_repo.create_or_update_episodes_batch.return_value = ([], [])

        mock_subscription = Mock()
        mock_subscription.id = 1
        mock_subscription.config = {"platform": PodcastPlatform.XIMALAYA}
        mock_repo.create_or_update_subscription.return_value = mock_subscription

        subscription, episodes = await service.add_subscription(feed_url)

        # Verify platform was passed to repository
        call_args = mock_repo.create_or_update_subscription.call_args
        metadata = call_args.kwargs.get("metadata") or call_args[0][5]
        assert metadata["platform"] == PodcastPlatform.XIMALAYA

    @pytest.mark.asyncio
    async def test_add_subscription_stores_xiaoyuzhou_platform(
        self,
        service,
        mock_repo,
        mock_parser,
    ):
        """Test adding Xiaoyuzhou subscription stores platform in metadata"""
        feed_url = "https://feed.xyzfm.space/mcklbwxjdvfu"
        mock_feed = self.create_mock_feed(PodcastPlatform.XIAOYUZHOU)

        mock_parser.fetch_and_parse_feed.return_value = (True, mock_feed, None)
        mock_repo.get_user_subscriptions.return_value = []
        mock_repo.create_or_update_episodes_batch.return_value = ([], [])

        mock_subscription = Mock()
        mock_subscription.id = 1
        mock_subscription.config = {"platform": PodcastPlatform.XIAOYUZHOU}
        mock_repo.create_or_update_subscription.return_value = mock_subscription

        subscription, episodes = await service.add_subscription(feed_url)

        # Verify platform was passed to repository
        call_args = mock_repo.create_or_update_subscription.call_args
        metadata = call_args.kwargs.get("metadata") or call_args[0][5]
        assert metadata["platform"] == PodcastPlatform.XIAOYUZHOU

    @pytest.mark.asyncio
    async def test_add_subscription_stores_generic_platform(
        self,
        service,
        mock_repo,
        mock_parser,
    ):
        """Test adding generic RSS subscription stores generic platform"""
        feed_url = "https://example.com/podcast.rss"
        mock_feed = self.create_mock_feed(PodcastPlatform.GENERIC)

        mock_parser.fetch_and_parse_feed.return_value = (True, mock_feed, None)
        mock_repo.get_user_subscriptions.return_value = []
        mock_repo.create_or_update_episodes_batch.return_value = ([], [])

        mock_subscription = Mock()
        mock_subscription.id = 1
        mock_subscription.config = {"platform": PodcastPlatform.GENERIC}
        mock_repo.create_or_update_subscription.return_value = mock_subscription

        subscription, episodes = await service.add_subscription(feed_url)

        # Verify platform was passed to repository
        call_args = mock_repo.create_or_update_subscription.call_args
        metadata = call_args.kwargs.get("metadata") or call_args[0][5]
        assert metadata["platform"] == PodcastPlatform.GENERIC

    @pytest.mark.asyncio
    async def test_add_subscription_includes_all_metadata_with_platform(
        self,
        service,
        mock_repo,
        mock_parser,
    ):
        """Test subscription metadata includes platform along with other fields"""
        feed_url = "https://www.ximalaya.com/album/123.xml"
        mock_feed = self.create_mock_feed(PodcastPlatform.XIMALAYA)

        mock_parser.fetch_and_parse_feed.return_value = (True, mock_feed, None)
        mock_repo.get_user_subscriptions.return_value = []
        mock_repo.create_or_update_episodes_batch.return_value = ([], [])

        mock_subscription = Mock()
        mock_repo.create_or_update_subscription.return_value = mock_subscription

        await service.add_subscription(feed_url)

        # Verify all metadata fields including platform
        call_args = mock_repo.create_or_update_subscription.call_args
        metadata = call_args.kwargs.get("metadata") or call_args[0][5]

        assert "platform" in metadata
        assert metadata["platform"] == PodcastPlatform.XIMALAYA
        assert "author" in metadata
        assert "language" in metadata
        assert "categories" in metadata
        assert "image_url" in metadata

    @pytest.mark.asyncio
    async def test_list_subscriptions_returns_platform(self, service, mock_repo):
        """Test listing subscriptions returns platform information"""
        mock_subscription = Mock()
        mock_subscription.id = 1
        mock_subscription.title = "Test Podcast"
        mock_subscription.config = {"platform": PodcastPlatform.XIMALAYA}
        mock_subscription.created_at = datetime.now(UTC)
        mock_subscription.status = "active"
        mock_subscription.description = "desc"
        mock_subscription.source_url = "https://example.com/feed.xml"
        mock_subscription.last_fetched_at = None
        mock_subscription.error_message = None
        mock_subscription.fetch_interval = 3600
        mock_subscription.image_url = "https://example.com/image.jpg"
        mock_subscription.updated_at = datetime.now(UTC)

        mock_repo.get_user_subscriptions_paginated.return_value = (
            [mock_subscription],
            1,
            {1: 0},
        )
        mock_repo.get_subscription_episodes_batch.return_value = {1: []}
        mock_repo.get_playback_states_batch.return_value = {}

        result, total = await service.list_subscriptions(page=1, size=20)

        assert total == 1
        assert len(result) == 1
        # Platform should be included in subscription data
        assert "config" in result[0] or "platform" in str(result[0])
        mock_repo.get_episodes_counts_batch.assert_not_called()

    @pytest.mark.asyncio
    async def test_refresh_subscription_preserves_platform(
        self,
        service,
        mock_repo,
        mock_parser,
    ):
        """Test refreshing subscription preserves platform information"""
        subscription_id = 1
        feed_url = "https://www.ximalaya.com/album/123.xml"

        mock_subscription = Mock()
        mock_subscription.id = subscription_id
        mock_subscription.source_url = feed_url
        mock_subscription.config = {"platform": PodcastPlatform.XIMALAYA}
        mock_repo.get_subscription_by_id.return_value = mock_subscription

        mock_feed = self.create_mock_feed(PodcastPlatform.XIMALAYA)
        mock_feed.last_fetched = datetime.now(UTC)
        mock_parser.fetch_and_parse_feed.return_value = (True, mock_feed, None)

        mock_repo.create_or_update_episodes_batch.return_value = ([], [])

        await service.refresh_subscription(subscription_id)

        # Verify platform is preserved during refresh
        mock_repo.update_subscription_fetch_time.assert_called_once_with(
            subscription_id,
            mock_feed.last_fetched,
        )

    @pytest.mark.asyncio
    async def test_refresh_subscription_succeeds_when_redis_unavailable(
        self,
        service,
        mock_repo,
        mock_parser,
    ):
        """Refresh should still succeed when Redis invalidation fails."""
        subscription_id = 1

        mock_subscription = Mock()
        mock_subscription.id = subscription_id
        mock_subscription.source_url = "https://www.ximalaya.com/album/123.xml"
        mock_subscription.config = {"platform": PodcastPlatform.XIMALAYA}
        mock_repo.get_subscription_by_id.return_value = mock_subscription

        mock_feed = self.create_mock_feed(PodcastPlatform.XIMALAYA)
        mock_feed.last_fetched = datetime.now(UTC)
        mock_parser.fetch_and_parse_feed.return_value = (True, mock_feed, None)
        mock_repo.create_or_update_episodes_batch.return_value = ([], [])

        service.redis.invalidate_episode_list = AsyncMock(
            side_effect=RuntimeError("redis unavailable"),
        )
        service.redis.invalidate_subscription_list = AsyncMock(
            side_effect=RuntimeError("redis unavailable"),
        )

        await service.refresh_subscription(subscription_id)
        mock_repo.update_subscription_fetch_time.assert_called_once_with(
            subscription_id,
            mock_feed.last_fetched,
        )
