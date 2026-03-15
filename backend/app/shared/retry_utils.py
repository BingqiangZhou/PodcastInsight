"""Reusable retry utilities with exponential backoff."""

from __future__ import annotations

import asyncio
import functools
import logging
import random
from collections.abc import Awaitable, Callable
from typing import ParamSpec, TypeVar


P = ParamSpec("P")
T = TypeVar("T")


def with_retry(
    *,
    max_retries: int = 3,
    base_delay: float = 1.0,
    retryable_exceptions: tuple[type[Exception], ...] = (Exception,),
    non_retryable_exceptions: tuple[type[Exception], ...] = (),
    logger: logging.Logger | None = None,
    operation_name: str = "operation",
) -> Callable[[Callable[P, Awaitable[T]]], Callable[P, Awaitable[T]]]:
    """Decorator for async functions with exponential backoff retry.

    Args:
        max_retries: Maximum number of retry attempts.
        base_delay: Base delay in seconds for exponential backoff.
        retryable_exceptions: Tuple of exception types that should trigger retry.
        non_retryable_exceptions: Tuple of exception types that should NOT be retried.
        logger: Optional logger for retry messages.
        operation_name: Name of the operation for logging.

    Returns:
        Decorated async function with retry logic.

    Example:
        @with_retry(
            max_retries=3,
            base_delay=1.0,
            retryable_exceptions=(aiohttp.ClientError, TimeoutError),
            non_retryable_exceptions=(ValidationError,),
            logger=logger,
            operation_name="API call",
        )
        async def call_api() -> str:
            ...
    """

    def decorator(func: Callable[P, Awaitable[T]]) -> Callable[P, Awaitable[T]]:
        @functools.wraps(func)
        async def wrapper(*args: P.args, **kwargs: P.kwargs) -> T:
            for attempt in range(max_retries):
                try:
                    return await func(*args, **kwargs)
                except non_retryable_exceptions:
                    raise
                except retryable_exceptions as exc:
                    if attempt >= max_retries - 1:
                        if logger:
                            logger.error(
                                "%s retries exhausted attempts=%s error_type=%s error=%s",
                                operation_name,
                                max_retries,
                                type(exc).__name__,
                                exc,
                            )
                        raise

                    backoff = base_delay * (2**attempt)
                    jitter = random.uniform(0, 0.5 * backoff)
                    await asyncio.sleep(backoff + jitter)

                    if logger:
                        logger.warning(
                            "%s transient error attempt=%s/%s retryable=true error_type=%s error=%s",
                            operation_name,
                            attempt + 1,
                            max_retries,
                            type(exc).__name__,
                            exc,
                        )

            # This should never be reached, but satisfies type checker
            raise RuntimeError(f"{operation_name} failed after {max_retries} attempts")

        return wrapper

    return decorator


def calculate_backoff(attempt: int, base_delay: float = 1.0) -> float:
    """Calculate backoff time with jitter for retry attempts.

    Args:
        attempt: Current attempt number (0-indexed).
        base_delay: Base delay in seconds.

    Returns:
        Backoff time in seconds with added jitter.
    """
    backoff = base_delay * (2**attempt)
    jitter = random.uniform(0, 0.5 * backoff)
    return backoff + jitter
