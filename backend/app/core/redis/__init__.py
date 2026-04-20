"""Redis cache with distributed lock and sorted sets.

Usage:
    from app.core.redis import AppCache, get_shared_redis

    redis = get_shared_redis()
    await redis.cache_set("key", "value", ttl=3600)
"""

import asyncio
import hashlib
import logging
import secrets
import threading
from collections.abc import Awaitable, Callable
from typing import Any, TypeVar

import orjson

from app.core.cache_ttl import CacheTTL
from app.core.redis.client import RedisClientManager, redis_json_default


logger = logging.getLogger(__name__)

# Null value cache constants
_NULL_VALUE_MARKER = "__NULL__"
_NULL_CACHE_TTL = 60

# Shared instance for process-level reuse
_shared_redis: "AppCache | None" = None
_shared_redis_lock = threading.Lock()


# ---------------------------------------------------------------------------
# Safe Cache Operation Helpers
# (swallow exceptions for best-effort cache operations)
# ---------------------------------------------------------------------------

T = TypeVar("T")


async def _safe_cache_operation(
    operation: Callable[[], Awaitable[T]],
    *,
    log_warning: Callable[[str], None],
    error_message: str,
    default: T | None = None,
) -> T | None:
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
    result = await _safe_cache_operation(
        invalidator,
        log_warning=log_warning,
        error_message=error_message,
        default=None,
    )
    return result is not None


# ---------------------------------------------------------------------------
# Helper utilities
# ---------------------------------------------------------------------------


def _stable_hash(value: str) -> str:
    normalized = value.strip().lower()
    return hashlib.md5(normalized.encode("utf-8")).hexdigest()


def _hash_search_query(query: str, search_in: str, page: int, size: int) -> str:
    query_str = f"{query}:{search_in}:{page}:{size}".lower()
    return hashlib.md5(query_str.encode("utf-8")).hexdigest()


async def _delete_keys_nonblocking(client: Any, *keys: str) -> int:
    if not keys:
        return 0
    try:
        return int(await client.unlink(*keys) or 0)
    except Exception:
        return int(await client.delete(*keys) or 0)


# ---------------------------------------------------------------------------
# AppCache - thin wrapper over redis-py async client
# ---------------------------------------------------------------------------


class AppCache(RedisClientManager):
    """Unified Redis cache with distributed lock and sorted sets."""

    def __init__(self):
        super().__init__()
        self._background_tasks: set[asyncio.Task] = set()

    # === Key Scanning ===

    async def _scan_keys(self, pattern: str) -> list[str]:
        client = await self._get_client()
        keys: list[str] = []
        async for key in client.scan_iter(match=pattern, count=100):
            keys.append(key)
        return keys

    async def scan_keys(self, pattern: str) -> list[str]:
        return await self._scan_keys(pattern)

    # === Key Deletion ===

    async def delete_keys(self, *keys: str) -> int:
        if not keys:
            return 0
        if keys and not isinstance(keys[0], str):
            keys = keys[1:]
        if not keys:
            return 0
        client = await self._get_client()
        return await _delete_keys_nonblocking(client, *keys)

    _delete_keys = delete_keys

    # === Primitive cache operations ===

    async def cache_get(self, key: str) -> str | None:
        client = await self._get_client()
        return await client.get(key)

    async def cache_set(self, key: str, value: str, ttl: int = CacheTTL.DEFAULT) -> bool:
        client = await self._get_client()
        result = await client.setex(key, ttl, value)
        return result

    async def cache_delete(self, key: str) -> bool:
        client = await self._get_client()
        result = await client.delete(key)
        return result

    # === JSON cache helpers ===

    async def cache_get_json(self, key: str) -> Any | None:
        client = await self._get_client()
        data = await client.get(key)
        if data:
            # Check for null value marker to prevent cache penetration
            if isinstance(data, bytes) and data == _NULL_VALUE_MARKER.encode():
                return None
            if isinstance(data, str) and data == _NULL_VALUE_MARKER:
                return None
            try:
                return orjson.loads(data)
            except orjson.JSONDecodeError:
                return None
        return None

    async def cache_set_json(self, key: str, value: Any, ttl: int = CacheTTL.DEFAULT) -> bool:
        client = await self._get_client()
        try:
            if value is None:
                return bool(await client.setex(key, _NULL_CACHE_TTL, _NULL_VALUE_MARKER))
            json_str = orjson.dumps(value, default=redis_json_default).decode("utf-8")
            return bool(await client.setex(key, ttl, json_str))
        except (TypeError, ValueError):
            return False

    # === Anti-stampede cache (inlined from old cache_get_with_lock) ===

    async def cache_get_with_lock(
        self,
        key: str,
        loader: Any,
        ttl: int = CacheTTL.DEFAULT,
        lock_timeout: int = 10,
        max_wait_time: float = 3.0,
    ) -> tuple[Any, bool]:
        client = await self._get_client()
        value = await self.cache_get_json(key)
        if value is not None:
            return value, True

        lock_key = f"lock:{key}"
        lock_acquired = await client.set(lock_key, "1", nx=True, ex=lock_timeout)

        if lock_acquired:
            try:
                value = await loader()
                if value is None:
                    await client.setex(key, _NULL_CACHE_TTL, _NULL_VALUE_MARKER)
                else:
                    await self.cache_set_json(key, value, ttl)
                return value, False
            except Exception:
                import contextlib

                with contextlib.suppress(Exception):
                    await client.setex(f"{key}:error", 5, "1")
                raise
            finally:
                await _delete_keys_nonblocking(client, lock_key)
        else:
            wait_start = asyncio.get_running_loop().time()
            initial_delay = 0.05
            max_delay = 0.5
            attempt = 0

            while (asyncio.get_running_loop().time() - wait_start) < max_wait_time:
                delay = min(initial_delay * (2**attempt), max_delay)
                await asyncio.sleep(delay)

                value = await self.cache_get_json(key)
                if value is not None:
                    return value, True

                lock_exists = await client.exists(lock_key)
                if not lock_exists:
                    lock_acquired = await client.set(
                        lock_key, "1", nx=True, ex=lock_timeout,
                    )
                    if lock_acquired:
                        try:
                            value = await loader()
                            await self.cache_set_json(key, value, ttl)
                            return value, False
                        finally:
                            await _delete_keys_nonblocking(client, lock_key)

                attempt += 1

            value = await loader()
            await self.cache_set_json(key, value, ttl)
            return value, False

    # === User Stats ===

    async def get_user_stats(self, user_id: int) -> dict | None:
        return await self.cache_get_json(f"podcast:stats:{user_id}")

    async def set_user_stats(self, user_id: int, stats: dict) -> bool:
        return await self.cache_set_json(f"podcast:stats:{user_id}", stats, ttl=CacheTTL.STATS_LONG)

    async def invalidate_user_stats(self, user_id: int) -> None:
        client = await self._get_client()
        await client.delete(f"podcast:stats:{user_id}")

    # === Profile Stats ===

    async def get_profile_stats(self, user_id: int) -> dict | None:
        return await self.cache_get_json(f"podcast:stats:profile:{user_id}")

    async def set_profile_stats(self, user_id: int, stats: dict) -> bool:
        return await self.cache_set_json(f"podcast:stats:profile:{user_id}", stats, ttl=CacheTTL.STATS_SHORT)

    async def invalidate_profile_stats(self, user_id: int) -> None:
        client = await self._get_client()
        await client.delete(f"podcast:stats:profile:{user_id}")

    # === Subscription List ===

    def _subscription_index_key(self, user_id: int) -> str:
        return f"podcast:subscriptions:index:{user_id}"

    def _subscription_list_key(
        self,
        user_id: int,
        page: int,
        size: int,
        filters: dict[str, Any] | None = None,
    ) -> str:
        payload = {
            "user_id": user_id,
            "page": page,
            "size": size,
            "filters": filters or {},
        }
        payload_str = orjson.dumps(payload, option=orjson.OPT_SORT_KEYS).decode("utf-8")
        token = _stable_hash(payload_str)
        return f"podcast:subscriptions:v2:{user_id}:{token}"

    async def get_subscription_list(
        self, user_id: int, page: int, size: int, filters: dict[str, Any] | None = None,
    ) -> dict | None:
        key = self._subscription_list_key(user_id, page, size, filters=filters)
        return await self.cache_get_json(key)

    async def set_subscription_list(
        self,
        user_id: int,
        page: int,
        size: int,
        data: dict,
        filters: dict[str, Any] | None = None,
    ) -> bool:
        key = self._subscription_list_key(user_id, page, size, filters=filters)
        index_key = self._subscription_index_key(user_id)

        try:
            json_str = orjson.dumps(data).decode("utf-8")
        except (TypeError, ValueError):
            return False

        client = await self._get_client()
        async with client.pipeline() as pipe:
            pipe.setex(key, CacheTTL.SUBSCRIPTION_LIST, json_str)
            pipe.sadd(index_key, key)
            pipe.expire(index_key, 1800)
            await pipe.execute()
        return True

    async def invalidate_subscription_list(self, user_id: int) -> None:
        client = await self._get_client()
        index_key = self._subscription_index_key(user_id)
        keys = list(await client.smembers(index_key))
        if not keys:
            keys = await self._scan_keys(f"podcast:subscriptions:v2:{user_id}:*")
        if keys:
            await _delete_keys_nonblocking(client, *keys, index_key)

    # === Episode List ===

    def _episode_index_key(self, subscription_id: int) -> str:
        return f"podcast:episodes:index:{subscription_id}"

    async def get_episode_list(
        self, subscription_id: int, page: int, size: int,
    ) -> dict | None:
        key = f"podcast:episodes:{subscription_id}:{page}:{size}"
        return await self.cache_get_json(key)

    async def set_episode_list(
        self, subscription_id: int, page: int, size: int, data: dict,
    ) -> bool:
        key = f"podcast:episodes:{subscription_id}:{page}:{size}"
        index_key = self._episode_index_key(subscription_id)

        try:
            json_str = orjson.dumps(data).decode("utf-8")
        except (TypeError, ValueError):
            return False

        client = await self._get_client()
        async with client.pipeline() as pipe:
            pipe.setex(key, CacheTTL.EPISODE_LIST, json_str)
            pipe.sadd(index_key, key)
            pipe.expire(index_key, 1800)
            await pipe.execute()
        return True

    async def invalidate_episode_list(self, subscription_id: int) -> None:
        client = await self._get_client()
        index_key = self._episode_index_key(subscription_id)
        keys = list(await client.smembers(index_key))
        if not keys:
            keys = await self._scan_keys(f"podcast:episodes:{subscription_id}:*")
        if keys:
            await _delete_keys_nonblocking(client, *keys, index_key)

    # === Episode Detail ===

    async def get_episode_detail(self, episode_id: int, loader: Any) -> Any | None:
        key = f"podcast:episode:detail:{episode_id}"
        result, _from_cache = await self.cache_get_with_lock(
            key=key, loader=loader, ttl=CacheTTL.EPISODE_DETAIL,
        )
        return result

    async def invalidate_episode_detail(self, episode_id: int) -> None:
        client = await self._get_client()
        await client.delete(f"podcast:episode:detail:{episode_id}")

    # === Highlight Dates ===

    async def get_highlight_dates(self, user_id: int, loader: Any) -> list[str]:
        key = f"highlights:dates:{user_id}"
        result, _from_cache = await self.cache_get_with_lock(
            key=key, loader=loader, ttl=CacheTTL.HIGHLIGHT_DATES,
        )
        return result or []

    async def invalidate_highlight_dates(self, user_id: int) -> None:
        client = await self._get_client()
        await client.delete(f"highlights:dates:{user_id}")

    # === Playback Rate ===

    async def get_effective_playback_rate(
        self, user_id: int, subscription_id: int | None, loader: Any,
    ) -> Any | None:
        key = f"playback:rate:{user_id}:{subscription_id or 'global'}"
        result, _from_cache = await self.cache_get_with_lock(
            key=key, loader=loader, ttl=CacheTTL.PLAYBACK_RATE,
        )
        return result

    async def invalidate_playback_rate(
        self, user_id: int, subscription_id: int | None = None,
    ) -> None:
        client = await self._get_client()
        await client.delete(f"playback:rate:{user_id}:{subscription_id or 'global'}")

    # === User Progress ===

    async def set_user_progress(self, user_id: int, episode_id: int, progress: float) -> None:
        client = await self._get_client()
        await client.setex(
            f"podcast:progress:{user_id}:{episode_id}",
            CacheTTL.PLAYBACK_PROGRESS,
            str(progress),
        )

    async def get_user_progress(self, user_id: int, episode_id: int) -> float | None:
        client = await self._get_client()
        progress = await client.get(f"podcast:progress:{user_id}:{episode_id}")
        return float(progress) if progress else None

    # === Episode Metadata ===

    async def set_episode_metadata(self, episode_id: int, metadata: dict) -> None:
        client = await self._get_client()
        key = f"podcast:meta:{episode_id}"
        async with client.pipeline(True) as pipe:
            pipe.hset(key, mapping=metadata)
            pipe.expire(key, CacheTTL.EPISODE_METADATA)
            await pipe.execute()

    # === AI Summary ===

    async def set_ai_summary(self, episode_id: int, summary: str, version: str = "v1") -> None:
        client = await self._get_client()
        key = f"podcast:summary:{episode_id}:{version}"
        await client.setex(key, CacheTTL.AI_SUMMARY, summary)

    # === Search Results ===

    _hash_search_query = staticmethod(_hash_search_query)

    async def get_search_results(
        self, query: str, search_in: str, page: int, size: int,
    ) -> dict | None:
        hash_key = _hash_search_query(query, search_in, page, size)
        key = f"podcast:search:v2:{hash_key}"
        return await self.cache_get_json(key)

    async def set_search_results(
        self, query: str, search_in: str, page: int, size: int, data: dict,
    ) -> bool:
        hash_key = _hash_search_query(query, search_in, page, size)
        key = f"podcast:search:v2:{hash_key}"
        return await self.cache_set_json(key, data, ttl=CacheTTL.STALE_REFRESH)

    # === Distributed Lock ===

    async def acquire_lock(
        self, lock_name: str, expire: int = CacheTTL.LOCK_TIMEOUT, value: str = "1",
    ) -> bool:
        client = await self._get_client()
        return bool(
            await client.set(f"podcast:lock:{lock_name}", value, ex=expire, nx=True)
        )

    async def release_lock(self, lock_name: str) -> None:
        client = await self._get_client()
        await client.delete(f"podcast:lock:{lock_name}")

    async def set_if_not_exists(
        self, key: str, value: str, *, ttl: int | None = None,
    ) -> bool:
        client = await self._get_client()
        return bool(await client.set(key, value, ex=ttl, nx=True))

    async def acquire_owned_lock(
        self, lock_name: str, *, expire: int = CacheTTL.LOCK_TIMEOUT,
    ) -> str | None:
        client = await self._get_client()
        token = secrets.token_urlsafe(16)
        acquired = await client.set(
            f"podcast:lock:{lock_name}", token, ex=expire, nx=True,
        )
        return token if acquired else None

    async def release_owned_lock(self, lock_name: str, token: str) -> bool:
        client = await self._get_client()
        result = await client.eval(
            'if redis.call("get", KEYS[1]) == ARGV[1] then return redis.call("del", KEYS[1]) end return 0',
            1,
            f"podcast:lock:{lock_name}",
            token,
        )
        return bool(result)

    # === Sorted-Set Operations ===

    async def sorted_set_add(self, key: str, member: str, score: float) -> int:
        client = await self._get_client()
        result = await client.zadd(key, {member: score})
        return int(result or 0)

    async def sorted_set_remove(self, key: str, *members: str) -> int:
        if not members:
            return 0
        client = await self._get_client()
        result = await client.zrem(key, *members)
        return int(result or 0)

    async def sorted_set_cardinality(self, key: str) -> int:
        client = await self._get_client()
        result = await client.zcard(key)
        return int(result or 0)

    async def sorted_set_range_by_score(
        self, key: str, min_score: float | str, max_score: float | str,
    ) -> list[str]:
        client = await self._get_client()
        result = await client.zrangebyscore(key, min_score, max_score)
        return list(result)

    async def sorted_set_remove_by_score(
        self, key: str, min_score: float | str, max_score: float | str,
    ) -> int:
        client = await self._get_client()
        result = await client.zremrangebyscore(key, min_score, max_score)
        return int(result or 0)

    # === Utility ===

    async def get_ttl(self, key: str) -> int:
        client = await self._get_client()
        return int(await client.ttl(key) or -1)


# Backward-compatible alias
PodcastRedis = AppCache


# === Module-level Functions ===


async def get_redis() -> AppCache:
    """Create a Redis helper."""
    return AppCache()


def get_shared_redis() -> AppCache:
    """Return a process-level shared Redis helper (thread-safe)."""
    global _shared_redis
    if _shared_redis is None:
        with _shared_redis_lock:
            if _shared_redis is None:
                _shared_redis = AppCache()
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
    "PodcastRedis",
    "get_redis",
    "get_shared_redis",
    "close_shared_redis",
    "_NULL_VALUE_MARKER",
    "_NULL_CACHE_TTL",
    "safe_cache_get",
    "safe_cache_write",
    "safe_cache_invalidate",
]
