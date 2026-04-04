"""Podcast-specific Cache Operations.

Business logic caching for podcast subscriptions, episodes, feeds, etc.
"""

import hashlib
import logging
from typing import Any

import orjson

from app.core.cache_ttl import CacheTTL


logger = logging.getLogger(__name__)


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
        payload_str = orjson.dumps(payload, option=orjson.OPT_SORT_KEYS).decode('utf-8')
        token = self._stable_hash(payload_str)
        return f"podcast:subscriptions:v2:{user_id}:{token}"

    def _episode_index_key(self, subscription_id: int) -> str:
        return f"podcast:episodes:index:{subscription_id}"

    def _hash_search_query(
        self,
        query: str,
        search_in: str,
        page: int,
        size: int,
    ) -> str:
        query_str = f"{query}:{search_in}:{page}:{size}".lower()
        return hashlib.md5(query_str.encode("utf-8")).hexdigest()

    # === Episode Metadata ===

    async def get_episode_metadata(
        self, client: Any, episode_id: int, cache_hgetall_func: Any = None
    ) -> dict | None:
        """Get cached episode metadata."""
        key = f"podcast:meta:{episode_id}"
        data = await cache_hgetall_func(client, key)
        return data or None

    async def set_episode_metadata(
        self, client: Any, episode_id: int, metadata: dict, cache_hset_func: Any = None
    ) -> None:
        """Cache episode metadata (24 hours)"""
        key = f"podcast:meta:{episode_id}"
        await cache_hset_func(client, key, metadata, ttl=CacheTTL.EPISODE_METADATA)

    # === Feed Cache ===
    async def get_cached_feed(
        self, client: Any, feed_url: str, cache_get_func: Any = None
    ) -> str | None:
        """Get cached RSS feed"""
        key = f"podcast:cache:v2:{self._stable_hash(feed_url)}"
        return await cache_get_func(key)

    async def set_cached_feed(
        self, client: Any, feed_url: str, xml_content: str, cache_set_func: Any = None
    ) -> None:
        """Cache RSS feed (15 minutes)"""
        key = f"podcast:cache:v2:{self._stable_hash(feed_url)}"
        await cache_set_func(key, xml_content, ttl=CacheTTL.FEED_CACHE)
    # === AI Summary ===
    async def get_ai_summary(
        self, client: Any, episode_id: int, version: str = "v1", cache_get_func: Any = None
    ) -> str | None:
        """Get cached AI summary"""
        key = f"podcast:summary:{episode_id}:{version}"
        return await cache_get_func(key)
    async def set_ai_summary(
        self,
        client: Any, episode_id: int, summary: str, version: str = "v1", cache_set_func: Any = None
    ) -> None:
        """Cache AI summary (7 days)"""
        key = f"podcast:summary:{episode_id}:{version}"
        await cache_set_func(key, summary, ttl=CacheTTL.AI_SUMMARY)
    # === User Progress ===
    async def get_user_progress(
        self, client: Any, user_id: int, episode_id: int, cache_get_func: Any = None
    ) -> float | None:
        """Get user listening progress"""
        key = f"podcast:progress:{user_id}:{episode_id}"
        progress = await cache_get_func(key)
        return float(progress) if progress else None

    async def set_user_progress(
        self, client: Any, user_id: int, episode_id: int, progress: float, cache_set_func: Any = None
    ) -> None:
        """Set user progress (30 days)"""
        key = f"podcast:progress:{user_id}:{episode_id}"
        await cache_set_func(key, str(progress), ttl=CacheTTL.PLAYBACK_PROGRESS)

    # === Subscription List Cache ===
    async def get_subscription_list(
        self,
        client: Any,
        user_id: int,
        page: int,
        size: int,
        filters: dict[str, Any] | None = None,
        cache_get_json_func: Any = None
    ) -> dict | None:
        """Get cached subscription list (15 minutes TTL)"""
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
        """Cache subscription list (15 minutes TTL) using pipeline for efficiency."""
        key = self._subscription_list_key(user_id, page, size, filters=filters)
        index_key = self._subscription_index_key(user_id)

        try:
            json_str = orjson.dumps(data).decode('utf-8')
        except (TypeError, ValueError):
            return False

        # Use pipeline for atomic batch operations
        async with client.pipeline() as pipe:
            pipe.setex(key, 900, json_str)
            pipe.sadd(index_key, key)
            pipe.expire(index_key, 1800)
            await pipe.execute()
        return True
    async def invalidate_subscription_list(
        self, client: Any, user_id: int, scan_keys_func: Any = None, delete_keys_func: Any = None
    ) -> None:
        """Invalidate all subscription list caches for a user"""
        index_key = self._subscription_index_key(user_id)
        keys = list(await client.smembers(index_key))
        if not keys:
            pattern = f"podcast:subscriptions:v2:{user_id}:*"
            keys = await scan_keys_func(client, pattern)
        if keys:
            await delete_keys_func(client, *keys, index_key)

    # === User Stats Cache ===
    async def get_user_stats(
        self, client: Any, user_id: int, cache_get_json_func: Any = None
    ) -> dict | None:
        """Get cached user statistics (30 minutes TTL)"""
        key = f"podcast:stats:{user_id}"
        return await cache_get_json_func(key)
    async def set_user_stats(
        self, client: Any, user_id: int, stats: dict, cache_set_json_func: Any = None
    ) -> bool:
        """Cache user statistics (30 minutes TTL)"""
        key = f"podcast:stats:{user_id}"
        return await cache_set_json_func(key, stats, ttl=CacheTTL.STATS_LONG)
    async def invalidate_user_stats(self, client: Any, user_id: int, cache_delete_func: Any = None) -> None:
        """Invalidate user stats cache"""
        key = f"podcast:stats:{user_id}"
        await cache_delete_func(key)
    # === Profile Stats Cache ===
    async def get_profile_stats(
        self, client: Any, user_id: int, cache_get_json_func: Any = None
    ) -> dict | None:
        """Get cached profile statistics (10 minutes TTL)."""
        key = f"podcast:stats:profile:{user_id}"
        return await cache_get_json_func(key)
    async def set_profile_stats(
        self, client: Any, user_id: int, stats: dict, cache_set_json_func: Any = None
    ) -> bool:
        """Cache profile statistics (10 minutes TTL)."""
        key = f"podcast:stats:profile:{user_id}"
        return await cache_set_json_func(key, stats, ttl=CacheTTL.STATS_SHORT)
    async def invalidate_profile_stats(self, client: Any, user_id: int, cache_delete_func: Any = None) -> None:
        """Invalidate profile stats cache."""
        key = f"podcast:stats:profile:{user_id}"
        await cache_delete_func(key)
    # === Episode List Cache ===
    async def get_episode_list(
        self, client: Any, subscription_id: int, page: int, size: int, cache_get_json_func: Any = None
    ) -> dict | None:
        """Get cached episode list (10 minutes TTL)"""
        key = f"podcast:episodes:{subscription_id}:{page}:{size}"
        return await cache_get_json_func(client, key)
    async def set_episode_list(
        self, client: Any, subscription_id: int, page: int, size: int, data: dict, cache_set_json_func: Any = None,
    ) -> bool:
        """Cache episode list (10 minutes TTL) using pipeline for efficiency."""
        key = f"podcast:episodes:{subscription_id}:{page}:{size}"
        index_key = self._episode_index_key(subscription_id)

        try:
            json_str = orjson.dumps(data).decode('utf-8')
        except (TypeError, ValueError):
            return False
        # Use pipeline for atomic batch operations
        async with client.pipeline() as pipe:
            pipe.setex(key, 600, json_str)
            pipe.sadd(index_key, key)
            pipe.expire(index_key, 1800)
            await pipe.execute()
        return True
    async def invalidate_episode_list(
        self, client: Any, subscription_id: int, scan_keys_func: Any = None, delete_keys_func: Any = None
    ) -> None:
        """Invalidate all episode list caches for a subscription"""
        index_key = self._episode_index_key(subscription_id)
        keys = list(await client.smembers(index_key))
        if not keys:
            pattern = f"podcast:episodes:{subscription_id}:*"
            keys = await scan_keys_func(client, pattern)
        if keys:
            await delete_keys_func(client, *keys, index_key)
    # === Search Results Cache ===
    async def get_search_results(
        self, client: Any, query: str, search_in: str, page: int, size: int, cache_get_json_func: Any = None
    ) -> dict | None:
        """Get cached search results (5 minutes TTL)"""
        hash_key = self._hash_search_query(query, search_in, page, size)
        key = f"podcast:search:v2:{hash_key}"
        return await cache_get_json_func(client, key)
    async def set_search_results(
        self, client: Any, query: str, search_in: str, page: int, size: int, data: dict, cache_set_json_func: Any = None
    ) -> bool:
        """Cache search results (5 minutes TTL)"""
        hash_key = self._hash_search_query(query, search_in, page, size)
        key = f"podcast:search:v2:{hash_key}"
        return await cache_set_json_func(client, key, data, ttl=CacheTTL.STALE_REFRESH)
    # === Batch Invalidation ===
    async def invalidate_user_caches(
        self, client: Any, user_id: int, invalidate_subscription_list_func: Any = None, invalidate_user_stats_func: Any = None
    ) -> None:
        """Invalidate all user-related caches"""
        await invalidate_subscription_list_func(client, user_id)
        await invalidate_user_stats_func(client, user_id)
