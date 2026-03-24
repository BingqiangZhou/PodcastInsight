"""Redis Cache Operations.

Basic caching operations (get/set/hash) and JSON helpers.
"""

import logging
from time import perf_counter
from typing import Any

import orjson

from app.core.cache_ttl import CacheTTL

logger = logging.getLogger(__name__)


# Null value cache marker
_NULL_VALUE_MARKER = "__NULL__"


class CacheOperations:
    """Basic cache operations mixin."""

    async def cache_get(self, client: Any, key: str) -> str | None:
        """Get cached value."""
        started = perf_counter()
        value = await client.get(key)
        # Note: timing recorded by caller
        return value

    async def cache_set(
        self, client: Any, key: str, value: str, ttl: int = CacheTTL.DEFAULT
    ) -> bool:
        """Set cached value with TTL."""
        started = perf_counter()
        result = await client.setex(key, ttl, value)
        return result

    async def cache_delete(self, client: Any, key: str) -> bool:
        """Delete cached value."""
        started = perf_counter()
        result = await client.delete(key)
        return result

    async def cache_hget(self, client: Any, key: str, field: str) -> str | None:
        """Get hash field."""
        started = perf_counter()
        value = await client.hget(key, field)
        return value

    async def cache_hgetall(self, client: Any, key: str) -> dict[str, str]:
        """Get all hash fields."""
        started = perf_counter()
        value = await client.hgetall(key)
        return value

    async def cache_hset(
        self, client: Any, key: str, mapping: dict, ttl: int | None = None
    ) -> int:
        """Set hash fields with optional TTL."""
        started = perf_counter()
        result = await client.hset(key, mapping=mapping)
        if ttl:
            expire_started = perf_counter()
            await client.expire(key, ttl)
        return result

    # === JSON Cache Helpers ===

    async def cache_get_json(self, key: str, client: Any, record_lookup: Any = None) -> Any | None:
        """Get and parse JSON from cache."""
        data = await self.cache_get(key)
        if data:
            try:
                value = orjson.loads(data)
                if record_lookup:
                    await record_lookup(key, hit=True)
                return value
            except orjson.JSONDecodeError:
                if record_lookup:
                    await record_lookup(key, hit=False)
                return None
        if record_lookup:
            await record_lookup(key, hit=False)
        return None

    async def cache_set_json(
        self, key: str, value: Any, client: Any, ttl: int = CacheTTL.DEFAULT
    ) -> bool:
        """Serialize and cache JSON value."""
        from app.core.redis.client import redis_json_default

        try:
            json_str = orjson.dumps(value, default=redis_json_default).decode('utf-8')
            return await self.cache_set(key, json_str, ttl=ttl)
        except (TypeError, ValueError):
            return False

    # === Anti-Stampede Cache Operations ===

    async def cache_get_with_lock(
        self,
        key: str,
        loader: Any,
        client: Any,
        ttl: int = CacheTTL.DEFAULT,
        lock_timeout: int = 10,
        max_wait_time: float = 3.0,
        record_timing: Any = None,
        record_lookup: Any = None,
    ) -> tuple[Any, bool]:
        """Get cached value with distributed lock to prevent cache stampede.

        Uses exponential backoff polling when lock is held by another process.
        """
        import asyncio

        # Try to get from cache first
        value = await self.cache_get_json(key, client, record_lookup)
        if value is not None:
            return value, True

        # Try to acquire lock
        lock_key = f"lock:{key}"
        started = perf_counter()
        lock_acquired = await client.set(lock_key, "1", nx=True, ex=lock_timeout)
        if record_timing:
            await record_timing("SET_NX", (perf_counter() - started) * 1000)

        if lock_acquired:
            try:
                # We hold the lock, load the value
                value = await loader()
                await self.cache_set_json(key, value, client, ttl)
                if record_lookup:
                    await record_lookup(key, hit=False)
                return value, False
            finally:
                # Release lock
                await self._delete_keys_nonblocking(client, lock_key)
        else:
            # Another process is loading, wait with exponential backoff
            import asyncio
            wait_start = perf_counter()
            initial_delay = 0.05
            max_delay = 0.5
            attempt = 0

            while (perf_counter() - wait_start) < max_wait_time:
                delay = min(initial_delay * (2 ** attempt), max_delay)
                await asyncio.sleep(delay)

                # Try to get from cache again
                value = await self.cache_get_json(key, client, record_lookup)
                if value is not None:
                    return value, True

                # Check if lock was released
                started = perf_counter()
                lock_exists = await client.exists(lock_key)
                if record_timing:
                    await record_timing("EXISTS", (perf_counter() - started) * 1000)

                if not lock_exists:
                    # Lock was released without cache being set, try to acquire it
                    started = perf_counter()
                    lock_acquired = await client.set(lock_key, "1", nx=True, ex=lock_timeout)
                    if record_timing:
                        await record_timing("SET_NX", (perf_counter() - started) * 1000)

                    if lock_acquired:
                        try:
                            value = await loader()
                            await self.cache_set_json(key, value, client, ttl)
                            if record_lookup:
                                await record_lookup(key, hit=False)
                            return value, False
                        finally:
                            await self._delete_keys_nonblocking(client, lock_key)

                attempt += 1

            # Max wait time exceeded, load anyway as fallback
            value = await loader()
            await self.cache_set_json(key, value, client, ttl)
            if record_lookup:
                await record_lookup(key, hit=False)
            return value, False

    async def cache_get_or_load(
        self,
        key: str,
        loader: Any,
        client: Any,
        ttl: int = CacheTTL.DEFAULT,
        stale_ttl: int = CacheTTL.STALE_REFRESH,
        record_timing: Any = None,
        record_lookup: Any = None,
    ) -> Any:
        """Get cached value with stale-while-revalidate pattern."""
        import asyncio

        value = await self.cache_get_json(key, client, record_lookup)
        if value is not None:
            # Check if we should background refresh
            started = perf_counter()
            ttl_remaining = await client.ttl(key)
            if record_timing:
                await record_timing("TTL", (perf_counter() - started) * 1000)

            if ttl_remaining > 0 and ttl_remaining < stale_ttl:
                # Trigger background refresh (non-blocking)
                asyncio.create_task(
                    self._background_refresh(key, loader, client, ttl)
                )
            return value

        # Cache miss, load synchronously
        value = await loader()
        await self.cache_set_json(key, value, client, ttl)
        if record_lookup:
            await record_lookup(key, hit=False)
        return value

    async def _background_refresh(
        self, key: str, loader: Any, client: Any, ttl: int
    ) -> None:
        """Background cache refresh task."""
        try:
            value = await loader()
            await self.cache_set_json(key, value, client, ttl)
        except Exception as e:
            logging.getLogger(__name__).warning(
                "Background cache refresh failed for key %s: %s", key, e
            )

    async def _delete_keys_nonblocking(self, client: Any, *keys: str) -> int:
        """Delete keys using UNLINK when available."""
        if not keys:
            return 0

        started = perf_counter()
        try:
            result = await client.unlink(*keys)
            return int(result or 0)
        except Exception:
            # Fall back to DEL for Redis deployments without UNLINK support.
            result = await client.delete(*keys)
            return int(result or 0)


# Export null marker
NULL_VALUE_MARKER = _NULL_VALUE_MARKER


# === Safe Cache Operation Helpers ===
# These functions swallow exceptions for best-effort cache operations

from collections.abc import Awaitable, Callable
from typing import TypeVar

T = TypeVar("T")


async def _safe_cache_operation(
    operation: Callable[[], Awaitable[T]],
    *,
    log_warning: Callable[[str], None],
    error_message: str,
    default: T | None = None,
) -> T | None:
    """Execute a cache operation and swallow backend errors."""
    try:
        return await operation()
    except Exception as exc:
        log_warning(f"{error_message}: {exc}")
        return default


async def safe_cache_get(
    getter: Callable[[], Awaitable[T]],
    *,
    log_warning: Callable[[str], None],
    error_message: str,
) -> T | None:
    """Try cache read and swallow backend cache errors."""
    return await _safe_cache_operation(
        getter,
        log_warning=log_warning,
        error_message=error_message,
        default=None,
    )


async def safe_cache_write(
    writer: Callable[[], Awaitable[object]],
    *,
    log_warning: Callable[[str], None],
    error_message: str,
) -> bool:
    """Try cache write and return success status."""
    result = await _safe_cache_operation(
        writer,
        log_warning=log_warning,
        error_message=error_message,
        default=None,
    )
    return result is not None


async def safe_cache_invalidate(
    invalidator: Callable[[], Awaitable[object]],
    *,
    log_warning: Callable[[str], None],
    error_message: str,
) -> bool:
    """Try cache invalidation and return success status."""
    result = await _safe_cache_operation(
        invalidator,
        log_warning=log_warning,
        error_message=error_message,
        default=None,
    )
    return result is not None
