"""Shared aiohttp client session management."""

from __future__ import annotations

import asyncio

import aiohttp


_shared_http_session: aiohttp.ClientSession | None = None
_shared_http_session_loop_token: int | None = None
_http_session_lock = asyncio.Lock()


def _current_loop_token() -> int | None:
    try:
        return id(asyncio.get_running_loop())
    except RuntimeError:
        return None


async def get_shared_http_session() -> aiohttp.ClientSession:
    """Return a process-level shared aiohttp session for outbound HTTP calls."""
    global _shared_http_session, _shared_http_session_loop_token

    current_loop_token = _current_loop_token()

    async with _http_session_lock:
        if (
            _shared_http_session is not None
            and _shared_http_session_loop_token == current_loop_token
            and not _shared_http_session.closed
        ):
            return _shared_http_session

        if _shared_http_session is not None and not _shared_http_session.closed:
            await _shared_http_session.close()

        # Configure default timeout for all requests
        timeout = aiohttp.ClientTimeout(
            total=120,  # Total request time
            connect=10,  # Connection timeout
            sock_read=30,  # Socket read timeout
        )
        connector = aiohttp.TCPConnector(
            limit=100,
            limit_per_host=20,
            enable_cleanup_closed=True,
        )
        _shared_http_session = aiohttp.ClientSession(
            connector=connector,
            timeout=timeout,
        )
        _shared_http_session_loop_token = current_loop_token
        return _shared_http_session


async def close_shared_http_session() -> None:
    """Close and clear the shared aiohttp session."""
    global _shared_http_session, _shared_http_session_loop_token

    async with _http_session_lock:
        if _shared_http_session is not None and not _shared_http_session.closed:
            await _shared_http_session.close()
        _shared_http_session = None
        _shared_http_session_loop_token = None


async def http_request_with_retry(
    method: str,
    url: str,
    max_retries: int = 3,
    initial_delay: float = 1.0,
    max_delay: float = 30.0,
    exponential_base: float = 2.0,
    retryable_status_codes: set[int] | None = None,
    **kwargs: any,
) -> aiohttp.ClientResponse:
    """Execute HTTP request with exponential backoff retry.

    Args:
        method: HTTP method (GET, POST, etc.)
        url: Request URL
        max_retries: Maximum number of retry attempts (default: 3)
        initial_delay: Initial delay in seconds (default: 1.0)
        max_delay: Maximum delay between retries (default: 30.0)
        exponential_base: Base for exponential backoff (default: 2.0)
        retryable_status_codes: HTTP status codes to retry (default: 5xx, 429)
        **kwargs: Additional arguments for aiohttp request

    Returns:
        aiohttp.ClientResponse object

    Raises:
        aiohttp.ClientError: After all retries exhausted
    """
    import logging

    logger = logging.getLogger(__name__)

    if retryable_status_codes is None:
        retryable_status_codes = {429, 500, 502, 503, 504}

    session = await get_shared_http_session()
    last_exception: Exception | None = None

    for attempt in range(max_retries + 1):
        try:
            response = await session.request(method, url, **kwargs)

            # Check if status code is retryable
            if response.status in retryable_status_codes and attempt < max_retries:
                delay = min(initial_delay * (exponential_base ** attempt), max_delay)
                logger.warning(
                    "HTTP %s %s returned %d, retrying in %.1fs (attempt %d/%d)",
                    method,
                    url,
                    response.status,
                    delay,
                    attempt + 1,
                    max_retries,
                )
                await response.release()  # Release connection before retry
                await asyncio.sleep(delay)
                continue

            return response

        except (TimeoutError, aiohttp.ClientError) as exc:
            last_exception = exc
            if attempt < max_retries:
                delay = min(initial_delay * (exponential_base ** attempt), max_delay)
                logger.warning(
                    "HTTP %s %s failed: %s, retrying in %.1fs (attempt %d/%d)",
                    method,
                    url,
                    exc,
                    delay,
                    attempt + 1,
                    max_retries,
                )
                await asyncio.sleep(delay)
            else:
                logger.error(
                    "HTTP %s %s failed after %d attempts: %s",
                    method,
                    url,
                    max_retries + 1,
                    exc,
                )

    # All retries exhausted
    raise last_exception or aiohttp.ClientError("Max retries exceeded")

