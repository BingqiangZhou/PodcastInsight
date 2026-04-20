"""JWT token creation, verification, and related utilities."""

import logging
import time
import uuid
from datetime import timedelta

import jwt as pyjwt
from fastapi import Depends, Header, HTTPException, Query, status
from jwt.exceptions import InvalidTokenError as JWTError

from app.core.config import settings


logger = logging.getLogger(__name__)


async def create_access_token(
    data: dict,
    expires_delta: timedelta | None = None,
) -> str:
    """Create JWT access token."""
    custom_minutes = expires_delta.total_seconds() / 60 if expires_delta else None

    # Assign a unique token ID for logging
    jti = str(uuid.uuid4())

    expire_minutes_val = custom_minutes or settings.ACCESS_TOKEN_EXPIRE_MINUTES
    now_ts = int(time.time())
    claims = {
        "exp": now_ts + int(expire_minutes_val * 60),
        "iat": now_ts,
    }
    claims.update(data or {})
    claims["jti"] = jti

    # HS256 is already highly optimized in python-jose (uses pyca/cryptography)
    # The jose library will cache the key internally
    encoded_jwt = pyjwt.encode(
        claims,
        settings.SECRET_KEY,
        algorithm=settings.ALGORITHM,
    )

    return encoded_jwt


async def create_refresh_token(
    data: dict,
    expires_delta: timedelta | None = None,
) -> str:
    """Create JWT refresh token."""
    # Use REFRESH_TOKEN_EXPIRE_DAYS as default if no expires_delta provided
    if expires_delta is None:
        expires_delta = timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)

    custom_days = expires_delta.total_seconds() / (24 * 60 * 60)

    # Assign a unique token ID for logging
    jti = str(uuid.uuid4())

    expire_minutes_val = custom_days * 24 * 60
    now_ts = int(time.time())
    claims = {
        "exp": now_ts + int(expire_minutes_val * 60),
        "iat": now_ts,
        "type": "refresh",
    }
    claims.update(data or {})
    claims["jti"] = jti

    encoded_jwt = pyjwt.encode(
        claims,
        settings.SECRET_KEY,
        algorithm=settings.ALGORITHM,
    )

    return encoded_jwt


async def verify_token(token: str, token_type: str = "access") -> dict:
    """Verify and decode JWT token."""
    try:
        logger.debug("Verifying token")

        payload = pyjwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM],
        )

        logger.debug("Token decoded successfully")

        # Check token type if present
        if "type" in payload and payload["type"] != token_type:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token type",
            )

        # Check expiration quickly (epoch comparison)
        exp = payload.get("exp")
        if exp is None or time.time() > exp:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token has expired",
            )

        return payload

    except JWTError as e:
        # This is an actual error condition
        logger.error(f"JWTError during token decode: {type(e).__name__}: {e!s}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
        ) from e


async def verify_token_optional(
    token: str | None = None,
    token_type: str = "access",
) -> dict:
    """Verify token if provided.
    In development mode, returns a mock user for testing when no token is provided.
    In production, raises an exception when no token is provided.
    """
    if token is None:
        # Only return mock user in development mode with DEBUG enabled
        if settings.ENVIRONMENT == "development" and settings.DEBUG:
            return {
                "sub": "1",  # Use integer for mock user
                "email": "dev-mock@internal.local",
                "type": token_type,
                "exp": int(time.time()) + 3600,  # 1 hour from now
            }
        # Production: require authentication
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required",
        )

    return await verify_token(token, token_type)


async def get_token_from_request(
    token: str | None = Query(
        None,
        description="Auth token (development only, deprecated - use Authorization header)",
    ),
    authorization: str | None = Header(
        None, description="Bearer token in Authorization header"
    ),
) -> dict:
    """Extract token from Authorization header.

    Query parameter token is deprecated and only accepted in development mode.
    In production, only the Authorization header is accepted.

    This function can be used directly as a FastAPI dependency.
    """
    # Prefer Authorization header over query parameter
    if authorization:
        if authorization.startswith("Bearer "):
            resolved_token = authorization[7:]  # Remove "Bearer " prefix
        else:
            resolved_token = authorization
    elif token is not None:
        # Query parameter provided (no Authorization header)
        if settings.ENVIRONMENT != "development":
            logger.warning(
                "Query parameter token rejected in non-development environment"
            )
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Query parameter authentication not allowed in production",
            )
        logger.warning(
            "DEPRECATED: Token passed via query parameter. Use Authorization header instead."
        )
        resolved_token = token
    else:
        resolved_token = None

    # If no token found, require authentication
    if resolved_token is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required",
        )

    # Verify the token
    return await verify_token(resolved_token, token_type="access")


# === Type Safety Helpers ===

# Type alias for user_id - always an integer in the application
# JWT token returns user["sub"] as string, but we convert it to int everywhere
UserId = int


def get_user_id_from_token(token_payload: dict) -> UserId:
    """Extract and convert user_id from JWT token payload.

    JWT tokens store user ID as string in the "sub" claim.
    This function converts it to int for type consistency throughout the application.

    Args:
        token_payload: The decoded JWT token payload (dict from verify_token)

    Returns:
        UserId: The user ID as an integer

    Raises:
        KeyError: If "sub" claim is missing
        ValueError: If "sub" claim is not a valid integer

    """
    sub = token_payload.get("sub")
    if sub is None:
        raise KeyError("Token payload missing 'sub' claim")

    try:
        return int(sub)
    except (ValueError, TypeError) as e:
        raise ValueError(f"Token 'sub' claim '{sub}' is not a valid integer") from e


async def require_user_id(
    user: dict = Depends(get_token_from_request),
) -> UserId:
    """FastAPI dependency that extracts and validates user_id from JWT token.

    This is a type-safe alternative to manually calling int(user["sub"]).

    Usage:
        ```python
        @router.get("/example")
        async def example_endpoint(user_id: UserId = Depends(require_user_id)):
            # user_id is already an int
            service = SomeService(db, user_id)
        ```

    Returns:
        UserId: The user ID as an integer

    Raises:
        HTTPException: If token is invalid or missing required claims

    """
    try:
        return get_user_id_from_token(user)
    except (KeyError, ValueError) as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid token: {e!s}",
        ) from e
