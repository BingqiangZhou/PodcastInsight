"""Tests ensuring user auth routes never leak internal exception details.

Verifies that:
1. Generic exceptions (db errors, etc.) are caught by the global handler
   and return a generic "Internal server error" message, NOT the exception string.
2. BaseCustomError subclasses propagate correctly with their own messages.

Covers all 7 endpoints in app.domains.user.api.routes.
"""

from unittest.mock import AsyncMock

import pytest
from fastapi.testclient import TestClient

from app.core.auth import get_authentication_service, get_current_user
from app.core.exceptions import ConflictError, UnauthorizedError
from app.domains.user.models import User
from app.main import app


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_user() -> User:
    """Create a mock User object for dependency override."""
    user = User(
        email="test@example.com",
        username="testuser",
        hashed_password="irrelevant",
        status="active",
        is_verified=True,
        is_superuser=False,
    )
    user.id = 1
    return user


@pytest.fixture()
def client():
    """Provide a TestClient with dependency overrides for isolated route tests."""
    mock_user = _make_user()
    mock_auth = AsyncMock()

    app.dependency_overrides[get_current_user] = lambda: mock_user
    app.dependency_overrides[get_authentication_service] = lambda: mock_auth

    tc = TestClient(app, raise_server_exceptions=False)
    yield tc, mock_auth

    app.dependency_overrides.pop(get_current_user, None)
    app.dependency_overrides.pop(get_authentication_service, None)


# ---------------------------------------------------------------------------
# Endpoint URL constants
# ---------------------------------------------------------------------------

REGISTER_URL = "/api/v1/auth/register"
LOGIN_URL = "/api/v1/auth/login"
REFRESH_URL = "/api/v1/auth/refresh"
LOGOUT_URL = "/api/v1/auth/logout"
LOGOUT_ALL_URL = "/api/v1/auth/logout-all"
FORGOT_URL = "/api/v1/auth/forgot-password"
RESET_URL = "/api/v1/auth/reset-password"

SENSITIVE_STRING = "SECRET_INTERNAL_DB_PASSWORD_LEAKED"


# ===================================================================
# 1. register
# ===================================================================


class TestRegisterNoLeak:
    """Generic Exception in /register must not leak to client."""

    def test_generic_exception_returns_generic_message(self, client):
        tc, mock_auth = client
        mock_auth.register_user = AsyncMock(
            side_effect=RuntimeError(SENSITIVE_STRING),
        )

        resp = tc.post(
            REGISTER_URL,
            json={"email": "a@b.com", "password": "SecurePass123!"},
        )

        assert resp.status_code == 500
        body = resp.json()
        detail = str(body)
        # The sensitive internal string must NOT appear in the response
        assert SENSITIVE_STRING not in detail

    def test_base_custom_error_propagates(self, client):
        tc, mock_auth = client
        mock_auth.register_user = AsyncMock(
            side_effect=ConflictError("Email already registered"),
        )

        resp = tc.post(
            REGISTER_URL,
            json={"email": "a@b.com", "password": "SecurePass123!"},
        )

        assert resp.status_code == 409
        body = resp.json()
        assert "Email already registered" in str(body)


# ===================================================================
# 2. login
# ===================================================================


class TestLoginNoLeak:
    """Generic Exception in /login must not leak to client."""

    def test_generic_exception_returns_generic_message(self, client):
        tc, mock_auth = client
        mock_auth.authenticate_user = AsyncMock(
            side_effect=RuntimeError(SENSITIVE_STRING),
        )

        resp = tc.post(
            LOGIN_URL,
            json={"email_or_username": "test@example.com", "password": "pass"},
        )

        assert resp.status_code == 500
        body = resp.json()
        assert SENSITIVE_STRING not in str(body)

    def test_base_custom_error_propagates(self, client):
        tc, mock_auth = client
        mock_auth.authenticate_user = AsyncMock(
            side_effect=UnauthorizedError("Invalid credentials"),
        )

        resp = tc.post(
            LOGIN_URL,
            json={"email_or_username": "test@example.com", "password": "wrong"},
        )

        assert resp.status_code == 401
        body = resp.json()
        assert "Invalid credentials" in str(body)


# ===================================================================
# 3. refresh
# ===================================================================


class TestRefreshNoLeak:
    """Generic Exception in /refresh must not leak to client."""

    def test_generic_exception_returns_generic_message(self, client):
        tc, mock_auth = client
        mock_auth.refresh_access_token = AsyncMock(
            side_effect=RuntimeError(SENSITIVE_STRING),
        )

        resp = tc.post(
            REFRESH_URL,
            json={"refresh_token": "some.token.here"},
        )

        assert resp.status_code == 500
        body = resp.json()
        assert SENSITIVE_STRING not in str(body)


# ===================================================================
# 4. logout
# ===================================================================


class TestLogoutNoLeak:
    """Generic Exception in /logout must not leak to client."""

    def test_generic_exception_returns_generic_message(self, client):
        tc, mock_auth = client
        mock_auth.logout_user = AsyncMock(
            side_effect=RuntimeError(SENSITIVE_STRING),
        )

        resp = tc.post(
            LOGOUT_URL,
            json={"refresh_token": "some.token.here"},
        )

        assert resp.status_code == 500
        body = resp.json()
        assert SENSITIVE_STRING not in str(body)


# ===================================================================
# 5. logout-all
# ===================================================================


class TestLogoutAllNoLeak:
    """Generic Exception in /logout-all must not leak to client."""

    def test_generic_exception_returns_generic_message(self, client):
        tc, mock_auth = client
        mock_auth.logout_all_sessions = AsyncMock(
            side_effect=RuntimeError(SENSITIVE_STRING),
        )

        resp = tc.post(LOGOUT_ALL_URL)

        assert resp.status_code == 500
        body = resp.json()
        assert SENSITIVE_STRING not in str(body)


# ===================================================================
# 6. forgot-password
# ===================================================================


class TestForgotPasswordNoLeak:
    """Generic Exception in /forgot-password must not leak to client."""

    def test_generic_exception_returns_generic_message(self, client):
        tc, mock_auth = client
        mock_auth.create_password_reset_token = AsyncMock(
            side_effect=RuntimeError(SENSITIVE_STRING),
        )

        resp = tc.post(
            FORGOT_URL,
            json={"email": "a@b.com"},
        )

        assert resp.status_code == 500
        body = resp.json()
        assert SENSITIVE_STRING not in str(body)

    def test_base_custom_error_propagates(self, client):
        tc, mock_auth = client
        mock_auth.create_password_reset_token = AsyncMock(
            side_effect=UnauthorizedError("Account locked"),
        )

        resp = tc.post(FORGOT_URL, json={"email": "a@b.com"})

        assert resp.status_code == 401
        body = resp.json()
        assert "Account locked" in str(body)


# ===================================================================
# 7. reset-password
# ===================================================================


class TestResetPasswordNoLeak:
    """Generic Exception in /reset-password must not leak to client."""

    def test_generic_exception_returns_generic_message(self, client):
        tc, mock_auth = client
        mock_auth.reset_password = AsyncMock(
            side_effect=RuntimeError(SENSITIVE_STRING),
        )

        resp = tc.post(
            RESET_URL,
            json={"token": "abc123", "new_password": "NewSecure123!"},
        )

        assert resp.status_code == 500
        body = resp.json()
        assert SENSITIVE_STRING not in str(body)

    def test_base_custom_error_propagates(self, client):
        tc, mock_auth = client
        mock_auth.reset_password = AsyncMock(
            side_effect=UnauthorizedError("Token expired"),
        )

        resp = tc.post(
            RESET_URL,
            json={"token": "abc123", "new_password": "NewSecure123!"},
        )

        assert resp.status_code == 401
        body = resp.json()
        assert "Token expired" in str(body)
