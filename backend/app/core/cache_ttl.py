"""Cache TTL Configuration.

Centralized configuration for all cache TTL (Time To Live) values.
This module provides a single source of truth for cache expiration times
across the entire application.

Usage:
    from app.core.cache_ttl import CacheTTL

    # Use predefined TTL values
    await redis.cache_set(key, value, ttl=CacheTTL.FEED_CACHE)

    # Or use the default
    await redis.cache_set(key, value, ttl=CacheTTL.DEFAULT)
"""


class CacheTTL:
    """Unified cache TTL configuration.

    Organized by duration to make it easy to find appropriate values.
    All values are in seconds.

    Categories:
    - Instant: Very short-lived data (seconds)
    - Short: Short-lived data (minutes)
    - Medium: Medium-lived data (hours)
    - Long: Long-lived data (days)
    - Extended: Very long-lived data (weeks/months)
    """

    # === Instant (seconds) ===
    # Used for data that changes frequently or needs quick invalidation
    NULL_VALUE: int = 60  # 1 minute - null value caching for penetration protection

    # === Short (minutes) ===
    # Used for data that changes moderately often
    STALE_REFRESH: int = 300  # 5 minutes - threshold for stale-while-revalidate
    STALE_WHILE_REVALIDATE: int = 300  # 5 minutes - alias for backward compatibility
    STATS_SHORT: int = 600  # 10 minutes - short-lived statistics
    FEED_CACHE: int = 900  # 15 minutes - RSS feed content cache
    STATS_LONG: int = 1800  # 30 minutes - long-lived statistics

    # === Medium (hours) ===
    # Used for data that changes infrequently
    DEFAULT: int = 3600  # 1 hour - default cache duration
    METRICS: int = 3600  # 1 hour - runtime metrics
    LOCK_TIMEOUT: int = 300  # 5 minutes - default lock timeout
    SUBSCRIPTION_LIST: int = 900  # 15 minutes - subscription list cache
    EPISODE_LIST: int = 600  # 10 minutes - episode list cache
    EPISODE_DETAIL: int = 300  # 5 minutes - single episode detail with summary

    # === Long (days) ===
    # Used for data that rarely changes
    EPISODE_METADATA: int = 86400  # 24 hours - episode metadata
    USER_SUBSCRIPTIONS: int = 86400  # 24 hours - user subscription index

    # === Extended (weeks/months) ===
    # Used for data that changes very rarely
    AI_SUMMARY: int = 604800  # 7 days - AI-generated summaries
    PLAYBACK_PROGRESS: int = 2592000  # 30 days - playback progress tracking

    # === Utility Methods ===

    @classmethod
    def for_namespace(cls, namespace: str) -> int:
        """Get appropriate TTL for a cache namespace.

        Args:
            namespace: Cache key namespace (e.g., 'podcast:meta', 'feed')

        Returns:
            Appropriate TTL in seconds
        """
        namespace_ttls = {
            # Podcast related
            "podcast:meta": cls.EPISODE_METADATA,
            "podcast:cache": cls.FEED_CACHE,
            "podcast:summary": cls.AI_SUMMARY,
            "podcast:progress": cls.PLAYBACK_PROGRESS,
            "podcast:subscriptions": cls.USER_SUBSCRIPTIONS,
            "podcast:stats": cls.STATS_LONG,
            "podcast:episodes": cls.SUBSCRIPTION_LIST,
            "podcast:search": cls.STATS_SHORT,
            "podcast:metrics": cls.METRICS,
            # Locks
            "lock": cls.LOCK_TIMEOUT,
        }

        # Try exact match first
        if namespace in namespace_ttls:
            return namespace_ttls[namespace]

        # Try prefix match
        for key, ttl in namespace_ttls.items():
            if namespace.startswith(key):
                return ttl

        # Default fallback
        return cls.DEFAULT

    @classmethod
    def seconds(cls, value: int) -> int:
        """Convert seconds to TTL (identity function for clarity)."""
        return value

    @classmethod
    def minutes(cls, value: int) -> int:
        """Convert minutes to TTL."""
        return value * 60

    @classmethod
    def hours(cls, value: int) -> int:
        """Convert hours to TTL."""
        return value * 3600

    @classmethod
    def days(cls, value: int) -> int:
        """Convert days to TTL."""
        return value * 86400


# Backward compatibility aliases
# These allow gradual migration from hardcoded values
CACHE_TTL_DEFAULT = CacheTTL.DEFAULT
CACHE_TTL_FEED = CacheTTL.FEED_CACHE
CACHE_TTL_METADATA = CacheTTL.EPISODE_METADATA
CACHE_TTL_SUMMARY = CacheTTL.AI_SUMMARY
CACHE_TTL_PROGRESS = CacheTTL.PLAYBACK_PROGRESS
