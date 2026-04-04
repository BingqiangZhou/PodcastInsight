"""JWT token blacklist using Redis.

Provides token revocation so that logout and password-change operations
actually invalidate old tokens before their natural expiry.

Key patterns stored in Redis:
  - ``token_blacklist:{jti}`` -- SETEX with remaining TTL, value "1"
  - ``user_tokens:{user_id}`` -- SET of JTIs registered for a user
"""

import logging

from app.core.redis import get_shared_redis


logger = logging.getLogger(__name__)

# Key patterns
_USER_TOKENS_KEY = "user_tokens:{user_id}"
_BLACKLIST_KEY = "token_blacklist:{jti}"

# TTL: maximum token lifetime (7 days)
_MAX_TOKEN_TTL = 7 * 24 * 3600


async def _get_raw_client():
    """Obtain the raw aioredis client from the shared AppCache."""
    app_cache = get_shared_redis()
    return await app_cache._get_client()


async def revoke_token(jti: str, remaining_ttl: int | None = None) -> None:
    """Revoke a single token by its JTI.

    Args:
        jti: The JWT ID claim identifying the token.
        remaining_ttl: Optional remaining TTL in seconds.  Falls back to
            ``_MAX_TOKEN_TTL`` when not provided or non-positive.
    """
    client = await _get_raw_client()
    ttl = remaining_ttl if remaining_ttl and remaining_ttl > 0 else _MAX_TOKEN_TTL
    await client.setex(_BLACKLIST_KEY.format(jti=jti), ttl, "1")
    logger.info("Token revoked: jti=%s ttl=%s", jti, ttl)


async def is_token_revoked(jti: str) -> bool:
    """Check if a token has been revoked.

    Args:
        jti: The JWT ID claim to check.

    Returns:
        ``True`` if the token is on the blacklist, ``False`` otherwise.
    """
    client = await _get_raw_client()
    return bool(await client.exists(_BLACKLIST_KEY.format(jti=jti)))


async def revoke_all_user_tokens(user_id: int) -> None:
    """Revoke all tokens for a user.

    Looks up every JTI registered for *user_id* via the ``user_tokens``
    tracking set, adds each to the blacklist, then clears the set.
    """
    client = await _get_raw_client()
    key = _USER_TOKENS_KEY.format(user_id=user_id)

    # Get all JTIs for this user
    jtis = await client.smembers(key)
    if jtis:
        # Revoke each token in a pipeline
        pipe = client.pipeline()
        for jti in jtis:
            jti_str = jti.decode() if isinstance(jti, bytes) else jti
            pipe.setex(
                _BLACKLIST_KEY.format(jti=jti_str),
                _MAX_TOKEN_TTL,
                "1",
            )
        await pipe.execute()

    # Clear the user's token set
    await client.delete(key)
    logger.info(
        "All tokens revoked for user_id=%s count=%s",
        user_id,
        len(jtis),
    )


async def register_user_token(user_id: int, jti: str) -> None:
    """Register a JTI for a user so it can be bulk-revoked later.

    Args:
        user_id: The user's integer ID.
        jti: The JWT ID claim of the freshly-created token.
    """
    client = await _get_raw_client()
    key = _USER_TOKENS_KEY.format(user_id=user_id)
    await client.sadd(key, jti)
    # Refresh expiry on the tracking set to match max token lifetime
    await client.expire(key, _MAX_TOKEN_TTL)
