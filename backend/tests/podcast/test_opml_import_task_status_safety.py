"""Status-safety tests for OPML background episode parsing handler."""

from datetime import UTC, datetime
from unittest.mock import AsyncMock, Mock, patch

import pytest

from app.domains.podcast.models import PodcastEpisode
from app.domains.podcast.tasks.task_orchestration import (
    PodcastTaskOrchestrationService,
)
from app.domains.podcast.tasks.tasks_maintenance import (
    process_opml_subscription_episodes_handler,
)


@pytest.mark.asyncio
async def test_opml_background_handler_does_not_mutate_existing_episode_status() -> (
    None
):
    existing_episode = PodcastEpisode(
        subscription_id=1,
        title="Existing",
        description="existing",
        audio_url="https://example.com/existing.mp3",
        published_at=datetime.now(UTC),
        item_link="https://example.com/episodes/existing",
        status="summarized",
        metadata_json={},
    )

    mock_feed_episode = Mock()
    mock_feed_episode.title = "Existing"
    mock_feed_episode.description = "existing"
    mock_feed_episode.audio_url = "https://example.com/existing.mp3"
    mock_feed_episode.published_at = datetime.now(UTC)
    mock_feed_episode.duration = 123
    mock_feed_episode.transcript_url = None
    mock_feed_episode.link = "https://example.com/episodes/existing"

    mock_feed = Mock()
    mock_feed.title = "Feed"
    mock_feed.author = None
    mock_feed.language = None
    mock_feed.categories = None
    mock_feed.explicit = None
    mock_feed.image_url = None
    mock_feed.podcast_type = None
    mock_feed.link = "https://example.com/feed"
    mock_feed.platform = "generic"
    mock_feed.last_fetched = datetime.now(UTC)
    mock_feed.episodes = [mock_feed_episode]

    mock_repo = AsyncMock()
    mock_repo.create_or_update_episodes_batch.return_value = ([existing_episode], [])
    mock_repo.update_subscription_metadata = AsyncMock()
    mock_repo.update_subscription_fetch_time = AsyncMock()

    mock_parser = AsyncMock()
    mock_parser.fetch_and_parse_feed.return_value = (True, mock_feed, None)

    service = PodcastTaskOrchestrationService(session=AsyncMock())

    with (
        patch(
            "app.domains.podcast.tasks.task_orchestration.PodcastSubscriptionRepository",
            return_value=mock_repo,
        ),
        patch(
            "app.domains.podcast.tasks.task_orchestration.SecureRSSParser",
            return_value=mock_parser,
        ),
    ):
        result = await service.process_opml_subscription_episodes(
            subscription_id=1,
            user_id=1,
            source_url="https://example.com/feed.xml",
        )

    assert result["status"] == "success"
    assert existing_episode.status == "summarized"
    mock_repo.create_or_update_episodes_batch.assert_awaited_once()
    mock_parser.close.assert_awaited_once()
    with patch.object(
        PodcastTaskOrchestrationService,
        "process_opml_subscription_episodes",
        new=AsyncMock(return_value=result),
    ):
        delegated_result = await process_opml_subscription_episodes_handler(
            session=AsyncMock(),
            subscription_id=1,
            user_id=1,
            source_url="https://example.com/feed.xml",
        )
    assert delegated_result == result
