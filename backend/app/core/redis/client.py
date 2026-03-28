"""Redis Client Management.

Handles connection pooling, health checks, and reconnection logic.
"""

import asyncio
import logging
from contextlib import suppress
from datetime import datetime
from time import perf_counter
from typing import Any

from redis import asyncio as aioredis
from redis.backoff import ExponentialBackoff
from redis.retry import Retry

from app.core.config import settings


logger = logging.getLogger(__name__)


def redis_json_default(obj: Any) -> Any:
    """Default JSON encoder function for Redis that handles datetime objects.

    Compatible with orjson.dumps(default=...).

    Args:
        obj: Object to encode

    Returns:
        JSON-serializable representation of the object

    Raises:
        TypeError: If object is not serializable
    """
    if isinstance(obj, datetime):
        return obj.isoformat()
    raise TypeError(f"Object of type {type(obj)} is not JSON serializable")


class RedisClientManager:
    """Manages Redis client lifecycle with automatic reconnection."""

    _health_check_interval_seconds = 30.0

    def __init__(self):
        self._client = None
        self._client_loop_token: int | None = None
        self._last_health_check_at = 0.0

    @staticmethod
    def _current_loop_token() -> int | None:
        """Get current event loop token for loop-change detection."""
        try:
            return id(asyncio.get_running_loop())
        except RuntimeError:
            return None

    @staticmethod
    def _build_client() -> aioredis.Redis:
        """Build a new Redis client with retry configuration."""
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

    async def _ping_client(self, client: aioredis.Redis, *, timeout: float = 2.0) -> bool:
        """Ping Redis client with timeout.

        Note: Do NOT record timing here to avoid circular call with _get_client()

        Args:
            client: Redis client to ping
            timeout: Timeout in seconds (default 2.0)

        Returns:
            True if ping successful, False otherwise
        """
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
        """Get Redis client instance with automatic reconnection."""
        current_loop_token = self._current_loop_token()

        # Celery prefork workers call asyncio.run() per task. When loop changes,
        # redis-py async clients bound to old loops must be discarded.
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

        # Health check needed
        if await self._ping_client(self._client):
            self._last_health_check_at = now
            return self._client

        # Health check failed, try to reconnect
        logger.warning("Redis health check failed, attempting reconnection")
        old_client = self._client
        self._client = None

        # Close old client
        with suppress(Exception):
            await old_client.close()

        # Try to reconnect with retry
        max_retries = 3
        for attempt in range(max_retries):
            new_client = self._build_client()
            if await self._ping_client(new_client):
                self._client = new_client
                self._client_loop_token = current_loop_token
                self._last_health_check_at = perf_counter()
                logger.info("Redis reconnection successful on attempt %d", attempt + 1)
                return self._client

            # Wait before retry (exponential backoff)
            if attempt < max_retries - 1:
                await asyncio.sleep(0.5 * (2 ** attempt))

        # All reconnection attempts failed
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
        """Return a compact Redis readiness payload suitable for readiness probes."""
        try:
            async with asyncio.timeout(timeout_seconds):
                client = await self._get_client()
                await client.ping()
            return {"status": "healthy"}
        except TimeoutError:
            return {"status": "unhealthy", "error": "timeout"}
        except Exception as exc:
            return {"status": "unhealthy", "error": str(exc)}
