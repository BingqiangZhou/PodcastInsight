"""Cache Penetration Protection Helpers.

Provides utility functions for using null value caching to prevent
cache penetration attacks when querying for non-existent data.

缓存穿透防护辅助工具 - 提供空值缓存功能防止缓存穿透攻击
"""

from __future__ import annotations

from collections.abc import Awaitable, Callable
from typing import Any, TypeVar

from app.core.redis import PodcastRedis, get_shared_redis


T = TypeVar("T")


async def get_with_null_protection(
    key: str,
    loader: Callable[[], Awaitable[T]],
    *,
    redis: PodcastRedis | None = None,
    ttl: int = 3600,
) -> tuple[T | None, bool]:
    """Get cached value with null value caching to prevent cache penetration.

    When the loader returns None (data not found), a special marker is cached
    to prevent repeated database queries for the same non-existent data.

    Args:
        key: Cache key
        loader: Async callable to load value if cache miss (should return None if not found)
        redis: Optional Redis instance (uses shared if not provided)
        ttl: Cache TTL in seconds for actual data (null values use 60 seconds)

    Returns:
        Tuple of (value, from_cache). Value is None if data doesn't exist.

    Example:
        # In a service method
        episode, from_cache = await get_with_null_protection(
            f"episode:{episode_id}",
            lambda: repo.get_episode_by_id(episode_id),
            ttl=3600,
        )
        if episode is None:
            raise HTTPException(404, "Episode not found")
        return episode

    """
    redis_client = redis or get_shared_redis()
    return await redis_client.cache_get_with_null_protection(
        key,
        loader,
        ttl=ttl,
    )


async def get_json_with_null_protection(
    key: str,
    loader: Callable[[], Awaitable[Any]],
    *,
    redis: PodcastRedis | None = None,
    ttl: int = 3600,
) -> Any:
    """Get JSON cached value with null protection (simplified API).

    Args:
        key: Cache key
        loader: Async callable to load value if cache miss
        redis: Optional Redis instance (uses shared if not provided)
        ttl: Cache TTL in seconds

    Returns:
        Cached or loaded value, or None if data doesn't exist

    Example:
        data = await get_json_with_null_protection(
            f"subscription:{sub_id}",
            lambda: fetch_subscription_data(sub_id),
            ttl=900,
        )

    """
    redis_client = redis or get_shared_redis()
    return await redis_client.cache_get_json_with_null_protection(
        key,
        loader,
        ttl=ttl,
    )


async def set_null_marker(
    key: str,
    *,
    redis: PodcastRedis | None = None,
) -> bool:
    """Explicitly set a null value marker for a key.

    Use this when you know a resource doesn't exist and want to
    prevent future cache penetration attempts.

    Args:
        key: Cache key to mark as null
        redis: Optional Redis instance (uses shared if not provided)

    Returns:
        True if successfully set

    """
    redis_client = redis or get_shared_redis()
    return await redis_client.set_null_value(key)


async def is_null_cached(
    key: str,
    *,
    redis: PodcastRedis | None = None,
) -> bool:
    """Check if a key has a null value marker cached.

    Args:
        key: Cache key to check
        redis: Optional Redis instance (uses shared if not provided)

    Returns:
        True if key has null marker cached

    """
    redis_client = redis or get_shared_redis()
    return await redis_client.is_null_value_cached(key)


async def invalidate_null_cache(
    pattern: str,
    *,
    redis: PodcastRedis | None = None,
) -> int:
    """Invalidate null value caches matching a pattern.

    Args:
        pattern: Key pattern to match (e.g., "podcast:meta:*")
        redis: Optional Redis instance (uses shared if not provided)

    Returns:
        Number of keys deleted

    """
    redis_client = redis or get_shared_redis()
    return await redis_client.invalidate_null_cache(pattern)
