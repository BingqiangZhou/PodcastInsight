"""Test fixtures for subscription domain tests."""

import asyncio
from collections.abc import AsyncGenerator, Callable, Generator
from unittest.mock import AsyncMock

import pytest
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

# Import all models to ensure proper registration with SQLAlchemy
# This is required for tests to work with relationships
from app.core.security import get_password_hash
from app.domains.subscription.models import (
    Subscription,
    SubscriptionStatus,
)
from app.domains.user.models import User, UserStatus
from app.main import app


# Use in-memory SQLite for testing
TEST_DATABASE_URL = "sqlite+aiosqlite:///:memory:"


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
def mock_subscription_service(mock_service_factory):
    """Provide a mocked SubscriptionService for route tests."""
    from app.domains.subscription.api.dependencies import get_subscription_service

    yield from mock_service_factory(get_subscription_service)


@pytest.fixture
def mock_schedule_service(mock_service_factory):
    from app.domains.podcast.api.dependencies import get_podcast_schedule_service

    yield from mock_service_factory(get_podcast_schedule_service)


@pytest.fixture(autouse=True)
def override_auth_dependencies():
    """Override authentication for routes requiring auth."""
    from app.core.auth import get_token_user_id
    from app.core.security import get_token_from_request

    app.dependency_overrides[get_token_from_request] = lambda: {"sub": "123"}
    app.dependency_overrides[get_token_user_id] = lambda: 123
    try:
        yield
    finally:
        app.dependency_overrides.pop(get_token_from_request, None)
        app.dependency_overrides.pop(get_token_user_id, None)


class TestBase:
    """Base class for test models."""


# Create test engine
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
def event_loop():
    """Create event loop for async tests."""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()


@pytest.fixture
async def db_session() -> AsyncGenerator[AsyncSession, None]:
    """Create a test database session."""
    from app.core.database import Base

    # Create all tables
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    # Create session
    async with TestSessionLocal() as session:
        yield session

    # Drop all tables
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


@pytest.fixture
async def test_user(db_session: AsyncSession) -> User:
    """Create a test user."""
    user = User(
        email="test@example.com",
        username="testuser",
        hashed_password=get_password_hash("testpass123"),
        status=UserStatus.ACTIVE,
        is_verified=True,
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest.fixture
async def another_user(db_session: AsyncSession) -> User:
    """Create another test user for multi-user tests."""
    user = User(
        email="another@example.com",
        username="anotheruser",
        hashed_password=get_password_hash("testpass123"),
        status=UserStatus.ACTIVE,
        is_verified=True,
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest.fixture
async def active_subscription(
    db_session: AsyncSession, test_user: User
) -> Subscription:
    """Create an active subscription for testing."""
    from app.domains.subscription.repositories import SubscriptionRepository
    from app.shared.schemas import SubscriptionCreate

    repo = SubscriptionRepository(db_session)
    sub_data = SubscriptionCreate(
        title="Tech News",
        description="Technology news feed",
        source_type="rss",
        source_url="https://example.com/feed.xml",
    )
    sub = await repo.create_subscription(test_user.id, sub_data)
    return sub


@pytest.fixture
async def error_subscription(db_session: AsyncSession, test_user: User) -> Subscription:
    """Create an ERROR status subscription for testing."""
    from app.domains.subscription.repositories import SubscriptionRepository
    from app.shared.schemas import SubscriptionCreate

    repo = SubscriptionRepository(db_session)
    sub_data = SubscriptionCreate(
        title="Error Feed",
        description="Feed with errors",
        source_type="rss",
        source_url="https://error.com/feed.xml",
    )
    sub = await repo.create_subscription(test_user.id, sub_data)

    # Set to ERROR status
    sub.status = SubscriptionStatus.ERROR
    sub.error_message = "Failed to fetch"
    await db_session.commit()
    await db_session.refresh(sub)
    return sub
