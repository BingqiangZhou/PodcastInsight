"""Shared pytest fixtures for backend tests."""

from __future__ import annotations

import asyncio
import os
import uuid
from collections.abc import AsyncGenerator

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.core.database import Base, register_orm_models


TEST_DATABASE_URL = "sqlite+aiosqlite:///:memory:"

test_engine = create_async_engine(
    TEST_DATABASE_URL,
    echo=False,
    future=True,
)

TestSessionLocal = async_sessionmaker(
    test_engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


@pytest.fixture(scope="session")
def performance_base_url() -> str:
    """Base URL for performance/integration HTTP client fixtures."""
    return os.getenv("PERFORMANCE_BASE_URL", "http://localhost:8000").rstrip("/")


@pytest_asyncio.fixture(scope="session")
async def async_client(performance_base_url: str) -> AsyncClient:
    """Async HTTP client against a running backend service."""
    run_performance_tests = os.getenv("RUN_PERFORMANCE_TESTS") == "1"

    if not run_performance_tests:
        from app.main import app

        async with AsyncClient(
            transport=ASGITransport(app=app),
            base_url="http://test",
            trust_env=False,
        ) as client:
            yield client
        return

    timeout = float(os.getenv("PERFORMANCE_HTTP_TIMEOUT_SECONDS", "30"))
    health_retries = int(os.getenv("PERFORMANCE_HEALTH_RETRIES", "20"))
    health_interval = float(os.getenv("PERFORMANCE_HEALTH_RETRY_INTERVAL", "1"))

    async with AsyncClient(
        base_url=performance_base_url,
        timeout=timeout,
        trust_env=False,
    ) as client:
        # Ensure target service is reachable before test execution.
        for attempt in range(health_retries):
            try:
                response = await client.get("/api/v1/health")
                if response.status_code == 200:
                    break
            except Exception:
                pass

            if attempt == health_retries - 1:
                pytest.skip(
                    f"Backend health check failed at {performance_base_url}/api/v1/health. "
                    "Run docker compose first or set PERFORMANCE_BASE_URL."
                )
            await asyncio.sleep(health_interval)

        yield client


@pytest_asyncio.fixture
async def db_session() -> AsyncGenerator[AsyncSession, None]:
    """Provide an isolated async DB session for repository-level tests."""
    register_orm_models()
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with TestSessionLocal() as session:
        yield session

    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


@pytest_asyncio.fixture(scope="session")
async def auth_headers(async_client: AsyncClient) -> dict[str, str]:
    """Create a test user and return Authorization headers."""
    suffix = uuid.uuid4().hex[:10]
    password = "PerfTestPass1!"
    register_payload = {
        "email": f"perf_{suffix}@example.com",
        "username": f"perf_{suffix}",
        "password": password,
    }

    register_response = await async_client.post(
        "/api/v1/auth/register",
        json=register_payload,
    )
    if register_response.status_code in (200, 201):
        token_payload = register_response.json()
    else:
        login_response = await async_client.post(
            "/api/v1/auth/login",
            json={
                "email_or_username": register_payload["email"],
                "password": password,
            },
        )
        if login_response.status_code != 200:
            pytest.skip(
                "Unable to create/login performance test user: "
                f"register={register_response.status_code}, login={login_response.status_code}"
            )
        token_payload = login_response.json()

    access_token = token_payload.get("access_token")
    if not access_token:
        pytest.skip("Performance auth token is missing in auth response payload")
    return {"Authorization": f"Bearer {access_token}"}
