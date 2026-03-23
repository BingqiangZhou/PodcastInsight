"""Redis Helper - Simplified for Personal Use

Uses single Redis DB for all personal-scale operations:
- Cache: Podcast episode metadata
- Rate limiting: RSS polling protection
- Locks: Prevent duplicate processing
- Session: User data (if needed)
- Task locks: Podcast processing coordination
- Runtime Metrics: Cross-process command and cache statistics

Recommended naming conventions:
- podcast:meta:{episode_id} - Episode metadata
- podcast:cache:{feed_url} - Feed cache
- podcast:lock:{action}:{id} - Distributed locks
- podcast:progress:{user}:{episode} - Listening progress
- podcast:summary:{episode}:{version} - AI summaries
- podcast:subscriptions:{user_id} - User subscription list
- podcast:stats:{user_id} - User statistics
- podcast:episodes:{sub_id}:{page} - Episode list page
- podcast:search:{query_hash} - Search results
- podcast:metrics:* - Runtime metrics stored in Redis
"""

import asyncio
import hashlib
import json
import secrets
from contextlib import suppress
from datetime import datetime, timedelta
from time import perf_counter
from typing import Any

from redis import asyncio as aioredis
from redis.backoff import ExponentialBackoff
from redis.retry import Retry

from app.core.config import settings


_shared_redis: "PodcastRedis | None" = None


class RedisJSONEncoder(json.JSONEncoder):
    """Custom JSON encoder for Redis that handles datetime objects"""

    def default(self, obj):
        if isinstance(obj, datetime):
            return obj.isoformat()
        return super().default(obj)


# Redis keys for distributed runtime metrics
_METRICS_COMMANDS_KEY = "podcast:metrics:commands"
_METRICS_CACHE_KEY = "podcast:metrics:cache"
_METRICS_CACHE_PENETRATION_KEY = "podcast:metrics:penetration"
_METRICS_TTL_SECONDS = 3600  # Metrics expire after 1 hour

# Null value cache marker and TTL
_NULL_VALUE_MARKER = "__NULL__"
_NULL_CACHE_TTL = 60  # 60 seconds for null value caching


class PodcastRedis:
    """Simple Redis wrapper for podcast features with distributed metrics"""

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
    def _cache_namespace(key: str) -> str:
        parts = key.split(":")
        if len(parts) >= 3:
            return ":".join(parts[:3])
        if len(parts) >= 2:
            return ":".join(parts[:2])
        return parts[0] if parts else "unknown"

    async def _record_command_timing(self, command: str, elapsed_ms: float) -> None:
        """Record command timing in Redis using atomic operations."""
        client = await self._get_client()
        started = perf_counter()
        try:
            # Use pipeline for atomic multi-operation
            async with client.pipeline() as pipe:
                # Total count and time
                pipe.hincrby(_METRICS_COMMANDS_KEY, "total_count", 1)
                pipe.hincrbyfloat(_METRICS_COMMANDS_KEY, "total_ms", elapsed_ms)

                # Track max_ms using Lua script for atomic max update
                max_update_script = """
                    local current = redis.call('HGET', KEYS[1], 'max_ms')
                    local new_val = tonumber(ARGV[1])
                    if current then
                        current = tonumber(current)
                        if new_val > current then
                            redis.call('HSET', KEYS[1], 'max_ms', new_val)
                        end
                    else
                        redis.call('HSET', KEYS[1], 'max_ms', new_val)
                    end
                """
                pipe.eval(max_update_script, 1, _METRICS_COMMANDS_KEY, elapsed_ms)

                # Per-command stats
                pipe.hincrby(f"{_METRICS_COMMANDS_KEY}:by_command:{command}", "count", 1)
                pipe.hincrbyfloat(f"{_METRICS_COMMANDS_KEY}:by_command:{command}", "total_ms", elapsed_ms)

                # Update max_ms for specific command
                pipe.eval(max_update_script, 1, f"{_METRICS_COMMANDS_KEY}:by_command:{command}", elapsed_ms)

                # Set TTL on all keys
                pipe.expire(_METRICS_COMMANDS_KEY, _METRICS_TTL_SECONDS)
                pipe.expire(f"{_METRICS_COMMANDS_KEY}:by_command:{command}", _METRICS_TTL_SECONDS)

                await pipe.execute()
        except Exception:
            # Silently fail to avoid impacting main operations
            pass

    async def _record_cache_lookup(self, key: str, *, hit: bool) -> None:
        """Record cache lookup in Redis using atomic operations."""
        client = await self._get_client()
        try:
            namespace = self._cache_namespace(key)
            field = "hits" if hit else "misses"

            async with client.pipeline() as pipe:
                # Global stats
                pipe.hincrby(_METRICS_CACHE_KEY, field, 1)

                # Per-namespace stats
                pipe.hincrby(f"{_METRICS_CACHE_KEY}:namespace:{namespace}", field, 1)

                # Set TTL
                pipe.expire(_METRICS_CACHE_KEY, _METRICS_TTL_SECONDS)
                pipe.expire(f"{_METRICS_CACHE_KEY}:namespace:{namespace}", _METRICS_TTL_SECONDS)

                await pipe.execute()
        except Exception:
            # Silently fail to avoid impacting main operations
            pass

    async def _record_cache_penetration(self, key: str) -> None:
        """Record cache penetration event (query for non-existent data)."""
        client = await self._get_client()
        try:
            namespace = self._cache_namespace(key)

            async with client.pipeline() as pipe:
                # Global penetration counter
                pipe.hincrby(_METRICS_CACHE_PENETRATION_KEY, "total_attempts", 1)

                # Per-namespace penetration counter
                pipe.hincrby(
                    f"{_METRICS_CACHE_PENETRATION_KEY}:namespace:{namespace}",
                    "attempts",
                    1,
                )

                # Set TTL
                pipe.expire(_METRICS_CACHE_PENETRATION_KEY, _METRICS_TTL_SECONDS)
                pipe.expire(
                    f"{_METRICS_CACHE_PENETRATION_KEY}:namespace:{namespace}",
                    _METRICS_TTL_SECONDS,
                )

                await pipe.execute()
        except Exception:
            # Silently fail to avoid impacting main operations
            pass

    async def get_runtime_metrics(self) -> dict[str, Any]:
        """Get runtime metrics from Redis (aggregated across all processes)."""
        client = await self._get_client()
        started = perf_counter()

        try:
            # Get command metrics
            commands_data = await client.hgetall(_METRICS_COMMANDS_KEY) or {}
            total_count = int(commands_data.get("total_count", 0))
            total_ms = float(commands_data.get("total_ms", 0.0))
            max_ms = float(commands_data.get("max_ms", 0.0))
            avg_ms = (total_ms / total_count) if total_count else 0.0

            # Get per-command metrics
            by_command: dict[str, Any] = {}
            command_keys_pattern = f"{_METRICS_COMMANDS_KEY}:by_command:*"
            async for key in client.scan_iter(match=command_keys_pattern):
                command_name = key.split(":")[-1]
                cmd_data = await client.hgetall(key) or {}
                count = int(cmd_data.get("count", 0))
                cmd_total_ms = float(cmd_data.get("total_ms", 0.0))
                cmd_max_ms = float(cmd_data.get("max_ms", 0.0))
                by_command[command_name] = {
                    "count": count,
                    "avg_ms": (cmd_total_ms / count) if count else 0.0,
                    "max_ms": cmd_max_ms,
                }

            # Get cache metrics
            cache_data = await client.hgetall(_METRICS_CACHE_KEY) or {}
            hits = int(cache_data.get("hits", 0))
            misses = int(cache_data.get("misses", 0))
            lookups = hits + misses
            hit_rate = (hits / lookups) if lookups else 0.0

            # Get per-namespace metrics
            by_namespace: dict[str, Any] = {}
            namespace_pattern = f"{_METRICS_CACHE_KEY}:namespace:*"
            async for key in client.scan_iter(match=namespace_pattern):
                namespace = key.split(":")[-1]
                ns_data = await client.hgetall(key) or {}
                ns_hits = int(ns_data.get("hits", 0))
                ns_misses = int(ns_data.get("misses", 0))
                ns_total = ns_hits + ns_misses
                by_namespace[namespace] = {
                    "hits": ns_hits,
                    "misses": ns_misses,
                    "hit_rate": (ns_hits / ns_total) if ns_total else 0.0,
                }

            await self._record_command_timing("HGETALL", (perf_counter() - started) * 1000)

            # Get cache penetration metrics
            penetration_data = await client.hgetall(_METRICS_CACHE_PENETRATION_KEY) or {}
            total_penetration = int(penetration_data.get("total_attempts", 0))

            # Get per-namespace penetration metrics
            penetration_by_namespace: dict[str, Any] = {}
            penetration_pattern = f"{_METRICS_CACHE_PENETRATION_KEY}:namespace:*"
            async for key in client.scan_iter(match=penetration_pattern):
                namespace = key.split(":")[-1]
                ns_data = await client.hgetall(key) or {}
                ns_attempts = int(ns_data.get("attempts", 0))
                penetration_by_namespace[namespace] = {
                    "attempts": ns_attempts,
                }

            return {
                "commands": {
                    "total_count": total_count,
                    "avg_ms": avg_ms,
                    "max_ms": max_ms,
                    "by_command": by_command,
                },
                "cache": {
                    "hits": hits,
                    "misses": misses,
                    "hit_rate": hit_rate,
                    "by_namespace": by_namespace,
                },
                "penetration": {
                    "total_attempts": total_penetration,
                    "by_namespace": penetration_by_namespace,
                },
            }
        except Exception:
            # Return empty metrics on error
            return {
                "commands": {
                    "total_count": 0,
                    "avg_ms": 0.0,
                    "max_ms": 0.0,
                    "by_command": {},
                },
                "cache": {
                    "hits": 0,
                    "misses": 0,
                    "hit_rate": 0.0,
                    "by_namespace": {},
                },
                "penetration": {
                    "total_attempts": 0,
                    "by_namespace": {},
                },
            }

    @classmethod
    def _record_command_timing_sync(cls, command: str, elapsed_ms: float) -> None:
        """Legacy method for backward compatibility - deprecated."""
        pass

    @classmethod
    def _record_cache_lookup_sync(cls, key: str, *, hit: bool) -> None:
        """Legacy method for backward compatibility - deprecated."""
        pass

    @staticmethod
    def _stable_hash(value: str) -> str:
        normalized = value.strip().lower()
        return hashlib.sha256(normalized.encode("utf-8")).hexdigest()

    @staticmethod
    def _subscription_index_key(user_id: int) -> str:
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
        payload_str = json.dumps(payload, sort_keys=True, separators=(",", ":"))
        token = self._stable_hash(payload_str)
        return f"podcast:subscriptions:v2:{user_id}:{token}"

    @staticmethod
    def _episode_index_key(subscription_id: int) -> str:
        return f"podcast:episodes:index:{subscription_id}"

    async def _scan_keys(self, pattern: str) -> list[str]:
        client = await self._get_client()
        keys: list[str] = []
        started = perf_counter()
        async for key in client.scan_iter(match=pattern):
            keys.append(key)
        await self._record_command_timing("SCAN_ITER", (perf_counter() - started) * 1000)
        return keys

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

    async def _ping_client(self, client: aioredis.Redis) -> None:
        # Note: Do NOT record timing here to avoid circular call with _get_client()
        await client.ping()

    async def _get_client(self) -> aioredis.Redis:
        """Get Redis client instance"""
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
            self._client = self._build_client()
            await self._ping_client(self._client)
            self._client_loop_token = current_loop_token
            self._last_health_check_at = perf_counter()
            return self._client

        now = perf_counter()
        if (now - self._last_health_check_at) < self._health_check_interval_seconds:
            return self._client

        try:
            await self._ping_client(self._client)
            self._last_health_check_at = now
        except Exception:
            # Reconnect if health check fails
            self._client = self._build_client()
            await self._ping_client(self._client)
            self._client_loop_token = current_loop_token
            self._last_health_check_at = perf_counter()
        return self._client

    # === Cache Operations ===

    async def cache_get(self, key: str) -> str | None:
        """Get cached value"""
        client = await self._get_client()
        started = perf_counter()
        value = await client.get(key)
        await self._record_command_timing("GET", (perf_counter() - started) * 1000)
        return value

    async def cache_set(self, key: str, value: str, ttl: int = 3600) -> bool:
        """Set cached value with TTL"""
        client = await self._get_client()
        started = perf_counter()
        result = await client.setex(key, ttl, value)
        await self._record_command_timing("SETEX", (perf_counter() - started) * 1000)
        return result

    async def cache_delete(self, key: str) -> bool:
        """Delete cached value"""
        client = await self._get_client()
        started = perf_counter()
        result = await client.delete(key)
        await self._record_command_timing("DEL", (perf_counter() - started) * 1000)
        return result

    # === Anti-Stampede Cache Operations ===

    async def cache_get_with_lock(
        self,
        key: str,
        loader: Any,
        ttl: int = 3600,
        lock_timeout: int = 10,
        max_wait_time: float = 3.0,
    ) -> tuple[Any, bool]:
        """Get cached value with distributed lock to prevent cache stampede.

        Uses exponential backoff polling when lock is held by another process.
        This prevents multiple requests from simultaneously loading the same data
        when the initial load takes longer than a short sleep interval.

        Args:
            key: Cache key
            loader: Async callable to load value if cache miss
            ttl: Cache TTL in seconds
            lock_timeout: Lock timeout in seconds
            max_wait_time: Maximum time to wait for lock holder (default 3.0 seconds)

        Returns:
            Tuple of (value, from_cache)
        """
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
                # We hold the lock, load the value
                value = await loader()
                await self.cache_set_json(key, value, ttl=ttl)
                await self._record_cache_lookup(key, hit=False)
                return value, False
            finally:
                # Release lock
                await self._delete_keys_nonblocking(lock_key)
        else:
            # Another process is loading, wait with exponential backoff
            # This prevents cache stampede when load time exceeds a short sleep
            wait_start = perf_counter()
            initial_delay = 0.05  # Start with 50ms
            max_delay = 0.5  # Cap at 500ms per attempt
            attempt = 0

            while (perf_counter() - wait_start) < max_wait_time:
                # Exponential backoff: 0.05s, 0.1s, 0.2s, 0.4s, 0.5s, 0.5s, ...
                delay = min(initial_delay * (2 ** attempt), max_delay)
                await asyncio.sleep(delay)

                # Try to get from cache again
                value = await self.cache_get_json(key)
                if value is not None:
                    await self._record_cache_lookup(key, hit=True)
                    return value, True

                # Check if lock was released (lock holder failed)
                started = perf_counter()
                lock_exists = await client.exists(lock_key)
                await self._record_command_timing("EXISTS", (perf_counter() - started) * 1000)

                if not lock_exists:
                    # Lock was released without cache being set, try to acquire it
                    started = perf_counter()
                    lock_acquired = await client.set(lock_key, "1", nx=True, ex=lock_timeout)
                    await self._record_command_timing("SET_NX", (perf_counter() - started) * 1000)

                    if lock_acquired:
                        try:
                            # We acquired the lock, load the value
                            value = await loader()
                            await self.cache_set_json(key, value, ttl=ttl)
                            await self._record_cache_lookup(key, hit=False)
                            return value, False
                        finally:
                            await self._delete_keys_nonblocking(lock_key)

                attempt += 1

            # Max wait time exceeded, load anyway as fallback
            # This ensures availability even if lock holder crashes
            value = await loader()
            await self.cache_set_json(key, value, ttl=ttl)
            await self._record_cache_lookup(key, hit=False)
            return value, False

    async def cache_get_or_load(
        self,
        key: str,
        loader: Any,
        ttl: int = 3600,
        stale_ttl: int = 300,
    ) -> Any:
        """Get cached value with stale-while-revalidate pattern.

        Returns stale data immediately while refreshing in background.

        Args:
            key: Cache key
            loader: Async callable to load value if cache miss
            ttl: Cache TTL in seconds
            stale_ttl: Refresh threshold - refresh if TTL remaining < stale_ttl

        Returns:
            Cached or freshly loaded value
        """
        value = await self.cache_get_json(key)
        if value is not None:
            # Check if we should background refresh
            client = await self._get_client()
            started = perf_counter()
            ttl_remaining = await client.ttl(key)
            await self._record_command_timing("TTL", (perf_counter() - started) * 1000)

            if ttl_remaining > 0 and ttl_remaining < stale_ttl:
                # Trigger background refresh (non-blocking)
                asyncio.create_task(self._background_refresh(key, loader, ttl))
                await self._record_cache_lookup(key, hit=True)
            return value

        # Cache miss, load synchronously
        value = await loader()
        await self.cache_set_json(key, value, ttl=ttl)
        await self._record_cache_lookup(key, hit=False)
        return value

    async def _background_refresh(
        self,
        key: str,
        loader: Any,
        ttl: int,
    ) -> None:
        """Background cache refresh task."""
        try:
            value = await loader()
            await self.cache_set_json(key, value, ttl=ttl)
        except Exception as e:
            # Log but don't raise - background task
            import logging
            logging.getLogger(__name__).warning(
                "Background cache refresh failed for key %s: %s", key, e
            )

    async def delete_keys(self, *keys: str) -> int:
        """Delete one or more keys."""
        return await self._delete_keys_nonblocking(*keys)

    async def cache_hget(self, key: str, field: str) -> str | None:
        """Get hash field"""
        client = await self._get_client()
        started = perf_counter()
        value = await client.hget(key, field)
        await self._record_command_timing("HGET", (perf_counter() - started) * 1000)
        return value

    async def cache_hgetall(self, key: str) -> dict[str, str]:
        """Get all hash fields."""
        client = await self._get_client()
        started = perf_counter()
        value = await client.hgetall(key)
        await self._record_command_timing("HGETALL", (perf_counter() - started) * 1000)
        return value

    async def cache_hset(self, key: str, mapping: dict, ttl: int | None = None) -> int:
        """Set hash fields with optional TTL"""
        client = await self._get_client()
        started = perf_counter()
        result = await client.hset(key, mapping=mapping)
        await self._record_command_timing("HSET", (perf_counter() - started) * 1000)
        if ttl:
            expire_started = perf_counter()
            await client.expire(key, ttl)
            await self._record_command_timing(
                "EXPIRE",
                (perf_counter() - expire_started) * 1000,
            )
        return result

    # === Convenience Methods ===

    async def get_episode_metadata(self, episode_id: int) -> dict | None:
        """Get cached episode metadata"""
        key = f"podcast:meta:{episode_id}"
        data = await self.cache_hgetall(key)
        return data or None

    async def set_episode_metadata(self, episode_id: int, metadata: dict) -> None:
        """Cache episode metadata (24 hours)"""
        key = f"podcast:meta:{episode_id}"
        await self.cache_hset(key, metadata, ttl=86400)

    async def get_cached_feed(self, feed_url: str) -> str | None:
        """Get cached RSS feed"""
        key = f"podcast:cache:v2:{self._stable_hash(feed_url)}"
        return await self.cache_get(key)

    async def set_cached_feed(self, feed_url: str, xml_content: str) -> None:
        """Cache RSS feed (15 minutes)"""
        key = f"podcast:cache:v2:{self._stable_hash(feed_url)}"
        await self.cache_set(key, xml_content, ttl=900)

    async def get_ai_summary(self, episode_id: int, version: str = "v1") -> str | None:
        """Get cached AI summary"""
        key = f"podcast:summary:{episode_id}:{version}"
        return await self.cache_get(key)

    async def set_ai_summary(
        self,
        episode_id: int,
        summary: str,
        version: str = "v1",
    ) -> None:
        """Cache AI summary (7 days)"""
        key = f"podcast:summary:{episode_id}:{version}"
        await self.cache_set(key, summary, ttl=604800)

    async def get_user_progress(self, user_id: int, episode_id: int) -> float | None:
        """Get user listening progress"""
        key = f"podcast:progress:{user_id}:{episode_id}"
        progress = await self.cache_get(key)
        return float(progress) if progress else None

    async def set_user_progress(
        self,
        user_id: int,
        episode_id: int,
        progress: float,
    ) -> None:
        """Set user progress (30 days)"""
        key = f"podcast:progress:{user_id}:{episode_id}"
        await self.cache_set(key, str(progress), ttl=2592000)

    # === JSON Cache Helpers ===

    async def cache_get_json(self, key: str) -> Any | None:
        """Get and parse JSON from cache"""
        data = await self.cache_get(key)
        if data:
            try:
                value = json.loads(data)
                await self._record_cache_lookup(key, hit=True)
                return value
            except json.JSONDecodeError:
                await self._record_cache_lookup(key, hit=False)
                return None
        await self._record_cache_lookup(key, hit=False)
        return None

    async def cache_set_json(self, key: str, value: Any, ttl: int = 3600) -> bool:
        """Serialize and cache JSON value"""
        try:
            json_str = json.dumps(value, cls=RedisJSONEncoder)
            return await self.cache_set(key, json_str, ttl)
        except (TypeError, ValueError):
            return False

    # === Subscription List Cache ===

    async def get_subscription_list(
        self,
        user_id: int,
        page: int,
        size: int,
        filters: dict[str, Any] | None = None,
    ) -> dict | None:
        """Get cached subscription list (15 minutes TTL)"""
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
        """Cache subscription list (15 minutes TTL) using pipeline for efficiency."""
        client = await self._get_client()
        key = self._subscription_list_key(user_id, page, size, filters=filters)
        index_key = self._subscription_index_key(user_id)

        try:
            json_str = json.dumps(data, cls=RedisJSONEncoder)
        except (TypeError, ValueError):
            return False

        started = perf_counter()
        # Use pipeline for atomic batch operations
        async with client.pipeline() as pipe:
            pipe.setex(key, 900, json_str)
            pipe.sadd(index_key, key)
            pipe.expire(index_key, 1800)
            await pipe.execute()
        await self._record_command_timing("PIPELINE_SETEX_SADD_EXPIRE", (perf_counter() - started) * 1000)
        return True

    async def invalidate_subscription_list(self, user_id: int) -> None:
        """Invalidate all subscription list caches for a user"""
        client = await self._get_client()
        index_key = self._subscription_index_key(user_id)
        started = perf_counter()
        keys = list(await client.smembers(index_key))
        await self._record_command_timing("SMEMBERS", (perf_counter() - started) * 1000)
        if not keys:
            pattern = f"podcast:subscriptions:v2:{user_id}:*"
            keys = await self._scan_keys(pattern)
        if keys:
            await self._delete_keys_nonblocking(*keys, index_key)

    # === User Stats Cache ===

    async def get_user_stats(self, user_id: int) -> dict | None:
        """Get cached user statistics (30 minutes TTL)"""
        key = f"podcast:stats:{user_id}"
        return await self.cache_get_json(key)

    async def set_user_stats(self, user_id: int, stats: dict) -> bool:
        """Cache user statistics (30 minutes TTL)"""
        key = f"podcast:stats:{user_id}"
        return await self.cache_set_json(key, stats, ttl=1800)

    async def invalidate_user_stats(self, user_id: int) -> None:
        """Invalidate user stats cache"""
        key = f"podcast:stats:{user_id}"
        await self.cache_delete(key)

    async def get_profile_stats(self, user_id: int) -> dict | None:
        """Get cached profile statistics (10 minutes TTL)."""
        key = f"podcast:stats:profile:{user_id}"
        return await self.cache_get_json(key)

    async def set_profile_stats(self, user_id: int, stats: dict) -> bool:
        """Cache profile statistics (10 minutes TTL)."""
        key = f"podcast:stats:profile:{user_id}"
        return await self.cache_set_json(key, stats, ttl=600)

    async def invalidate_profile_stats(self, user_id: int) -> None:
        """Invalidate profile stats cache."""
        key = f"podcast:stats:profile:{user_id}"
        await self.cache_delete(key)

    # === Episode List Cache ===

    async def get_episode_list(
        self,
        subscription_id: int,
        page: int,
        size: int,
    ) -> dict | None:
        """Get cached episode list (10 minutes TTL)"""
        key = f"podcast:episodes:{subscription_id}:{page}:{size}"
        return await self.cache_get_json(key)

    async def set_episode_list(
        self,
        subscription_id: int,
        page: int,
        size: int,
        data: dict,
    ) -> bool:
        """Cache episode list (10 minutes TTL) using pipeline for efficiency."""
        client = await self._get_client()
        key = f"podcast:episodes:{subscription_id}:{page}:{size}"
        index_key = self._episode_index_key(subscription_id)

        try:
            json_str = json.dumps(data, cls=RedisJSONEncoder)
        except (TypeError, ValueError):
            return False

        started = perf_counter()
        # Use pipeline for atomic batch operations
        async with client.pipeline() as pipe:
            pipe.setex(key, 600, json_str)
            pipe.sadd(index_key, key)
            pipe.expire(index_key, 1800)
            await pipe.execute()
        await self._record_command_timing("PIPELINE_SETEX_SADD_EXPIRE", (perf_counter() - started) * 1000)
        return True

    async def invalidate_episode_list(self, subscription_id: int) -> None:
        """Invalidate all episode list caches for a subscription"""
        client = await self._get_client()
        index_key = self._episode_index_key(subscription_id)
        started = perf_counter()
        keys = list(await client.smembers(index_key))
        await self._record_command_timing("SMEMBERS", (perf_counter() - started) * 1000)
        if not keys:
            pattern = f"podcast:episodes:{subscription_id}:*"
            keys = await self._scan_keys(pattern)
        if keys:
            await self._delete_keys_nonblocking(*keys, index_key)

    # === Search Results Cache ===

    def _hash_search_query(
        self,
        query: str,
        search_in: str,
        page: int,
        size: int,
    ) -> str:
        """Generate hash key for search query"""
        query_str = f"{query}:{search_in}:{page}:{size}".lower()
        return hashlib.sha256(query_str.encode("utf-8")).hexdigest()

    async def get_search_results(
        self,
        query: str,
        search_in: str,
        page: int,
        size: int,
    ) -> dict | None:
        """Get cached search results (5 minutes TTL)"""
        hash_key = self._hash_search_query(query, search_in, page, size)
        key = f"podcast:search:v2:{hash_key}"
        return await self.cache_get_json(key)

    async def set_search_results(
        self,
        query: str,
        search_in: str,
        page: int,
        size: int,
        data: dict,
    ) -> bool:
        """Cache search results (5 minutes TTL)"""
        hash_key = self._hash_search_query(query, search_in, page, size)
        key = f"podcast:search:v2:{hash_key}"
        return await self.cache_set_json(key, data, ttl=300)

    # === Batch Invalidation ===

    async def invalidate_user_caches(self, user_id: int) -> None:
        """Invalidate all user-related caches"""
        await self.invalidate_subscription_list(user_id)
        await self.invalidate_user_stats(user_id)

    # === Lock Operations ===

    async def acquire_lock(
        self,
        lock_name: str,
        expire: int = 300,
        value: str = "1",
    ) -> bool:
        """Acquire distributed lock
        Returns True if lock acquired
        """
        client = await self._get_client()
        key = f"podcast:lock:{lock_name}"
        started = perf_counter()
        result = await client.set(key, value, ex=expire, nx=True)
        await self._record_command_timing("SET", (perf_counter() - started) * 1000)
        return bool(result)

    async def release_lock(self, lock_name: str) -> None:
        """Release distributed lock"""
        client = await self._get_client()
        started = perf_counter()
        await client.delete(f"podcast:lock:{lock_name}")
        await self._record_command_timing("DEL", (perf_counter() - started) * 1000)

    async def acquire_owned_lock(
        self,
        lock_name: str,
        *,
        expire: int = 300,
    ) -> str | None:
        """Acquire a lock and return its owner token when successful."""
        token = secrets.token_urlsafe(16)
        acquired = await self.acquire_lock(lock_name, expire=expire, value=token)
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

    async def set_if_not_exists(
        self,
        key: str,
        value: str,
        *,
        ttl: int | None = None,
    ) -> bool:
        """Set a key only if it does not already exist."""
        client = await self._get_client()
        started = perf_counter()
        result = await client.set(key, value, ex=ttl, nx=True)
        await self._record_command_timing("SET", (perf_counter() - started) * 1000)
        return bool(result)

    async def get_ttl(self, key: str) -> int:
        """Get key TTL in seconds."""
        client = await self._get_client()
        started = perf_counter()
        ttl = await client.ttl(key)
        await self._record_command_timing("TTL", (perf_counter() - started) * 1000)
        return int(ttl)

    async def scan_keys(self, pattern: str) -> list[str]:
        """Return keys matching a pattern."""
        return await self._scan_keys(pattern)

    async def sorted_set_add(self, key: str, member: str, score: float) -> int:
        """Add or update one member in a sorted set."""
        client = await self._get_client()
        started = perf_counter()
        result = await client.zadd(key, {member: score})
        await self._record_command_timing("ZADD", (perf_counter() - started) * 1000)
        return int(result or 0)

    async def sorted_set_remove(self, key: str, *members: str) -> int:
        """Remove one or more members from a sorted set."""
        if not members:
            return 0
        client = await self._get_client()
        started = perf_counter()
        result = await client.zrem(key, *members)
        await self._record_command_timing("ZREM", (perf_counter() - started) * 1000)
        return int(result or 0)

    async def sorted_set_cardinality(self, key: str) -> int:
        """Return the number of members in a sorted set."""
        client = await self._get_client()
        started = perf_counter()
        result = await client.zcard(key)
        await self._record_command_timing("ZCARD", (perf_counter() - started) * 1000)
        return int(result or 0)

    async def sorted_set_range_by_score(
        self,
        key: str,
        min_score: float | str,
        max_score: float | str,
    ) -> list[str]:
        """Return sorted-set members whose scores fall within the inclusive range."""
        client = await self._get_client()
        started = perf_counter()
        result = await client.zrangebyscore(key, min_score, max_score)
        await self._record_command_timing("ZRANGEBYSCORE", (perf_counter() - started) * 1000)
        return list(result)

    async def sorted_set_remove_by_score(
        self,
        key: str,
        min_score: float | str,
        max_score: float | str,
    ) -> int:
        """Remove sorted-set members whose scores fall within the inclusive range."""
        client = await self._get_client()
        started = perf_counter()
        result = await client.zremrangebyscore(key, min_score, max_score)
        await self._record_command_timing(
            "ZREMRANGEBYSCORE",
            (perf_counter() - started) * 1000,
        )
        return int(result or 0)

    # === Rate Limiting ===

    async def check_rate_limit(
        self,
        user_id: int,
        action: str,
        limit: int,
        window: int,
    ) -> bool:
        """Simple rate limiting using Redis
        Returns True if allowed
        """
        client = await self._get_client()
        key = f"podcast:rate:{user_id}:{action}"
        started = perf_counter()
        current = await client.get(key)
        await self._record_command_timing("GET", (perf_counter() - started) * 1000)

        if current is None:
            set_started = perf_counter()
            await client.setex(key, window, 1)
            await self._record_command_timing("SETEX", (perf_counter() - set_started) * 1000)
            return True

        count = int(current)
        if count >= limit:
            return False

        incr_started = perf_counter()
        await client.incr(key)
        await self._record_command_timing("INCR", (perf_counter() - incr_started) * 1000)
        return True

    # === Raw Client Access (for advanced use cases) ===

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
        return await self.cache_set(key, value, ttl)

    async def ttl(self, key: str) -> int:
        """Get the time to live for a key in seconds."""
        client = await self._get_client()
        started = perf_counter()
        result = await client.ttl(key)
        await self._record_command_timing("TTL", (perf_counter() - started) * 1000)
        return int(result or -1)

    async def close(self):
        """Close Redis connection"""
        if self._client:
            try:
                await self._client.close()
            finally:
                self._client = None
                self._client_loop_token = None
                self._last_health_check_at = 0.0

    # === Cache Penetration Protection ===

    async def cache_get_with_null_protection(
        self,
        key: str,
        loader: Any,
        ttl: int = 3600,
    ) -> tuple[Any, bool]:
        """Get cached value with null value caching to prevent cache penetration.

        When a loader returns None (data not found), we cache a special marker
        to prevent repeated database queries for the same non-existent data.

        Args:
            key: Cache key
            loader: Async callable to load value if cache miss
            ttl: Cache TTL in seconds for actual data (null values use _NULL_CACHE_TTL)

        Returns:
            Tuple of (value, from_cache). Value is None if:
            - Data doesn't exist and was cached as null
            - Data doesn't exist and wasn't cached before

        """
        # Try to get from cache first
        cached_value = await self.cache_get(key)
        if cached_value is not None:
            if cached_value == _NULL_VALUE_MARKER:
                # Null value cached - data doesn't exist
                await self._record_cache_lookup(key, hit=True)
                await self._record_cache_penetration(key)
                return None, True
            # Actual data cached
            await self._record_cache_lookup(key, hit=True)
            return json.loads(cached_value), True

        # Cache miss - load from data source
        await self._record_cache_lookup(key, hit=False)
        value = await loader()

        if value is None:
            # Data doesn't exist - cache null marker to prevent penetration
            await self.cache_set(key, _NULL_VALUE_MARKER, ttl=_NULL_CACHE_TTL)
            await self._record_cache_penetration(key)
            return None, False

        # Cache the actual value
        await self.cache_set_json(key, value, ttl=ttl)
        return value, False

    async def cache_get_json_with_null_protection(
        self,
        key: str,
        loader: Any,
        ttl: int = 3600,
    ) -> Any:
        """Get JSON cached value with null protection (simplified API).

        Args:
            key: Cache key
            loader: Async callable to load value if cache miss
            ttl: Cache TTL in seconds

        Returns:
            Cached or loaded value, or None if data doesn't exist

        """
        value, _from_cache = await self.cache_get_with_null_protection(
            key,
            loader,
            ttl=ttl,
        )
        return value

    async def set_null_value(self, key: str) -> bool:
        """Explicitly set a null value marker for a key.

        Use this when you know a resource doesn't exist and want to
        prevent future cache penetration attempts.

        Args:
            key: Cache key to mark as null

        Returns:
            True if successfully set

        """
        return await self.cache_set(key, _NULL_VALUE_MARKER, ttl=_NULL_CACHE_TTL)

    async def is_null_value_cached(self, key: str) -> bool:
        """Check if a key has a null value marker cached.

        Args:
            key: Cache key to check

        Returns:
            True if key has null marker cached

        """
        value = await self.cache_get(key)
        return value == _NULL_VALUE_MARKER

    async def invalidate_null_cache(self, pattern: str | None = None) -> int:
        """Invalidate null value caches.

        Args:
            pattern: Optional key pattern to match (e.g., "podcast:meta:*").
                     If None, clears all null markers (use with caution).

        Returns:
            Number of keys deleted

        """
        client = await self._get_client()

        if pattern:
            # Delete null values matching pattern
            count = 0
            async for key in client.scan_iter(match=pattern):
                value = await client.get(key)
                if value == _NULL_VALUE_MARKER:
                    await self._delete_keys_nonblocking(key)
                    count += 1
            return count

        # This would be expensive - scan all keys and delete null markers
        # Not recommended for production use
        return 0

    async def get_penetration_metrics(self) -> dict[str, Any]:
        """Get cache penetration metrics.

        Returns:
            Dict with total_attempts and by_namespace breakdown

        """
        client = await self._get_client()
        try:
            penetration_data = await client.hgetall(_METRICS_CACHE_PENETRATION_KEY) or {}
            total_attempts = int(penetration_data.get("total_attempts", 0))

            # Get per-namespace penetration metrics
            by_namespace: dict[str, Any] = {}
            penetration_pattern = f"{_METRICS_CACHE_PENETRATION_KEY}:namespace:*"
            async for key in client.scan_iter(match=penetration_pattern):
                namespace = key.split(":")[-1]
                ns_data = await client.hgetall(key) or {}
                ns_attempts = int(ns_data.get("attempts", 0))
                by_namespace[namespace] = {
                    "attempts": ns_attempts,
                }

            return {
                "total_attempts": total_attempts,
                "by_namespace": by_namespace,
            }
        except Exception:
            return {
                "total_attempts": 0,
                "by_namespace": {},
            }

    async def check_health(self, timeout_seconds: float = 1.5) -> dict[str, Any]:
        """Return a compact Redis readiness payload suitable for readiness probes."""
        try:
            async with asyncio.timeout(timeout_seconds):
                client = await self._get_client()
                started = perf_counter()
                await client.ping()
                await self._record_command_timing("PING", (perf_counter() - started) * 1000)
            return {"status": "healthy"}
        except TimeoutError:
            return {"status": "unhealthy", "error": "timeout"}
        except Exception as exc:
            return {"status": "unhealthy", "error": str(exc)}


async def get_redis() -> PodcastRedis:
    """Create a Redis helper through the runtime/provider layer."""
    return PodcastRedis()


async def get_redis_runtime_metrics() -> dict[str, Any]:
    """Get distributed Redis command and cache metrics from Redis storage."""
    redis = await get_redis()
    return await redis.get_runtime_metrics()


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
