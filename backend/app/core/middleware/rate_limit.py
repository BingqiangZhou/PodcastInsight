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

from fastapi import FastAPI, Request, Response
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware

from app.core.config import settings

logger = logging.getLogger(__name__)


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
    """

    def __init__(self) -> None:
        self._requests: dict[str, list[float]] = {}
        self._lock = asyncio.Lock()

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
            # Get existing requests for this key
            requests = self._requests.get(key, [])

            # Remove expired requests (outside window)
            requests = [ts for ts in requests if ts > window_start]

            # Check if limit exceeded
            if len(requests) >= max_requests:
                oldest = min(requests) if requests else now
                retry_after = int(oldest + window_seconds - now) + 1
                return False, 0, retry_after

            # Record this request
            requests.append(now)
            self._requests[key] = requests

            remaining = max_requests - len(requests)
            return True, remaining, 0

    async def cleanup_expired(self, max_age_seconds: int = 3600) -> int:
        """Remove expired entries to prevent memory growth.

        Returns:
            Number of keys removed
        """
        now = time.time()
        cutoff = now - max_age_seconds

        async with self._lock:
            initial_count = len(self._requests)

            self._requests = {
                key: timestamps
                for key, timestamps in self._requests.items()
                if any(ts > cutoff for ts in timestamps)
            }

            removed = initial_count - len(self._requests)
            if removed > 0:
                logger.debug("Rate limiter cleanup removed %d expired keys", removed)

            return removed


class RedisRateLimiter:
    """Redis-based rate limiter for distributed deployments.

    Uses Redis INCR and EXPIRE for atomic rate limiting.
    """

    def __init__(self, redis_client: Any) -> None:
        self._redis = redis_client

    async def is_allowed(
        self,
        key: str,
        max_requests: int,
        window_seconds: int,
    ) -> tuple[bool, int, int]:
        """Check if request is allowed using Redis.

        Args:
            key: Unique identifier (IP or user ID)
            max_requests: Maximum requests allowed in window
            window_seconds: Time window in seconds

        Returns:
            Tuple of (is_allowed, remaining_requests, retry_after_seconds)
        """
        redis_key = f"rate_limit:{key}"
        now = time.time()

        try:
            # Use Redis pipeline for atomic operations
            async with self._redis.pipeline() as pipe:
                pipe.get(redis_key)
                pipe.ttl(redis_key)
                results = await pipe.execute()

            current_count = int(results[0] or 0)
            ttl = int(results[1] or 0)

            if current_count >= max_requests:
                retry_after = max(1, ttl)
                return False, 0, retry_after

            # Increment counter
            new_count = await self._redis.incr(redis_key)

            # Set expiry on first request
            if new_count == 1:
                await self._redis.expire(redis_key, window_seconds)
                ttl = window_seconds
            elif ttl < 0:
                # Key exists but no expiry (shouldn't happen, but handle it)
                await self._redis.expire(redis_key, window_seconds)
                ttl = window_seconds

            remaining = max(0, max_requests - new_count)
            return True, remaining, 0

        except Exception as e:
            logger.error("Redis rate limiter error: %s", e)
            # Fail open - allow request if Redis is unavailable
            return True, max_requests, 0


class RateLimitMiddleware(BaseHTTPMiddleware):
    """FastAPI middleware for rate limiting requests."""

    def __init__(
        self,
        app: FastAPI,
        config: RateLimitConfig | None = None,
        redis_client: Any = None,
    ) -> None:
        super().__init__(app)
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

    def _get_client_key(self, request: Request) -> str:
        """Get unique key for rate limiting.

        Prioritizes user ID if authenticated, otherwise uses IP address.
        """
        # Try to get user ID from request state (set by auth middleware)
        user_id = getattr(request.state, "user_id", None)
        if user_id:
            return f"user:{user_id}"

        # Fall back to IP address
        forwarded = request.headers.get("X-Forwarded-For")
        if forwarded:
            # Take first IP in chain (original client)
            client_ip = forwarded.split(",")[0].strip()
        else:
            client_ip = request.client.host if request.client else "unknown"

        return f"ip:{client_ip}"

    def _is_whitelisted(self, request: Request) -> bool:
        """Check if request path is whitelisted."""
        path = request.url.path

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
            client_ip = request.client.host if request.client else ""
            if client_ip in self.config.whitelist_ips:
                return True

        return False

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        """Process request with rate limiting."""
        if not self.config.enabled:
            return await call_next(request)

        if self._is_whitelisted(request):
            return await call_next(request)

        client_key = self._get_client_key(request)

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
            return self._rate_limit_response(retry_after)

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
            return self._rate_limit_response(retry_after)

        # Process request
        response = await call_next(request)

        # Add rate limit headers
        response.headers["X-RateLimit-Remaining"] = str(remaining)
        response.headers["X-RateLimit-Limit"] = str(self.config.requests_per_minute)

        return response

    def _rate_limit_response(self, retry_after: int) -> JSONResponse:
        """Create rate limit exceeded response."""
        return JSONResponse(
            status_code=429,
            content={
                "message_en": "Too many requests. Please try again later.",
                "message_zh": "请求过于频繁，请稍后再试。",
                "retry_after": retry_after,
            },
            headers={
                "Retry-After": str(retry_after),
                "X-RateLimit-Remaining": "0",
            },
        )


def setup_rate_limiting(
    app: FastAPI,
    redis_client: Any = None,
    config: RateLimitConfig | None = None,
) -> RateLimitMiddleware:
    """Set up rate limiting middleware for a FastAPI app.

    Args:
        app: FastAPI application
        redis_client: Optional Redis client for distributed rate limiting
        config: Rate limit configuration

    Returns:
        RateLimitMiddleware instance
    """
    middleware = RateLimitMiddleware(app, config=config, redis_client=redis_client)
    app.add_middleware(RateLimitMiddleware, config=config, redis_client=redis_client)
    return middleware
