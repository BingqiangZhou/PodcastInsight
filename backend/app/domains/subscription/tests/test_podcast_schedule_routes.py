from datetime import UTC, datetime
from unittest.mock import AsyncMock

import pytest
from fastapi.testclient import TestClient

from app.core.providers import get_podcast_schedule_service
from app.domains.podcast.schedule_projections import ScheduleConfigProjection
from app.main import app


@pytest.fixture
def client():
    return TestClient(app)


@pytest.fixture
def mock_service():
    service = AsyncMock()
    app.dependency_overrides[get_podcast_schedule_service] = lambda: service
    yield service
    app.dependency_overrides.pop(get_podcast_schedule_service, None)


def test_get_subscription_schedule_returns_assembled_response(
    client: TestClient, mock_service: AsyncMock
):
    now = datetime.now(UTC)
    mock_service.get_subscription_schedule.return_value = ScheduleConfigProjection(
        id=8,
        title="Podcast 8",
        update_frequency="DAILY",
        update_time="07:15",
        update_day_of_week=None,
        fetch_interval=3600,
        next_update_at=now,
        last_updated_at=now,
    )

    response = client.get("/api/v1/subscriptions/podcasts/8/schedule")

    assert response.status_code == 200
    payload = response.json()
    assert payload["id"] == 8
    assert payload["title"] == "Podcast 8"
    assert payload["update_frequency"] == "DAILY"


def test_get_all_subscription_schedules_returns_projection_list(
    client: TestClient, mock_service: AsyncMock
):
    now = datetime.now(UTC)
    mock_service.get_all_subscription_schedules.return_value = [
        ScheduleConfigProjection(
            id=1,
            title="Podcast 1",
            update_frequency="WEEKLY",
            update_time="09:00",
            update_day_of_week=1,
            fetch_interval=7200,
            next_update_at=now,
            last_updated_at=now,
        )
    ]

    response = client.get("/api/v1/subscriptions/podcasts/schedule/all")

    assert response.status_code == 200
    payload = response.json()
    assert len(payload) == 1
    assert payload[0]["update_day_of_week"] == 1
