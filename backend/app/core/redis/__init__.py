"""Redis Helper - Modular Structure.

This package provides a unified interface to Redis operations through the PodcastRedis class.
The modules are organized by functionality:

Usage:
    from app.core.redis import PodcastRedis, get_redis, get_shared_redis

    redis = await get_redis()
    await redis.cache_set("key", "value", ttl=3600)
"""

import asyncio
import logging
from contextlib import suppress
from time import perf_counter
from typing import Any

import orjson

from redis import asyncio as aioredis

from app.core.config import settings
from app.core.cache_ttl import CacheTTL

from app.core.redis.client import RedisClientManager
from app.core.redis.cache import CacheOperations
from app.core.redis.podcast_cache import PodcastCacheOperations
from app.core.redis.lock import LockOperations
from app.core.redis.rate_limit import RateLimitOperations
from app.core.redis.metrics import MetricsOperations, _METRICS_COMMANDS_KEY, _METRICS_CACHE_KEY, _METRICS_CACHE_PENETRATION_KEY
from app.core.redis.sorted_set import SortedSetOperations
from app.core.redis.penetration import PenetrationOperations, _NULL_VALUE_MARKER, _NULL_CACHE_TTL
from app.core.redis.cache import (
    safe_cache_get,
    safe_cache_write,
    safe_cache_invalidate,
)

logger = logging.getLogger(__name__)

# Shared instance for process-level reuse
_shared_redis: "PodcastRedis | None" = None


class _DeferredScript:
    """Deferred Lua script that gets the client when executed.

    This handles the case where register_script is called before
    the Redis client is initialized (e.g., during middleware setup).
    """

    def __init__(self, redis_helper: "PodcastRedis", script: str):
        self._redis = redis_helper
        self._script = script
        self._cached_script = None

    async def __call__(self, keys: list[str] = None, args: list[Any] = None):
        """Execute the script with the given keys and arguments."""
        if self._cached_script is None:
            client = await self._redis._get_client()
            self._cached_script = client.register_script(self._script)
        return await self._cached_script(keys=keys, args=args)


class PodcastRedis(
    RedisClientManager,
    CacheOperations,
    PodcastCacheOperations,
    LockOperations,
    RateLimitOperations,
    MetricsOperations,
    SortedSetOperations,
    PenetrationOperations,
):
    """Simple Redis wrapper for podcast features with distributed metrics.

    This class combines all operation mixins into a unified interface.
    """

    # Import static methods from mixins (only true static methods)
    _hash_search_query = PodcastCacheOperations._hash_search_query
    _cache_namespace = MetricsOperations._cache_namespace

    def __init__(self):
        # Initialize all mixin classes
        RedisClientManager.__init__(self)
        # Other mixins don't need initialization

    # Delegate _get_client to RedisClientManager
    async def _get_client(self) -> aioredis.Redis:
        return await RedisClientManager._get_client(self)

    # === Key Scanning ===

    async def _scan_keys(self, pattern: str) -> list[str]:
        """Scan for keys matching a pattern."""
        client = await self._get_client()
        keys: list[str] = []
        started = perf_counter()
        async for key in client.scan_iter(match=pattern):
            keys.append(key)
        await self._record_command_timing("SCAN_ITER", (perf_counter() - started) * 1000)
        return keys

    async def scan_keys(self, pattern: str) -> list[str]:
        """Public API for key scanning."""
        return await self._scan_keys(pattern)

    # === Key Deletion ===

    async def _delete_keys_nonblocking(self, *keys: str) -> int:
        """Delete keys using UNLINK when available to reduce Redis main-thread blocking."""
        if not keys:
            return 0

        client = await self._get_client()
        started = perf_counter()
        try:
            result = await client.unlink(*keys)
            await self._record_command_timing("UNLINK", (perf_counter() - started) * 1000)
            return int(result or 0)
        except Exception:
            # Fall back to DEL for Redis deployments without UNLINK support.
            fallback_started = perf_counter()
            result = await client.delete(*keys)
            await self._record_command_timing(
                "DEL", (perf_counter() - fallback_started) * 1000
            )
            return int(result or 0)

    async def delete_keys(self, *keys: str) -> int:
        """Delete one or more keys."""
        return await self._delete_keys_nonblocking(*keys)

    # === Pipeline Support ===

    def pipeline(self):
        """Return a Redis pipeline context manager."""
        return self._PipelineContextManager(self)

    class _PipelineContextManager:
        """Context manager for Redis pipeline operations."""

        def __init__(self, redis_helper: "PodcastRedis"):
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
            """Delegate attribute access to the pipeline."""
            return getattr(self._pipe, name)

    # === Raw Client Access ===

    async def incr(self, key: str) -> int:
        """Increment the value of a key by 1."""
        client = await self._get_client()
        started = perf_counter()
        result = await client.incr(key)
        await self._record_command_timing("INCR", (perf_counter() - started) * 1000)
        return int(result or 0)

    async def expire(self, key: str, seconds: int) -> bool:
        """Set a key's time to live in seconds."""
        client = await self._get_client()
        started = perf_counter()
        result = await client.expire(key, seconds)
        await self._record_command_timing("EXPIRE", (perf_counter() - started) * 1000)
        return bool(result)

    async def get(self, key: str) -> str | None:
        """Get the value of a key (raw access)."""
        return await self.cache_get(key)

    async def setex(self, key: str, ttl: int, value: str) -> bool:
        """Set key with expiry (raw access)."""
        return await self.cache_set(key, value, ttl=ttl)

    async def ttl(self, key: str) -> int:
        """Get the time to live for a key in seconds."""
        client = await self._get_client()
        started = perf_counter()
        result = await client.ttl(key)
        await self._record_command_timing("TTL", (perf_counter() - started) * 1000)
        return int(result or -1)

    async def get_ttl(self, key: str) -> int:
        """Get key TTL in seconds."""
        return await self.ttl(key)

    # === Lua Script Support ===

    def register_script(self, script: str):
        """Register a Lua script for execution.

        This is a synchronous wrapper that returns a Script object
        which can be used to execute the script later.

        Args:
            script: The Lua script content.

        Returns:
            A Script object that can be called to execute the script.
        """
        # Get the client synchronously - this is safe because register_script
        # just creates a Script object that will be executed later
        if self._client is None:
            # Client not initialized yet - return a deferred script
            # that will get the client when executed
            return _DeferredScript(self, script)

        return self._client.register_script(script)

    # === Wrapper Methods for Mixin Integration ===
    # These methods wrap mixin methods to provide a clean API

    async def cache_get(self, key: str) -> str | None:
        """Get cached value."""
        client = await self._get_client()
        started = perf_counter()
        value = await CacheOperations.cache_get(self, client, key)
        await self._record_command_timing("GET", (perf_counter() - started) * 1000)
        return value

    async def cache_set(self, key: str, value: str, ttl: int = CacheTTL.DEFAULT) -> bool:
        """Set cached value with TTL."""
        client = await self._get_client()
        started = perf_counter()
        result = await CacheOperations.cache_set(self, client, key, value, ttl)
        await self._record_command_timing("SETEX", (perf_counter() - started) * 1000)
        return result

    async def cache_delete(self, key: str) -> bool:
        """Delete cached value."""
        client = await self._get_client()
        started = perf_counter()
        result = await CacheOperations.cache_delete(self, client, key)
        await self._record_command_timing("DEL", (perf_counter() - started) * 1000)
        return result

    async def cache_hget(self, key: str, field: str) -> str | None:
        """Get hash field."""
        client = await self._get_client()
        started = perf_counter()
        value = await CacheOperations.cache_hget(self, client, key, field)
        await self._record_command_timing("HGET", (perf_counter() - started) * 1000)
        return value

    async def cache_hgetall(self, key: str) -> dict[str, str]:
        """Get all hash fields."""
        client = await self._get_client()
        started = perf_counter()
        value = await CacheOperations.cache_hgetall(self, client, key)
        await self._record_command_timing("HGETALL", (perf_counter() - started) * 1000)
        return value

    async def cache_hset(self, key: str, mapping: dict, ttl: int | None = None) -> int:
        """Set hash fields with optional TTL."""
        client = await self._get_client()
        started = perf_counter()
        result = await CacheOperations.cache_hset(self, client, key, mapping, ttl)
        await self._record_command_timing("HSET", (perf_counter() - started) * 1000)
        if ttl:
            expire_started = perf_counter()
            await client.expire(key, ttl)
            await self._record_command_timing(
                "EXPIRE",
                (perf_counter() - expire_started) * 1000,
            )
        return result

    async def cache_get_json(self, key: str) -> Any | None:
        """Get and parse JSON from cache."""
        client = await self._get_client()
        started = perf_counter()
        data = await client.get(key)
        await self._record_command_timing("GET", (perf_counter() - started) * 1000)
        if data:
            try:
                value = orjson.loads(data)
                await self._record_cache_lookup(key, hit=True)
                return value
            except orjson.JSONDecodeError:
                await self._record_cache_lookup(key, hit=False)
                return None
        await self._record_cache_lookup(key, hit=False)
        return None

    async def cache_set_json(self, key: str, value: Any, ttl: int = CacheTTL.DEFAULT) -> bool:
        """Serialize and cache JSON value."""
        from app.core.redis.client import redis_json_default
        client = await self._get_client()
        started = perf_counter()
        try:
            json_str = orjson.dumps(value, default=redis_json_default).decode('utf-8')
            result = await client.setex(key, ttl, json_str)
            await self._record_command_timing("SETEX", (perf_counter() - started) * 1000)
            return bool(result)
        except (TypeError, ValueError):
            return False

    # === Stats Cache Invalidation ===

    async def invalidate_user_stats(self, user_id: int) -> None:
        """Invalidate user stats cache."""
        client = await self._get_client()
        key = f"podcast:stats:{user_id}"
        started = perf_counter()
        await client.delete(key)
        await self._record_command_timing("DEL", (perf_counter() - started) * 1000)

    async def invalidate_profile_stats(self, user_id: int) -> None:
        """Invalidate profile stats cache."""
        client = await self._get_client()
        key = f"podcast:stats:profile:{user_id}"
        started = perf_counter()
        await client.delete(key)
        await self._record_command_timing("DEL", (perf_counter() - started) * 1000)

    # === User Stats Wrapper Methods ===

    async def get_user_stats(self, user_id: int) -> dict | None:
        """Get cached user statistics."""
        client = await self._get_client()
        started = perf_counter()
        result = await PodcastCacheOperations.get_user_stats(
            self, client, user_id, cache_get_json_func=self.cache_get_json
        )
        await self._record_command_timing("GET", (perf_counter() - started) * 1000)
        return result

    async def set_user_stats(self, user_id: int, stats: dict) -> bool:
        """Cache user statistics."""
        client = await self._get_client()
        started = perf_counter()
        result = await PodcastCacheOperations.set_user_stats(
            self, client, user_id, stats, cache_set_json_func=self.cache_set_json
        )
        await self._record_command_timing("SETEX", (perf_counter() - started) * 1000)
        return result

    async def get_profile_stats(self, user_id: int) -> dict | None:
        """Get cached profile statistics."""
        client = await self._get_client()
        started = perf_counter()
        result = await PodcastCacheOperations.get_profile_stats(
            self, client, user_id, cache_get_json_func=self.cache_get_json
        )
        await self._record_command_timing("GET", (perf_counter() - started) * 1000)
        return result

    async def set_profile_stats(self, user_id: int, stats: dict) -> bool:
        """Cache profile statistics."""
        client = await self._get_client()
        started = perf_counter()
        result = await PodcastCacheOperations.set_profile_stats(
            self, client, user_id, stats, cache_set_json_func=self.cache_set_json
        )
        await self._record_command_timing("SETEX", (perf_counter() - started) * 1000)
        return result

    # === Subscription List Wrapper Methods ===

    async def get_subscription_list(
        self,
        user_id: int,
        page: int,
        size: int,
        filters: dict[str, Any] | None = None
    ) -> dict | None:
        """Get cached subscription list."""
        client = await self._get_client()
        started = perf_counter()
        result = await PodcastCacheOperations.get_subscription_list(
            self, client, user_id, page, size, filters=filters,
            cache_get_json_func=self.cache_get_json
        )
        await self._record_command_timing("GET", (perf_counter() - started) * 1000)
        return result

    async def set_subscription_list(
        self,
        user_id: int,
        page: int,
        size: int,
        data: dict,
        filters: dict[str, Any] | None = None
    ) -> bool:
        """Cache subscription list."""
        client = await self._get_client()
        started = perf_counter()
        result = await PodcastCacheOperations.set_subscription_list(
            self, client, user_id, page, size, data, filters=filters,
            cache_set_json_func=self.cache_set_json,
            expire_func=self._record_command_timing
        )
        await self._record_command_timing("SETEX", (perf_counter() - started) * 1000)
        return result

    async def invalidate_subscription_list(self, user_id: int) -> None:
        """Invalidate all subscription list caches for a user."""
        client = await self._get_client()
        started = perf_counter()
        await PodcastCacheOperations.invalidate_subscription_list(
            self, client, user_id,
            scan_keys_func=self.scan_keys,
            delete_keys_func=self._delete_keys
        )
        await self._record_command_timing("DEL", (perf_counter() - started) * 1000)

    # === Episode List Wrapper Methods ===

    async def get_episode_list(
        self, subscription_id: int, page: int, size: int
    ) -> dict | None:
        """Get cached episode list."""
        client = await self._get_client()
        started = perf_counter()
        result = await PodcastCacheOperations.get_episode_list(
            self, client, subscription_id, page, size,
            cache_get_json_func=self.cache_get_json
        )
        await self._record_command_timing("GET", (perf_counter() - started) * 1000)
        return result

    async def set_episode_list(
        self, subscription_id: int, page: int, size: int, data: dict
    ) -> bool:
        """Cache episode list."""
        client = await self._get_client()
        started = perf_counter()
        result = await PodcastCacheOperations.set_episode_list(
            self, client, subscription_id, page, size, data,
            cache_set_json_func=self.cache_set_json,
            expire_func=self._record_command_timing
        )
        await self._record_command_timing("SETEX", (perf_counter() - started) * 1000)
        return result

    async def invalidate_episode_list(self, subscription_id: int) -> None:
        """Invalidate all episode list caches for a subscription."""
        client = await self._get_client()
        started = perf_counter()
        await PodcastCacheOperations.invalidate_episode_list(
            self, client, subscription_id,
            scan_keys_func=self.scan_keys,
            delete_keys_func=self._delete_keys
        )
        await self._record_command_timing("DEL", (perf_counter() - started) * 1000)

    # === User Progress ===

    async def set_user_progress(self, user_id: int, episode_id: int, progress: float) -> None:
        """Set user progress (30 days TTL)."""
        client = await self._get_client()
        key = f"podcast:progress:{user_id}:{episode_id}"
        started = perf_counter()
        await client.setex(key, CacheTTL.PLAYBACK_PROGRESS, str(progress))
        await self._record_command_timing("SETEX", (perf_counter() - started) * 1000)

    async def get_user_progress(self, user_id: int, episode_id: int) -> float | None:
        """Get user listening progress."""
        client = await self._get_client()
        key = f"podcast:progress:{user_id}:{episode_id}"
        started = perf_counter()
        progress = await client.get(key)
        await self._record_command_timing("GET", (perf_counter() - started) * 1000)
        return float(progress) if progress else None

    # === Episode Metadata ===

    async def set_episode_metadata(self, episode_id: int, metadata: dict) -> None:
        """Cache episode metadata (24 hours TTL)."""
        client = await self._get_client()
        key = f"podcast:meta:{episode_id}"
        started = perf_counter()
        await client.hset(key, mapping=metadata)
        await client.expire(key, CacheTTL.EPISODE_METADATA)
        await self._record_command_timing("HSET", (perf_counter() - started) * 1000)

    # === Sorted Set Operations ===

    async def sorted_set_add(self, key: str, member: str, score: float) -> int:
        """Add or update one member in a sorted set."""
        client = await self._get_client()
        started = perf_counter()
        result = await SortedSetOperations.sorted_set_add(self, client, key, member, score)
        await self._record_command_timing("ZADD", (perf_counter() - started) * 1000)
        return result

    async def sorted_set_remove(self, key: str, *members: str) -> int:
        """Remove one or more members from a sorted set."""
        client = await self._get_client()
        started = perf_counter()
        result = await SortedSetOperations.sorted_set_remove(self, client, key, *members)
        await self._record_command_timing("ZREM", (perf_counter() - started) * 1000)
        return result

    async def sorted_set_cardinality(self, key: str) -> int:
        """Return the number of members in a sorted set."""
        client = await self._get_client()
        started = perf_counter()
        result = await SortedSetOperations.sorted_set_cardinality(self, client, key)
        await self._record_command_timing("ZCARD", (perf_counter() - started) * 1000)
        return result

    async def sorted_set_range_by_score(
        self, key: str, min_score: float | str, max_score: float | str
    ) -> list[str]:
        """Return sorted-set members whose scores fall within the inclusive range."""
        client = await self._get_client()
        started = perf_counter()
        result = await SortedSetOperations.sorted_set_range_by_score(
            self, client, key, min_score, max_score
        )
        await self._record_command_timing("ZRANGEBYSCORE", (perf_counter() - started) * 1000)
        return result

    async def sorted_set_remove_by_score(
        self, key: str, min_score: float | str, max_score: float | str
    ) -> int:
        """Remove sorted-set members whose scores fall within the inclusive range."""
        client = await self._get_client()
        started = perf_counter()
        result = await SortedSetOperations.sorted_set_remove_by_score(
            self, client, key, min_score, max_score
        )
        await self._record_command_timing("ZREMRANGEBYSCORE", (perf_counter() - started) * 1000)
        return result

    # === Distributed Lock ===

    async def acquire_lock(
        self, lock_name: str, expire: int = CacheTTL.LOCK_TIMEOUT, value: str = "1"
    ) -> bool:
        """Acquire distributed lock. Returns True if lock acquired."""
        client = await self._get_client()
        key = f"podcast:lock:{lock_name}"
        started = perf_counter()
        result = await client.set(key, value, ex=expire, nx=True)
        await self._record_command_timing("SET", (perf_counter() - started) * 1000)
        return bool(result)

    async def release_lock(self, lock_name: str) -> None:
        """Release distributed lock."""
        client = await self._get_client()
        key = f"podcast:lock:{lock_name}"
        started = perf_counter()
        await client.delete(key)
        await self._record_command_timing("DEL", (perf_counter() - started) * 1000)

    async def set_if_not_exists(self, key: str, value: str, *, ttl: int | None = None) -> bool:
        """Set a key only if it does not already exist. Returns True if set."""
        client = await self._get_client()
        started = perf_counter()
        result = await client.set(key, value, ex=ttl, nx=True)
        await self._record_command_timing("SET", (perf_counter() - started) * 1000)
        return bool(result)

    async def acquire_owned_lock(
        self, lock_name: str, *, expire: int = CacheTTL.LOCK_TIMEOUT
    ) -> str | None:
        """Acquire a lock and return its owner token when successful."""
        import secrets
        client = await self._get_client()
        token = secrets.token_urlsafe(16)
        key = f"podcast:lock:{lock_name}"
        started = perf_counter()
        acquired = await client.set(key, token, ex=expire, nx=True)
        await self._record_command_timing("SET", (perf_counter() - started) * 1000)
        return token if acquired else None

    async def release_owned_lock(self, lock_name: str, token: str) -> bool:
        """Release a lock only when the stored token matches the caller token."""
        client = await self._get_client()
        started = perf_counter()
        result = await client.eval(
            """
            if redis.call("get", KEYS[1]) == ARGV[1] then
                return redis.call("del", KEYS[1])
            end
            return 0
            """,
            1,
            f"podcast:lock:{lock_name}",
            token,
        )
        await self._record_command_timing("EVAL", (perf_counter() - started) * 1000)
        return bool(result)

    # === Anti-Stampede Cache ===

    async def cache_get_with_lock(
        self,
        key: str,
        loader: Any,
        ttl: int = CacheTTL.DEFAULT,
        lock_timeout: int = 10,
        max_wait_time: float = 3.0,
    ) -> tuple[Any, bool]:
        """Get cached value with distributed lock to prevent cache stampede."""
        # Try to get from cache first
        value = await self.cache_get_json(key)
        if value is not None:
            await self._record_cache_lookup(key, hit=True)
            return value, True

        # Try to acquire lock
        lock_key = f"lock:{key}"
        client = await self._get_client()
        started = perf_counter()
        lock_acquired = await client.set(lock_key, "1", nx=True, ex=lock_timeout)
        await self._record_command_timing("SET_NX", (perf_counter() - started) * 1000)

        if lock_acquired:
            try:
                value = await loader()
                await self.cache_set_json(key, value, ttl=ttl)
                await self._record_cache_lookup(key, hit=False)
                return value, False
            finally:
                await self._delete_keys_nonblocking(lock_key)
        else:
            # Wait with exponential backoff
            wait_start = perf_counter()
            initial_delay = 0.05
            max_delay = 0.5
            attempt = 0

            while (perf_counter() - wait_start) < max_wait_time:
                delay = min(initial_delay * (2 ** attempt), max_delay)
                await asyncio.sleep(delay)

                value = await self.cache_get_json(key)
                if value is not None:
                    await self._record_cache_lookup(key, hit=True)
                    return value, True

                started = perf_counter()
                lock_exists = await client.exists(lock_key)
                await self._record_command_timing("EXISTS", (perf_counter() - started) * 1000)

                if not lock_exists:
                    started = perf_counter()
                    lock_acquired = await client.set(lock_key, "1", nx=True, ex=lock_timeout)
                    await self._record_command_timing("SET_NX", (perf_counter() - started) * 1000)

                    if lock_acquired:
                        try:
                            value = await loader()
                            await self.cache_set_json(key, value, ttl=ttl)
                            await self._record_cache_lookup(key, hit=False)
                            return value, False
                        finally:
                            await self._delete_keys_nonblocking(lock_key)

                attempt += 1

            # Fallback
            value = await loader()
            await self.cache_set_json(key, value, ttl=ttl)
            await self._record_cache_lookup(key, hit=False)
            return value, False

    async def cache_get_or_load(
        self,
        key: str,
        loader: Any,
        ttl: int = CacheTTL.DEFAULT,
        stale_ttl: int = CacheTTL.STALE_REFRESH,
    ) -> Any:
        """Get cached value with stale-while-revalidate pattern."""
        value = await self.cache_get_json(key)
        if value is not None:
            client = await self._get_client()
            started = perf_counter()
            ttl_remaining = await client.ttl(key)
            await self._record_command_timing("TTL", (perf_counter() - started) * 1000)
            if ttl_remaining > 0 and ttl_remaining < stale_ttl:
                asyncio.create_task(self._background_refresh(key, loader, ttl))
                await self._record_cache_lookup(key, hit=True)
            return value
        value = await loader()
        await self.cache_set_json(key, value, ttl=ttl)
        await self._record_cache_lookup(key, hit=False)
        return value

    async def _background_refresh(self, key: str, loader: Any, ttl: int) -> None:
        """Background cache refresh task."""
        try:
            value = await loader()
            await self.cache_set_json(key, value, ttl=ttl)
        except Exception as e:
            logger.warning("Background cache refresh failed for key %s: %s", key, e)


# === Module-level Functions ===


async def get_redis() -> PodcastRedis:
    """Create a Redis helper through the runtime/provider layer."""
    return PodcastRedis()


async def get_redis_runtime_metrics() -> dict[str, Any]:
    """Get distributed Redis command and cache metrics from Redis storage."""
    redis = await get_redis()
    return await redis.get_runtime_metrics(await redis._get_client())


def get_shared_redis() -> PodcastRedis:
    """Return a process-level shared Redis helper."""
    global _shared_redis
    if _shared_redis is None:
        _shared_redis = PodcastRedis()
    return _shared_redis


async def close_shared_redis() -> None:
    """Close the process-level shared Redis helper if it exists."""
    global _shared_redis
    if _shared_redis is None:
        return
    await _shared_redis.close()
    _shared_redis = None


# Export all public symbols for backward compatibility
__all__ = [
    "PodcastRedis",
    "get_redis",
    "get_shared_redis",
    "close_shared_redis",
    "get_redis_runtime_metrics",
    # Export constants from submodules
    "_METRICS_COMMANDS_KEY",
    "_METRICS_CACHE_KEY",
    "_METRICS_CACHE_PENETRATION_KEY",
    "_NULL_VALUE_MARKER",
    "_NULL_CACHE_TTL",
    # Safe cache helpers
    "safe_cache_get",
    "safe_cache_write",
    "safe_cache_invalidate",
]
