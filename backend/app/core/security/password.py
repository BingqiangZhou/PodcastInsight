"""Password hashing (bcrypt), API key generation, and password reset tokens."""

import logging
import secrets
from datetime import UTC, datetime, timedelta

import bcrypt
import jwt as pyjwt

from app.core.config import settings


logger = logging.getLogger(__name__)


def get_password_hash(password: str) -> str:
    """Hash password using bcrypt."""
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify plain password against hashed password."""
    try:
        return bcrypt.checkpw(
            plain_password.encode("utf-8"),
            hashed_password.encode("utf-8"),
        )
    except Exception as exc:
        logger.warning("Password verification failed: %s", type(exc).__name__)
        return False


def generate_password_reset_token(email: str) -> str:
    """Generate password reset token."""
    delta = timedelta(hours=settings.EMAIL_RESET_TOKEN_EXPIRE_HOURS)
    now = datetime.now(UTC)
    expires = now + delta
    exp = expires.timestamp()
    encoded_jwt = pyjwt.encode(
        {"exp": exp, "nbf": now, "sub": email},
        settings.SECRET_KEY,
        algorithm=settings.ALGORITHM,
    )
    return encoded_jwt


def verify_password_reset_token(token: str) -> str | None:
    """Verify password reset token."""
    try:
        decoded_token = pyjwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM],
        )
        return decoded_token["sub"]
    except pyjwt.InvalidTokenError:
        return None


def generate_api_key() -> str:
    """Generate a secure API key."""
    return secrets.token_urlsafe(32)


def generate_random_string(length: int = 32) -> str:
    """Generate a random string."""
    return secrets.token_urlsafe(length)
