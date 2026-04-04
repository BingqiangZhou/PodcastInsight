"""Redis Lock Operations.

Distributed lock implementation for coordination across processes.
"""

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
    ) -> bool:
        """Acquire distributed lock.

        Returns True if lock acquired.
        """
        key = f"podcast:lock:{lock_name}"
        result = await client.set(key, value, ex=expire, nx=True)
        return bool(result)

    async def release_lock(self, client: Any, lock_name: str) -> None:
        """Release distributed lock."""
        await client.delete(f"podcast:lock:{lock_name}")

    async def set_if_not_exists(
        self,
        client: Any,
        key: str,
        value: str,
        *,
        ttl: int | None = None,
    ) -> bool:
        """Set a key only if it does not already exist."""
        result = await client.set(key, value, ex=ttl, nx=True)
        return bool(result)
