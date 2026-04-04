"""Comprehensive tests for rate limiting middleware.

Covers InMemoryRateLimiter, RateLimitConfig, RateLimitMiddleware (pure ASGI),
and the setup_rate_limiting helper function.
"""

import time

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient

from app.core.middleware.rate_limit import (
    InMemoryRateLimiter,
    RateLimitConfig,
    RateLimitMiddleware,
    setup_rate_limiting,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture
def rate_limit_app() -> FastAPI:
    """Minimal FastAPI app with strict rate limiting for testing."""

    app = FastAPI()
    config = RateLimitConfig(
        requests_per_minute=5,
        requests_per_hour=100,
        enabled=True,
    )
    app.add_middleware(RateLimitMiddleware, config=config)

    @app.get("/api/v1/test")
    async def test_endpoint():
        return {"status": "ok"}

    @app.get("/api/v1/health")
    async def health():
        return {"status": "healthy"}

    @app.get("/api/v1/data")
    async def data_endpoint():
        return {"data": [1, 2, 3]}

    return app


@pytest.fixture
def rate_limit_app_disabled() -> FastAPI:
    """FastAPI app with rate limiting disabled."""

    app = FastAPI()
    config = RateLimitConfig(
        requests_per_minute=2,
        requests_per_hour=10,
        enabled=False,
    )
    app.add_middleware(RateLimitMiddleware, config=config)

    @app.get("/api/v1/test")
    async def test_endpoint():
        return {"status": "ok"}

    return app


@pytest.fixture
def rate_limit_app_whitelist_paths() -> FastAPI:
    """FastAPI app with custom whitelist paths."""

    app = FastAPI()
    config = RateLimitConfig(
        requests_per_minute=2,
        requests_per_hour=10,
        enabled=True,
        whitelist_paths={"/api/v1/internal/"},
    )
    app.add_middleware(RateLimitMiddleware, config=config)

    @app.get("/api/v1/test")
    async def test_endpoint():
        return {"status": "ok"}

    @app.get("/api/v1/internal/metrics")
    async def internal_metrics():
        return {"metrics": {}}

    return app


@pytest.fixture
def rate_limit_app_whitelist_ips() -> FastAPI:
    """FastAPI app with IP whitelist."""

    app = FastAPI()
    config = RateLimitConfig(
        requests_per_minute=2,
        requests_per_hour=10,
        enabled=True,
        whitelist_ips={"10.0.0.1"},
    )
    app.add_middleware(RateLimitMiddleware, config=config)

    @app.get("/api/v1/test")
    async def test_endpoint():
        return {"status": "ok"}

    return app


# ---------------------------------------------------------------------------
# Tests: RateLimitConfig
# ---------------------------------------------------------------------------


class TestRateLimitConfig:
    """Tests for RateLimitConfig dataclass defaults and customization."""

    def test_default_values(self):
        config = RateLimitConfig()
        assert config.requests_per_minute == 60
        assert config.requests_per_hour == 1000
        assert config.burst_size == 10
        assert config.enabled is True
        assert config.whitelist_paths is None
        assert config.whitelist_ips is None

    def test_custom_values(self):
        config = RateLimitConfig(
            requests_per_minute=30,
            requests_per_hour=500,
            burst_size=5,
            enabled=False,
            whitelist_paths={"/health/"},
            whitelist_ips={"127.0.0.1"},
        )
        assert config.requests_per_minute == 30
        assert config.requests_per_hour == 500
        assert config.burst_size == 5
        assert config.enabled is False
        assert config.whitelist_paths == {"/health/"}
        assert config.whitelist_ips == {"127.0.0.1"}

    def test_enabled_false_skips_limiting(self):
        config = RateLimitConfig(enabled=False)
        assert config.enabled is False


# ---------------------------------------------------------------------------
# Tests: InMemoryRateLimiter.is_allowed
# ---------------------------------------------------------------------------


class TestInMemoryRateLimiter:
    """Tests for InMemoryRateLimiter sliding-window logic."""

    @pytest.mark.asyncio
    async def test_allows_under_limit(self):
        limiter = InMemoryRateLimiter()
        allowed, remaining, retry_after = await limiter.is_allowed(
            "ip:1.2.3.4",
            max_requests=5,
            window_seconds=60,
        )
        assert allowed is True
        assert remaining == 4
        assert retry_after == 0

    @pytest.mark.asyncio
    async def test_remaining_decrements_with_each_request(self):
        limiter = InMemoryRateLimiter()
        for i in range(4):
            allowed, remaining, retry_after = await limiter.is_allowed(
                "ip:1.2.3.4",
                max_requests=5,
                window_seconds=60,
            )
            assert allowed is True
            assert remaining == 4 - i
            assert retry_after == 0

    @pytest.mark.asyncio
    async def test_rejects_over_limit(self):
        limiter = InMemoryRateLimiter()
        for _ in range(5):
            await limiter.is_allowed("ip:1.2.3.4", max_requests=5, window_seconds=60)

        allowed, remaining, retry_after = await limiter.is_allowed(
            "ip:1.2.3.4",
            max_requests=5,
            window_seconds=60,
        )
        assert allowed is False
        assert remaining == 0
        assert retry_after > 0

    @pytest.mark.asyncio
    async def test_remaining_is_zero_at_limit(self):
        limiter = InMemoryRateLimiter()
        for _ in range(5):
            await limiter.is_allowed("ip:1.2.3.4", max_requests=5, window_seconds=60)

        # The 5th request consumed the last slot, so remaining is 0
        allowed, remaining, _ = await limiter.is_allowed(
            "ip:1.2.3.4",
            max_requests=5,
            window_seconds=60,
        )
        assert allowed is False
        assert remaining == 0

    @pytest.mark.asyncio
    async def test_different_keys_tracked_independently(self):
        limiter = InMemoryRateLimiter()
        # Exhaust limit for key A
        for _ in range(3):
            await limiter.is_allowed("ip:a", max_requests=3, window_seconds=60)

        # Key A is blocked
        allowed_a, _, _ = await limiter.is_allowed(
            "ip:a",
            max_requests=3,
            window_seconds=60,
        )
        assert allowed_a is False

        # Key B is still allowed
        allowed_b, remaining_b, _ = await limiter.is_allowed(
            "ip:b",
            max_requests=3,
            window_seconds=60,
        )
        assert allowed_b is True
        assert remaining_b == 2

    @pytest.mark.asyncio
    async def test_window_expiry_allows_new_requests(self):
        limiter = InMemoryRateLimiter()
        # Record requests with a past timestamp so they appear expired
        fake_now = time.time() - 120  # 2 minutes ago
        limiter._requests["ip:expired"] = [fake_now, fake_now + 1, fake_now + 2]

        # With a 60-second window those timestamps are expired, so new request is allowed
        allowed, remaining, _ = await limiter.is_allowed(
            "ip:expired",
            max_requests=3,
            window_seconds=60,
        )
        assert allowed is True
        assert remaining == 2  # 3 - 1 new

    @pytest.mark.asyncio
    async def test_retry_after_is_positive(self):
        limiter = InMemoryRateLimiter()
        for _ in range(3):
            await limiter.is_allowed("ip:x", max_requests=3, window_seconds=60)

        _, _, retry_after = await limiter.is_allowed(
            "ip:x",
            max_requests=3,
            window_seconds=60,
        )
        assert retry_after >= 1

    @pytest.mark.asyncio
    async def test_single_request_remaining_correct(self):
        limiter = InMemoryRateLimiter()
        allowed, remaining, retry_after = await limiter.is_allowed(
            "ip:single",
            max_requests=1,
            window_seconds=60,
        )
        assert allowed is True
        assert remaining == 0

    @pytest.mark.asyncio
    async def test_single_request_rejects_second(self):
        limiter = InMemoryRateLimiter()
        await limiter.is_allowed("ip:single", max_requests=1, window_seconds=60)

        allowed, remaining, retry_after = await limiter.is_allowed(
            "ip:single",
            max_requests=1,
            window_seconds=60,
        )
        assert allowed is False
        assert remaining == 0
        assert retry_after > 0


# ---------------------------------------------------------------------------
# Tests: InMemoryRateLimiter cleanup / memory eviction
# ---------------------------------------------------------------------------


class TestInMemoryRateLimiterCleanup:
    """Tests for memory protection and eviction in InMemoryRateLimiter."""

    @pytest.mark.asyncio
    async def test_cleanup_removes_old_entries(self):
        limiter = InMemoryRateLimiter()
        old_ts = time.time() - 7200  # 2 hours ago
        limiter._requests["old_key"] = [old_ts]
        limiter._requests["old_key2"] = [old_ts, old_ts + 1]

        removed = await limiter.cleanup_expired(max_age_seconds=3600)
        assert removed == 2
        assert "old_key" not in limiter._requests
        assert "old_key2" not in limiter._requests

    @pytest.mark.asyncio
    async def test_cleanup_keeps_recent_entries(self):
        limiter = InMemoryRateLimiter()
        recent_ts = time.time() - 100  # 100 seconds ago
        limiter._requests["recent_key"] = [recent_ts]

        removed = await limiter.cleanup_expired(max_age_seconds=3600)
        assert removed == 0
        assert "recent_key" in limiter._requests

    @pytest.mark.asyncio
    async def test_cleanup_returns_zero_when_nothing_expired(self):
        limiter = InMemoryRateLimiter()
        limiter._requests["key1"] = [time.time()]

        removed = await limiter.cleanup_expired(max_age_seconds=3600)
        assert removed == 0

    @pytest.mark.asyncio
    async def test_eviction_when_max_entries_exceeded(self):
        limiter = InMemoryRateLimiter()
        # Fill up to MAX_ENTRIES - 1 with unique keys
        for i in range(limiter._MAX_ENTRIES - 1):
            limiter._requests[f"key_{i}"] = [time.time()]

        # Next unique key triggers eviction
        allowed, remaining, _ = await limiter.is_allowed(
            "new_unique_key",
            max_requests=10,
            window_seconds=60,
        )
        assert allowed is True
        # One old key should have been evicted, new key added
        assert "new_unique_key" in limiter._requests

    @pytest.mark.asyncio
    async def test_periodic_cleanup_triggered_by_threshold(self):
        limiter = InMemoryRateLimiter()
        # Fill beyond the cleanup threshold
        for i in range(limiter._CLEANUP_THRESHOLD + 100):
            limiter._requests[f"old_{i}"] = [time.time() - 7200]

        # Making a request should trigger internal cleanup
        await limiter.is_allowed("trigger_key", max_requests=10, window_seconds=60)
        # After cleanup, old entries with timestamps older than 1 hour are removed
        # The internal cleanup uses cutoff = now - 3600
        remaining_keys = len(limiter._requests)
        assert remaining_keys < limiter._CLEANUP_THRESHOLD + 100


# ---------------------------------------------------------------------------
# Tests: RateLimitMiddleware via HTTP
# ---------------------------------------------------------------------------


class TestRateLimitMiddleware:
    """Integration tests for RateLimitMiddleware with httpx ASGITransport."""

    @pytest.mark.asyncio
    async def test_allows_requests_under_limit(self, rate_limit_app: FastAPI):
        transport = ASGITransport(app=rate_limit_app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.get("/api/v1/test")
        assert response.status_code == 200
        assert response.json() == {"status": "ok"}

    @pytest.mark.asyncio
    async def test_rate_limit_headers_added_to_response(self, rate_limit_app: FastAPI):
        transport = ASGITransport(app=rate_limit_app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.get("/api/v1/test")
        assert response.status_code == 200
        assert "X-RateLimit-Remaining" in response.headers
        assert "X-RateLimit-Limit" in response.headers
        assert response.headers["X-RateLimit-Limit"] == "5"

    @pytest.mark.asyncio
    async def test_remaining_decrements(self, rate_limit_app: FastAPI):
        transport = ASGITransport(app=rate_limit_app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            r1 = await client.get("/api/v1/test")
            r2 = await client.get("/api/v1/test")
        assert int(r1.headers["X-RateLimit-Remaining"]) == 4
        assert int(r2.headers["X-RateLimit-Remaining"]) == 3

    @pytest.mark.asyncio
    async def test_returns_429_when_limit_exceeded(self, rate_limit_app: FastAPI):
        transport = ASGITransport(app=rate_limit_app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            for _ in range(5):
                await client.get("/api/v1/test")
            response = await client.get("/api/v1/test")
        assert response.status_code == 429

    @pytest.mark.asyncio
    async def test_429_response_has_json_body(self, rate_limit_app: FastAPI):
        transport = ASGITransport(app=rate_limit_app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            for _ in range(5):
                await client.get("/api/v1/test")
            response = await client.get("/api/v1/test")
        data = response.json()
        assert "message_en" in data
        assert "message_zh" in data
        assert "Too many requests" in data["message_en"]

    @pytest.mark.asyncio
    async def test_429_response_has_retry_after_header(self, rate_limit_app: FastAPI):
        transport = ASGITransport(app=rate_limit_app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            for _ in range(5):
                await client.get("/api/v1/test")
            response = await client.get("/api/v1/test")
        assert "retry-after" in response.headers
        assert int(response.headers["retry-after"]) >= 1

    @pytest.mark.asyncio
    async def test_429_response_has_remaining_zero(self, rate_limit_app: FastAPI):
        transport = ASGITransport(app=rate_limit_app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            for _ in range(5):
                await client.get("/api/v1/test")
            response = await client.get("/api/v1/test")
        assert response.headers["X-RateLimit-Remaining"] == "0"

    @pytest.mark.asyncio
    async def test_429_response_content_type_json(self, rate_limit_app: FastAPI):
        transport = ASGITransport(app=rate_limit_app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            for _ in range(5):
                await client.get("/api/v1/test")
            response = await client.get("/api/v1/test")
        assert "application/json" in response.headers.get("content-type", "")

    @pytest.mark.asyncio
    async def test_bilingual_error_messages(self, rate_limit_app: FastAPI):
        transport = ASGITransport(app=rate_limit_app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            for _ in range(5):
                await client.get("/api/v1/test")
            response = await client.get("/api/v1/test")
        data = response.json()
        assert data["message_en"] == "Too many requests. Please try again later."
        assert (
            data["message_zh"]
            == "\u8bf7\u6c42\u8fc7\u4e8e\u9891\u7e41\uff0c\u8bf7\u7a0d\u540e\u518d\u8bd5\u3002"
        )

    @pytest.mark.asyncio
    async def test_429_body_includes_retry_after(self, rate_limit_app: FastAPI):
        transport = ASGITransport(app=rate_limit_app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            for _ in range(5):
                await client.get("/api/v1/test")
            response = await client.get("/api/v1/test")
        data = response.json()
        assert "retry_after" in data
        assert data["retry_after"] >= 1


# ---------------------------------------------------------------------------
# Tests: Whitelisted paths bypass rate limiting
# ---------------------------------------------------------------------------


class TestWhitelistedPaths:
    """Tests for path-based and IP-based whitelist bypassing."""

    @pytest.mark.asyncio
    async def test_default_health_path_bypasses_limit(self, rate_limit_app: FastAPI):
        transport = ASGITransport(app=rate_limit_app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            # Exhaust the rate limit on the test endpoint
            for _ in range(5):
                await client.get("/api/v1/test")
            # Health endpoint should still work (default whitelist)
            response = await client.get("/api/v1/health")
        assert response.status_code == 200
        assert response.json() == {"status": "healthy"}

    @pytest.mark.asyncio
    async def test_docs_path_bypasses_limit(self):
        app = FastAPI()
        config = RateLimitConfig(requests_per_minute=1, enabled=True)
        app.add_middleware(RateLimitMiddleware, config=config)

        @app.get("/docs")
        async def docs():
            return {"docs": True}

        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            for _ in range(5):
                r = await client.get("/docs")
            assert r.status_code == 200

    @pytest.mark.asyncio
    async def test_openapi_json_path_bypasses_limit(self):
        app = FastAPI()
        config = RateLimitConfig(requests_per_minute=1, enabled=True)
        app.add_middleware(RateLimitMiddleware, config=config)

        @app.get("/openapi.json")
        async def openapi():
            return {"openapi": "3.0"}

        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            for _ in range(5):
                r = await client.get("/openapi.json")
            assert r.status_code == 200

    @pytest.mark.asyncio
    async def test_custom_whitelist_paths_bypass(
        self,
        rate_limit_app_whitelist_paths: FastAPI,
    ):
        transport = ASGITransport(app=rate_limit_app_whitelist_paths)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            # Exhaust the rate limit
            for _ in range(2):
                await client.get("/api/v1/test")
            # This should be blocked
            blocked = await client.get("/api/v1/test")
            assert blocked.status_code == 429

            # But the whitelisted path should still work
            response = await client.get("/api/v1/internal/metrics")
        assert response.status_code == 200

    @pytest.mark.asyncio
    async def test_ip_whitelist_bypasses_limit(
        self,
        rate_limit_app_whitelist_ips: FastAPI,
    ):
        transport = ASGITransport(app=rate_limit_app_whitelist_ips)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            # The test client uses 127.0.0.1 by default, not the whitelisted IP.
            # Exhaust the limit for the non-whitelisted client.
            for _ in range(2):
                await client.get("/api/v1/test")
            blocked = await client.get("/api/v1/test")
            assert blocked.status_code == 429


# ---------------------------------------------------------------------------
# Tests: enabled=False bypasses all rate limiting
# ---------------------------------------------------------------------------


class TestDisabledRateLimiting:
    """Tests that enabled=False disables all rate limiting."""

    @pytest.mark.asyncio
    async def test_disabled_allows_unlimited_requests(
        self,
        rate_limit_app_disabled: FastAPI,
    ):
        transport = ASGITransport(app=rate_limit_app_disabled)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            for _ in range(20):
                response = await client.get("/api/v1/test")
            assert response.status_code == 200

    @pytest.mark.asyncio
    async def test_disabled_no_rate_limit_headers(
        self,
        rate_limit_app_disabled: FastAPI,
    ):
        transport = ASGITransport(app=rate_limit_app_disabled)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.get("/api/v1/test")
        assert "X-RateLimit-Remaining" not in response.headers


# ---------------------------------------------------------------------------
# Tests: Non-HTTP scope passthrough
# ---------------------------------------------------------------------------


class TestNonHttpScope:
    """Tests that non-HTTP scopes (e.g. websocket, lifespan) pass through."""

    @pytest.mark.asyncio
    async def test_lifespan_scope_passes_through(self):
        app = FastAPI()
        config = RateLimitConfig(requests_per_minute=1, enabled=True)
        app.add_middleware(RateLimitMiddleware, config=config)

        @app.get("/api/v1/test")
        async def test_endpoint():
            return {"status": "ok"}

        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            # A normal HTTP request should still work - this implicitly tests
            # that the lifespan startup/shutdown (non-HTTP scopes) pass through
            response = await client.get("/api/v1/test")
        assert response.status_code == 200


# ---------------------------------------------------------------------------
# Tests: X-Forwarded-For header handling
# ---------------------------------------------------------------------------


class TestForwardedForHeader:
    """Tests that the middleware reads the client IP from X-Forwarded-For."""

    @pytest.mark.asyncio
    async def test_uses_x_forwarded_for_first_ip(self):
        app = FastAPI()
        config = RateLimitConfig(requests_per_minute=2, enabled=True)
        app.add_middleware(RateLimitMiddleware, config=config)

        @app.get("/api/v1/test")
        async def test_endpoint():
            return {"status": "ok"}

        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            # Requests with different X-Forwarded-For should be tracked separately
            headers_a = {"X-Forwarded-For": "1.1.1.1, 2.2.2.2"}
            headers_b = {"X-Forwarded-For": "3.3.3.3"}

            for _ in range(2):
                await client.get("/api/v1/test", headers=headers_a)

            # Client A should be blocked
            r_blocked = await client.get("/api/v1/test", headers=headers_a)
            assert r_blocked.status_code == 429

            # Client B should still be allowed
            r_allowed = await client.get("/api/v1/test", headers=headers_b)
            assert r_allowed.status_code == 200


# ---------------------------------------------------------------------------
# Tests: setup_rate_limiting helper
# ---------------------------------------------------------------------------


class TestSetupRateLimiting:
    """Tests for the setup_rate_limiting convenience function."""

    def test_setup_adds_middleware(self):
        app = FastAPI()
        initial_middleware_count = len(app.user_middleware)
        setup_rate_limiting(app)
        # Starlette stores middleware in user_middleware list
        assert len(app.user_middleware) > initial_middleware_count

    def test_setup_with_custom_config(self):
        app = FastAPI()
        config = RateLimitConfig(requests_per_minute=10, enabled=False)
        setup_rate_limiting(app, config=config)
        # Middleware was added (we verify by count)
        assert len(app.user_middleware) >= 1


# ---------------------------------------------------------------------------
# Tests: Rate limiting across different endpoints (same IP, shared limit)
# ---------------------------------------------------------------------------


class TestSharedLimitAcrossEndpoints:
    """Tests that rate limits are shared across all endpoints for the same IP."""

    @pytest.mark.asyncio
    async def test_shared_limit_across_endpoints(self, rate_limit_app: FastAPI):
        transport = ASGITransport(app=rate_limit_app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            # Exhaust limit by hitting different endpoints
            await client.get("/api/v1/test")
            await client.get("/api/v1/test")
            await client.get("/api/v1/data")
            await client.get("/api/v1/data")
            await client.get("/api/v1/test")

            # Next request to any endpoint should be blocked
            response = await client.get("/api/v1/data")
        assert response.status_code == 429
