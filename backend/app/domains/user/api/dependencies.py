"""User API dependency providers."""

from app.core.auth import get_authentication_service, get_current_user


__all__ = ["get_authentication_service", "get_current_user"]
