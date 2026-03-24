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
    assert "request_counts" in payload
    assert "response_times" in payload
    assert "error_counts" in payload
    assert "summary" in payload
    assert "global_p95_ms" in payload["summary"]
    assert "db_pool" in payload
    assert "redis_runtime" in payload
    assert "observability" in payload
    assert "commands" in payload["redis_runtime"]
    assert "cache" in payload["redis_runtime"]
    assert "summary" in payload["observability"]
    assert "checks" in payload["observability"]
    assert "alerts" in payload["observability"]
    for endpoint_stats in payload["response_times"].values():
        assert "p95_ms" in endpoint_stats


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
