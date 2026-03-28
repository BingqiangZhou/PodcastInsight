from unittest.mock import AsyncMock, patch

from fastapi.testclient import TestClient

from app.main import app


def test_metrics_endpoint_includes_runtime_sections():
    mock_redis_runtime = {
        "commands": {"total": 0, "errors": 0},
        "cache": {"hits": 0, "misses": 0, "hit_rate": 0.0},
    }

    with patch(
        "app.bootstrap.http.get_redis_runtime_metrics",
        new_callable=AsyncMock,
        return_value=mock_redis_runtime,
    ):
        client = TestClient(app)
        client.get("/")

        response = client.get("/metrics")

    assert response.status_code == 200
    payload = response.json()
    assert "db_pool" in payload
    assert "redis_runtime" in payload


def test_metrics_summary_endpoint_returns_compact_observability():
    mock_redis_runtime = {
        "commands": {"total": 0, "errors": 0},
        "cache": {"hits": 0, "misses": 0, "hit_rate": 0.0},
    }

    with patch(
        "app.bootstrap.http.get_redis_runtime_metrics",
        new_callable=AsyncMock,
        return_value=mock_redis_runtime,
    ):
        client = TestClient(app)
        client.get("/")

        response = client.get("/metrics/summary")

    assert response.status_code == 200
    payload = response.json()
    assert "summary" in payload
    assert "checks" in payload
    assert "alerts" in payload
    assert payload["summary"]["overall_status"] in {"ok", "warning", "critical"}
