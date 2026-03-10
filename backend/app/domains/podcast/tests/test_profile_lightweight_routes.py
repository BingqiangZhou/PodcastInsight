from datetime import UTC, datetime
from unittest.mock import AsyncMock

import pytest
from fastapi.testclient import TestClient

from app.core.providers import get_podcast_episode_service, get_podcast_stats_service
from app.main import app


@pytest.fixture
def client():
    return TestClient(app)


@pytest.fixture
def mock_service():
    service = AsyncMock()
    app.dependency_overrides[get_podcast_stats_service] = lambda: service
    app.dependency_overrides[get_podcast_episode_service] = lambda: service
    yield service
    app.dependency_overrides.pop(get_podcast_stats_service, None)
    app.dependency_overrides.pop(get_podcast_episode_service, None)


def test_get_profile_stats_returns_lightweight_fields(
    client: TestClient, mock_service: AsyncMock
):
    mock_service.get_profile_stats.return_value = {
        "total_subscriptions": 3,
        "total_episodes": 42,
        "summaries_generated": 15,
        "pending_summaries": 27,
        "played_episodes": 11,
    }

    response = client.get("/api/v1/podcasts/stats/profile")

    assert response.status_code == 200
    data = response.json()
    assert data["total_subscriptions"] == 3
    assert data["total_episodes"] == 42
    assert data["summaries_generated"] == 15
    assert data["pending_summaries"] == 27
    assert data["played_episodes"] == 11
    mock_service.get_profile_stats.assert_awaited_once_with()


@pytest.mark.parametrize("size", [1, 100])
def test_get_history_lite_page_size_boundaries(
    client: TestClient, mock_service: AsyncMock, size: int
):
    now = datetime.now(UTC)
    mock_service.list_playback_history_lite.return_value = (
        [
            {
                "id": 1,
                "subscription_id": 9,
                "subscription_title": "Test Podcast",
                "subscription_image_url": "https://example.com/sub.jpg",
                "title": "Episode A",
                "image_url": "https://example.com/ep.jpg",
                "audio_duration": 1234,
                "playback_position": 321,
                "last_played_at": now,
                "published_at": now,
            }
        ],
        1,
    )

    response = client.get(f"/api/v1/podcasts/episodes/history-lite?page=1&size={size}")

    assert response.status_code == 200
    data = response.json()
    assert data["size"] == size
    assert data["total"] == 1
    assert len(data["episodes"]) == 1
    mock_service.list_playback_history_lite.assert_awaited_with(page=1, size=size)


def test_get_history_lite_excludes_heavy_fields(
    client: TestClient, mock_service: AsyncMock
):
    now = datetime.now(UTC)
    mock_service.list_playback_history_lite.return_value = (
        [
            {
                "id": 88,
                "subscription_id": 7,
                "subscription_title": "Podcast 7",
                "subscription_image_url": None,
                "title": "Episode 88",
                "image_url": None,
                "audio_duration": 1800,
                "playback_position": 90,
                "last_played_at": now,
                "published_at": now,
            }
        ],
        1,
    )

    response = client.get("/api/v1/podcasts/episodes/history-lite?page=1&size=20")

    assert response.status_code == 200
    item = response.json()["episodes"][0]
    assert item["id"] == 88
    assert "transcript_content" not in item
    assert "ai_summary" not in item
    assert "metadata" not in item
