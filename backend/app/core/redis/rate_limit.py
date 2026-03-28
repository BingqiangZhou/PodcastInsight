"""Redis Rate Limiting Operations.

Simple rate limiting using Redis.
"""

import logging
from time import perf_counter
from typing import Any


logger = logging.getLogger(__name__)


class RateLimitOperations:
    """Rate limiting operations mixin."""

    async def check_rate_limit(
        self,
        client: Any,
        user_id: int,
        action: str,
        limit: int,
        window: int,
    ) -> bool:
        """Simple rate limiting using Redis.

        Returns True if allowed
        """
        key = f"podcast:rate:{user_id}:{action}"
        started = perf_counter()
        current = await client.get(key)
        # Note: timing recorded by caller

        if current is None:
            set_started = perf_counter()
            await client.setex(key, window, 1)
            return True

        count = int(current)
        if count >= limit:
            return False

        incr_started = perf_counter()
        await client.incr(key)
        return True
