from datetime import UTC, date, datetime
from unittest.mock import AsyncMock

import pytest
from fastapi.testclient import TestClient

from app.core.providers import get_daily_report_service
from app.main import app


@pytest.fixture
def client():
    return TestClient(app)


@pytest.fixture
def mock_service():
    service = AsyncMock()
    app.dependency_overrides[get_daily_report_service] = lambda: service
    yield service
    app.dependency_overrides.pop(get_daily_report_service, None)


def test_get_daily_report_not_available(client: TestClient, mock_service: AsyncMock):
    mock_service.get_daily_report.return_value = {
        "available": False,
        "report_date": None,
        "timezone": "Asia/Shanghai",
        "schedule_time_local": "03:30",
        "generated_at": None,
        "total_items": 0,
        "items": [],
    }

    response = client.get("/api/v1/podcasts/reports/daily")

    assert response.status_code == 200
    data = response.json()
    assert data["available"] is False
    assert data["total_items"] == 0
    assert data["items"] == []
    mock_service.get_daily_report.assert_awaited_once_with(target_date=None)


def test_get_daily_report_by_date_success(client: TestClient, mock_service: AsyncMock):
    now = datetime.now(UTC)
    mock_service.get_daily_report.return_value = {
        "available": True,
        "report_date": date(2026, 2, 20),
        "timezone": "Asia/Shanghai",
        "schedule_time_local": "03:30",
        "generated_at": now,
        "total_items": 1,
        "items": [
            {
                "episode_id": 11,
                "subscription_id": 5,
                "episode_title": "Episode 11",
                "subscription_title": "Podcast A",
                "one_line_summary": "One line summary.",
                "is_carryover": False,
                "episode_created_at": now,
                "episode_published_at": now,
            }
        ],
    }

    response = client.get("/api/v1/podcasts/reports/daily?date=2026-02-20")

    assert response.status_code == 200
    data = response.json()
    assert data["available"] is True
    assert data["report_date"] == "2026-02-20"
    assert data["total_items"] == 1
    assert data["items"][0]["episode_id"] == 11
    mock_service.get_daily_report.assert_awaited_once_with(
        target_date=date(2026, 2, 20)
    )


def test_generate_daily_report_without_date(
    client: TestClient, mock_service: AsyncMock
):
    now = datetime.now(UTC)
    mock_service.generate_daily_report.return_value = {
        "available": True,
        "report_date": date(2026, 2, 20),
        "timezone": "Asia/Shanghai",
        "schedule_time_local": "03:30",
        "generated_at": now,
        "total_items": 1,
        "items": [
            {
                "episode_id": 11,
                "subscription_id": 5,
                "episode_title": "Episode 11",
                "subscription_title": "Podcast A",
                "one_line_summary": "One line summary.",
                "is_carryover": False,
                "episode_created_at": now,
                "episode_published_at": now,
            }
        ],
    }

    response = client.post("/api/v1/podcasts/reports/daily/generate")

    assert response.status_code == 200
    data = response.json()
    assert data["available"] is True
    assert data["report_date"] == "2026-02-20"
    assert data["items"][0]["is_carryover"] is False
    mock_service.generate_daily_report.assert_awaited_once_with(
        target_date=None,
        rebuild=False,
    )


def test_generate_daily_report_by_date_success(
    client: TestClient,
    mock_service: AsyncMock,
):
    now = datetime.now(UTC)
    mock_service.generate_daily_report.return_value = {
        "available": True,
        "report_date": date(2026, 2, 20),
        "timezone": "Asia/Shanghai",
        "schedule_time_local": "03:30",
        "generated_at": now,
        "total_items": 1,
        "items": [
            {
                "episode_id": 11,
                "subscription_id": 5,
                "episode_title": "Episode 11",
                "subscription_title": "Podcast A",
                "one_line_summary": "One line summary.",
                "is_carryover": False,
                "episode_created_at": now,
                "episode_published_at": now,
            }
        ],
    }

    response = client.post("/api/v1/podcasts/reports/daily/generate?date=2026-02-20")

    assert response.status_code == 200
    data = response.json()
    assert data["available"] is True
    assert data["report_date"] == "2026-02-20"
    assert data["items"][0]["is_carryover"] is False
    mock_service.generate_daily_report.assert_awaited_once_with(
        target_date=date(2026, 2, 20),
        rebuild=False,
    )


def test_generate_daily_report_with_rebuild_flag(
    client: TestClient,
    mock_service: AsyncMock,
):
    now = datetime.now(UTC)
    mock_service.generate_daily_report.return_value = {
        "available": True,
        "report_date": date(2026, 2, 20),
        "timezone": "Asia/Shanghai",
        "schedule_time_local": "03:30",
        "generated_at": now,
        "total_items": 1,
        "items": [
            {
                "episode_id": 11,
                "subscription_id": 5,
                "episode_title": "Episode 11",
                "subscription_title": "Podcast A",
                "one_line_summary": "One line summary.",
                "is_carryover": False,
                "episode_created_at": now,
                "episode_published_at": now,
            }
        ],
    }

    response = client.post(
        "/api/v1/podcasts/reports/daily/generate?date=2026-02-20&rebuild=true"
    )

    assert response.status_code == 200
    data = response.json()
    assert data["available"] is True
    assert data["report_date"] == "2026-02-20"
    mock_service.generate_daily_report.assert_awaited_once_with(
        target_date=date(2026, 2, 20),
        rebuild=True,
    )


def test_list_daily_report_dates_with_pagination(
    client: TestClient,
    mock_service: AsyncMock,
):
    now = datetime.now(UTC)
    mock_service.list_report_dates.return_value = {
        "dates": [
            {
                "report_date": date(2026, 2, 20),
                "total_items": 8,
                "generated_at": now,
            }
        ],
        "total": 31,
        "page": 2,
        "size": 30,
        "pages": 2,
    }

    response = client.get("/api/v1/podcasts/reports/daily/dates?page=2&size=30")

    assert response.status_code == 200
    data = response.json()
    assert data["total"] == 31
    assert data["page"] == 2
    assert data["size"] == 30
    assert data["pages"] == 2
    assert data["dates"][0]["report_date"] == "2026-02-20"
    mock_service.list_report_dates.assert_awaited_once_with(page=2, size=30)
