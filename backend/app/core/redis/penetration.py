"""Cache Penetration Protection.

Prevents cache penetration by caching null values.
"""

import logging
from time import perf_counter
from typing import Any

import orjson

from app.core.cache_ttl import CacheTTL

logger = logging.getLogger(__name__)

# Null value cache marker and TTL
_NULL_VALUE_MARKER = "__NULL__"
_NULL_CACHE_TTL = 60  # 60 seconds for null value caching


class PenetrationOperations:
    """Cache penetration protection operations mixin."""

    async def cache_get_with_null_protection(
        self,
        key: str,
        loader: Any,
        client: Any,
        ttl: int = CacheTTL.DEFAULT,
        cache_get_func: Any = None,
        cache_set_func: Any = None,
        record_lookup: Any = None,
        record_penetration: Any = None,
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
        cached_value = await cache_get_func(key)
        if cached_value is not None:
            if cached_value == _NULL_VALUE_MARKER:
                # Null value cached - data doesn't exist
                if record_penetration:
                    await record_penetration(client, key)
                return None, True
            # Actual data cached
            if record_lookup:
                await record_lookup(key, hit=True)
            return orjson.loads(cached_value), True

        # Cache miss - load from data source
        if record_lookup:
            await record_lookup(key, hit=False)
        value = await loader()

        if value is None:
            # Data doesn't exist - cache null marker to prevent penetration
            await cache_set_func(key, _NULL_VALUE_MARKER, ttl=_NULL_CACHE_TTL)
            if record_penetration:
                await record_penetration(client, key)
            return None, False

        # Cache the actual value
        await cache_set_func(key, orjson.dumps(value).decode('utf-8'), ttl=ttl)
        return value, False

    async def cache_get_json_with_null_protection(
        self,
        key: str,
        loader: Any,
        client: Any,
        ttl: int = CacheTTL.DEFAULT,
        cache_get_with_null_protection_func: Any = None,
    ) -> Any:
        """Get JSON cached value with null protection (simplified API).

        Args:
            key: Cache key
            loader: Async callable to load value if cache miss
            ttl: Cache TTL in seconds

        Returns:
            Cached or loaded value, or None if data doesn't exist
        """
        value, _from_cache = await cache_get_with_null_protection_func(
            key,
            loader,
            client,
            ttl=ttl,
        )
        return value

    async def set_null_value(
        self, client: Any, key: str, cache_set_func: Any = None
    ) -> bool:
        """Explicitly set a null value marker for a key.

        Use this when you know a resource doesn't exist and want to
        prevent future cache penetration attempts.

        Args:
            key: Cache key to mark as null

        Returns:
            True if successfully set
        """
        return await cache_set_func(key, _NULL_VALUE_MARKER, ttl=_NULL_CACHE_TTL)

    async def is_null_value_cached(
        self, client: Any, key: str, cache_get_func: Any = None
    ) -> bool:
        """Check if a key has a null value marker cached.

        Args:
            key: Cache key to check

        Returns:
            True if key has null marker cached
        """
        value = await cache_get_func(key)
        return value == _NULL_VALUE_MARKER

    async def invalidate_null_cache(
        self, client: Any, pattern: str | None = None
    ) -> int:
        """Invalidate null value caches.

        Uses Lua script for efficient batch processing.

        Args:
            pattern: Optional key pattern to match (e.g., "podcast:meta:*").
                     If None, clears all null markers (use with caution).

        Returns:
            Number of keys deleted
        """
        if pattern is None:
            logger.warning("invalidate_null_cache called without pattern - skipping")
            return 0

        started = perf_counter()

        # Use Lua script for efficient batch processing
        lua_script = """
        local cursor = ARGV[1]
        local pattern = ARGV[2]
        local null_marker = ARGV[3]
        local count = 0

        local result = redis.call('SCAN', cursor, 'MATCH', pattern, 'COUNT', 100)
        local new_cursor = result[1]
        local keys = result[2]

        for _, key in ipairs(keys) do
            local value = redis.call('GET', key)
            if value == null_marker then
                redis.call('DEL', key)
                count = count + 1
            end
        end

        return {new_cursor, count}
        """
        script = client.register_script(lua_script)

        total_deleted = 0
        cursor = "0"

        while True:
            result = await script(args=[cursor, pattern, _NULL_VALUE_MARKER])
            cursor = str(result[0])
            batch_deleted = int(result[1])
            total_deleted += batch_deleted

            if cursor == "0":
                break

        if total_deleted > 0:
            logger.info(
                "Invalidated %d null cache entries matching pattern %s",
                total_deleted,
                pattern,
            )

        return total_deleted


# Export constants
NULL_VALUE_MARKER = _NULL_VALUE_MARKER
NULL_CACHE_TTL = _NULL_CACHE_TTL

# Backward compatibility alias
PenetrationProtection = PenetrationOperations
