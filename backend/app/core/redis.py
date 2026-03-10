"""
Redis Helper - Simplified for Personal Use

Uses single Redis DB for all personal-scale operations:
- Cache: Podcast episode metadata
- Rate limiting: RSS polling protection
- Locks: Prevent duplicate processing
- Session: User data (if needed)
- Task locks: Podcast processing coordination

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
"""

import asyncio
import hashlib
import json
import secrets
from contextlib import suppress
from datetime import datetime
from time import perf_counter
from typing import Any

from redis import asyncio as aioredis

from app.core.config import settings


_shared_redis: "PodcastRedis | None" = None


class RedisJSONEncoder(json.JSONEncoder):
    """Custom JSON encoder for Redis that handles datetime objects"""

    def default(self, obj):
        if isinstance(obj, datetime):
            return obj.isoformat()
        return super().default(obj)


class PodcastRedis:
    """
    Simple Redis wrapper for podcast features
    """

    _runtime_metrics: dict[str, Any] = {
        "commands": {
            "total_count": 0,
            "total_ms": 0.0,
            "max_ms": 0.0,
            "by_command": {},
        },
        "cache": {
            "hits": 0,
            "misses": 0,
            "by_namespace": {},
        },
    }
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

    @classmethod
    def _record_command_timing(cls, command: str, elapsed_ms: float) -> None:
        commands = cls._runtime_metrics["commands"]
        commands["total_count"] += 1
        commands["total_ms"] += elapsed_ms
        commands["max_ms"] = max(commands["max_ms"], elapsed_ms)

        per_command = commands["by_command"]
        stats = per_command.get(command)
        if stats is None:
            stats = {"count": 0, "total_ms": 0.0, "max_ms": 0.0}
            per_command[command] = stats
        stats["count"] += 1
        stats["total_ms"] += elapsed_ms
        stats["max_ms"] = max(stats["max_ms"], elapsed_ms)

    @classmethod
    def _record_cache_lookup(cls, key: str, *, hit: bool) -> None:
        cache = cls._runtime_metrics["cache"]
        if hit:
            cache["hits"] += 1
        else:
            cache["misses"] += 1

        namespace = cls._cache_namespace(key)
        by_namespace = cache["by_namespace"]
        ns_stats = by_namespace.get(namespace)
        if ns_stats is None:
            ns_stats = {"hits": 0, "misses": 0}
            by_namespace[namespace] = ns_stats
        if hit:
            ns_stats["hits"] += 1
        else:
            ns_stats["misses"] += 1

    @classmethod
    def get_runtime_metrics(cls) -> dict[str, Any]:
        commands = cls._runtime_metrics["commands"]
        cache = cls._runtime_metrics["cache"]

        total_count = commands["total_count"]
        total_ms = commands["total_ms"]
        avg_ms = (total_ms / total_count) if total_count else 0.0

        hits = cache["hits"]
        misses = cache["misses"]
        lookups = hits + misses
        hit_rate = (hits / lookups) if lookups else 0.0

        by_command: dict[str, Any] = {}
        for name, stats in commands["by_command"].items():
            count = stats["count"]
            by_command[name] = {
                "count": count,
                "avg_ms": (stats["total_ms"] / count) if count else 0.0,
                "max_ms": stats["max_ms"],
            }

        by_namespace: dict[str, Any] = {}
        for namespace, stats in cache["by_namespace"].items():
            ns_hits = stats["hits"]
            ns_misses = stats["misses"]
            ns_total = ns_hits + ns_misses
            by_namespace[namespace] = {
                "hits": ns_hits,
                "misses": ns_misses,
                "hit_rate": (ns_hits / ns_total) if ns_total else 0.0,
            }

        return {
            "commands": {
                "total_count": total_count,
                "avg_ms": avg_ms,
                "max_ms": commands["max_ms"],
                "by_command": by_command,
            },
            "cache": {
                "hits": hits,
                "misses": misses,
                "hit_rate": hit_rate,
                "by_namespace": by_namespace,
            },
        }

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
        self._record_command_timing("SCAN_ITER", (perf_counter() - started) * 1000)
        return keys

    @staticmethod
    def _build_client() -> aioredis.Redis:
        return aioredis.from_url(
            settings.REDIS_URL,
            decode_responses=True,
            socket_timeout=5,
            socket_connect_timeout=5,
            retry_on_timeout=True,
            max_connections=20,
        )

    async def _ping_client(self, client: aioredis.Redis) -> None:
        started = perf_counter()
        await client.ping()
        self._record_command_timing("PING", (perf_counter() - started) * 1000)

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
        self._record_command_timing("GET", (perf_counter() - started) * 1000)
        return value

    async def cache_set(self, key: str, value: str, ttl: int = 3600) -> bool:
        """Set cached value with TTL"""
        client = await self._get_client()
        started = perf_counter()
        result = await client.setex(key, ttl, value)
        self._record_command_timing("SETEX", (perf_counter() - started) * 1000)
        return result

    async def cache_delete(self, key: str) -> bool:
        """Delete cached value"""
        client = await self._get_client()
        started = perf_counter()
        result = await client.delete(key)
        self._record_command_timing("DEL", (perf_counter() - started) * 1000)
        return result

    async def delete_keys(self, *keys: str) -> int:
        """Delete one or more keys."""
        if not keys:
            return 0
        client = await self._get_client()
        started = perf_counter()
        result = await client.delete(*keys)
        self._record_command_timing("DEL", (perf_counter() - started) * 1000)
        return int(result or 0)

    async def cache_hget(self, key: str, field: str) -> str | None:
        """Get hash field"""
        client = await self._get_client()
        started = perf_counter()
        value = await client.hget(key, field)
        self._record_command_timing("HGET", (perf_counter() - started) * 1000)
        return value

    async def cache_hgetall(self, key: str) -> dict[str, str]:
        """Get all hash fields."""
        client = await self._get_client()
        started = perf_counter()
        value = await client.hgetall(key)
        self._record_command_timing("HGETALL", (perf_counter() - started) * 1000)
        return value

    async def cache_hset(self, key: str, mapping: dict, ttl: int | None = None) -> int:
        """Set hash fields with optional TTL"""
        client = await self._get_client()
        started = perf_counter()
        result = await client.hset(key, mapping=mapping)
        self._record_command_timing("HSET", (perf_counter() - started) * 1000)
        if ttl:
            expire_started = perf_counter()
            await client.expire(key, ttl)
            self._record_command_timing(
                "EXPIRE", (perf_counter() - expire_started) * 1000
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
        self, episode_id: int, summary: str, version: str = "v1"
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
        self, user_id: int, episode_id: int, progress: float
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
                self._record_cache_lookup(key, hit=True)
                return value
            except json.JSONDecodeError:
                self._record_cache_lookup(key, hit=False)
                return None
        self._record_cache_lookup(key, hit=False)
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
        """Cache subscription list (15 minutes TTL)"""
        client = await self._get_client()
        key = self._subscription_list_key(user_id, page, size, filters=filters)
        cached = await self.cache_set_json(key, data, ttl=900)
        if cached:
            index_key = self._subscription_index_key(user_id)
            started = perf_counter()
            await client.sadd(index_key, key)
            self._record_command_timing("SADD", (perf_counter() - started) * 1000)

            expire_started = perf_counter()
            await client.expire(index_key, 1800)
            self._record_command_timing(
                "EXPIRE", (perf_counter() - expire_started) * 1000
            )
        return cached

    async def invalidate_subscription_list(self, user_id: int) -> None:
        """Invalidate all subscription list caches for a user"""
        client = await self._get_client()
        index_key = self._subscription_index_key(user_id)
        started = perf_counter()
        keys = list(await client.smembers(index_key))
        self._record_command_timing("SMEMBERS", (perf_counter() - started) * 1000)
        if not keys:
            pattern = f"podcast:subscriptions:v2:{user_id}:*"
            keys = await self._scan_keys(pattern)
        if keys:
            delete_started = perf_counter()
            await client.delete(*keys, index_key)
            self._record_command_timing("DEL", (perf_counter() - delete_started) * 1000)

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
        self, subscription_id: int, page: int, size: int
    ) -> dict | None:
        """Get cached episode list (10 minutes TTL)"""
        key = f"podcast:episodes:{subscription_id}:{page}:{size}"
        return await self.cache_get_json(key)

    async def set_episode_list(
        self, subscription_id: int, page: int, size: int, data: dict
    ) -> bool:
        """Cache episode list (10 minutes TTL)"""
        client = await self._get_client()
        key = f"podcast:episodes:{subscription_id}:{page}:{size}"
        cached = await self.cache_set_json(key, data, ttl=600)
        if cached:
            index_key = self._episode_index_key(subscription_id)
            started = perf_counter()
            await client.sadd(index_key, key)
            self._record_command_timing("SADD", (perf_counter() - started) * 1000)

            expire_started = perf_counter()
            await client.expire(index_key, 1800)
            self._record_command_timing(
                "EXPIRE", (perf_counter() - expire_started) * 1000
            )
        return cached

    async def invalidate_episode_list(self, subscription_id: int) -> None:
        """Invalidate all episode list caches for a subscription"""
        client = await self._get_client()
        index_key = self._episode_index_key(subscription_id)
        started = perf_counter()
        keys = list(await client.smembers(index_key))
        self._record_command_timing("SMEMBERS", (perf_counter() - started) * 1000)
        if not keys:
            pattern = f"podcast:episodes:{subscription_id}:*"
            keys = await self._scan_keys(pattern)
        if keys:
            delete_started = perf_counter()
            await client.delete(*keys, index_key)
            self._record_command_timing("DEL", (perf_counter() - delete_started) * 1000)

    # === Search Results Cache ===

    def _hash_search_query(
        self, query: str, search_in: str, page: int, size: int
    ) -> str:
        """Generate hash key for search query"""
        query_str = f"{query}:{search_in}:{page}:{size}".lower()
        return hashlib.sha256(query_str.encode("utf-8")).hexdigest()

    async def get_search_results(
        self, query: str, search_in: str, page: int, size: int
    ) -> dict | None:
        """Get cached search results (5 minutes TTL)"""
        hash_key = self._hash_search_query(query, search_in, page, size)
        key = f"podcast:search:v2:{hash_key}"
        return await self.cache_get_json(key)

    async def set_search_results(
        self, query: str, search_in: str, page: int, size: int, data: dict
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
        self, lock_name: str, expire: int = 300, value: str = "1"
    ) -> bool:
        """
        Acquire distributed lock
        Returns True if lock acquired
        """
        client = await self._get_client()
        key = f"podcast:lock:{lock_name}"
        started = perf_counter()
        result = await client.set(key, value, ex=expire, nx=True)
        self._record_command_timing("SET", (perf_counter() - started) * 1000)
        return bool(result)

    async def release_lock(self, lock_name: str) -> None:
        """Release distributed lock"""
        client = await self._get_client()
        started = perf_counter()
        await client.delete(f"podcast:lock:{lock_name}")
        self._record_command_timing("DEL", (perf_counter() - started) * 1000)

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
        self._record_command_timing("EVAL", (perf_counter() - started) * 1000)
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
        self._record_command_timing("SET", (perf_counter() - started) * 1000)
        return bool(result)

    async def get_ttl(self, key: str) -> int:
        """Get key TTL in seconds."""
        client = await self._get_client()
        started = perf_counter()
        ttl = await client.ttl(key)
        self._record_command_timing("TTL", (perf_counter() - started) * 1000)
        return int(ttl)

    async def scan_keys(self, pattern: str) -> list[str]:
        """Return keys matching a pattern."""
        return await self._scan_keys(pattern)

    # === Rate Limiting ===

    async def check_rate_limit(
        self, user_id: int, action: str, limit: int, window: int
    ) -> bool:
        """
        Simple rate limiting using Redis
        Returns True if allowed
        """
        client = await self._get_client()
        key = f"podcast:rate:{user_id}:{action}"
        started = perf_counter()
        current = await client.get(key)
        self._record_command_timing("GET", (perf_counter() - started) * 1000)

        if current is None:
            set_started = perf_counter()
            await client.setex(key, window, 1)
            self._record_command_timing("SETEX", (perf_counter() - set_started) * 1000)
            return True

        count = int(current)
        if count >= limit:
            return False

        incr_started = perf_counter()
        await client.incr(key)
        self._record_command_timing("INCR", (perf_counter() - incr_started) * 1000)
        return True

    async def close(self):
        """Close Redis connection"""
        if self._client:
            try:
                await self._client.close()
            finally:
                self._client = None
                self._client_loop_token = None
                self._last_health_check_at = 0.0

    async def check_health(self, timeout_seconds: float = 1.5) -> dict[str, Any]:
        """Return a compact Redis readiness payload suitable for readiness probes."""
        try:
            async with asyncio.timeout(timeout_seconds):
                client = await self._get_client()
                started = perf_counter()
                await client.ping()
                self._record_command_timing("PING", (perf_counter() - started) * 1000)
            return {"status": "healthy"}
        except TimeoutError:
            return {"status": "unhealthy", "error": "timeout"}
        except Exception as exc:
            return {"status": "unhealthy", "error": str(exc)}


async def get_redis() -> PodcastRedis:
    """Create a Redis helper through the runtime/provider layer."""
    return PodcastRedis()


def get_redis_runtime_metrics() -> dict[str, Any]:
    """Get process-level Redis command and cache metrics."""
    return PodcastRedis.get_runtime_metrics()


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
