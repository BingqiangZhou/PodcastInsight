"""Redis Lock Operations.

Distributed lock implementation for coordination across processes.
"""

import secrets
from time import perf_counter
from typing import Any

from app.core.cache_ttl import CacheTTL


class LockOperations:
    """Distributed lock operations mixin."""

    async def acquire_lock(
        self,
        client: Any,
        lock_name: str,
        expire: int = CacheTTL.LOCK_TIMEOUT,
        value: str = "1",
        record_timing: Any = None,
    ) -> bool:
        """Acquire distributed lock.

        Returns True if lock acquired.
        """
        key = f"podcast:lock:{lock_name}"
        started = perf_counter()
        result = await client.set(key, value, ex=expire, nx=True)
        if record_timing:
            await record_timing("SET", (perf_counter() - started) * 1000)
        return bool(result)

    async def release_lock(
        self, client: Any, lock_name: str, record_timing: Any = None
    ) -> None:
        """Release distributed lock."""
        started = perf_counter()
        await client.delete(f"podcast:lock:{lock_name}")
        if record_timing:
            await record_timing("DEL", (perf_counter() - started) * 1000)

    async def set_if_not_exists(
        self,
        client: Any,
        key: str,
        value: str,
        *,
        ttl: int | None = None,
        record_timing: Any = None,
    ) -> bool:
        """Set a key only if it does not already exist."""
        started = perf_counter()
        result = await client.set(key, value, ex=ttl, nx=True)
        if record_timing:
            await record_timing("SET", (perf_counter() - started) * 1000)
        return bool(result)
