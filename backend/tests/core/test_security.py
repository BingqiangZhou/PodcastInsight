"""Comprehensive tests for the security module.

Covers:
- JWT token creation, verification, and round-trip
- Expired and invalid token rejection
- verify_token_optional development mock vs production enforcement
- get_token_from_request header extraction and environment gating
- Password hashing and verification
- User ID extraction from token payloads
- Export password strength validation
"""

from __future__ import annotations

import time
from datetime import timedelta
from unittest.mock import patch

import pytest
from fastapi import HTTPException

from app.core.config import settings
from app.core.security import (
    create_access_token,
    create_refresh_token,
    get_password_hash,
    get_token_from_request,
    get_user_id_from_token,
    validate_export_password,
    verify_password,
    verify_token,
    verify_token_optional,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
def sample_payload() -> dict:
    """Standard JWT payload for testing."""
    return {"sub": "42", "email": "user@example.com"}


@pytest.fixture
async def access_token(sample_payload: dict) -> str:
    """Create a valid access token for testing."""
    return await create_access_token(sample_payload)


@pytest.fixture
async def refresh_token(sample_payload: dict) -> str:
    """Create a valid refresh token for testing."""
    return await create_refresh_token(sample_payload)


# ---------------------------------------------------------------------------
# 1. Token creation and verification round-trip
# ---------------------------------------------------------------------------


class TestTokenCreationRoundTrip:
    """Verify that created tokens can be decoded and contain expected claims."""

    @pytest.mark.asyncio
    async def test_access_token_round_trip(
        self, sample_payload: dict
    ) -> None:
        token = await create_access_token(sample_payload)
        payload = await verify_token(token, token_type="access")

        assert payload["sub"] == "42"
        assert payload["email"] == "user@example.com"
        assert "exp" in payload
        assert "iat" in payload
        assert "jti" in payload
        # Access tokens should NOT have a "type" claim
        assert "type" not in payload

    @pytest.mark.asyncio
    async def test_refresh_token_round_trip(
        self, sample_payload: dict
    ) -> None:
        token = await create_refresh_token(sample_payload)
        payload = await verify_token(token, token_type="refresh")

        assert payload["sub"] == "42"
        assert payload["type"] == "refresh"
        assert "jti" in payload

    @pytest.mark.asyncio
    async def test_access_token_with_custom_expiry(
        self, sample_payload: dict
    ) -> None:
        delta = timedelta(minutes=5)
        token = await create_access_token(sample_payload, expires_delta=delta)
        payload = await verify_token(token, token_type="access")

        # Expiry should be roughly 5 minutes from now
        remaining_seconds = payload["exp"] - time.time()
        assert 200 < remaining_seconds < 400  # generous window

    @pytest.mark.asyncio
    async def test_refresh_token_with_custom_expiry(
        self, sample_payload: dict
    ) -> None:
        delta = timedelta(days=1)
        token = await create_refresh_token(sample_payload, expires_delta=delta)
        payload = await verify_token(token, token_type="refresh")

        remaining_seconds = payload["exp"] - time.time()
        # ~1 day in seconds
        assert 80000 < remaining_seconds < 90000

    @pytest.mark.asyncio
    async def test_access_token_accepted_for_any_type(
        self, sample_payload: dict
    ) -> None:
        """Access tokens don't have a 'type' field, so type check is skipped."""
        token = await create_access_token(sample_payload)
        # Access tokens lack the 'type' claim, so verify_token skips type enforcement
        payload = await verify_token(token, token_type="refresh")
        assert payload["sub"] == sample_payload["sub"]

    @pytest.mark.asyncio
    async def test_refresh_token_rejected_as_access(
        self, sample_payload: dict
    ) -> None:
        """Refresh token used as access token should be rejected."""
        token = await create_refresh_token(sample_payload)
        with pytest.raises(HTTPException) as exc_info:
            await verify_token(token, token_type="access")
        assert exc_info.value.status_code == 401


# ---------------------------------------------------------------------------
# 2. Expired token rejection
# ---------------------------------------------------------------------------


class TestExpiredTokenRejection:
    """Tokens past their expiry must be rejected."""

    @pytest.mark.asyncio
    async def test_expired_access_token_rejected(
        self, sample_payload: dict
    ) -> None:
        token = await create_access_token(
            sample_payload, expires_delta=timedelta(seconds=-1)
        )
        with pytest.raises(HTTPException) as exc_info:
            await verify_token(token, token_type="access")
        assert exc_info.value.status_code == 401

    @pytest.mark.asyncio
    async def test_expired_refresh_token_rejected(
        self, sample_payload: dict
    ) -> None:
        token = await create_refresh_token(
            sample_payload, expires_delta=timedelta(seconds=-1)
        )
        with pytest.raises(HTTPException) as exc_info:
            await verify_token(token, token_type="refresh")
        assert exc_info.value.status_code == 401


# ---------------------------------------------------------------------------
# 3. Invalid token rejection
# ---------------------------------------------------------------------------


class TestInvalidTokenRejection:
    """Malformed or tampered tokens must be rejected."""

    @pytest.mark.asyncio
    async def test_completely_invalid_token(self) -> None:
        with pytest.raises(HTTPException) as exc_info:
            await verify_token("not-a-real-token", token_type="access")
        assert exc_info.value.status_code == 401
        assert "Could not validate credentials" in exc_info.value.detail

    @pytest.mark.asyncio
    async def test_tampered_token_rejected(self, access_token: str) -> None:
        # Alter one character in the token body
        tampered = access_token[:-5] + "XXXXX"
        with pytest.raises(HTTPException) as exc_info:
            await verify_token(tampered, token_type="access")
        assert exc_info.value.status_code == 401

    @pytest.mark.asyncio
    async def test_empty_string_token_rejected(self) -> None:
        with pytest.raises(HTTPException) as exc_info:
            await verify_token("", token_type="access")
        assert exc_info.value.status_code == 401

    @pytest.mark.asyncio
    async def test_wrong_secret_key_rejected(self, sample_payload: dict) -> None:
        """Token signed with a different key must be rejected."""
        import jwt as pyjwt

        from app.core.config import settings

        # Forge a token with a different secret
        forged = pyjwt.encode(
            {"sub": "99", "exp": int(time.time()) + 3600, "iat": int(time.time())},
            "wrong-secret-key-not-the-real-one",
            algorithm=settings.ALGORITHM,
        )
        with pytest.raises(HTTPException) as exc_info:
            await verify_token(forged, token_type="access")
        assert exc_info.value.status_code == 401


# ---------------------------------------------------------------------------
# 4 & 5. verify_token_optional: development mock vs production enforcement
# ---------------------------------------------------------------------------


class TestVerifyTokenOptional:
    """verify_token_optional returns mock user in dev, raises in prod."""

    @pytest.mark.asyncio
    async def test_returns_mock_user_in_dev_mode_when_no_token(self) -> None:
        with patch("app.core.security.jwt.settings") as mock_settings:
            mock_settings.ENVIRONMENT = "development"
            result = await verify_token_optional(token=None, token_type="access")

        assert result["sub"] == "1"
        assert result["email"] == "dev-mock@internal.local"
        assert result["type"] == "access"
        assert result["exp"] > int(time.time())

    @pytest.mark.asyncio
    async def test_raises_401_in_production_when_no_token(self) -> None:
        with patch("app.core.security.jwt.settings") as mock_settings:
            mock_settings.ENVIRONMENT = "production"
            with pytest.raises(HTTPException) as exc_info:
                await verify_token_optional(token=None, token_type="access")

        assert exc_info.value.status_code == 401
        assert "Authentication required" in exc_info.value.detail

    @pytest.mark.asyncio
    async def test_verifies_real_token_when_provided(self, access_token: str) -> None:
        """When a real token is provided, it should be verified normally."""
        payload = await verify_token_optional(token=access_token, token_type="access")
        assert payload["sub"] == "42"

    @pytest.mark.asyncio
    async def test_rejects_invalid_token_when_provided(self) -> None:
        """When an invalid token is provided, it should raise."""
        with pytest.raises(HTTPException) as exc_info:
            await verify_token_optional(token="invalid-token", token_type="access")
        assert exc_info.value.status_code == 401

    @pytest.mark.asyncio
    async def test_dev_mock_has_correct_token_type(self) -> None:
        """Mock user should reflect the requested token_type."""
        with patch("app.core.security.jwt.settings") as mock_settings:
            mock_settings.ENVIRONMENT = "development"
            result = await verify_token_optional(token=None, token_type="refresh")

        assert result["type"] == "refresh"


# ---------------------------------------------------------------------------
# 6, 7, 8. get_token_from_request: header extraction and environment gating
# ---------------------------------------------------------------------------


class TestGetTokenFromRequest:
    """Token extraction from request headers / query params."""

    @pytest.mark.asyncio
    async def test_extracts_from_authorization_header(
        self, access_token: str
    ) -> None:
        payload = await get_token_from_request(
            token=None, authorization=f"Bearer {access_token}"
        )
        assert payload["sub"] == "42"

    @pytest.mark.asyncio
    async def test_extracts_token_without_bearer_prefix(
        self, access_token: str
    ) -> None:
        """Authorization header without 'Bearer ' prefix should still work."""
        payload = await get_token_from_request(token=None, authorization=access_token)
        assert payload["sub"] == "42"

    @pytest.mark.asyncio
    async def test_raises_401_when_no_token_provided(self) -> None:
        with pytest.raises(HTTPException) as exc_info:
            await get_token_from_request(token=None, authorization=None)
        assert exc_info.value.status_code == 401
        assert "Authentication required" in exc_info.value.detail

    @pytest.mark.asyncio
    async def test_rejects_query_param_in_production(
        self, access_token: str
    ) -> None:
        """Query param token must be rejected when not in development."""
        with patch.object(settings, "ENVIRONMENT", "production"):
            with pytest.raises(HTTPException) as exc_info:
                await get_token_from_request(token=access_token, authorization=None)

        assert exc_info.value.status_code == 401
        assert "production" in exc_info.value.detail.lower()

    @pytest.mark.asyncio
    async def test_allows_query_param_in_development(
        self, access_token: str
    ) -> None:
        """Query param token is accepted in development with a deprecation warning."""
        with patch.object(settings, "ENVIRONMENT", "development"):
            payload = await get_token_from_request(
                token=access_token, authorization=None
            )

        assert payload["sub"] == "42"

    @pytest.mark.asyncio
    async def test_authorization_header_takes_precedence_over_query_param(
        self, access_token: str
    ) -> None:
        """When both are provided, Authorization header wins."""
        payload = await get_token_from_request(
            token="should-be-ignored", authorization=f"Bearer {access_token}"
        )
        assert payload["sub"] == "42"

    @pytest.mark.asyncio
    async def test_rejects_invalid_token_from_header(self) -> None:
        with pytest.raises(HTTPException) as exc_info:
            await get_token_from_request(
                token=None, authorization="Bearer invalid-token"
            )
        assert exc_info.value.status_code == 401


# ---------------------------------------------------------------------------
# 9 & 10. Password hashing and verification
# ---------------------------------------------------------------------------


class TestPasswordHashing:
    """Password hashing and verification via bcrypt."""

    def test_hash_and_verify_round_trip(self) -> None:
        password = "MySecureP@ssw0rd!"
        hashed = get_password_hash(password)
        assert verify_password(password, hashed) is True

    def test_wrong_password_rejected(self) -> None:
        hashed = get_password_hash("correct-password")
        assert verify_password("wrong-password", hashed) is False

    def test_different_hashes_for_same_password(self) -> None:
        """bcrypt generates unique salts each time."""
        password = "same-password"
        hash1 = get_password_hash(password)
        hash2 = get_password_hash(password)
        assert hash1 != hash2
        # Both should still verify
        assert verify_password(password, hash1) is True
        assert verify_password(password, hash2) is True

    def test_empty_password_hashed_and_verified(self) -> None:
        """Edge case: empty string should still hash and verify."""
        hashed = get_password_hash("")
        assert verify_password("", hashed) is True

    def test_unicode_password(self) -> None:
        """Passwords with unicode characters should work."""
        password = "p@$$w0rd\u00e9\u4e2d\u6587"
        hashed = get_password_hash(password)
        assert verify_password(password, hashed) is True
        assert verify_password("wrong", hashed) is False


# ---------------------------------------------------------------------------
# 11. User ID extraction from token payload
# ---------------------------------------------------------------------------


class TestGetUserIdFromToken:
    """Extract and convert user ID from JWT token payload."""

    def test_extracts_valid_integer_user_id(self) -> None:
        payload = {"sub": "12345", "email": "user@example.com"}
        assert get_user_id_from_token(payload) == 12345

    def test_raises_key_error_when_sub_missing(self) -> None:
        with pytest.raises(KeyError, match="missing 'sub' claim"):
            get_user_id_from_token({"email": "user@example.com"})

    def test_raises_value_error_when_sub_not_integer(self) -> None:
        with pytest.raises(ValueError, match="not a valid integer"):
            get_user_id_from_token({"sub": "not-a-number"})

    def test_raises_key_error_when_sub_is_none(self) -> None:
        with pytest.raises(KeyError, match="missing 'sub' claim"):
            get_user_id_from_token({"sub": None})

    def test_raises_value_error_when_sub_is_float_string(self) -> None:
        with pytest.raises(ValueError, match="not a valid integer"):
            get_user_id_from_token({"sub": "12.34"})

    def test_zero_user_id(self) -> None:
        assert get_user_id_from_token({"sub": "0"}) == 0

    def test_large_user_id(self) -> None:
        assert get_user_id_from_token({"sub": "999999999"}) == 999999999


# ---------------------------------------------------------------------------
# 12 & 13. Export password validation
# ---------------------------------------------------------------------------


class TestValidateExportPassword:
    """Password strength validation for export encryption."""

    # -- Strong passwords (accepted) --

    @pytest.mark.parametrize(
        "password",
        [
            "Abcdefgh123!",  # upper, lower, digit, special - 12 chars
            "MySecureP@ssword123",  # mixed types
            "aAbbccDDEE1122!",  # 16 chars, 3 types
            "P@ssw0rdP@ss",  # 12 chars with repeats
        ],
    )
    def test_accepts_strong_passwords(self, password: str) -> None:
        is_valid, error = validate_export_password(password)
        assert is_valid is True
        assert error == ""

    # -- Weak passwords (rejected) --

    @pytest.mark.parametrize(
        "password",
        [
            "short1!",  # too short (7 chars)
            "abcdefghij",  # 10 chars but too short and only lowercase
            "Abc123",  # too short (6 chars)
            "123456789012",  # 12 chars but only digits
            "abcdefghijkl",  # 12 chars but only lowercase
            "ABCDEFGHIJKL",  # 12 chars but only uppercase
            "!@#$%^&*()_+",  # 12 chars but only special
        ],
    )
    def test_rejects_too_short_passwords(self, password: str) -> None:
        is_valid, error = validate_export_password(password)
        assert is_valid is False
        # Error message depends on which check fails first
        assert error != ""

    def test_rejects_password_with_only_two_character_types(self) -> None:
        """12 chars with only 2 types should be rejected (needs 3 of 4)."""
        # Only lowercase + digits
        is_valid, error = validate_export_password("abcdefghijkl12")
        # This has 2 types (lower + digit) which is < 3
        assert is_valid is False
        assert "at least 3 of" in error

    def test_rejects_empty_password(self) -> None:
        is_valid, error = validate_export_password("")
        assert is_valid is False
        assert "at least 12 characters" in error

    def test_exactly_12_chars_with_three_types_accepted(self) -> None:
        """Boundary case: exactly 12 characters with 3 types."""
        is_valid, error = validate_export_password("Abcdefghij1!")
        assert is_valid is True

    def test_11_chars_rejected_even_with_all_types(self) -> None:
        """Boundary case: 11 characters with all 4 types still rejected."""
        is_valid, error = validate_export_password("Aa1!Bb2@Cc")
        assert is_valid is False
        assert "at least 12 characters" in error
