"""Response optimization middleware for compression and payload limits.

Provides gzip compression for large responses and enforces payload size limits.
"""

import logging
from typing import Callable

from fastapi import FastAPI, Request, Response
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware

logger = logging.getLogger(__name__)


class PayloadSizeLimitMiddleware(BaseHTTPMiddleware):
    """Middleware to enforce request payload size limits.

    Prevents excessively large request bodies from being processed,
    protecting against DoS attacks and resource exhaustion.
    """

    def __init__(
        self,
        app: FastAPI,
        max_content_length: int = 10 * 1024 * 1024,  # 10MB default
        exclude_paths: set[str] | None = None,
    ):
        super().__init__(app)
        self.max_content_length = max_content_length
        self.exclude_paths = exclude_paths or {
            "/api/v1/health",
            "/metrics",
        }

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        """Check payload size before processing request."""
        # Skip for non-body methods
        if request.method not in ["POST", "PUT", "PATCH"]:
            return await call_next(request)

        # Skip excluded paths
        path = request.url.path
        if any(path.startswith(excluded) for excluded in self.exclude_paths):
            return await call_next(request)

        # Check Content-Length header
        content_length = request.headers.get("content-length")
        if content_length:
            try:
                length = int(content_length)
                if length > self.max_content_length:
                    logger.warning(
                        "Request payload too large: %d bytes (max: %d) - Path: %s %s",
                        length,
                        self.max_content_length,
                        request.method,
                        path,
                    )
                    return JSONResponse(
                        status_code=413,
                        content={
                            "detail": "Request payload too large",
                            "max_size_bytes": self.max_content_length,
                            "message_en": "Request payload too large. Maximum size is 10MB.",
                            "message_zh": "请求负载过大。最大限制为10MB。",
                        },
                    )
            except ValueError:
                pass  # Invalid Content-Length header, let it through

        # Check for Transfer-Encoding: chunked (can't know size upfront)
        transfer_encoding = request.headers.get("transfer-encoding", "").lower()
        if "chunked" in transfer_encoding:
            # For chunked uploads, we rely on the receiving endpoint to enforce limits
            # This is common for file uploads which are streamed
            pass

        return await call_next(request)


def configure_response_optimization(
    app: FastAPI,
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
