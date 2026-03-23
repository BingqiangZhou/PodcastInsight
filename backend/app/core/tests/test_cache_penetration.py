"""Tests for cache penetration protection.

Tests for null value caching to prevent cache penetration attacks.
"""

import pytest

from app.core.redis import (
    PodcastRedis,
    _NULL_CACHE_TTL,
    _NULL_VALUE_MARKER,
)


@pytest.mark.asyncio
class TestCachePenetrationProtection:
    """Test suite for cache penetration protection features."""

    async def test_cache_get_with_null_protection_miss_then_cache(
        self, redis_helper: PodcastRedis
    ):
        """Test that null values are cached after initial miss."""

        call_count = 0

        async def loader():
            nonlocal call_count
            call_count += 1
            return None  # Simulate data not found

        key = "test:null:protection:1"

        # First call - should hit loader and cache null
        value, from_cache = await redis_helper.cache_get_with_null_protection(
            key, loader, ttl=60
        )

        assert value is None
        assert from_cache is False
        assert call_count == 1

        # Verify null marker is cached
        cached = await redis_helper.cache_get(key)
        assert cached == _NULL_VALUE_MARKER

        # Second call - should return cached null without calling loader
        value2, from_cache2 = await redis_helper.cache_get_with_null_protection(
            key, loader, ttl=60
        )

        assert value2 is None
        assert from_cache2 is True
        assert call_count == 1  # Loader not called again

    async def test_cache_get_with_null_protection_value_cached(
        self, redis_helper: PodcastRedis
    ):
        """Test that actual values are cached normally."""

        call_count = 0
        expected_data = {"id": 1, "name": "test"}

        async def loader():
            nonlocal call_count
            call_count += 1
            return expected_data

        key = "test:null:protection:2"

        # First call - should hit loader and cache value
        value, from_cache = await redis_helper.cache_get_with_null_protection(
            key, loader, ttl=60
        )

        assert value == expected_data
        assert from_cache is False
        assert call_count == 1

        # Second call - should return cached value without calling loader
        value2, from_cache2 = await redis_helper.cache_get_with_null_protection(
            key, loader, ttl=60
        )

        assert value2 == expected_data
        assert from_cache2 is True
        assert call_count == 1  # Loader not called again

    async def test_set_null_value(self, redis_helper: PodcastRedis):
        """Test explicit null value setting."""

        key = "test:null:explicit:1"

        # Set null value explicitly
        result = await redis_helper.set_null_value(key)
        assert result is True

        # Check it's cached as null
        cached = await redis_helper.cache_get(key)
        assert cached == _NULL_VALUE_MARKER

        # Check is_null_value_cached
        is_null = await redis_helper.is_null_value_cached(key)
        assert is_null is True

    async def test_is_null_value_cached(self, redis_helper: PodcastRedis):
        """Test is_null_value_cached method."""

        key = "test:null:check:1"

        # Initially not cached
        assert await redis_helper.is_null_value_cached(key) is False

        # Set null value
        await redis_helper.set_null_value(key)

        # Now should be true
        assert await redis_helper.is_null_value_cached(key) is True

        # Set actual value
        await redis_helper.cache_set(key, "actual_value")

        # Should no longer be null
        assert await redis_helper.is_null_value_cached(key) is False

    async def test_invalidate_null_cache(self, redis_helper: PodcastRedis):
        """Test invalidating null caches by pattern."""

        # Set up some test keys
        await redis_helper.set_null_value("test:null:pattern:1")
        await redis_helper.set_null_value("test:null:pattern:2")
        await redis_helper.cache_set("test:null:pattern:3", "real_value")
        await redis_helper.set_null_value("other:key:1")

        # Invalidate null caches with pattern
        count = await redis_helper.invalidate_null_cache("test:null:pattern:*")

        assert count == 2  # Only the two null markers

        # Verify
        assert await redis_helper.is_null_value_cached("test:null:pattern:1") is False
        assert await redis_helper.is_null_value_cached("test:null:pattern:2") is False
        assert await redis_helper.cache_get("test:null:pattern:3") == "real_value"
        assert await redis_helper.is_null_value_cached("other:key:1") is True

    async def test_null_cache_ttl(self, redis_helper: PodcastRedis):
        """Test that null caches have correct TTL."""

        key = "test:null:ttl:1"

        await redis_helper.set_null_value(key)

        ttl = await redis_helper.get_ttl(key)
        # TTL should be close to _NULL_CACHE_TTL (60 seconds)
        assert _NULL_CACHE_TTL - 1 <= ttl <= _NULL_CACHE_TTL

    async def test_cache_penetration_metrics(self, redis_helper: PodcastRedis):
        """Test cache penetration metrics recording."""

        async def none_loader():
            return None

        key = "test:penetration:metrics:1"

        # Clear any existing metrics
        await redis_helper.invalidate_null_cache("test:penetration:*")

        # Make several calls that will be cached as null
        for _ in range(3):
            await redis_helper.cache_get_with_null_protection(key, none_loader)

        # Get penetration metrics
        metrics = await redis_helper.get_penetration_metrics()

        assert "total_attempts" in metrics
        assert metrics["total_attempts"] >= 3
        assert "by_namespace" in metrics

    async def test_cache_get_json_with_null_protection(
        self, redis_helper: PodcastRedis
    ):
        """Test the simplified JSON API with null protection."""

        call_count = 0

        async def loader():
            nonlocal call_count
            call_count += 1
            return None

        key = "test:null:json:1"

        # First call
        result1 = await redis_helper.cache_get_json_with_null_protection(
            key, loader, ttl=60
        )
        assert result1 is None
        assert call_count == 1

        # Second call - should use cache
        result2 = await redis_helper.cache_get_json_with_null_protection(
            key, loader, ttl=60
        )
        assert result2 is None
        assert call_count == 1  # Not called again

    async def test_penetration_included_in_runtime_metrics(
        self, redis_helper: PodcastRedis
    ):
        """Test that penetration metrics are included in runtime metrics."""

        async def none_loader():
            return None

        key = "test:runtime:metrics:1"

        # Generate some penetration events
        await redis_helper.cache_get_with_null_protection(key, none_loader)
        await redis_helper.cache_get_with_null_protection(key, none_loader)

        # Get full runtime metrics
        metrics = await redis_helper.get_runtime_metrics()

        # Should have penetration section
        assert "penetration" in metrics
        assert "total_attempts" in metrics["penetration"]
        assert metrics["penetration"]["total_attempts"] >= 2
