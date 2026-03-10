from datetime import UTC, datetime
from unittest.mock import AsyncMock

import pytest
from fastapi.testclient import TestClient

from app.core.providers import get_podcast_queue_service
from app.domains.podcast.playback_queue_projections import PodcastQueueProjection
from app.main import app


@pytest.fixture
def client():
    return TestClient(app)


@pytest.fixture
def mock_service():
    service = AsyncMock()
    app.dependency_overrides[get_podcast_queue_service] = lambda: service
    yield service
    app.dependency_overrides.pop(get_podcast_queue_service, None)


def test_get_queue_returns_assembled_response(
    client: TestClient, mock_service: AsyncMock
):
    now = datetime.now(UTC)
    mock_service.get_queue.return_value = PodcastQueueProjection.model_validate(
        {
            "current_episode_id": 9,
            "revision": 4,
            "updated_at": now,
            "items": [
                {
                    "episode_id": 9,
                    "position": 0,
                    "playback_position": 42,
                    "title": "Episode 9",
                    "podcast_id": 3,
                    "audio_url": "https://example.com/audio.mp3",
                    "duration": 200,
                    "published_at": now,
                    "image_url": None,
                    "subscription_title": "Podcast",
                    "subscription_image_url": None,
                }
            ],
        }
    )

    response = client.get("/api/v1/podcasts/queue")

    assert response.status_code == 200
    payload = response.json()
    assert payload["current_episode_id"] == 9
    assert payload["revision"] == 4
    assert payload["items"][0]["episode_id"] == 9
    mock_service.get_queue.assert_awaited_once_with()


def test_add_queue_item_preserves_not_found_mapping(
    client: TestClient, mock_service: AsyncMock
):
    mock_service.add_to_queue.side_effect = ValueError("EPISODE_NOT_FOUND")

    response = client.post("/api/v1/podcasts/queue/items", json={"episode_id": 123})

    assert response.status_code == 404
    assert response.json()["detail"]["message_en"] == "Episode not found"
    mock_service.add_to_queue.assert_awaited_once_with(123)
