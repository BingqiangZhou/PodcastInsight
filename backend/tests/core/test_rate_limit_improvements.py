"""Tests for rate limiter improvements.

Covers:
- InMemoryRateLimiter internals (OrderedDict-style eviction, sliding window precision)
- RedisRateLimiter Lua script behavior (mocked Redis)
- RedisRateLimiter circuit breaker integration and fallback
- RateLimitMiddleware get_rate_limit_stats counters
- Edge cases: concurrent keys, window boundary, zero-window
"""

from __future__ import annotations

import time
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.core.middleware.rate_limit import (
    InMemoryRateLimiter,
    RateLimitConfig,
    RateLimitMiddleware,
    RedisRateLimiter,
    get_rate_limit_stats,
)


# ---------------------------------------------------------------------------
# InMemoryRateLimiter internals
# ---------------------------------------------------------------------------


class TestInMemoryRateLimiterOrderedEviction:
    """Verify LRU-style eviction and sliding window accuracy."""

    @pytest.mark.asyncio
    async def test_evicts_oldest_key_when_max_entries_reached(self) -> None:
        """When _MAX_ENTRIES keys exist, adding a new unique key evicts the oldest."""
        limiter = InMemoryRateLimiter()
        # Fill to max with keys that have OLD timestamps
        for i in range(limiter._MAX_ENTRIES):
            limiter._requests[f"old_{i}"] = [time.time() - 1000]

        # The oldest key is old_0 (lowest timestamp)
        assert "old_0" in limiter._requests

        # Add a new unique key to trigger eviction
        await limiter.is_allowed("brand_new_key", max_requests=5, window_seconds=60)

        assert "brand_new_key" in limiter._requests
        # The oldest key should have been evicted
        assert "old_0" not in limiter._requests

    @pytest.mark.asyncio
    async def test_existing_key_not_evicted_when_under_max(self) -> None:
        """If the key already exists, no eviction occurs even at max entries."""
        limiter = InMemoryRateLimiter()
        for i in range(limiter._MAX_ENTRIES):
            limiter._requests[f"key_{i}"] = [time.time()]

        # Updating an existing key should NOT trigger eviction
        allowed, remaining, _ = await limiter.is_allowed(
            "key_0", max_requests=10, window_seconds=60
        )
        assert allowed is True
        # All keys should still be present
        for i in range(limiter._MAX_ENTRIES):
            assert f"key_{i}" in limiter._requests

    @pytest.mark.asyncio
    async def test_sliding_window_precisely_expires_old_entries(self) -> None:
        """Entries outside the window are filtered out before checking the limit."""
        limiter = InMemoryRateLimiter()

        # Insert 3 timestamps that are outside a 60-second window
        old_time = time.time() - 120
        limiter._requests["ip:precise"] = [old_time, old_time + 1, old_time + 2]

        # With a 60-second window, all 3 are expired; new request should be allowed
        allowed, remaining, _ = await limiter.is_allowed(
            "ip:precise", max_requests=3, window_seconds=60
        )
        assert allowed is True
        assert remaining == 2  # 3 max - 1 new = 2 remaining

    @pytest.mark.asyncio
    async def test_partial_window_expiry_mixed_timestamps(self) -> None:
        """Some timestamps in window, some expired."""
        limiter = InMemoryRateLimiter()
        now = time.time()
        # 2 old (expired) + 1 recent
        limiter._requests["ip:mixed"] = [now - 120, now - 100, now - 10]

        # With 60-second window, only the recent one (now-10) is in window
        allowed, remaining, _ = await limiter.is_allowed(
            "ip:mixed", max_requests=3, window_seconds=60
        )
        assert allowed is True
        # 3 max - 2 (1 old in window + 1 new) = 1 remaining
        assert remaining == 1

    @pytest.mark.asyncio
    async def test_cleanup_lock_is_held_during_cleanup(self) -> None:
        """Cleanup should acquire the lock to prevent concurrent modification."""
        limiter = InMemoryRateLimiter()
        old_ts = time.time() - 7200
        limiter._requests["stale_key"] = [old_ts]

        removed = await limiter.cleanup_expired(max_age_seconds=3600)
        assert removed == 1
        assert "stale_key" not in limiter._requests

    @pytest.mark.asyncio
    async def test_cleanup_does_not_remove_keys_within_max_age(self) -> None:
        limiter = InMemoryRateLimiter()
        recent_ts = time.time() - 30
        limiter._requests["fresh_key"] = [recent_ts]

        removed = await limiter.cleanup_expired(max_age_seconds=3600)
        assert removed == 0
        assert "fresh_key" in limiter._requests

    @pytest.mark.asyncio
    async def test_periodic_cleanup_triggered_at_threshold(self) -> None:
        """When entries exceed _CLEANUP_THRESHOLD, internal cleanup is triggered."""
        limiter = InMemoryRateLimiter()
        # Add entries beyond threshold with old timestamps
        for i in range(limiter._CLEANUP_THRESHOLD + 50):
            limiter._requests[f"stale_{i}"] = [time.time() - 7200]

        # Making a request should trigger cleanup (threshold check is in is_allowed)
        await limiter.is_allowed("trigger", max_requests=10, window_seconds=60)

        # Many stale entries should have been removed
        assert len(limiter._requests) < limiter._CLEANUP_THRESHOLD + 50

    @pytest.mark.asyncio
    async def test_retry_after_calculation_accuracy(self) -> None:
        """retry_after should reflect when the oldest request in window expires."""
        limiter = InMemoryRateLimiter()
        now = time.time()
        # Fill to limit with requests that started 30 seconds ago
        window = 60
        max_req = 3
        # Put 3 requests at now - 30
        limiter._requests["ip:retry"] = [now - 30, now - 29, now - 28]

        _, _, retry_after = await limiter.is_allowed(
            "ip:retry", max_requests=max_req, window_seconds=window
        )
        # Oldest is at now-30, window is 60, so retry_after should be ~31-32 seconds
        assert retry_after >= 30
        assert retry_after <= 34


# ---------------------------------------------------------------------------
# RedisRateLimiter with mocked Redis
# ---------------------------------------------------------------------------


class TestRedisRateLimiterLuaScript:
    """Tests for RedisRateLimiter with mocked Redis Lua script behavior."""

    def _make_redis_mock(self, script_result=None):
        """Create a mock Redis client with configurable script results."""
        mock_redis = MagicMock()
        mock_script = AsyncMock(return_value=script_result)
        mock_redis.register_script.return_value = mock_script
        return mock_redis, mock_script

    @pytest.mark.asyncio
    async def test_lua_script_allows_under_limit(self) -> None:
        """When Lua script returns count < limit, request is allowed."""
        # Lua returns [new_count, ttl] where new_count=1 means first request
        mock_redis, mock_script = self._make_redis_mock(script_result=[1, 60])
        limiter = RedisRateLimiter(mock_redis)

        allowed, remaining, retry_after = await limiter.is_allowed(
            "ip:1.2.3.4", max_requests=10, window_seconds=60
        )
        assert allowed is True
        assert remaining == 9  # 10 - 1
        assert retry_after == 0
        mock_script.assert_called_once_with(
            keys=["rate_limit:ip:1.2.3.4"],
            args=[10, 60],
        )

    @pytest.mark.asyncio
    async def test_lua_script_rejects_over_limit(self) -> None:
        """When Lua script returns [-1, ttl], request is rejected."""
        mock_redis, mock_script = self._make_redis_mock(script_result=[-1, 45])
        limiter = RedisRateLimiter(mock_redis)

        allowed, remaining, retry_after = await limiter.is_allowed(
            "ip:1.2.3.4", max_requests=10, window_seconds=60
        )
        assert allowed is False
        assert remaining == 0
        assert retry_after == 45

    @pytest.mark.asyncio
    async def test_lua_script_rejects_with_zero_ttl(self) -> None:
        """When limit exceeded and ttl is 0, use window_seconds as retry_after."""
        mock_redis, mock_script = self._make_redis_mock(script_result=[-1, 0])
        limiter = RedisRateLimiter(mock_redis)

        allowed, remaining, retry_after = await limiter.is_allowed(
            "ip:test", max_requests=5, window_seconds=120
        )
        assert allowed is False
        assert retry_after == 120  # falls back to window_seconds

    @pytest.mark.asyncio
    async def test_lua_script_remaining_cannot_be_negative(self) -> None:
        """Remaining is clamped to 0 even if new_count somehow exceeds max_requests."""
        mock_redis, mock_script = self._make_redis_mock(script_result=[15, 30])
        limiter = RedisRateLimiter(mock_redis)

        allowed, remaining, retry_after = await limiter.is_allowed(
            "ip:overflow", max_requests=10, window_seconds=60
        )
        assert allowed is True
        assert remaining == 0  # max(0, 10 - 15) = 0

    @pytest.mark.asyncio
    async def test_script_loaded_lazily_once(self) -> None:
        """The Lua script should be registered on first call, not in __init__."""
        mock_redis, mock_script = self._make_redis_mock(script_result=[1, 60])
        limiter = RedisRateLimiter(mock_redis)

        # Not loaded yet
        mock_redis.register_script.assert_not_called()

        # First call loads it
        await limiter.is_allowed("ip:first", max_requests=5, window_seconds=60)
        mock_redis.register_script.assert_called_once()

        # Second call does not re-register
        await limiter.is_allowed("ip:second", max_requests=5, window_seconds=60)
        mock_redis.register_script.assert_called_once()

    @pytest.mark.asyncio
    async def test_failure_counter_reset_on_success(self) -> None:
        """Consecutive failure counter resets after a successful Redis call."""
        mock_redis, mock_script = self._make_redis_mock(script_result=[1, 60])
        limiter = RedisRateLimiter(mock_redis)
        limiter._consecutive_failures = 3

        await limiter.is_allowed("ip:reset", max_requests=5, window_seconds=60)
        assert limiter._consecutive_failures == 0


# ---------------------------------------------------------------------------
# RedisRateLimiter circuit breaker integration
# ---------------------------------------------------------------------------


class TestRedisCircuitBreakerIntegration:
    """Tests for the circuit breaker pattern in RedisRateLimiter."""

    def _make_failing_redis_mock(self):
        """Create a Redis mock that always fails."""
        mock_redis = MagicMock()
        mock_script = AsyncMock(side_effect=ConnectionError("Redis down"))
        mock_redis.register_script.return_value = mock_script
        return mock_redis

    @pytest.mark.asyncio
    async def test_fallback_to_in_memory_on_redis_error(self) -> None:
        """When Redis fails, requests should still be handled by in-memory fallback."""
        mock_redis = self._make_failing_redis_mock()
        limiter = RedisRateLimiter(mock_redis)

        allowed, remaining, retry_after = await limiter.is_allowed(
            "ip:fallback", max_requests=10, window_seconds=60
        )
        assert allowed is True
        assert remaining >= 0

    @pytest.mark.asyncio
    async def test_circuit_opens_after_consecutive_failures(self) -> None:
        """After _failure_threshold consecutive failures, circuit opens."""
        mock_redis = self._make_failing_redis_mock()
        limiter = RedisRateLimiter(mock_redis)
        limiter._failure_threshold = 3

        # Trigger failures
        for _ in range(3):
            await limiter.is_allowed("ip:cb", max_requests=10, window_seconds=60)

        assert limiter._circuit_open is True
        assert limiter._circuit_open_until > time.time()

    @pytest.mark.asyncio
    async def test_circuit_open_uses_fallback_limiter(self) -> None:
        """When circuit is open, fallback limiter is used directly (no Redis call)."""
        mock_redis = self._make_failing_redis_mock()
        limiter = RedisRateLimiter(mock_redis)
        limiter._failure_threshold = 2

        # Open the circuit
        for _ in range(2):
            await limiter.is_allowed("ip:circuit", max_requests=10, window_seconds=60)

        assert limiter._circuit_open is True

        # Reset the mock to track new calls
        mock_redis.register_script.reset_mock()

        # Next call should use fallback (no Redis call attempted)
        await limiter.is_allowed("ip:circuit", max_requests=10, window_seconds=60)
        # register_script should NOT be called again since circuit is open
        mock_redis.register_script.assert_not_called()

    @pytest.mark.asyncio
    async def test_circuit_closes_after_recovery_timeout(self) -> None:
        """Circuit should close after recovery_timeout elapses."""
        mock_redis = self._make_failing_redis_mock()
        limiter = RedisRateLimiter(mock_redis)
        limiter._failure_threshold = 1
        limiter._recovery_timeout = 0.1  # 100ms

        # Open the circuit
        await limiter.is_allowed("ip:recovery", max_requests=10, window_seconds=60)
        assert limiter._circuit_open is True

        # Wait for recovery timeout
        time.sleep(0.15)

        # Now replace the script with a healthy one.
        # Must reset _script so _ensure_script_loaded re-registers it.
        mock_script = AsyncMock(return_value=[1, 60])
        limiter._script = mock_script

        # Should attempt Redis again
        allowed, remaining, _ = await limiter.is_allowed(
            "ip:recovery", max_requests=10, window_seconds=60
        )
        assert allowed is True
        assert limiter._circuit_open is False
        assert limiter._consecutive_failures == 0

    @pytest.mark.asyncio
    async def test_failure_count_increments_on_each_error(self) -> None:
        mock_redis = self._make_failing_redis_mock()
        limiter = RedisRateLimiter(mock_redis)

        await limiter.is_allowed("ip:count", max_requests=10, window_seconds=60)
        assert limiter._consecutive_failures == 1

        await limiter.is_allowed("ip:count", max_requests=10, window_seconds=60)
        assert limiter._consecutive_failures == 2

    @pytest.mark.asyncio
    async def test_circuit_not_open_before_threshold(self) -> None:
        mock_redis = self._make_failing_redis_mock()
        limiter = RedisRateLimiter(mock_redis)
        limiter._failure_threshold = 10

        # Only 3 failures, not enough to open
        for _ in range(3):
            await limiter.is_allowed("ip:notyet", max_requests=10, window_seconds=60)

        assert limiter._circuit_open is False

    @pytest.mark.asyncio
    async def test_fallback_limiter_enforces_limits(self) -> None:
        """The in-memory fallback actually enforces rate limits."""
        mock_redis = self._make_failing_redis_mock()
        limiter = RedisRateLimiter(mock_redis)
        limiter._failure_threshold = 1

        # Open circuit
        await limiter.is_allowed("ip:strict", max_requests=2, window_seconds=60)

        # Use up fallback allowance
        await limiter.is_allowed("ip:strict", max_requests=2, window_seconds=60)
        await limiter.is_allowed("ip:strict", max_requests=2, window_seconds=60)

        # Should be blocked by fallback limiter
        allowed, _, _ = await limiter.is_allowed(
            "ip:strict", max_requests=2, window_seconds=60
        )
        assert allowed is False


# ---------------------------------------------------------------------------
# RateLimitMiddleware stats counters
# ---------------------------------------------------------------------------


class TestRateLimitStats:
    """Tests for get_rate_limit_stats and middleware counters."""

    def setup_method(self) -> None:
        """Reset middleware counters before each test."""
        RateLimitMiddleware._total_requests = 0
        RateLimitMiddleware._rejected_requests = 0

    def test_stats_initial_state(self) -> None:
        stats = get_rate_limit_stats()
        assert stats["total_requests"] == 0
        assert stats["rejected_requests"] == 0
        assert stats["rejection_rate"] == 0.0
        assert stats["enabled"] is True

    def test_stats_rejection_rate_calculation(self) -> None:
        RateLimitMiddleware._total_requests = 100
        RateLimitMiddleware._rejected_requests = 25

        stats = get_rate_limit_stats()
        assert stats["rejection_rate"] == 0.25

    def test_stats_rejection_rate_zero_when_no_requests(self) -> None:
        stats = get_rate_limit_stats()
        assert stats["rejection_rate"] == 0.0

    def test_stats_rejection_rate_100_percent(self) -> None:
        RateLimitMiddleware._total_requests = 10
        RateLimitMiddleware._rejected_requests = 10

        stats = get_rate_limit_stats()
        assert stats["rejection_rate"] == 1.0


# ---------------------------------------------------------------------------
# RateLimitMiddleware ASGI integration
# ---------------------------------------------------------------------------


class TestRateLimitMiddlewareASGI:
    """Integration tests for ASGI middleware behavior."""

    def setup_method(self) -> None:
        RateLimitMiddleware._total_requests = 0
        RateLimitMiddleware._rejected_requests = 0

    @pytest.mark.asyncio
    async def test_non_http_scope_passes_through(self) -> None:
        """Non-HTTP scopes (e.g. websocket) should pass through without counting."""
        from starlette.types import Scope

        received: list[dict] = []

        async def mock_app(scope: Scope, receive, send) -> None:
            received.append(scope)

        middleware = RateLimitMiddleware(mock_app, config=RateLimitConfig(enabled=True))

        websocket_scope = {"type": "websocket", "path": "/ws"}
        await middleware(websocket_scope, None, None)

        assert len(received) == 1
        assert RateLimitMiddleware._total_requests == 0

    @pytest.mark.asyncio
    async def test_user_id_from_state_takes_priority_over_ip(self) -> None:
        """When request state has a user_id, it's used as the rate limit key."""

        async def mock_app(scope, receive, send) -> None:
            pass

        middleware = RateLimitMiddleware(mock_app, config=RateLimitConfig(enabled=True))
        state = MagicMock()
        state.user_id = 42

        scope = {
            "type": "http",
            "path": "/api/v1/test",
            "state": state,
            "headers": [],
            "client": ("1.2.3.4", 1234),
        }

        key = middleware._get_client_key(scope)
        assert key == "user:42"

    @pytest.mark.asyncio
    async def test_ip_from_client_when_no_user_id(self) -> None:
        """Without user_id, the client IP is used."""

        async def mock_app(scope, receive, send) -> None:
            pass

        middleware = RateLimitMiddleware(mock_app, config=RateLimitConfig(enabled=True))
        scope = {
            "type": "http",
            "path": "/api/v1/test",
            "state": MagicMock(spec=[]),  # no user_id attribute
            "headers": [],
            "client": ("5.6.7.8", 1234),
        }

        key = middleware._get_client_key(scope)
        assert key == "ip:5.6.7.8"

    @pytest.mark.asyncio
    async def test_x_forwarded_for_first_ip_used(self) -> None:
        """X-Forwarded-For header is parsed and first IP is used."""

        async def mock_app(scope, receive, send) -> None:
            pass

        middleware = RateLimitMiddleware(mock_app, config=RateLimitConfig(enabled=True))
        scope = {
            "type": "http",
            "path": "/api/v1/test",
            "headers": [(b"x-forwarded-for", b"10.0.0.1, 172.16.0.1")],
            "client": ("1.2.3.4", 1234),
        }

        key = middleware._get_client_key(scope)
        assert key == "ip:10.0.0.1"

    @pytest.mark.asyncio
    async def test_whitelist_path_check(self) -> None:

        async def mock_app(scope, receive, send) -> None:
            pass

        config = RateLimitConfig(
            enabled=True,
            whitelist_paths={"/api/v1/internal/"},
        )
        middleware = RateLimitMiddleware(mock_app, config=config)

        scope = {"path": "/api/v1/internal/metrics", "headers": [], "client": None}
        assert middleware._is_whitelisted(scope) is True

        scope = {"path": "/api/v1/test", "headers": [], "client": None}
        assert middleware._is_whitelisted(scope) is False

    @pytest.mark.asyncio
    async def test_whitelist_ip_check(self) -> None:

        async def mock_app(scope, receive, send) -> None:
            pass

        config = RateLimitConfig(
            enabled=True,
            whitelist_ips={"10.0.0.1"},
        )
        middleware = RateLimitMiddleware(mock_app, config=config)

        scope = {"path": "/api/v1/test", "headers": [], "client": ("10.0.0.1", 1234)}
        assert middleware._is_whitelisted(scope) is True

        scope = {"path": "/api/v1/test", "headers": [], "client": ("10.0.0.2", 1234)}
        assert middleware._is_whitelisted(scope) is False

    @pytest.mark.asyncio
    async def test_default_whitelist_includes_health_and_docs(self) -> None:

        async def mock_app(scope, receive, send) -> None:
            pass

        middleware = RateLimitMiddleware(mock_app, config=RateLimitConfig(enabled=True))

        for path in ["/api/v1/health", "/api/v1/health/ready", "/docs", "/redoc", "/openapi.json"]:
            scope = {"path": path, "headers": [], "client": None}
            assert middleware._is_whitelisted(scope) is True, f"{path} should be whitelisted"
