"""Standardized error handling decorators for routes.

This module provides decorators to reduce boilerplate error handling
code across API and admin routes.
"""

import asyncio
import logging
from collections.abc import Callable
from functools import wraps
from typing import TypeVar

from fastapi import HTTPException, status


logger = logging.getLogger(__name__)

F = TypeVar("F", bound=Callable)


def handle_api_errors(
    operation: str,
    *,
    error_message: str | None = None,
) -> Callable[[F], F]:
    """Decorator for consistent error handling in API routes.

    This decorator:
    - Re-raises HTTPException as-is
    - Converts BaseCustomError to HTTPException with its status code
    - Catches other exceptions and converts to 500 Internal Server Error
    - Logs errors with context

    Args:
        operation: Description of the operation (for logging)
        error_message: Custom error message (optional)

    Returns:
        Decorated function
    """

    def decorator(func: F) -> F:
        @wraps(func)
        async def async_wrapper(*args, **kwargs):
            try:
                return await func(*args, **kwargs)
            except HTTPException:
                raise
            except Exception as exc:
                # Check if this is a BaseCustomError with its own status code
                status_code = getattr(exc, "status_code", None)
                detail = getattr(exc, "message", None) or str(exc)
                if status_code is None:
                    status_code = status.HTTP_500_INTERNAL_SERVER_ERROR
                    detail = error_message or f"Failed to {operation}"

                if status_code >= 500:
                    logger.error("%s error: %s", operation, exc)
                else:
                    logger.warning("%s error: %s", operation, exc)

                raise HTTPException(status_code=status_code, detail=detail) from exc

        @wraps(func)
        def sync_wrapper(*args, **kwargs):
            try:
                return func(*args, **kwargs)
            except HTTPException:
                raise
            except Exception as exc:
                status_code = getattr(exc, "status_code", None)
                detail = getattr(exc, "message", None) or str(exc)
                if status_code is None:
                    status_code = status.HTTP_500_INTERNAL_SERVER_ERROR
                    detail = error_message or f"Failed to {operation}"

                if status_code >= 500:
                    logger.error("%s error: %s", operation, exc)
                else:
                    logger.warning("%s error: %s", operation, exc)

                raise HTTPException(status_code=status_code, detail=detail) from exc

        if asyncio.iscoroutinefunction(func):
            return async_wrapper  # type: ignore
        return sync_wrapper  # type: ignore

    return decorator


def handle_admin_errors(
    operation: str,
    *,
    error_detail: str | None = None,
) -> Callable[[F], F]:
    """Decorator for consistent error handling in admin routes.

    Similar to handle_api_errors but uses simpler error messages
    suitable for admin panel responses.
    """

    def decorator(func: F) -> F:
        @wraps(func)
        async def async_wrapper(*args, **kwargs):
            try:
                return await func(*args, **kwargs)
            except HTTPException:
                raise
            except Exception as exc:
                status_code = getattr(exc, "status_code", None)
                detail = getattr(exc, "message", None) or error_detail or f"Failed to {operation}"
                if status_code is None:
                    status_code = status.HTTP_500_INTERNAL_SERVER_ERROR
                    detail = error_detail or f"Failed to {operation}"

                if status_code >= 500:
                    logger.error("%s error: %s", operation, exc)
                else:
                    logger.warning("%s error: %s", operation, exc)

                raise HTTPException(status_code=status_code, detail=detail) from exc

        @wraps(func)
        def sync_wrapper(*args, **kwargs):
            try:
                return func(*args, **kwargs)
            except HTTPException:
                raise
            except Exception as exc:
                status_code = getattr(exc, "status_code", None)
                detail = getattr(exc, "message", None) or error_detail or f"Failed to {operation}"
                if status_code is None:
                    status_code = status.HTTP_500_INTERNAL_SERVER_ERROR
                    detail = error_detail or f"Failed to {operation}"

                if status_code >= 500:
                    logger.error("%s error: %s", operation, exc)
                else:
                    logger.warning("%s error: %s", operation, exc)

                raise HTTPException(status_code=status_code, detail=detail) from exc

        if asyncio.iscoroutinefunction(func):
            return async_wrapper  # type: ignore
        return sync_wrapper  # type: ignore

    return decorator
