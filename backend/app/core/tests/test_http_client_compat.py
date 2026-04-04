"""Test that TestClient works with dependency overrides for Redis.

This test verifies the basic compatibility between FastAPI's TestClient
and dependency injection via Depends().
"""

from fastapi import Depends, FastAPI
from fastapi.testclient import TestClient

from app.core.auth import get_redis_client
from app.core.redis import AppCache


def test_redis_dependency_can_be_overridden(monkeypatch):
    """Verify that get_redis_client can be overridden via dependency_overrides."""

    class FakeRedis(AppCache):
        pass

    fake_instance = FakeRedis()

    app = FastAPI()

    @app.get("/ping")
    async def ping(_: AppCache = Depends(get_redis_client)):
        return {"status": "ok"}

    app.dependency_overrides[get_redis_client] = lambda: fake_instance

    with TestClient(app) as client:
        response = client.get("/ping")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
