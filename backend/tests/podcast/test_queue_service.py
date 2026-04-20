"""Unit tests for podcast queue service."""

from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

import pytest

from app.core.exceptions import EpisodeNotFoundError
from app.domains.podcast.services.playback_service import PodcastQueueService


@pytest.fixture
def mock_db():
    return AsyncMock()


@pytest.fixture
def mock_repo():
    with patch(
        "app.domains.podcast.services.playback_service.PodcastQueueRepository"
    ) as mock:
        repo_instance = AsyncMock()
        mock.return_value = repo_instance
        yield repo_instance


@pytest.fixture
def service(mock_db, mock_repo):
    return PodcastQueueService(mock_db, user_id=1)


def _queue_snapshot(current_episode_id: int | None = 10):
    episode = SimpleNamespace(
        title="Episode 10",
        subscription_id=2,
        audio_url="https://example.com/audio.mp3",
        audio_duration=1800,
        published_at=None,
        image_url=None,
        subscription=SimpleNamespace(
            title="Podcast A", config={"image_url": "https://example.com/cover.png"}
        ),
    )
    item = SimpleNamespace(id=1, episode_id=10, position=0, episode=episode)
    episode_2 = SimpleNamespace(
        title="Episode 11",
        subscription_id=3,
        audio_url="https://example.com/audio-2.mp3",
        audio_duration=2400,
        published_at=None,
        image_url=None,
        subscription=SimpleNamespace(
            title="Podcast B", config={"image_url": "https://example.com/cover-2.png"}
        ),
    )
    item_2 = SimpleNamespace(id=2, episode_id=11, position=1, episode=episode_2)
    return SimpleNamespace(
        current_episode_id=current_episode_id,
        revision=3,
        updated_at=None,
        items=[item, item_2],
    )


@pytest.mark.asyncio
async def test_get_queue_serializes_snapshot(service, mock_repo):
    mock_repo.get_queue_with_items.return_value = _queue_snapshot()
    mock_repo.get_playback_states_batch.return_value = {
        10: SimpleNamespace(current_position=321),
    }

    result = await service.get_queue()

    assert result["current_episode_id"] == 10
    assert result["revision"] == 3
    assert len(result["items"]) == 2
    assert result["items"][0]["episode_id"] == 10
    assert result["items"][0]["title"] == "Episode 10"
    assert result["items"][0]["playback_position"] == 321
    assert result["items"][1]["episode_id"] == 11
    assert result["items"][1]["playback_position"] is None
    mock_repo.get_playback_states_batch.assert_called_once_with(1, [10, 11])


@pytest.mark.asyncio
async def test_add_to_queue_requires_accessible_episode(service, mock_repo):
    mock_repo.get_episode_by_id.return_value = None

    with pytest.raises(EpisodeNotFoundError):
        await service.add_to_queue(999)


@pytest.mark.asyncio
async def test_reorder_queue_propagates_payload(service, mock_repo):
    mock_repo.reorder_items.return_value = _queue_snapshot()
    mock_repo.get_playback_states_batch.return_value = {}

    await service.reorder_queue([10])

    mock_repo.reorder_items.assert_called_once_with(1, [10])


@pytest.mark.asyncio
async def test_activate_episode_requires_accessible_episode(service, mock_repo):
    mock_repo.get_episode_by_id.return_value = None

    with pytest.raises(EpisodeNotFoundError):
        await service.activate_episode(999)


@pytest.mark.asyncio
async def test_activate_episode_propagates_to_repository(service, mock_repo):
    mock_repo.get_episode_by_id.return_value = SimpleNamespace(id=10)
    mock_repo.activate_episode.return_value = _queue_snapshot()
    mock_repo.get_playback_states_batch.return_value = {}

    await service.activate_episode(10)

    mock_repo.activate_episode.assert_called_once_with(
        user_id=1,
        episode_id=10,
        max_items=500,
    )
