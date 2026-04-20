"""Simplified Redis cache for single-user mode.

Usage:
    from app.core.redis import get_shared_redis

    redis = get_shared_redis()
    await redis.set("key", "value", ttl=3600)
"""

import asyncio
import hashlib
import logging
import threading
from contextlib import suppress
from datetime import datetime
from time import perf_counter
from typing import Any

import orjson
from redis import asyncio as aioredis
from redis.backoff import ExponentialBackoff
from redis.retry import Retry

from app.core.config import settings


logger = logging.getLogger(__name__)


class CacheTTL:
    """Cache TTL constants (seconds)."""

    DEFAULT: int = 1800           # 30 minutes
    SHORT: int = 60               # 1 minute
    LONG: int = 86400             # 1 day
    EPISODE_METADATA: int = 3600  # 1 hour
    LOCK_TIMEOUT: int = 30        # 30 seconds


def redis_json_default(obj: Any) -> Any:
    """Default JSON encoder for Redis — handles datetime objects."""
    if isinstance(obj, datetime):
        return obj.isoformat()
    raise TypeError(f"Object of type {type(obj)} is not JSON serializable")


class RedisCache:
    """Thin wrapper over redis-py async client for single-user caching."""

    _health_check_interval_seconds = 30.0

    def __init__(self):
        self._client = None
        self._client_loop_token: int | None = None
        self._last_health_check_at = 0.0

    @staticmethod
    def _current_loop_token() -> int | None:
        try:
            return id(asyncio.get_running_loop())
        except RuntimeError:
            return None

    @staticmethod
    def _build_client() -> aioredis.Redis:
        return aioredis.from_url(
            settings.REDIS_URL,
            decode_responses=True,
            socket_timeout=5,
            socket_connect_timeout=5,
            retry_on_timeout=True,
            max_connections=settings.REDIS_MAX_CONNECTIONS,
            retry=Retry(
                ExponentialBackoff(cap=10, base=1),
                3,
            ),
        )

    async def _ping_client(
        self, client: aioredis.Redis, *, timeout: float = 2.0
    ) -> bool:
        try:
            async with asyncio.timeout(timeout):
                await client.ping()
            return True
        except TimeoutError:
            logger.warning("Redis ping timed out after %.1f seconds", timeout)
            return False
        except Exception as e:
            logger.warning("Redis ping failed: %s", e)
            return False

    async def _get_client(self) -> aioredis.Redis:
        """Get Redis client with automatic reconnection and health checks."""
        current_loop_token = self._current_loop_token()

        if self._client is not None and self._client_loop_token != current_loop_token:
            old_client = self._client
            self._client = None
            self._client_loop_token = None
            self._last_health_check_at = 0.0
            with suppress(Exception):
                await old_client.close()

        if self._client is None:
            new_client = self._build_client()
            if not await self._ping_client(new_client):
                raise ConnectionError("Failed to connect to Redis after initial ping")
            self._client = new_client
            self._client_loop_token = current_loop_token
            self._last_health_check_at = perf_counter()
            return self._client

        now = perf_counter()
        if (now - self._last_health_check_at) < self._health_check_interval_seconds:
            return self._client

        if await self._ping_client(self._client):
            self._last_health_check_at = now
            return self._client

        logger.warning("Redis health check failed, attempting reconnection")
        old_client = self._client
        self._client = None

        with suppress(Exception):
            await old_client.close()

        max_retries = 3
        for attempt in range(max_retries):
            new_client = self._build_client()
            if await self._ping_client(new_client):
                self._client = new_client
                self._client_loop_token = current_loop_token
                self._last_health_check_at = perf_counter()
                logger.info("Redis reconnection successful on attempt %d", attempt + 1)
                return self._client

            if attempt < max_retries - 1:
                await asyncio.sleep(0.5 * (2**attempt))

        raise ConnectionError(
            f"Failed to reconnect to Redis after {max_retries} attempts"
        )

    async def close(self):
        """Close Redis connection."""
        if self._client:
            try:
                await self._client.close()
            finally:
                self._client = None
                self._client_loop_token = None
                self._last_health_check_at = 0.0

    async def check_health(self, timeout_seconds: float = 1.5) -> dict:
        """Return a compact Redis readiness payload."""
        try:
            async with asyncio.timeout(timeout_seconds):
                client = await self._get_client()
                await client.ping()
            return {"status": "healthy"}
        except TimeoutError:
            return {"status": "unhealthy", "error": "timeout"}
        except Exception as exc:
            return {"status": "unhealthy", "error": str(exc)}

    # ── Primitive operations ───────────────────────────────────────────────

    async def get(self, key: str) -> str | None:
        client = await self._get_client()
        return await client.get(key)

    async def set(self, key: str, value: str, ttl: int = CacheTTL.DEFAULT) -> bool:
        client = await self._get_client()
        return await client.setex(key, ttl, value)

    async def delete(self, key: str) -> bool:
        client = await self._get_client()
        result = await client.delete(key)
        return bool(result)

    async def exists(self, key: str) -> bool:
        client = await self._get_client()
        return bool(await client.exists(key))

    async def get_ttl(self, key: str) -> int:
        client = await self._get_client()
        return int(await client.ttl(key) or -1)

    async def set_if_not_exists(self, key: str, value: str, *, ttl: int | None = None) -> bool:
        client = await self._get_client()
        return bool(await client.set(key, value, ex=ttl, nx=True))

    # ── Pattern delete ─────────────────────────────────────────────────────

    async def delete_pattern(self, pattern: str) -> int:
        """Delete all keys matching a pattern using SCAN."""
        client = await self._get_client()
        keys: list[str] = []
        async for key in client.scan_iter(match=pattern, count=100):
            keys.append(key)
        if not keys:
            return 0
        try:
            return int(await client.unlink(*keys) or 0)
        except Exception:
            return int(await client.delete(*keys) or 0)

    # ── JSON helpers ───────────────────────────────────────────────────────

    async def get_json(self, key: str) -> Any | None:
        client = await self._get_client()
        data = await client.get(key)
        if data:
            try:
                return orjson.loads(data)
            except orjson.JSONDecodeError:
                return None
        return None

    async def set_json(self, key: str, value: Any, ttl: int = CacheTTL.DEFAULT) -> bool:
        client = await self._get_client()
        try:
            json_str = orjson.dumps(value, default=redis_json_default).decode("utf-8")
            return bool(await client.setex(key, ttl, json_str))
        except (TypeError, ValueError):
            return False

    # ── Simple locks ───────────────────────────────────────────────────────

    async def acquire_lock(self, lock_name: str, expire: int = CacheTTL.LOCK_TIMEOUT) -> bool:
        client = await self._get_client()
        return bool(
            await client.set(f"lock:{lock_name}", "1", ex=expire, nx=True)
        )

    async def release_lock(self, lock_name: str) -> None:
        client = await self._get_client()
        await client.delete(f"lock:{lock_name}")


# Backward-compatible aliases
AppCache = RedisCache
PodcastRedis = RedisCache


# ── Module-level singleton ──────────────────────────────────────────────────

_shared_redis: RedisCache | None = None
_shared_redis_lock = threading.Lock()


def get_redis() -> RedisCache:
    """Create a new Redis cache helper."""
    return RedisCache()


def get_shared_redis() -> RedisCache:
    """Return a process-level shared Redis helper (thread-safe)."""
    global _shared_redis
    if _shared_redis is None:
        with _shared_redis_lock:
            if _shared_redis is None:
                _shared_redis = RedisCache()
    return _shared_redis


async def close_shared_redis() -> None:
    """Close the process-level shared Redis helper if it exists."""
    global _shared_redis
    if _shared_redis is None:
        return
    await _shared_redis.close()
    _shared_redis = None


__all__ = [
    "AppCache",
    "CacheTTL",
    "PodcastRedis",
    "RedisCache",
    "close_shared_redis",
    "get_redis",
    "get_shared_redis",
]
