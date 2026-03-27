"""Response optimization middleware for compression and payload limits.

Provides gzip compression for large responses and enforces payload size limits.
"""

import logging
from typing import Any

from fastapi.middleware.gzip import GZipMiddleware
from starlette.types import ASGIApp, Message, Receive, Scope, Send

logger = logging.getLogger(__name__)


class PayloadSizeLimitMiddleware:
    """Pure ASGI middleware to enforce request payload size limits.

    Prevents excessively large request bodies from being processed,
    protecting against DoS attacks and resource exhaustion.

    Avoids BaseHTTPMiddleware overhead by working directly with ASGI scope.
    """

    def __init__(
        self,
        app: ASGIApp,
        max_content_length: int = 10 * 1024 * 1024,  # 10MB default
        exclude_paths: set[str] | None = None,
    ) -> None:
        self.app = app
        self.max_content_length = max_content_length
        self.exclude_paths = exclude_paths or {
            "/api/v1/health",
            "/metrics",
        }

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        """Check payload size before processing request."""
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        # Only check methods that carry a body
        method = scope.get("method", "")
        if method not in ("POST", "PUT", "PATCH"):
            await self.app(scope, receive, send)
            return

        # Skip excluded paths
        path = scope.get("path", "")
        if any(path.startswith(excluded) for excluded in self.exclude_paths):
            await self.app(scope, receive, send)
            return

        # Check Content-Length header
        headers = dict(scope.get("headers", []))
        content_length = headers.get(b"content-length", b"").decode("latin-1")
        if content_length:
            try:
                length = int(content_length)
                if length > self.max_content_length:
                    logger.warning(
                        "Request payload too large: %d bytes (max: %d) - Path: %s %s",
                        length,
                        self.max_content_length,
                        method,
                        path,
                    )
                    await self._send_payload_too_large(send)
                    return
            except ValueError:
                pass  # Invalid Content-Length header, let it through

        # Chunked transfers rely on the receiving endpoint to enforce limits
        # This is common for file uploads which are streamed
        await self.app(scope, receive, send)

    async def _send_payload_too_large(self, send: Send) -> None:
        """Send 413 Payload Too Large response directly via ASGI."""
        import orjson

        body = orjson.dumps({
            "detail": "Request payload too large",
            "max_size_bytes": self.max_content_length,
            "message_en": "Request payload too large. Maximum size is 10MB.",
            "message_zh": "请求负载过大。最大限制为10MB。",
        })

        await send({
            "type": "http.response.start",
            "status": 413,
            "headers": [
                [b"content-type", b"application/json; charset=utf-8"],
            ],
        })
        await send({
            "type": "http.response.body",
            "body": body,
        })


def configure_response_optimization(
    app: Any,
    compression_min_size: int = 1000,  # Compress responses > 1KB
    max_payload_size: int = 10 * 1024 * 1024,  # 10MB
) -> None:
    """Configure response optimization middleware.

    Args:
        app: FastAPI application instance
        compression_min_size: Minimum response size for gzip compression
        max_payload_size: Maximum request payload size in bytes
    """
    # Add gzip compression for responses
    app.add_middleware(GZipMiddleware, minimum_size=compression_min_size)
    logger.info(
        "GZip compression enabled for responses > %d bytes",
        compression_min_size,
    )

    # Add payload size limiting
    app.add_middleware(
        PayloadSizeLimitMiddleware,
        max_content_length=max_payload_size,
    )
    logger.info(
        "Payload size limit configured: %d bytes (%.1f MB)",
        max_payload_size,
        max_payload_size / (1024 * 1024),
    )
