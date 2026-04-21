"""Shared pytest fixtures for podcast domain route tests."""

from collections.abc import Callable, Generator
from unittest.mock import AsyncMock

import pytest
from fastapi.testclient import TestClient

from app.main import app


@pytest.fixture
def client() -> TestClient:
    """Provide a TestClient for route testing."""
    return TestClient(app)


@pytest.fixture
def mock_service_factory() -> Callable[[Callable], Generator[AsyncMock, None, None]]:
    """Factory fixture to create mock services for any provider."""

    def _factory(provider: Callable) -> Generator[AsyncMock, None, None]:
        service = AsyncMock()
        app.dependency_overrides[provider] = lambda: service
        try:
            yield service
        finally:
            app.dependency_overrides.pop(provider, None)

    return _factory


@pytest.fixture
def mock_daily_report_service(mock_service_factory):
    from app.domains.podcast.routes.dependencies import get_daily_report_service

    yield from mock_service_factory(get_daily_report_service)


@pytest.fixture
def mock_playback_service(mock_service_factory):
    from app.domains.podcast.routes.dependencies import get_podcast_playback_service

    yield from mock_service_factory(get_podcast_playback_service)


@pytest.fixture
def mock_queue_service(mock_service_factory):
    from app.domains.podcast.routes.dependencies import get_podcast_queue_service

    yield from mock_service_factory(get_podcast_queue_service)


@pytest.fixture
def mock_stats_service(mock_service_factory):
    from app.domains.podcast.routes.dependencies import (
        get_podcast_episode_service,
        get_podcast_stats_service,
    )

    # Override both services with the same mock for stats-related tests
    service = AsyncMock()
    app.dependency_overrides[get_podcast_stats_service] = lambda: service
    app.dependency_overrides[get_podcast_episode_service] = lambda: service
    try:
        yield service
    finally:
        app.dependency_overrides.pop(get_podcast_stats_service, None)
        app.dependency_overrides.pop(get_podcast_episode_service, None)


@pytest.fixture
def mock_episode_service(mock_service_factory):
    from app.domains.podcast.routes.dependencies import get_podcast_episode_service

    yield from mock_service_factory(get_podcast_episode_service)


@pytest.fixture
def mock_subscription_service(mock_service_factory):
    from app.domains.podcast.routes.dependencies import get_podcast_subscription_service

    yield from mock_service_factory(get_podcast_subscription_service)


@pytest.fixture
def mock_workflow_service(mock_service_factory):
    from app.domains.podcast.routes.dependencies import (
        get_transcription_workflow_service,
    )

    yield from mock_service_factory(get_transcription_workflow_service)


@pytest.fixture
def mock_schedule_service(mock_service_factory):
    from app.domains.podcast.routes.dependencies import get_podcast_schedule_service

    yield from mock_service_factory(get_podcast_schedule_service)


@pytest.fixture(autouse=True)
def override_auth_dependencies():
    """Override authentication for routes requiring auth."""
    from app.core.auth import require_api_key

    app.dependency_overrides[require_api_key] = lambda: 1
    try:
        yield
    finally:
        app.dependency_overrides.pop(require_api_key, None)
