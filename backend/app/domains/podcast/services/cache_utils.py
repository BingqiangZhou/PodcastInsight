"""Shared cache access helpers for best-effort read/write/invalidate flows."""

from __future__ import annotations

from collections.abc import Awaitable, Callable
from typing import TypeVar


T = TypeVar("T")


async def _safe_cache_operation(
    operation: Callable[[], Awaitable[T]],
    *,
    log_warning: Callable[[str], None],
    error_message: str,
    default: T | None = None,
) -> T | None:
    """Execute a cache operation and swallow backend errors."""
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
    """Try cache read and swallow backend cache errors."""
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
    """Try cache write and return success status."""
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
    """Try cache invalidation and return success status."""
    result = await _safe_cache_operation(
        invalidator,
        log_warning=log_warning,
        error_message=error_message,
        default=None,
    )
    return result is not None
