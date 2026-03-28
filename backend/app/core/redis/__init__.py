"""Redis cache with distributed lock, rate limiting, and sorted sets.

Usage:
    from app.core.redis import AppCache, get_shared_redis

    redis = get_shared_redis()
    await redis.cache_set("key", "value", ttl=3600)
"""

import logging
import secrets
from typing import Any

import orjson

from app.core.cache_ttl import CacheTTL
from app.core.redis.cache import (
    CacheOperations,
    safe_cache_get,
    safe_cache_invalidate,
    safe_cache_write,
)
from app.core.redis.client import RedisClientManager
from app.core.redis.lock import LockOperations
from app.core.redis.podcast_cache import PodcastCacheOperations
from app.core.redis.rate_limit import RateLimitOperations
from app.core.redis.sorted_set import SortedSetOperations


logger = logging.getLogger(__name__)

# Null value cache constants (kept from penetration module)
_NULL_VALUE_MARKER = "__NULL__"
_NULL_CACHE_TTL = 60

# Shared instance for process-level reuse
_shared_redis: "AppCache | None" = None


class _DeferredScript:
    """Deferred Lua script that gets the client when executed."""

    def __init__(self, redis_helper: "AppCache", script: str):
        self._redis = redis_helper
        self._script = script
        self._cached_script = None

    async def __call__(self, keys: list[str] = None, args: list[Any] = None):
        if self._cached_script is None:
            client = await self._redis._get_client()
            self._cached_script = client.register_script(self._script)
        return await self._cached_script(keys=keys, args=args)


class AppCache(
    RedisClientManager,
    CacheOperations,
    PodcastCacheOperations,
    LockOperations,
    RateLimitOperations,
    SortedSetOperations,
):
    """Unified Redis cache with distributed lock, rate limiting, and sorted sets."""

    _hash_search_query = PodcastCacheOperations._hash_search_query

    def __init__(self):
        RedisClientManager.__init__(self)

    # === Key Scanning ===

    async def _scan_keys(self, pattern: str) -> list[str]:
        """Scan for keys matching a pattern."""
        client = await self._get_client()
        keys: list[str] = []
        async for key in client.scan_iter(match=pattern):
            keys.append(key)
        return keys

    async def scan_keys(self, pattern: str) -> list[str]:
        """Public API for key scanning."""
        return await self._scan_keys(pattern)

    # === Key Deletion ===

    async def _delete_keys_nonblocking(self, *keys: str) -> int:
        """Delete keys using UNLINK when available."""
        if not keys:
            return 0
        # Compatibility shim: CacheOperations passes client as first arg
        if keys and not isinstance(keys[0], str):
            keys = keys[1:]
        if not keys:
            return 0

        client = await self._get_client()
        try:
            return int(await client.unlink(*keys) or 0)
        except Exception:
            return int(await client.delete(*keys) or 0)

    async def delete_keys(self, *keys: str) -> int:
        """Delete one or more keys."""
        return await self._delete_keys_nonblocking(*keys)

    # Alias used by some mixin delegates
    _delete_keys = _delete_keys_nonblocking

    # === Pipeline Support ===

    def pipeline(self):
        """Return a Redis pipeline context manager."""
        return self._PipelineContextManager(self)

    class _PipelineContextManager:
        def __init__(self, redis_helper: "AppCache"):
            self._redis = redis_helper
            self._client = None
            self._pipe = None

        async def __aenter__(self):
            self._client = await self._redis._get_client()
            self._pipe = self._client.pipeline()
            return self._pipe

        async def __aexit__(self, exc_type, exc_val, exc_tb):
            if self._pipe:
                await self._pipe.execute()

        def __getattr__(self, name):
            return getattr(self._pipe, name)

    # === Raw Client Access ===

    async def incr(self, key: str) -> int:
        client = await self._get_client()
        return int(await client.incr(key) or 0)

    async def expire(self, key: str, seconds: int) -> bool:
        client = await self._get_client()
        return bool(await client.expire(key, seconds))

    async def get(self, key: str) -> str | None:
        return await self.cache_get(key)

    async def setex(self, key: str, ttl: int, value: str) -> bool:
        return await self.cache_set(key, value, ttl=ttl)

    async def ttl(self, key: str) -> int:
        client = await self._get_client()
        return int(await client.ttl(key) or -1)

    async def get_ttl(self, key: str) -> int:
        return await self.ttl(key)

    # === Lua Script Support ===

    def register_script(self, script: str):
        if self._client is None:
            return _DeferredScript(self, script)
        return self._client.register_script(script)

    # === Core Cache Operations (delegated to CacheOperations mixin) ===

    async def cache_get(self, key: str) -> str | None:
        client = await self._get_client()
        return await CacheOperations.cache_get(self, client, key)

    async def cache_set(self, key: str, value: str, ttl: int = CacheTTL.DEFAULT) -> bool:
        client = await self._get_client()
        return await CacheOperations.cache_set(self, client, key, value, ttl)

    async def cache_delete(self, key: str) -> bool:
        client = await self._get_client()
        return await CacheOperations.cache_delete(self, client, key)

    async def cache_hget(self, key: str, field: str) -> str | None:
        client = await self._get_client()
        return await CacheOperations.cache_hget(self, client, key, field)

    async def cache_hgetall(self, key: str) -> dict[str, str]:
        client = await self._get_client()
        return await CacheOperations.cache_hgetall(self, client, key)

    async def cache_hset(self, key: str, mapping: dict, ttl: int | None = None) -> int:
        client = await self._get_client()
        result = await CacheOperations.cache_hset(self, client, key, mapping, ttl)
        if ttl:
            await client.expire(key, ttl)
        return result

    async def cache_get_json(self, key: str, _client: Any = None, _record_lookup: Any = None) -> Any | None:
        client = await self._get_client()
        data = await client.get(key)
        if data:
            try:
                return orjson.loads(data)
            except orjson.JSONDecodeError:
                return None
        return None

    async def cache_set_json(self, key: str, value: Any, _client: Any = None, ttl: int = CacheTTL.DEFAULT) -> bool:
        from app.core.redis.client import redis_json_default
        client = await self._get_client()
        try:
            json_str = orjson.dumps(value, default=redis_json_default).decode('utf-8')
            return bool(await client.setex(key, ttl, json_str))
        except (TypeError, ValueError):
            return False

    # === Anti-Stampede Cache ===

    async def cache_get_with_lock(
        self, key: str, loader: Any, ttl: int = CacheTTL.DEFAULT,
        lock_timeout: int = 10, max_wait_time: float = 3.0,
    ) -> tuple[Any, bool]:
        client = await self._get_client()
        return await CacheOperations.cache_get_with_lock(
            self, key=key, loader=loader, client=client,
            ttl=ttl, lock_timeout=lock_timeout, max_wait_time=max_wait_time,
            record_timing=None, record_lookup=None,
        )

    async def cache_get_or_load(
        self, key: str, loader: Any, ttl: int = CacheTTL.DEFAULT,
        stale_ttl: int = CacheTTL.STALE_REFRESH,
    ) -> Any:
        client = await self._get_client()
        return await CacheOperations.cache_get_or_load(
            self, key=key, loader=loader, client=client,
            ttl=ttl, stale_ttl=stale_ttl,
            record_timing=None, record_lookup=None,
        )

    # === Stats Cache Invalidation ===

    async def invalidate_user_stats(self, user_id: int) -> None:
        client = await self._get_client()
        await client.delete(f"podcast:stats:{user_id}")

    async def invalidate_profile_stats(self, user_id: int) -> None:
        client = await self._get_client()
        await client.delete(f"podcast:stats:profile:{user_id}")

    # === User Stats ===

    async def get_user_stats(self, user_id: int) -> dict | None:
        client = await self._get_client()
        return await PodcastCacheOperations.get_user_stats(
            self, client, user_id, cache_get_json_func=self.cache_get_json
        )

    async def set_user_stats(self, user_id: int, stats: dict) -> bool:
        client = await self._get_client()
        return await PodcastCacheOperations.set_user_stats(
            self, client, user_id, stats, cache_set_json_func=self.cache_set_json
        )

    async def get_profile_stats(self, user_id: int) -> dict | None:
        client = await self._get_client()
        return await PodcastCacheOperations.get_profile_stats(
            self, client, user_id, cache_get_json_func=self.cache_get_json
        )

    async def set_profile_stats(self, user_id: int, stats: dict) -> bool:
        client = await self._get_client()
        return await PodcastCacheOperations.set_profile_stats(
            self, client, user_id, stats, cache_set_json_func=self.cache_set_json
        )

    # === Subscription List ===

    async def get_subscription_list(self, user_id: int, page: int, size: int, filters: dict[str, Any] | None = None) -> dict | None:
        client = await self._get_client()
        return await PodcastCacheOperations.get_subscription_list(
            self, client, user_id, page, size, filters=filters, cache_get_json_func=self.cache_get_json
        )

    async def set_subscription_list(self, user_id: int, page: int, size: int, data: dict, filters: dict[str, Any] | None = None) -> bool:
        client = await self._get_client()
        return await PodcastCacheOperations.set_subscription_list(
            self, client, user_id, page, size, data, filters=filters,
            cache_set_json_func=self.cache_set_json, expire_func=None,
        )

    async def invalidate_subscription_list(self, user_id: int) -> None:
        client = await self._get_client()
        await PodcastCacheOperations.invalidate_subscription_list(
            self, client, user_id, scan_keys_func=self.scan_keys, delete_keys_func=self._delete_keys
        )

    # === Episode List ===

    async def get_episode_list(self, subscription_id: int, page: int, size: int) -> dict | None:
        client = await self._get_client()
        return await PodcastCacheOperations.get_episode_list(
            self, client, subscription_id, page, size, cache_get_json_func=self.cache_get_json
        )

    async def set_episode_list(self, subscription_id: int, page: int, size: int, data: dict) -> bool:
        client = await self._get_client()
        return await PodcastCacheOperations.set_episode_list(
            self, client, subscription_id, page, size, data,
            cache_set_json_func=self.cache_set_json, expire_func=None,
        )

    async def invalidate_episode_list(self, subscription_id: int) -> None:
        client = await self._get_client()
        await PodcastCacheOperations.invalidate_episode_list(
            self, client, subscription_id, scan_keys_func=self.scan_keys, delete_keys_func=self._delete_keys
        )

    # === User Progress ===

    async def set_user_progress(self, user_id: int, episode_id: int, progress: float) -> None:
        client = await self._get_client()
        await client.setex(f"podcast:progress:{user_id}:{episode_id}", CacheTTL.PLAYBACK_PROGRESS, str(progress))

    async def get_user_progress(self, user_id: int, episode_id: int) -> float | None:
        client = await self._get_client()
        progress = await client.get(f"podcast:progress:{user_id}:{episode_id}")
        return float(progress) if progress else None

    # === Episode Metadata ===

    async def set_episode_metadata(self, episode_id: int, metadata: dict) -> None:
        client = await self._get_client()
        key = f"podcast:meta:{episode_id}"
        await client.hset(key, mapping=metadata)
        await client.expire(key, CacheTTL.EPISODE_METADATA)

    # === Sorted Set Operations ===

    async def sorted_set_add(self, key: str, member: str, score: float) -> int:
        client = await self._get_client()
        return await SortedSetOperations.sorted_set_add(self, client, key, member, score)

    async def sorted_set_remove(self, key: str, *members: str) -> int:
        client = await self._get_client()
        return await SortedSetOperations.sorted_set_remove(self, client, key, *members)

    async def sorted_set_cardinality(self, key: str) -> int:
        client = await self._get_client()
        return await SortedSetOperations.sorted_set_cardinality(self, client, key)

    async def sorted_set_range_by_score(self, key: str, min_score: float | str, max_score: float | str) -> list[str]:
        client = await self._get_client()
        return await SortedSetOperations.sorted_set_range_by_score(self, client, key, min_score, max_score)

    async def sorted_set_remove_by_score(self, key: str, min_score: float | str, max_score: float | str) -> int:
        client = await self._get_client()
        return await SortedSetOperations.sorted_set_remove_by_score(self, client, key, min_score, max_score)

    # === Distributed Lock ===

    async def acquire_lock(self, lock_name: str, expire: int = CacheTTL.LOCK_TIMEOUT, value: str = "1") -> bool:
        client = await self._get_client()
        return bool(await client.set(f"podcast:lock:{lock_name}", value, ex=expire, nx=True))

    async def release_lock(self, lock_name: str) -> None:
        client = await self._get_client()
        await client.delete(f"podcast:lock:{lock_name}")

    async def set_if_not_exists(self, key: str, value: str, *, ttl: int | None = None) -> bool:
        client = await self._get_client()
        return bool(await client.set(key, value, ex=ttl, nx=True))

    async def acquire_owned_lock(self, lock_name: str, *, expire: int = CacheTTL.LOCK_TIMEOUT) -> str | None:
        client = await self._get_client()
        token = secrets.token_urlsafe(16)
        acquired = await client.set(f"podcast:lock:{lock_name}", token, ex=expire, nx=True)
        return token if acquired else None

    async def release_owned_lock(self, lock_name: str, token: str) -> bool:
        client = await self._get_client()
        result = await client.eval(
            'if redis.call("get", KEYS[1]) == ARGV[1] then return redis.call("del", KEYS[1]) end return 0',
            1, f"podcast:lock:{lock_name}", token,
        )
        return bool(result)

    # === Stub for removed metrics ===

    async def get_runtime_metrics(self, client: Any = None) -> dict[str, Any]:
        """Return empty metrics (batched metrics system removed)."""
        return {
            "commands": {"total": 0, "errors": 0, "avg_ms": 0.0, "max_ms": 0.0},
            "cache": {"hits": 0, "misses": 0, "hit_rate": 0.0},
        }

    async def _record_command_timing(self, command: str, duration_ms: float) -> None:
        """No-op stub (metrics recording removed)."""

    async def _record_cache_lookup(self, key: str, hit: bool) -> None:
        """No-op stub (metrics recording removed)."""


# Backward-compatible alias
PodcastRedis = AppCache


# === Module-level Functions ===

async def get_redis() -> AppCache:
    """Create a Redis helper."""
    return AppCache()


async def get_redis_runtime_metrics() -> dict[str, Any]:
    """Get Redis runtime metrics (stub - metrics system removed)."""
    redis = get_shared_redis()
    return await redis.get_runtime_metrics()


def get_shared_redis() -> AppCache:
    """Return a process-level shared Redis helper."""
    global _shared_redis
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
    "get_redis_runtime_metrics",
    "_NULL_VALUE_MARKER",
    "_NULL_CACHE_TTL",
    "safe_cache_get",
    "safe_cache_write",
    "safe_cache_invalidate",
]
