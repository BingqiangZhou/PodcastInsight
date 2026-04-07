"""Redis Cache, Lock, Podcast, and Sorted-Set Operations.

Consolidated from lock.py, podcast_cache.py, sorted_set.py into a single module.
All mixin classes expect to be used via AppCache which provides ``_get_client()``.
"""

import asyncio
import hashlib
import logging
from collections.abc import Awaitable, Callable
from typing import Any, TypeVar

import orjson

from app.core.cache_ttl import CacheTTL


logger = logging.getLogger(__name__)

# Null value cache marker
_NULL_VALUE_MARKER = "__NULL__"
_NULL_CACHE_TTL = 60  # seconds


# ---------------------------------------------------------------------------
# Basic Cache Operations
# ---------------------------------------------------------------------------


class CacheOperations:
    """Basic cache operations mixin."""

    def __init__(self) -> None:
        self._background_tasks: set[asyncio.Task] = set()

    async def cache_get(self, client: Any, key: str) -> str | None:
        value = await client.get(key)
        return value

    async def cache_set(
        self, client: Any, key: str, value: str, ttl: int = CacheTTL.DEFAULT
    ) -> bool:
        result = await client.setex(key, ttl, value)
        return result

    async def cache_delete(self, client: Any, key: str) -> bool:
        result = await client.delete(key)
        return result

    async def cache_hget(self, client: Any, key: str, field: str) -> str | None:
        value = await client.hget(key, field)
        return value

    async def cache_hgetall(self, client: Any, key: str) -> dict[str, str]:
        value = await client.hgetall(key)
        return value

    async def cache_hset(
        self, client: Any, key: str, mapping: dict, ttl: int | None = None
    ) -> int:
        if ttl:
            async with client.pipeline(True) as pipe:
                pipe.hset(key, mapping=mapping)
                pipe.expire(key, ttl)
                results = await pipe.execute()
                return int(results[0] or 0)
        return await client.hset(key, mapping=mapping)

    # --- JSON helpers ---

    async def cache_get_json(
        self, key: str, client: Any, record_lookup: Any = None
    ) -> Any | None:
        data = await self.cache_get(client, key)
        if data:
            try:
                return orjson.loads(data)
            except orjson.JSONDecodeError:
                return None
        return None

    async def cache_set_json(
        self, key: str, value: Any, client: Any, ttl: int = CacheTTL.DEFAULT
    ) -> bool:
        from app.core.redis.client import redis_json_default

        try:
            json_str = orjson.dumps(value, default=redis_json_default).decode("utf-8")
            return await self.cache_set(client, key, json_str, ttl=ttl)
        except (TypeError, ValueError):
            return False

    # --- Anti-stampede cache ---

    async def cache_get_with_lock(
        self,
        key: str,
        loader: Any,
        client: Any,
        ttl: int = CacheTTL.DEFAULT,
        lock_timeout: int = 10,
        max_wait_time: float = 3.0,
    ) -> tuple[Any, bool]:
        value = await self.cache_get_json(key, client)
        if value is not None:
            return value, True

        lock_key = f"lock:{key}"
        lock_acquired = await client.set(lock_key, "1", nx=True, ex=lock_timeout)

        if lock_acquired:
            try:
                value = await loader()
                # Cache null values with marker to prevent cache penetration
                if value is None:
                    await client.setex(key, _NULL_CACHE_TTL, _NULL_VALUE_MARKER)
                else:
                    await self.cache_set_json(key, value, client, ttl)
                return value, False
            except Exception:
                # Cache short-lived error marker to prevent thundering herd
                import contextlib
                with contextlib.suppress(Exception):
                    await client.setex(f"{key}:error", 5, "1")
                raise
            finally:
                await self._delete_keys_nonblocking(client, lock_key)
        else:
            wait_start = asyncio.get_running_loop().time()
            initial_delay = 0.05
            max_delay = 0.5
            attempt = 0

            while (asyncio.get_running_loop().time() - wait_start) < max_wait_time:
                delay = min(initial_delay * (2**attempt), max_delay)
                await asyncio.sleep(delay)

                value = await self.cache_get_json(key, client)
                if value is not None:
                    return value, True

                lock_exists = await client.exists(lock_key)
                if not lock_exists:
                    lock_acquired = await client.set(
                        lock_key, "1", nx=True, ex=lock_timeout
                    )
                    if lock_acquired:
                        try:
                            value = await loader()
                            await self.cache_set_json(key, value, client, ttl)
                            return value, False
                        finally:
                            await self._delete_keys_nonblocking(client, lock_key)

                attempt += 1

            value = await loader()
            await self.cache_set_json(key, value, client, ttl)
            return value, False

    async def cache_get_or_load(
        self,
        key: str,
        loader: Any,
        client: Any,
        ttl: int = CacheTTL.DEFAULT,
        stale_ttl: int = CacheTTL.STALE_REFRESH,
    ) -> Any:
        value = await self.cache_get_json(key, client)
        if value is not None:
            ttl_remaining = await client.ttl(key)
            if ttl_remaining > 0 and ttl_remaining < stale_ttl:
                task = asyncio.create_task(self._background_refresh(key, loader, client, ttl))
                self._background_tasks.add(task)
                task.add_done_callback(self._background_tasks.discard)
            return value

        value = await loader()
        await self.cache_set_json(key, value, client, ttl)
        return value

    async def _background_refresh(
        self, key: str, loader: Any, client: Any, ttl: int
    ) -> None:
        try:
            value = await loader()
            await self.cache_set_json(key, value, client, ttl)
        except Exception as e:
            logger.warning("Background cache refresh failed for key %s: %s", key, e)

    async def _delete_keys_nonblocking(self, client: Any, *keys: str) -> int:
        if not keys:
            return 0
        try:
            result = await client.unlink(*keys)
            return int(result or 0)
        except Exception:
            result = await client.delete(*keys)
            return int(result or 0)


# ---------------------------------------------------------------------------
# Distributed Lock Operations
# ---------------------------------------------------------------------------


class LockOperations:
    """Distributed lock operations mixin."""

    async def acquire_lock(
        self,
        client: Any,
        lock_name: str,
        expire: int = CacheTTL.LOCK_TIMEOUT,
        value: str = "1",
    ) -> bool:
        result = await client.set(
            f"podcast:lock:{lock_name}", value, ex=expire, nx=True
        )
        return bool(result)

    async def release_lock(self, client: Any, lock_name: str) -> None:
        await client.delete(f"podcast:lock:{lock_name}")

    async def set_if_not_exists(
        self,
        client: Any,
        key: str,
        value: str,
        *,
        ttl: int | None = None,
    ) -> bool:
        result = await client.set(key, value, ex=ttl, nx=True)
        return bool(result)


# ---------------------------------------------------------------------------
# Podcast-specific Cache Operations
# ---------------------------------------------------------------------------


class PodcastCacheOperations:
    """Podcast-specific cache operations mixin."""

    def _stable_hash(self, value: str) -> str:
        normalized = value.strip().lower()
        return hashlib.md5(normalized.encode("utf-8")).hexdigest()

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
        token = self._stable_hash(payload_str)
        return f"podcast:subscriptions:v2:{user_id}:{token}"

    def _episode_index_key(self, subscription_id: int) -> str:
        return f"podcast:episodes:index:{subscription_id}"

    def _hash_search_query(
        self, query: str, search_in: str, page: int, size: int
    ) -> str:
        query_str = f"{query}:{search_in}:{page}:{size}".lower()
        return hashlib.md5(query_str.encode("utf-8")).hexdigest()

    # --- Episode metadata ---

    async def get_episode_metadata(
        self, client: Any, episode_id: int, cache_hgetall_func: Any = None
    ) -> dict | None:
        key = f"podcast:meta:{episode_id}"
        data = await cache_hgetall_func(client, key)
        return data or None

    async def set_episode_metadata(
        self, client: Any, episode_id: int, metadata: dict, cache_hset_func: Any = None
    ) -> None:
        key = f"podcast:meta:{episode_id}"
        await cache_hset_func(client, key, metadata, ttl=CacheTTL.EPISODE_METADATA)

    # --- Feed cache ---

    async def get_cached_feed(
        self, client: Any, feed_url: str, cache_get_func: Any = None
    ) -> str | None:
        key = f"podcast:cache:v2:{self._stable_hash(feed_url)}"
        return await cache_get_func(key)

    async def set_cached_feed(
        self, client: Any, feed_url: str, xml_content: str, cache_set_func: Any = None
    ) -> None:
        key = f"podcast:cache:v2:{self._stable_hash(feed_url)}"
        await cache_set_func(key, xml_content, ttl=CacheTTL.FEED_CACHE)

    # --- AI summary ---

    async def get_ai_summary(
        self,
        client: Any,
        episode_id: int,
        version: str = "v1",
        cache_get_func: Any = None,
    ) -> str | None:
        key = f"podcast:summary:{episode_id}:{version}"
        return await cache_get_func(key)

    async def set_ai_summary(
        self,
        client: Any,
        episode_id: int,
        summary: str,
        version: str = "v1",
        cache_set_func: Any = None,
    ) -> None:
        key = f"podcast:summary:{episode_id}:{version}"
        await cache_set_func(key, summary, ttl=CacheTTL.AI_SUMMARY)

    # --- User progress ---

    async def get_user_progress(
        self, client: Any, user_id: int, episode_id: int, cache_get_func: Any = None
    ) -> float | None:
        key = f"podcast:progress:{user_id}:{episode_id}"
        progress = await cache_get_func(key)
        return float(progress) if progress else None

    async def set_user_progress(
        self,
        client: Any,
        user_id: int,
        episode_id: int,
        progress: float,
        cache_set_func: Any = None,
    ) -> None:
        key = f"podcast:progress:{user_id}:{episode_id}"
        await cache_set_func(key, str(progress), ttl=CacheTTL.PLAYBACK_PROGRESS)

    # --- Subscription list ---

    async def get_subscription_list(
        self,
        client: Any,
        user_id: int,
        page: int,
        size: int,
        filters: dict[str, Any] | None = None,
        cache_get_json_func: Any = None,
    ) -> dict | None:
        key = self._subscription_list_key(user_id, page, size, filters=filters)
        return await cache_get_json_func(key)

    async def set_subscription_list(
        self,
        client: Any,
        user_id: int,
        page: int,
        size: int,
        data: dict,
        filters: dict[str, Any] | None = None,
        cache_set_json_func: Any = None,
    ) -> bool:
        key = self._subscription_list_key(user_id, page, size, filters=filters)
        index_key = self._subscription_index_key(user_id)

        try:
            json_str = orjson.dumps(data).decode("utf-8")
        except (TypeError, ValueError):
            return False

        async with client.pipeline() as pipe:
            pipe.setex(key, CacheTTL.SUBSCRIPTION_LIST, json_str)
            pipe.sadd(index_key, key)
            pipe.expire(index_key, 1800)
            await pipe.execute()
        return True

    async def invalidate_subscription_list(
        self,
        client: Any,
        user_id: int,
        scan_keys_func: Any = None,
        delete_keys_func: Any = None,
    ) -> None:
        index_key = self._subscription_index_key(user_id)
        keys = list(await client.smembers(index_key))
        if not keys:
            pattern = f"podcast:subscriptions:v2:{user_id}:*"
            keys = await scan_keys_func(client, pattern)
        if keys:
            await delete_keys_func(client, *keys, index_key)

    # --- User stats ---

    async def get_user_stats(
        self, client: Any, user_id: int, cache_get_json_func: Any = None
    ) -> dict | None:
        key = f"podcast:stats:{user_id}"
        return await cache_get_json_func(key)

    async def set_user_stats(
        self, client: Any, user_id: int, stats: dict, cache_set_json_func: Any = None
    ) -> bool:
        key = f"podcast:stats:{user_id}"
        return await cache_set_json_func(key, stats, ttl=CacheTTL.STATS_LONG)

    async def invalidate_user_stats(
        self, client: Any, user_id: int, cache_delete_func: Any = None
    ) -> None:
        await cache_delete_func(f"podcast:stats:{user_id}")

    # --- Profile stats ---

    async def get_profile_stats(
        self, client: Any, user_id: int, cache_get_json_func: Any = None
    ) -> dict | None:
        key = f"podcast:stats:profile:{user_id}"
        return await cache_get_json_func(key)

    async def set_profile_stats(
        self, client: Any, user_id: int, stats: dict, cache_set_json_func: Any = None
    ) -> bool:
        key = f"podcast:stats:profile:{user_id}"
        return await cache_set_json_func(key, stats, ttl=CacheTTL.STATS_SHORT)

    async def invalidate_profile_stats(
        self, client: Any, user_id: int, cache_delete_func: Any = None
    ) -> None:
        await cache_delete_func(f"podcast:stats:profile:{user_id}")

    # --- Episode list ---

    async def get_episode_list(
        self,
        client: Any,
        subscription_id: int,
        page: int,
        size: int,
        cache_get_json_func: Any = None,
    ) -> dict | None:
        key = f"podcast:episodes:{subscription_id}:{page}:{size}"
        return await cache_get_json_func(client, key)

    async def set_episode_list(
        self,
        client: Any,
        subscription_id: int,
        page: int,
        size: int,
        data: dict,
        cache_set_json_func: Any = None,
    ) -> bool:
        key = f"podcast:episodes:{subscription_id}:{page}:{size}"
        index_key = self._episode_index_key(subscription_id)

        try:
            json_str = orjson.dumps(data).decode("utf-8")
        except (TypeError, ValueError):
            return False

        async with client.pipeline() as pipe:
            pipe.setex(key, CacheTTL.EPISODE_LIST, json_str)
            pipe.sadd(index_key, key)
            pipe.expire(index_key, 1800)
            await pipe.execute()
        return True

    async def invalidate_episode_list(
        self,
        client: Any,
        subscription_id: int,
        scan_keys_func: Any = None,
        delete_keys_func: Any = None,
    ) -> None:
        index_key = self._episode_index_key(subscription_id)
        keys = list(await client.smembers(index_key))
        if not keys:
            pattern = f"podcast:episodes:{subscription_id}:*"
            keys = await scan_keys_func(client, pattern)
        if keys:
            await delete_keys_func(client, *keys, index_key)

    # --- Search results ---

    async def get_search_results(
        self,
        client: Any,
        query: str,
        search_in: str,
        page: int,
        size: int,
        cache_get_json_func: Any = None,
    ) -> dict | None:
        hash_key = self._hash_search_query(query, search_in, page, size)
        key = f"podcast:search:v2:{hash_key}"
        return await cache_get_json_func(client, key)

    async def set_search_results(
        self,
        client: Any,
        query: str,
        search_in: str,
        page: int,
        size: int,
        data: dict,
        cache_set_json_func: Any = None,
    ) -> bool:
        hash_key = self._hash_search_query(query, search_in, page, size)
        key = f"podcast:search:v2:{hash_key}"
        return await cache_set_json_func(client, key, data, ttl=CacheTTL.STALE_REFRESH)

    # --- Episode detail (single episode with summary) ---

    async def get_episode_detail(
        self,
        client: Any,
        episode_id: int,
        loader: Callable[[], Awaitable[dict | None]],
        cache_get_with_lock_func: Any = None,
    ) -> dict | None:
        """Cache episode detail (with summary) with 5-minute TTL."""
        key = f"podcast:episode:detail:{episode_id}"
        result, _from_cache = await cache_get_with_lock_func(
            key=key,
            loader=loader,
            ttl=CacheTTL.EPISODE_DETAIL,
        )
        return result

    async def invalidate_episode_detail(
        self, client: Any, episode_id: int, cache_delete_func: Any = None
    ) -> None:
        """Invalidate episode detail cache after update or summary generation."""
        await cache_delete_func(f"podcast:episode:detail:{episode_id}")

    # --- Batch invalidation ---

    async def invalidate_user_caches(
        self,
        client: Any,
        user_id: int,
        invalidate_subscription_list_func: Any = None,
        invalidate_user_stats_func: Any = None,
    ) -> None:
        await invalidate_subscription_list_func(client, user_id)
        await invalidate_user_stats_func(client, user_id)


# ---------------------------------------------------------------------------
# Sorted-Set Operations
# ---------------------------------------------------------------------------


class SortedSetOperations:
    """Sorted set operations mixin."""

    async def sorted_set_add(
        self, client: Any, key: str, member: str, score: float
    ) -> int:
        result = await client.zadd(key, {member: score})
        return int(result or 0)

    async def sorted_set_remove(self, client: Any, key: str, *members: str) -> int:
        if not members:
            return 0
        result = await client.zrem(key, *members)
        return int(result or 0)

    async def sorted_set_cardinality(self, client: Any, key: str) -> int:
        result = await client.zcard(key)
        return int(result or 0)

    async def sorted_set_range_by_score(
        self,
        client: Any,
        key: str,
        min_score: float | str,
        max_score: float | str,
    ) -> list[str]:
        result = await client.zrangebyscore(key, min_score, max_score)
        return list(result)

    async def sorted_set_remove_by_score(
        self,
        client: Any,
        key: str,
        min_score: float | str,
        max_score: float | str,
    ) -> int:
        result = await client.zremrangebyscore(key, min_score, max_score)
        return int(result or 0)


# ---------------------------------------------------------------------------
# Export null marker
# ---------------------------------------------------------------------------

NULL_VALUE_MARKER = _NULL_VALUE_MARKER

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
