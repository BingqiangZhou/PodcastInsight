"""JWT token blacklist using Redis.

Provides token revocation so that logout and password-change operations
actually invalidate old tokens before their natural expiry.

Key patterns stored in Redis:
  - ``token_blacklist:{jti}`` -- SETEX with remaining TTL, value "1"
  - ``user_tokens:{user_id}`` -- SET of JTIs registered for a user
"""

import logging

import redis as redis_lib

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
    try:
        client = await _get_raw_client()
        ttl = remaining_ttl if remaining_ttl and remaining_ttl > 0 else _MAX_TOKEN_TTL
        await client.setex(_BLACKLIST_KEY.format(jti=jti), ttl, "1")
        logger.info("Token revoked: jti=%s ttl=%s", jti, ttl)
    except (redis_lib.RedisError, ConnectionError, OSError) as exc:
        logger.warning("Token revoke failed — Redis unavailable: jti=%s error=%s", jti, exc)


async def is_token_revoked(jti: str) -> bool:
    """Check if a token has been revoked.

    Args:
        jti: The JWT ID claim to check.

    Returns:
        ``True`` if the token is on the blacklist, ``False`` otherwise.
        Fails open (returns ``False``) when Redis is unavailable.
    """
    try:
        client = await _get_raw_client()
        return bool(await client.exists(_BLACKLIST_KEY.format(jti=jti)))
    except (redis_lib.RedisError, ConnectionError, OSError) as exc:
        logger.warning("Token blacklist check failed — Redis unavailable: jti=%s error=%s", jti, exc)
        return False  # Fail open: treat as not revoked


async def revoke_all_user_tokens(user_id: int) -> None:
    """Revoke all tokens for a user.

    Looks up every JTI registered for *user_id* via the ``user_tokens``
    tracking set, adds each to the blacklist, then clears the set.

    Note: Uses SSCAN pagination to avoid loading all JTIs into memory
    at once for users with many active sessions.
    """
    try:
        client = await _get_raw_client()
        key = _USER_TOKENS_KEY.format(user_id=user_id)

        # Use SSCAN for paginated iteration instead of SMEMBERS to avoid
        # loading the entire set into memory at once.
        jti_count = 0

        # Collect and revoke in batches
        batch: list[str] = []
        async for jti in client.sscan_iter(key, count=100):
            jti_str = jti.decode() if isinstance(jti, bytes) else jti
            batch.append(jti_str)
            if len(batch) >= 100:
                pipe = client.pipeline()
                for j in batch:
                    pipe.setex(_BLACKLIST_KEY.format(jti=j), _MAX_TOKEN_TTL, "1")
                await pipe.execute()
                jti_count += len(batch)
                batch = []

        # Flush remaining
        if batch:
            pipe = client.pipeline()
            for j in batch:
                pipe.setex(_BLACKLIST_KEY.format(jti=j), _MAX_TOKEN_TTL, "1")
            await pipe.execute()
            jti_count += len(batch)

        # Clear the user's token set
        await client.delete(key)
        logger.info(
            "All tokens revoked for user_id=%s count=%s",
            user_id,
            jti_count,
        )
    except (redis_lib.RedisError, ConnectionError, OSError) as exc:
        logger.warning(
            "Revoke all user tokens failed — Redis unavailable: user_id=%s error=%s",
            user_id,
            exc,
        )


async def register_user_token(user_id: int, jti: str) -> None:
    """Register a JTI for a user so it can be bulk-revoked later.

    Args:
        user_id: The user's integer ID.
        jti: The JWT ID claim of the freshly-created token.
    """
    try:
        client = await _get_raw_client()
        key = _USER_TOKENS_KEY.format(user_id=user_id)
        await client.sadd(key, jti)
        # Refresh expiry on the tracking set to match max token lifetime
        await client.expire(key, _MAX_TOKEN_TTL)
    except (redis_lib.RedisError, ConnectionError, OSError) as exc:
        logger.warning(
            "Token registration failed — Redis unavailable: user_id=%s jti=%s error=%s",
            user_id,
            jti,
            exc,
        )
