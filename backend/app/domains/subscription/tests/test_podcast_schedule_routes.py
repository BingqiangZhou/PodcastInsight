from datetime import UTC, datetime
from unittest.mock import AsyncMock

from fastapi.testclient import TestClient


def test_get_subscription_schedule_returns_assembled_response(
    client: TestClient,
    mock_schedule_service: AsyncMock,
):
    now = datetime.now(UTC)
    mock_schedule_service.get_subscription_schedule.return_value = {
        "id": 8,
        "title": "Podcast 8",
        "update_frequency": "DAILY",
        "update_time": "07:15",
        "update_day_of_week": None,
        "fetch_interval": 3600,
        "next_update_at": now,
        "last_updated_at": now,
    }

    response = client.get("/api/v1/podcasts/subscriptions/8/schedule")

    assert response.status_code == 200
    payload = response.json()
    assert payload["id"] == 8
    assert payload["title"] == "Podcast 8"
    assert payload["update_frequency"] == "DAILY"


def test_get_all_subscription_schedules_returns_dict_list(
    client: TestClient,
    mock_schedule_service: AsyncMock,
):
    now = datetime.now(UTC)
    mock_schedule_service.get_all_subscription_schedules.return_value = [
        {
            "id": 1,
            "title": "Podcast 1",
            "update_frequency": "WEEKLY",
            "update_time": "09:00",
            "update_day_of_week": 1,
            "fetch_interval": 7200,
            "next_update_at": now,
            "last_updated_at": now,
        },
    ]

    response = client.get("/api/v1/podcasts/subscriptions/schedule/all")

    assert response.status_code == 200
    payload = response.json()
    assert len(payload) == 1
    assert payload[0]["update_day_of_week"] == 1
