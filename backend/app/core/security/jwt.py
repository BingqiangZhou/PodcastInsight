"""JWT token creation, verification, and related utilities."""

import logging
import time
import uuid
from datetime import timedelta
from typing import Any

from fastapi import Depends, Header, HTTPException, Query, status
import jwt as pyjwt
from jwt.exceptions import InvalidTokenError as JWTError

from app.core.config import settings


logger = logging.getLogger(__name__)


# Token operation cache (micro-optimization)
class TokenOptimizer:
    """Pre-compute token claims to reduce CPU cycles per request."""

    @staticmethod
    def build_standard_claims(
        extra_claims: dict[str, Any] = None,
        expire_minutes: int = None,
        is_refresh: bool = False,
    ) -> dict[str, Any]:
        """Fast claim builder optimized for 500+ req/s throughput."""
        # Use time.time() directly to avoid timezone issues with datetime.now(timezone.utc).timestamp()
        now_timestamp = int(time.time())
        expire_seconds = (expire_minutes or settings.ACCESS_TOKEN_EXPIRE_MINUTES) * 60
        exp_timestamp = now_timestamp + expire_seconds

        claims = {
            "exp": exp_timestamp,
            "iat": now_timestamp,
        }

        if is_refresh:
            claims["type"] = "refresh"

        if extra_claims:
            claims.update(extra_claims)

        return claims


token_optimizer = TokenOptimizer()


async def create_access_token(
    data: dict,
    expires_delta: timedelta | None = None,
) -> str:
    """Create JWT access token - optimized performance version."""
    # Fast path - using optimized claim builder
    custom_minutes = expires_delta.total_seconds() / 60 if expires_delta else None

    # Assign a unique token ID for revocation support
    jti = str(uuid.uuid4())

    claims = token_optimizer.build_standard_claims(
        extra_claims=data,
        expire_minutes=custom_minutes,
        is_refresh=False,
    )
    claims["jti"] = jti

    # HS256 is already highly optimized in python-jose (uses pyca/cryptography)
    # The jose library will cache the key internally
    encoded_jwt = pyjwt.encode(
        claims,
        settings.SECRET_KEY,
        algorithm=settings.ALGORITHM,
    )

    # Register token for bulk-revocation on logout/password-change
    sub = data.get("sub")
    if sub is not None:
        try:
            from app.core.security.token_blacklist import register_user_token

            await register_user_token(int(sub), jti)
        except (ImportError, ConnectionError, OSError) as exc:
            logger.warning("Token registration skipped: %s", exc)

    return encoded_jwt


async def create_refresh_token(
    data: dict,
    expires_delta: timedelta | None = None,
) -> str:
    """Create JWT refresh token - optimized performance version."""
    # Use REFRESH_TOKEN_EXPIRE_DAYS as default if no expires_delta provided
    if expires_delta is None:
        expires_delta = timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)

    custom_days = expires_delta.total_seconds() / (24 * 60 * 60)

    # Assign a unique token ID for revocation support
    jti = str(uuid.uuid4())

    claims = token_optimizer.build_standard_claims(
        extra_claims=data,
        expire_minutes=custom_days * 24 * 60,
        is_refresh=True,
    )
    claims["jti"] = jti

    encoded_jwt = pyjwt.encode(
        claims,
        settings.SECRET_KEY,
        algorithm=settings.ALGORITHM,
    )

    # Register token for bulk-revocation on logout/password-change
    sub = data.get("sub")
    if sub is not None:
        try:
            from app.core.security.token_blacklist import register_user_token

            await register_user_token(int(sub), jti)
        except (ImportError, ConnectionError, OSError) as exc:
            logger.warning("Token registration skipped: %s", exc)

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

        # Check token blacklist (revocation)
        jti = payload.get("jti")
        if jti:
            try:
                from app.core.security.token_blacklist import is_token_revoked

                if await is_token_revoked(jti):
                    raise HTTPException(
                        status_code=status.HTTP_401_UNAUTHORIZED,
                        detail="Token has been revoked",
                    )
            except HTTPException:
                raise
            except (ImportError, ConnectionError, OSError) as exc:
                # Redis unavailable -- allow the token through rather than
                # blocking all authenticated requests.
                logger.warning("Token blacklist check skipped: %s", exc)

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
