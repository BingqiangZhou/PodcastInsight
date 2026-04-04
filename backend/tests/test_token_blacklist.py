"""Tests for JWT token revocation blacklist."""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest


@pytest.fixture
def mock_redis():
    """Mock Redis client."""
    redis = AsyncMock()
    pipe = AsyncMock()
    pipe.setex = AsyncMock()
    pipe.execute = AsyncMock()
    redis.pipeline = MagicMock(return_value=pipe)
    with patch(
        "app.core.security.token_blacklist._get_raw_client",
        return_value=redis,
    ):
        yield {"redis": redis, "pipe": pipe}


class TestRevokeToken:
    @pytest.mark.asyncio
    async def test_sets_blacklist_key(self, mock_redis):
        from app.core.security.token_blacklist import revoke_token

        redis = mock_redis["redis"]
        await revoke_token("test-jti", remaining_ttl=3600)
        redis.setex.assert_called_once_with("token_blacklist:test-jti", 3600, "1")

    @pytest.mark.asyncio
    async def test_default_ttl(self, mock_redis):
        from app.core.security.token_blacklist import revoke_token

        redis = mock_redis["redis"]
        await revoke_token("test-jti")
        call_args = redis.setex.call_args
        assert call_args[0][0] == "token_blacklist:test-jti"
        assert call_args[0][1] == 7 * 24 * 3600


class TestIsTokenRevoked:
    @pytest.mark.asyncio
    async def test_revoked_token(self, mock_redis):
        from app.core.security.token_blacklist import is_token_revoked

        mock_redis["redis"].exists = AsyncMock(return_value=1)
        assert await is_token_revoked("revoked-jti") is True

    @pytest.mark.asyncio
    async def test_valid_token(self, mock_redis):
        from app.core.security.token_blacklist import is_token_revoked

        mock_redis["redis"].exists = AsyncMock(return_value=0)
        assert await is_token_revoked("valid-jti") is False


class TestRevokeAllUserTokens:
    @pytest.mark.asyncio
    async def test_revokes_all_and_clears_set(self, mock_redis):
        from app.core.security.token_blacklist import revoke_all_user_tokens

        redis = mock_redis["redis"]
        pipe = mock_redis["pipe"]

        redis.smembers = AsyncMock(return_value={b"jti-1", b"jti-2"})
        redis.delete = AsyncMock()

        await revoke_all_user_tokens(42)

        redis.smembers.assert_called_once_with("user_tokens:42")
        assert pipe.setex.call_count == 2
        pipe.execute.assert_called_once()
        redis.delete.assert_called_once_with("user_tokens:42")

    @pytest.mark.asyncio
    async def test_no_tokens_registered(self, mock_redis):
        from app.core.security.token_blacklist import revoke_all_user_tokens

        redis = mock_redis["redis"]
        redis.smembers = AsyncMock(return_value=set())
        redis.delete = AsyncMock()

        await revoke_all_user_tokens(42)

        redis.delete.assert_called_once_with("user_tokens:42")


class TestRegisterUserToken:
    @pytest.mark.asyncio
    async def test_adds_to_set_and_sets_expiry(self, mock_redis):
        from app.core.security.token_blacklist import register_user_token

        redis = mock_redis["redis"]
        redis.sadd = AsyncMock()
        redis.expire = AsyncMock()

        await register_user_token(42, "new-jti")

        redis.sadd.assert_called_once_with("user_tokens:42", "new-jti")
        redis.expire.assert_called_once()
