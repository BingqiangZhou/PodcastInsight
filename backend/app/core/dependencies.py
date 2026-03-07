"""Compatibility exports for authentication dependencies."""

from app.core.providers import (
    get_current_active_user,
    get_current_superuser,
    get_current_user,
)


__all__ = [
    "get_current_active_user",
    "get_current_superuser",
    "get_current_user",
]
