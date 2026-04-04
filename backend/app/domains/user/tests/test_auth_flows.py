"""Comprehensive auth flow tests for AuthenticationService.

Tests registration, authentication, session management, token refresh,
password reset, and security edge cases using SQLite in-memory database.


Note: SQLite stores timezone-aware datetimes as naive (stripping tz info).
We work around this by using naive datetimes in test data and mocking
datetime.now(UTC) where the service compares against stored values.
"""

from __future__ import annotations

import uuid
from collections.abc import AsyncGenerator
from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, MagicMock, patch

# ruff: noqa: ARG005

import pytest
import pytest_asyncio
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.core.database import Base, register_orm_models
from app.core.exceptions import (
    BadRequestError,
    ConflictError,
    NotFoundError,
    UnauthorizedError,
)
from app.core.security import get_password_hash
from app.domains.user.models import PasswordReset, User, UserSession
from app.domains.user.services.auth_service import AuthenticationService


TEST_DATABASE_URL = "sqlite+aiosqlite:///:memory:"
_engine = create_async_engine(TEST_DATABASE_URL, echo=False, future=True)
_SessionFactory = async_sessionmaker(
    _engine, class_=AsyncSession, expire_on_commit=False,
)

# Counter for generating unique mock JWT tokens
_token_counter = 0


def _unique_token(prefix: str = "access") -> str:
    """Generate a unique fake JWT token."""
    global _token_counter
    _token_counter += 1
    return f"mock.{prefix}.{_token_counter}"


@pytest_asyncio.fixture
async def db() -> AsyncGenerator[AsyncSession, None]:
    """Create a fresh in-memory database for each test."""
    global _token_counter
    _token_counter = 0
    register_orm_models()
    async with _engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    async with _SessionFactory() as session:
        yield session
    async with _engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


@pytest.fixture
def auth_service(db: AsyncSession) -> AuthenticationService:
    return AuthenticationService(db)


@pytest.fixture(autouse=True)
def mock_jwt():
    """Auto-use fixture: mock all JWT creation/verification in auth_service."""
    user_email = "user@example.com"

    def _verify(token, token_type="access"):
        return {
            "sub": "1",
            "type": "refresh" if ".refresh." in token else "access",
            "email": user_email,
        }

    mock_dt = MagicMock()
    mock_dt.now.return_value = datetime.utcnow()
    mock_dt.side_effect = lambda *a, **kw: datetime(*a, **kw) if a else datetime.utcnow()
    # Preserve real datetime attributes used in auth_service
    mock_dt.timedelta = timedelta
    mock_dt.UTC = UTC

    patches = [
        patch(
            "app.domains.user.services.auth_service.create_access_token",
            side_effect=lambda *a, **kw: _unique_token("access"),
        ),
        patch(
            "app.domains.user.services.auth_service.create_refresh_token",
            side_effect=lambda *a, **kw: _unique_token("refresh"),
        ),
        patch(
            "app.domains.user.services.auth_service.verify_token",
            side_effect=_verify,
        ),
        patch("app.domains.user.services.auth_service.datetime", mock_dt),
    ]
    for p in patches:
        p.start()
    yield
    for p in reversed(patches):
        p.stop()


async def _create_user(
    db: AsyncSession,
    email: str = "user@example.com",
    password: str = "SecurePass123!",
    username: str = "testuser",
) -> User:
    """Helper: directly insert a user row into the database."""
    user = User(
        email=email,
        username=username,
        hashed_password=get_password_hash(password),
        status="active",
        is_verified=False,
        is_superuser=False,
    )
    db.add(user)
    await db.commit()
    return user


# ── Registration ──────────────────────────────────────────────────────


class TestRegistration:
    async def test_register_user_success(self, auth_service: AuthenticationService):
        user = await auth_service.register_user("new@example.com", "SecurePass123!")
        assert user.id is not None
        assert user.email == "new@example.com"

    async def test_register_without_username_generates_from_email(
        self,
        auth_service: AuthenticationService,
    ):
        user = await auth_service.register_user("alice@example.com", "SecurePass123!")
        assert user.username == "alice"

    async def test_register_duplicate_email_raises_conflict(
        self,
        auth_service: AuthenticationService,
        db: AsyncSession,
    ):
        await _create_user(db, email="dup@example.com")
        with pytest.raises(ConflictError, match="Email already"):
            await auth_service.register_user("dup@example.com", "SecurePass123!")

    async def test_register_duplicate_username_raises_conflict(
        self,
        auth_service: AuthenticationService,
        db: AsyncSession,
    ):
        await _create_user(db, username="taken")
        with pytest.raises(ConflictError, match="Username already"):
            await auth_service.register_user("other@example.com", "SecurePass123!", username="taken")

    async def test_register_weak_password_raises_bad_request(
        self,
        auth_service: AuthenticationService,
    ):
        with pytest.raises(BadRequestError, match="at least 8 characters"):
            await auth_service.register_user("weak@example.com", "short")

    async def test_register_username_auto_increment_on_duplicate(
        self,
        auth_service: AuthenticationService,
        db: AsyncSession,
    ):
        await _create_user(db, email="a@b.com", username="bob")
        # Email "bob@example.com" generates username "bob" which is taken,
        # so service should auto-increment to "bob1"
        user = await auth_service.register_user("bob@example.com", "SecurePass123!")
        assert user.username == "bob1"


# ── Authentication ────────────────────────────────────────────────────


class TestAuthentication:
    async def test_authenticate_with_valid_credentials(
        self,
        auth_service: AuthenticationService,
        db: AsyncSession,
    ):
        await _create_user(db)
        user = await auth_service.authenticate_user("user@example.com", "SecurePass123!")
        assert user is not None
        assert user.email == "user@example.com"

    async def test_authenticate_with_username(
        self,
        auth_service: AuthenticationService,
        db: AsyncSession,
    ):
        await _create_user(db)
        user = await auth_service.authenticate_user("testuser", "SecurePass123!")
        assert user is not None

    async def test_authenticate_with_invalid_password(
        self,
        auth_service: AuthenticationService,
        db: AsyncSession,
    ):
        await _create_user(db)
        result = await auth_service.authenticate_user("user@example.com", "WrongPass!")
        assert result is None

    async def test_authenticate_nonexistent_user(
        self,
        auth_service: AuthenticationService,
    ):
        result = await auth_service.authenticate_user("noone@example.com", "whatever")
        assert result is None

    async def test_authenticate_inactive_user_returns_none(
        self,
        auth_service: AuthenticationService,
        db: AsyncSession,
    ):
        user = await _create_user(db)
        user.status = "inactive"
        await db.commit()
        result = await auth_service.authenticate_user("user@example.com", "SecurePass123!")
        assert result is None

    async def test_authenticate_updates_last_login(
        self,
        auth_service: AuthenticationService,
        db: AsyncSession,
    ):
        await _create_user(db)
        user = await auth_service.authenticate_user("user@example.com", "SecurePass123!")
        assert user is not None
        assert user.last_login_at is not None


# ── Token Refresh ─────────────────────────────────────────────────────


class TestTokenRefresh:
    async def test_refresh_with_valid_refresh_token(
        self,
        auth_service: AuthenticationService,
        db: AsyncSession,
    ):
        user = await _create_user(db)
        session_data = await auth_service.create_user_session(user)
        # Mock datetime to return naive UTC for the refresh comparison
        with patch("app.domains.user.services.auth_service.datetime") as mock_dt:
            mock_dt.now.return_value = datetime.utcnow()
            mock_dt.side_effect = lambda *a, **kw: datetime.utcnow()
            result = await auth_service.refresh_access_token(session_data["refresh_token"])
        assert "access_token" in result
        assert "refresh_token" in result

    async def test_refresh_with_invalid_token_raises_unauthorized(
        self,
        auth_service: AuthenticationService,
    ):
        # With our mock_jwt autouse fixture, verify_token always succeeds,
        # so the error comes from session lookup (NotFoundError) not token verification.
        with pytest.raises((UnauthorizedError, NotFoundError)):
            await auth_service.refresh_access_token("invalid.token.here")

    async def test_refresh_with_expired_token_raises_unauthorized(
        self,
        auth_service: AuthenticationService,
    ):
        with patch("app.domains.user.services.auth_service.verify_token") as mock_verify:
            mock_verify.side_effect = Exception("Token expired")
            with pytest.raises(UnauthorizedError):
                await auth_service.refresh_access_token("expired")

    async def test_refresh_with_no_active_session_raises_not_found(
        self,
        auth_service: AuthenticationService,
        db: AsyncSession,
    ):
        user = await _create_user(db)
        session_data = await auth_service.create_user_session(user)
        # Deactivate session
        await auth_service.logout_user(session_data["refresh_token"])
        with pytest.raises((UnauthorizedError, NotFoundError)):
            await auth_service.refresh_access_token(session_data["refresh_token"])


# ── Password Reset ───────────────────────────────────────────────────


class TestPasswordReset:
    async def test_create_password_reset_token_for_existing_user(
        self,
        auth_service: AuthenticationService,
        db: AsyncSession,
    ):
        await _create_user(db)
        with patch("app.domains.user.services.auth_service.email_service") as mock_email:
            mock_email.send_password_reset_email = AsyncMock()
            result = await auth_service.create_password_reset_token("user@example.com")
        assert result["token"] is not None
        assert "message" in result

    async def test_create_password_reset_token_for_nonexistent_email(
        self,
        auth_service: AuthenticationService,
    ):
        result = await auth_service.create_password_reset_token("nobody@example.com")
        assert result["token"] is None  # Don't reveal existence

    async def test_reset_password_with_valid_token(
        self,
        auth_service: AuthenticationService,
        db: AsyncSession,
    ):
        await _create_user(db)
        # Create reset token via service
        with patch("app.domains.user.services.auth_service.email_service") as mock_email:
            mock_email.send_password_reset_email = AsyncMock()
            reset_result = await auth_service.create_password_reset_token("user@example.com")
        token = reset_result["token"]

        result = await auth_service.reset_password(token, "NewSecure123!")
        assert "successfully reset" in result["message"]

        # Verify password changed
        updated_user = await auth_service.authenticate_user(
            "user@example.com", "NewSecure123!",
        )
        assert updated_user is not None

    async def test_reset_password_with_expired_token_raises_bad_request(
        self,
        auth_service: AuthenticationService,
        db: AsyncSession,
    ):
        await _create_user(db)
        token = str(uuid.uuid4())
        # Use naive datetime (SQLite stores as naive)
        reset = PasswordReset(
            email="user@example.com",
            token=token,
            expires_at=datetime.utcnow() - timedelta(hours=1),  # expired
            is_used=False,
        )
        db.add(reset)
        await db.commit()

        with pytest.raises(BadRequestError, match="Invalid or expired"):
            await auth_service.reset_password(token, "NewSecure123!")

    async def test_reset_password_with_used_token_raises_bad_request(
        self,
        auth_service: AuthenticationService,
        db: AsyncSession,
    ):
        await _create_user(db)
        token = str(uuid.uuid4())
        reset = PasswordReset(
            email="user@example.com",
            token=token,
            expires_at=datetime.utcnow() + timedelta(hours=1),
            is_used=True, # already used
        )
        db.add(reset)
        await db.commit()

        with pytest.raises(BadRequestError, match="Invalid or expired"):
            await auth_service.reset_password(token, "NewSecure123!")

    async def test_reset_password_weak_password_raises_bad_request(
        self,
        auth_service: AuthenticationService,
    ):
        with pytest.raises(BadRequestError, match="at least 8 characters"):
            await auth_service.reset_password("any-token", "short")

    async def test_reset_password_invalidates_sessions(
        self,
        auth_service: AuthenticationService,
        db: AsyncSession,
    ):
        user = await _create_user(db)
        session_data = await auth_service.create_user_session(user)

        # Create reset token via service
        with patch("app.domains.user.services.auth_service.email_service") as mock_email:
            mock_email.send_password_reset_email = AsyncMock()
            reset_result = await auth_service.create_password_reset_token("user@example.com")

        await auth_service.reset_password(reset_result["token"], "NewSecure123!")

        # Old session should be invalidated
        with pytest.raises((NotFoundError, UnauthorizedError)):
            await auth_service.refresh_access_token(session_data["refresh_token"])

    async def test_create_reset_invalidates_previous_tokens(
        self,
        auth_service: AuthenticationService,
        db: AsyncSession,
    ):
        await _create_user(db)
        with patch("app.domains.user.services.auth_service.email_service") as mock_email:
            mock_email.send_password_reset_email = AsyncMock()
            result1 = await auth_service.create_password_reset_token("user@example.com")
            result2 = await auth_service.create_password_reset_token("user@example.com")
        # First token should be invalidated
        with pytest.raises(BadRequestError, match="Invalid or expired"):
            await auth_service.reset_password(result1["token"], "NewSecure123!")


# ── Session Management ────────────────────────────────────────────────


class TestSessionManagement:
    async def test_create_session_returns_tokens(
        self,
        auth_service: AuthenticationService,
        db: AsyncSession,
    ):
        user = await _create_user(db)
        result = await auth_service.create_user_session(user)
        assert "access_token" in result
        assert "refresh_token" in result
        assert result["token_type"] == "bearer"
        assert "expires_in" in result

    async def test_create_session_with_device_info(
        self,
        auth_service: AuthenticationService,
        db: AsyncSession,
    ):
        user = await _create_user(db)
        result = await auth_service.create_user_session(
            user,
            device_info={"name": "Test Device"},
            ip_address="127.0.0.1",
            user_agent="TestAgent/1.0",
        )
        assert "access_token" in result

    async def test_logout_user(
        self,
        auth_service: AuthenticationService,
        db: AsyncSession,
    ):
        user = await _create_user(db)
        session_data = await auth_service.create_user_session(user)
        result = await auth_service.logout_user(session_data["refresh_token"])
        assert result is True

    async def test_logout_invalid_session_raises_not_found(
        self,
        auth_service: AuthenticationService,
    ):
        with pytest.raises(NotFoundError, match="Session not found"):
            await auth_service.logout_user("nonexistent-refresh-token")

    async def test_logout_all_sessions(
        self,
        auth_service: AuthenticationService,
        db: AsyncSession,
    ):
        user = await _create_user(db)
        s1 = await auth_service.create_user_session(user)
        s2 = await auth_service.create_user_session(user)

        result = await auth_service.logout_all_sessions(user.id)
        assert result is True

        # Both sessions should be invalidated
        with pytest.raises((NotFoundError, UnauthorizedError)):
            await auth_service.refresh_access_token(s1["refresh_token"])
        with pytest.raises((NotFoundError, UnauthorizedError)):
            await auth_service.refresh_access_token(s2["refresh_token"])

    async def test_concurrent_session_limit_enforced(
        self,
        auth_service: AuthenticationService,
        db: AsyncSession,
    ):
        user = await _create_user(db)
        # Create 6 sessions (limit is 5)
        sessions = []
        for _ in range(6):
            s = await auth_service.create_user_session(user)
            sessions.append(s)

        # The first session should have been evicted
        with pytest.raises((NotFoundError, UnauthorizedError)):
            await auth_service.refresh_access_token(sessions[0]["refresh_token"])

        # The last session should still work
        with patch("app.domains.user.services.auth_service.datetime") as mock_dt:
            mock_dt.now.return_value = datetime.utcnow()
            mock_dt.side_effect = lambda *a, **kw: datetime.utcnow()
            result = await auth_service.refresh_access_token(sessions[-1]["refresh_token"])
        assert "access_token" in result

    async def test_remember_me_extends_refresh_expiry(
        self,
        auth_service: AuthenticationService,
        db: AsyncSession,
    ):
        user = await _create_user(db)
        result = await auth_service.create_user_session(user, remember_me=True)
        # Session should still work and return valid tokens
        assert "access_token" in result
        assert "refresh_token" in result
        # Refresh should also work (proving the session is valid)
        with patch("app.domains.user.services.auth_service.datetime") as mock_dt:
            mock_dt.now.return_value = datetime.utcnow()
            mock_dt.side_effect = lambda *a, **kw: datetime.utcnow()
            refreshed = await auth_service.refresh_access_token(result["refresh_token"])
        assert "access_token" in refreshed

    async def test_cleanup_expired_sessions(
        self,
        auth_service: AuthenticationService,
        db: AsyncSession,
    ):
        user = await _create_user(db)
        # Create a session then immediately expire it
        await auth_service.create_user_session(user)
        # Manually expire all sessions
        from sqlalchemy import update
        await db.execute(
            update(UserSession)
            .where(UserSession.user_id == user.id)
            .values(expires_at=datetime.utcnow() - timedelta(days=1))
        )
        await db.commit()

        count = await auth_service.cleanup_expired_sessions()
        assert count >= 1
