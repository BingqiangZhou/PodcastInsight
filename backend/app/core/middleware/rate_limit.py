"""Rate Limiting Middleware.

Provides request rate limiting based on IP address or user ID.
Uses Redis for distributed rate limiting across multiple instances.
"""

import asyncio
import logging
import time
from collections.abc import Callable
from dataclasses import dataclass
from typing import Any

from starlette.requests import Request
from starlette.responses import JSONResponse
from starlette.types import ASGIApp, Message, Receive, Scope, Send

from app.core.config import settings

logger = logging.getLogger(__name__)

# Lua script for atomic rate limit check and increment
# Returns: [current_count, ttl] or [-1, retry_after] if limit exceeded
RATE_LIMIT_SCRIPT = """
local key = KEYS[1]
local limit = tonumber(ARGV[1])
local window = tonumber(ARGV[2])
local current = tonumber(redis.call('GET', key)) or 0

if current >= limit then
    local ttl = redis.call('TTL', key)
    return {-1, ttl}
end

local new_count = redis.call('INCR', key)
if new_count == 1 then
    redis.call('EXPIRE', key, window)
end

local ttl = redis.call('TTL', key)
return {new_count, ttl}
"""


@dataclass
class RateLimitConfig:
    """Configuration for rate limiting."""

    requests_per_minute: int = 60
    requests_per_hour: int = 1000
    burst_size: int = 10  # Allow short bursts
    enabled: bool = True
    whitelist_paths: set[str] | None = None
    whitelist_ips: set[str] | None = None


class InMemoryRateLimiter:
    """Simple in-memory rate limiter for single-instance deployments.

    Uses sliding window algorithm for accurate rate limiting.
    Includes memory protection with max entries limit.
    """

    # Maximum number of unique keys to track (prevents memory exhaustion)
    _MAX_ENTRIES = 10000
    # Cleanup threshold (trigger cleanup when entries exceed this)
    _CLEANUP_THRESHOLD = 8000

    def __init__(self) -> None:
        self._requests: dict[str, list[float]] = {}
        self._lock = asyncio.Lock()
        self._last_cleanup = time.time()

    async def is_allowed(
        self,
        key: str,
        max_requests: int,
        window_seconds: int,
    ) -> tuple[bool, int, int]:
        """Check if request is allowed.

        Args:
            key: Unique identifier (IP or user ID)
            max_requests: Maximum requests allowed in window
            window_seconds: Time window in seconds

        Returns:
            Tuple of (is_allowed, remaining_requests, retry_after_seconds)
        """
        now = time.time()
        window_start = now - window_seconds

        async with self._lock:
            # Periodic cleanup to prevent memory growth
            if len(self._requests) > self._CLEANUP_THRESHOLD:
                await self._cleanup_locked(now - 3600)  # Clean entries older than 1 hour

            # Get existing requests for this key
            requests = self._requests.get(key, [])

            # Remove expired requests (outside window)
            requests = [ts for ts in requests if ts > window_start]

            # Check if limit exceeded
            if len(requests) >= max_requests:
                oldest = min(requests) if requests else now
                retry_after = int(oldest + window_seconds - now) + 1
                return False, 0, retry_after

            # Check memory limit before adding new key
            if key not in self._requests and len(self._requests) >= self._MAX_ENTRIES:
                # Evict oldest key to make room (LRU-style)
                oldest_key = min(self._requests.keys(), key=lambda k: min(self._requests[k]) if self._requests[k] else now)
                del self._requests[oldest_key]
                logger.warning("Rate limiter reached max entries, evicted oldest key")

            # Record this request
            requests.append(now)
            self._requests[key] = requests

            remaining = max_requests - len(requests)
            return True, remaining, 0

    async def _cleanup_locked(self, cutoff: float) -> int:
        """Internal cleanup method (must be called with lock held)."""
        initial_count = len(self._requests)

        self._requests = {
            key: timestamps
            for key, timestamps in self._requests.items()
            if any(ts > cutoff for ts in timestamps)
        }

        removed = initial_count - len(self._requests)
        if removed > 0:
            logger.debug("Rate limiter cleanup removed %d expired keys", removed)

        self._last_cleanup = time.time()
        return removed

    async def cleanup_expired(self, max_age_seconds: int = 3600) -> int:
        """Remove expired entries to prevent memory growth.

        Returns:
            Number of keys removed
        """
        now = time.time()
        cutoff = now - max_age_seconds

        async with self._lock:
            return await self._cleanup_locked(cutoff)


class RedisRateLimiter:
    """Redis-based rate limiter for distributed deployments.

    Uses Lua script for atomic rate limiting to prevent race conditions.
    Falls back to in-memory rate limiting when Redis is unavailable.
    """

    def __init__(self, redis_client: Any) -> None:
        self._redis = redis_client
        self._script = None
        # Fallback in-memory limiter for degraded mode
        self._fallback_limiter = InMemoryRateLimiter()
        self._consecutive_failures = 0
        self._circuit_open = False
        self._circuit_open_until = 0.0
        # Circuit breaker thresholds
        self._failure_threshold = 5
        self._recovery_timeout = 60.0  # seconds

    async def _ensure_script_loaded(self) -> None:
        """Lazy load and cache the Lua script."""
        if self._script is None:
            self._script = self._redis.register_script(RATE_LIMIT_SCRIPT)

    async def is_allowed(
        self,
        key: str,
        max_requests: int,
        window_seconds: int,
    ) -> tuple[bool, int, int]:
        """Check if request is allowed using atomic Lua script.

        Args:
            key: Unique identifier (IP or user ID)
            max_requests: Maximum requests allowed in window
            window_seconds: Time window in seconds

        Returns:
            Tuple of (is_allowed, remaining_requests, retry_after_seconds)
        """
        redis_key = f"rate_limit:{key}"

        # Check if circuit breaker is open
        now = time.time()
        if self._circuit_open:
            if now < self._circuit_open_until:
                # Circuit is open, use fallback limiter
                logger.debug("Circuit breaker open, using fallback rate limiter")
                return await self._fallback_limiter.is_allowed(
                    key, max_requests, window_seconds
                )
            else:
                # Recovery timeout passed, try to close circuit
                self._circuit_open = False
                self._consecutive_failures = 0
                logger.info("Circuit breaker reset, attempting Redis recovery")

        try:
            await self._ensure_script_loaded()

            # Execute Lua script atomically
            result = await self._script(
                keys=[redis_key],
                args=[max_requests, window_seconds]
            )

            new_count, ttl = result

            # Reset failure counter on success
            self._consecutive_failures = 0

            if new_count == -1:
                # Limit exceeded
                retry_after = max(1, ttl) if ttl > 0 else window_seconds
                return False, 0, retry_after

            remaining = max(0, max_requests - new_count)
            return True, remaining, 0

        except Exception as e:
            self._consecutive_failures += 1
            logger.warning(
                "Redis rate limiter error (failure %d/%d): %s",
                self._consecutive_failures,
                self._failure_threshold,
                e,
            )

            # Check if we should open the circuit breaker
            if self._consecutive_failures >= self._failure_threshold:
                self._circuit_open = True
                self._circuit_open_until = now + self._recovery_timeout
                logger.error(
                    "Circuit breaker opened due to %d consecutive failures. "
                    "Using fallback limiter for %.0f seconds.",
                    self._consecutive_failures,
                    self._recovery_timeout,
                )

            # Use fallback limiter instead of failing open
            return await self._fallback_limiter.is_allowed(
                key, max_requests, window_seconds
            )


class RateLimitMiddleware:
    """Pure ASGI middleware for rate limiting requests.

    Avoids BaseHTTPMiddleware overhead by working directly with ASGI scope/send.
    """

    def __init__(
        self,
        app: ASGIApp,
        config: RateLimitConfig | None = None,
        redis_client: Any = None,
    ) -> None:
        self.app = app
        self.config = config or RateLimitConfig()

        # Use Redis rate limiter if available, otherwise in-memory
        if redis_client:
            self._limiter = RedisRateLimiter(redis_client)
            logger.info("Rate limiting using Redis")
        else:
            self._limiter = InMemoryRateLimiter()
            logger.info("Rate limiting using in-memory storage")

        # Default whitelist paths (health checks, etc.)
        self._default_whitelist = {
            "/api/v1/health",
            "/api/v1/health/ready",
            "/api/v1/health/live",
            "/docs",
            "/redoc",
            "/openapi.json",
        }

    def _get_client_key(self, scope: Scope) -> str:
        """Get unique key for rate limiting from ASGI scope.

        Prioritizes user ID if authenticated, otherwise uses IP address.
        """
        # Try to get user ID from request state (set by auth middleware)
        state = scope.get("state")
        if state is not None:
            user_id = getattr(state, "user_id", None)
            if user_id:
                return f"user:{user_id}"

        # Fall back to IP address
        headers = dict(scope.get("headers", []))
        forwarded = headers.get(b"x-forwarded-for", b"").decode("latin-1")
        if forwarded:
            # Take first IP in chain (original client)
            client_ip = forwarded.split(",")[0].strip()
        else:
            client = scope.get("client")
            client_ip = client[0] if client else "unknown"

        return f"ip:{client_ip}"

    def _is_whitelisted(self, scope: Scope) -> bool:
        """Check if request path is whitelisted."""
        path = scope.get("path", "")

        # Check default whitelist
        if path in self._default_whitelist:
            return True

        # Check configured whitelist
        if self.config.whitelist_paths:
            for whitelist_path in self.config.whitelist_paths:
                if path.startswith(whitelist_path):
                    return True

        # Check IP whitelist
        if self.config.whitelist_ips:
            client = scope.get("client")
            if client and client[0] in self.config.whitelist_ips:
                return True

        return False

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        """Process request with rate limiting (pure ASGI)."""
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        if not self.config.enabled or self._is_whitelisted(scope):
            await self.app(scope, receive, send)
            return

        client_key = self._get_client_key(scope)

        # Check minute rate limit
        allowed, remaining, retry_after = await self._limiter.is_allowed(
            f"{client_key}:minute",
            self.config.requests_per_minute,
            60,
        )

        if not allowed:
            logger.warning(
                "Rate limit exceeded for %s (minute limit)",
                client_key,
            )
            await self._send_rate_limit_response(send, retry_after)
            return

        # Check hour rate limit
        allowed, remaining_hour, retry_after = await self._limiter.is_allowed(
            f"{client_key}:hour",
            self.config.requests_per_hour,
            3600,
        )

        if not allowed:
            logger.warning(
                "Rate limit exceeded for %s (hour limit)",
                client_key,
            )
            await self._send_rate_limit_response(send, retry_after)
            return

        # Wrap send to inject rate limit headers into the response
        headers_added = False

        async def send_with_headers(message: Message) -> None:
            nonlocal headers_added
            if message["type"] == "http.response.start" and not headers_added:
                headers_added = True
                headers = list(message.get("headers", []))
                headers.append(
                    (b"X-RateLimit-Remaining", str(remaining).encode())
                )
                headers.append(
                    (b"X-RateLimit-Limit", str(self.config.requests_per_minute).encode())
                )
                message = {**message, "headers": headers}
            await send(message)

        await self.app(scope, receive, send_with_headers)

    async def _send_rate_limit_response(self, send: Send, retry_after: int) -> None:
        """Send 429 rate limit response directly via ASGI."""
        import orjson

        body = orjson.dumps({
            "message_en": "Too many requests. Please try again later.",
            "message_zh": "请求过于频繁，请稍后再试。",
            "retry_after": retry_after,
        })

        headers = [
            [b"content-type", b"application/json; charset=utf-8"],
            [b"retry-after", str(retry_after).encode()],
            [b"X-RateLimit-Remaining", b"0"],
        ]

        await send({
            "type": "http.response.start",
            "status": 429,
            "headers": headers,
        })
        await send({
            "type": "http.response.body",
            "body": body,
        })


def setup_rate_limiting(
    app: ASGIApp,
    redis_client: Any = None,
    config: RateLimitConfig | None = None,
) -> None:
    """Set up rate limiting middleware for a FastAPI app.

    Args:
        app: FastAPI application
        redis_client: Optional Redis client for distributed rate limiting
        config: Rate limit configuration
    """
    app.add_middleware(RateLimitMiddleware, config=config, redis_client=redis_client)
