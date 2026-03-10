from unittest.mock import AsyncMock

from fastapi.testclient import TestClient

from app.bootstrap import http as http_module
from app.main import app


def test_readiness_endpoint_returns_healthy(monkeypatch):
    fake_redis = type("FakeRedis", (), {"check_health": AsyncMock(return_value={"status": "healthy"})})()
    monkeypatch.setattr(http_module, "check_db_readiness", AsyncMock(return_value={"status": "healthy"}))
    monkeypatch.setattr(http_module, "get_shared_redis", lambda: fake_redis)

    client = TestClient(app)
    response = client.get("/api/v1/health/ready")

    assert response.status_code == 200
    assert response.json() == {
        "status": "healthy",
        "db": {"status": "healthy"},
        "redis": {"status": "healthy"},
    }


def test_readiness_endpoint_returns_503_when_dependency_unhealthy(monkeypatch):
    fake_redis = type(
        "FakeRedis",
        (),
        {"check_health": AsyncMock(return_value={"status": "unhealthy", "error": "timeout"})},
    )()
    monkeypatch.setattr(http_module, "check_db_readiness", AsyncMock(return_value={"status": "healthy"}))
    monkeypatch.setattr(http_module, "get_shared_redis", lambda: fake_redis)

    client = TestClient(app)
    response = client.get("/api/v1/health/ready")

    assert response.status_code == 503
    payload = response.json()
    assert payload["status"] == "unhealthy"
    assert payload["db"]["status"] == "healthy"
    assert payload["redis"]["status"] == "unhealthy"
