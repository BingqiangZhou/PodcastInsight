from datetime import UTC, datetime
from unittest.mock import AsyncMock

import pytest
from fastapi.testclient import TestClient

from app.core.providers import get_podcast_playback_service
from app.main import app


@pytest.fixture
def client():
    return TestClient(app)


@pytest.fixture
def mock_service():
    service = AsyncMock()
    app.dependency_overrides[get_podcast_playback_service] = lambda: service
    yield service
    app.dependency_overrides.pop(get_podcast_playback_service, None)


def test_get_effective_playback_rate_success(
    client: TestClient, mock_service: AsyncMock
):
    mock_service.get_effective_playback_rate.return_value = {
        "global_playback_rate": 1.25,
        "subscription_playback_rate": 2.0,
        "effective_playback_rate": 2.0,
        "source": "subscription",
    }

    response = client.get("/api/v1/podcasts/playback/rate/effective?subscription_id=3")

    assert response.status_code == 200
    data = response.json()
    assert data["global_playback_rate"] == 1.25
    assert data["subscription_playback_rate"] == 2.0
    assert data["effective_playback_rate"] == 2.0
    assert data["source"] == "subscription"
    mock_service.get_effective_playback_rate.assert_awaited_once_with(subscription_id=3)


def test_apply_playback_rate_global_with_clear(
    client: TestClient, mock_service: AsyncMock
):
    mock_service.apply_playback_rate_preference.return_value = {
        "global_playback_rate": 2.5,
        "subscription_playback_rate": None,
        "effective_playback_rate": 2.5,
        "source": "global",
    }

    response = client.put(
        "/api/v1/podcasts/playback/rate/apply",
        json={
            "playback_rate": 2.5,
            "subscription_id": 12,
            "apply_to_subscription": False,
        },
    )

    assert response.status_code == 200
    data = response.json()
    assert data["effective_playback_rate"] == 2.5
    assert data["source"] == "global"
    mock_service.apply_playback_rate_preference.assert_awaited_once_with(
        playback_rate=2.5,
        apply_to_subscription=False,
        subscription_id=12,
    )


def test_apply_playback_rate_subscription_only(
    client: TestClient, mock_service: AsyncMock
):
    mock_service.apply_playback_rate_preference.return_value = {
        "global_playback_rate": 1.0,
        "subscription_playback_rate": 3.0,
        "effective_playback_rate": 3.0,
        "source": "subscription",
    }

    response = client.put(
        "/api/v1/podcasts/playback/rate/apply",
        json={
            "playback_rate": 3.0,
            "subscription_id": 8,
            "apply_to_subscription": True,
        },
    )

    assert response.status_code == 200
    data = response.json()
    assert data["effective_playback_rate"] == 3.0
    assert data["source"] == "subscription"
    mock_service.apply_playback_rate_preference.assert_awaited_once_with(
        playback_rate=3.0,
        apply_to_subscription=True,
        subscription_id=8,
    )


def test_apply_playback_rate_subscription_id_required_bilingual_error(
    client: TestClient, mock_service: AsyncMock
):
    mock_service.apply_playback_rate_preference.side_effect = ValueError(
        "SUBSCRIPTION_ID_REQUIRED"
    )

    response = client.put(
        "/api/v1/podcasts/playback/rate/apply",
        json={
            "playback_rate": 2.0,
            "subscription_id": None,
            "apply_to_subscription": True,
        },
    )

    assert response.status_code == 400
    detail = response.json()["detail"]
    assert "message_en" in detail
    assert "message_zh" in detail


def test_apply_playback_rate_validation_rejects_out_of_range(
    client: TestClient, mock_service: AsyncMock
):
    response_low = client.put(
        "/api/v1/podcasts/playback/rate/apply",
        json={
            "playback_rate": 0.4,
            "subscription_id": None,
            "apply_to_subscription": False,
        },
    )
    response_high = client.put(
        "/api/v1/podcasts/playback/rate/apply",
        json={
            "playback_rate": 3.1,
            "subscription_id": None,
            "apply_to_subscription": False,
        },
    )

    assert response_low.status_code == 422
    assert response_high.status_code == 422
    mock_service.apply_playback_rate_preference.assert_not_awaited()


def test_update_playback_progress_response_contains_rate_and_last_updated_at(
    client: TestClient, mock_service: AsyncMock
):
    now = datetime.now(UTC)
    mock_service.update_playback_progress.return_value = {
        "episode_id": 99,
        "progress": 321,
        "is_playing": True,
        "playback_rate": 3.0,
        "play_count": 5,
        "last_updated_at": now,
        "progress_percentage": 17.2,
        "remaining_time": 1540,
    }

    response = client.put(
        "/api/v1/podcasts/episodes/99/playback",
        json={
            "position": 321,
            "is_playing": True,
            "playback_rate": 3.0,
        },
    )

    assert response.status_code == 200
    data = response.json()
    assert data["episode_id"] == 99
    assert data["playback_rate"] == 3.0
    assert isinstance(data["last_updated_at"], str)
    assert data["remaining_time"] == 1540
