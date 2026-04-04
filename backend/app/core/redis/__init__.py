"""Redis cache with distributed lock and sorted sets.

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
from app.core.redis.metrics_collector import RuntimeMetricsCollector
from app.core.redis.podcast_cache import PodcastCacheOperations
from app.core.redis.sorted_set import SortedSetOperations


logger = logging.getLogger(__name__)

# Null value cache constants (kept from penetration module)
_NULL_VALUE_MARKER = "__NULL__"
_NULL_CACHE_TTL = 60

# Shared instance for process-level reuse
_shared_redis: "AppCache | None" = None

# Module-level metrics collector for runtime observability
_metrics_collector = RuntimeMetricsCollector()

# ---------------------------------------------------------------------------
# Delegation decorator: replaces boilerplate wrapper methods
# ---------------------------------------------------------------------------

# Each entry maps the public method name to the (mixin_class, mixin_method_name)
# and optional extra keyword args injected into every call.
_DELEGATE_SPECS: dict[str, tuple[type, str, dict[str, Any]]] = {
    # --- CacheOperations (client passed as first positional arg) ---
    "cache_get":          (CacheOperations, "cache_get", {}),
    "cache_set":          (CacheOperations, "cache_set", {}),
    "cache_delete":       (CacheOperations, "cache_delete", {}),
    "cache_hget":         (CacheOperations, "cache_hget", {}),
    "cache_hgetall":      (CacheOperations, "cache_hgetall", {}),
    "cache_hset":         (CacheOperations, "cache_hset", {}),
    # --- SortedSetOperations ---
    "sorted_set_add":              (SortedSetOperations, "sorted_set_add", {}),
    "sorted_set_remove":           (SortedSetOperations, "sorted_set_remove", {}),
    "sorted_set_cardinality":      (SortedSetOperations, "sorted_set_cardinality", {}),
    "sorted_set_range_by_score":   (SortedSetOperations, "sorted_set_range_by_score", {}),
    "sorted_set_remove_by_score":  (SortedSetOperations, "sorted_set_remove_by_score", {}),
}


def _apply_delegates(cls: type) -> type:
    """Class decorator that attaches auto-delegation methods to *cls*.

    For every entry in ``_DELEGATE_SPECS`` a ``async def method(self, *args, **kwargs)``
    is created on the class.  The generated method obtains a Redis client via
    ``self._get_client()``, inserts it as the second positional argument (after
    *self*), merges any fixed extra kwargs, and forwards to the mixin method.
    """
    for method_name, (mixin_cls, mixin_method_name, extra_kw) in _DELEGATE_SPECS.items():
        _make_delegate(cls, method_name, mixin_cls, mixin_method_name, extra_kw)
    return cls


def _make_delegate(
    cls: type,
    method_name: str,
    mixin_cls: type,
    mixin_method_name: str,
    extra_kw: dict[str, Any],
) -> None:
    """Create and attach a single delegation method to *cls*."""

    mixin_fn = getattr(mixin_cls, mixin_method_name)

    async def _delegate(self, *args: Any, **kwargs: Any) -> Any:
        client = await self._get_client()
        kwargs.update(extra_kw)
        return await mixin_fn(self, client, *args, **kwargs)

    _delegate.__qualname__ = f"{cls.__name__}.{method_name}"
    _delegate.__name__ = method_name
    setattr(cls, method_name, _delegate)


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


@_apply_delegates
class AppCache(
    RedisClientManager,
    CacheOperations,
    PodcastCacheOperations,
    LockOperations,
    SortedSetOperations,
):
    """Unified Redis cache with distributed lock and sorted sets."""

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

    # === Custom JSON cache overrides (inline client handling) ===

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

    # === Anti-Stampede Cache (extra kwargs injected) ===

    async def cache_get_with_lock(
        self, key: str, loader: Any, ttl: int = CacheTTL.DEFAULT,
        lock_timeout: int = 10, max_wait_time: float = 3.0,
    ) -> tuple[Any, bool]:
        client = await self._get_client()
        return await CacheOperations.cache_get_with_lock(
            self, key=key, loader=loader, client=client,
            ttl=ttl, lock_timeout=lock_timeout, max_wait_time=max_wait_time,
            record_timing=_metrics_collector.record_timing,
            record_lookup=_metrics_collector.record_lookup,
        )

    async def cache_get_or_load(
        self, key: str, loader: Any, ttl: int = CacheTTL.DEFAULT,
        stale_ttl: int = CacheTTL.STALE_REFRESH,
    ) -> Any:
        client = await self._get_client()
        return await CacheOperations.cache_get_or_load(
            self, key=key, loader=loader, client=client,
            ttl=ttl, stale_ttl=stale_ttl,
            record_timing=_metrics_collector.record_timing,
            record_lookup=_metrics_collector.record_lookup,
        )

    # === Stats Cache Invalidation ===

    async def invalidate_user_stats(self, user_id: int) -> None:
        client = await self._get_client()
        await client.delete(f"podcast:stats:{user_id}")

    async def invalidate_profile_stats(self, user_id: int) -> None:
        client = await self._get_client()
        await client.delete(f"podcast:stats:profile:{user_id}")

    # === User Stats (custom kwargs) ===

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

    # === Subscription List (custom kwargs) ===

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

    # === Episode List (custom kwargs) ===

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

    # === Episode Metadata (direct) ===

    async def set_episode_metadata(self, episode_id: int, metadata: dict) -> None:
        client = await self._get_client()
        key = f"podcast:meta:{episode_id}"
        await client.hset(key, mapping=metadata)
        await client.expire(key, CacheTTL.EPISODE_METADATA)

    # === Distributed Lock (inline implementations) ===

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


# Backward-compatible alias
PodcastRedis = AppCache


# === Module-level Functions ===

async def get_redis() -> AppCache:
    """Create a Redis helper."""
    return AppCache()


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


def get_redis_runtime_metrics() -> dict[str, Any]:
    """Get runtime metrics from the metrics collector.

    Returns real metrics tracked by the ``RuntimeMetricsCollector`` including
    command latencies, cache hit/miss counts, and error counts.
    """
    return _metrics_collector.get_metrics()


def get_null_redis_runtime_metrics() -> dict[str, Any]:
    """Deprecated: Use ``get_redis_runtime_metrics`` instead.

    Kept for backward compatibility with callers that import this name.
    Now returns real runtime metrics instead of zero-value placeholders.
    """
    return get_redis_runtime_metrics()


__all__ = [
    "AppCache",
    "PodcastRedis",
    "get_redis",
    "get_shared_redis",
    "close_shared_redis",
    "get_redis_runtime_metrics",
    "get_null_redis_runtime_metrics",
    "_NULL_VALUE_MARKER",
    "_NULL_CACHE_TTL",
    "safe_cache_get",
    "safe_cache_write",
    "safe_cache_invalidate",
]
