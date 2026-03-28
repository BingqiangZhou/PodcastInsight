"""Redis Sorted Set Operations.

Operations for managing sorted sets in Redis.
"""

import logging
from time import perf_counter
from typing import Any


logger = logging.getLogger(__name__)


class SortedSetOperations:
    """Sorted set operations mixin."""

    async def sorted_set_add(
        self, client: Any, key: str, member: str, score: float
    ) -> int:
        """Add or update one member in a sorted set."""
        started = perf_counter()
        result = await client.zadd(key, {member: score})
        return int(result or 0)

    async def sorted_set_remove(self, client: Any, key: str, *members: str) -> int:
        """Remove one or more members from a sorted set."""
        if not members:
            return 0
        started = perf_counter()
        result = await client.zrem(key, *members)
        return int(result or 0)

    async def sorted_set_cardinality(self, client: Any, key: str) -> int:
        """Return the number of members in a sorted set."""
        started = perf_counter()
        result = await client.zcard(key)
        return int(result or 0)

    async def sorted_set_range_by_score(
        self,
        client: Any,
        key: str,
        min_score: float | str,
        max_score: float | str,
    ) -> list[str]:
        """Return sorted-set members whose scores fall within the inclusive range."""
        started = perf_counter()
        result = await client.zrangebyscore(key, min_score, max_score)
        return list(result)

    async def sorted_set_remove_by_score(
        self,
        client: Any,
        key: str,
        min_score: float | str,
        max_score: float | str,
    ) -> int:
        """Remove sorted-set members whose scores fall within the inclusive range."""
        started = perf_counter()
        result = await client.zremrangebyscore(key, min_score, max_score)
        return int(result or 0)
