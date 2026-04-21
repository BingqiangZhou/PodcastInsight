"""Request logging middleware with slow-request detection."""

import logging
import time

from starlette.types import ASGIApp, Message, Receive, Scope, Send


logger = logging.getLogger(__name__)

SLOW_API_THRESHOLD_MS = 5000
SKIP_LOGGING_PATHS = {
    "/health",
    "/api/v1/health",
    "/api/v1/health/ready",
    "/docs",
    "/redoc",
    "/openapi.json",
    "/api/v1/openapi.json",
}


class RequestLoggingMiddleware:
    """Lightweight request logging with slow-request detection and timing headers."""

    def __init__(self, app: ASGIApp, *, slow_threshold: float = 5.0):
        self.app = app
        self.slow_threshold_ms = slow_threshold * 1000

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        path = scope.get("path", "")
        if path in SKIP_LOGGING_PATHS:
            await self.app(scope, receive, send)
            return

        method = scope.get("method", "GET")
        client = scope.get("client")
        client_host = client[0] if client else "unknown"
        headers = {
            key.decode("latin-1"): value.decode("latin-1")
            for key, value in scope.get("headers", [])
        }
        cookies = headers.get("cookie", "")
        user_label = "anonymous"
        if headers.get("authorization", "").startswith("Bearer "):
            user_label = "authenticated"
        elif "admin_session=" in cookies:
            user_label = "admin_session"

        start_time = time.perf_counter()
        status_code: int | None = None
        response_started = False

        async def send_wrapper(message: Message) -> None:
            nonlocal response_started, status_code
            if message["type"] == "http.response.start":
                response_started = True
                status_code = int(message["status"])
                elapsed_ms = (time.perf_counter() - start_time) * 1000
                from starlette.datastructures import MutableHeaders

                headers_obj = MutableHeaders(scope=message)
                headers_obj["X-Process-Time"] = f"{elapsed_ms / 1000:.3f}"
            await send(message)

        try:
            await self.app(scope, receive, send_wrapper)
        except Exception as exc:
            duration_ms = (time.perf_counter() - start_time) * 1000
            logger.error(
                "API request failed: %s %s | error=%s | elapsed=%.3fs | client=%s",
                method,
                path,
                str(exc),
                duration_ms / 1000,
                client_host,
                exc_info=True,
            )
            raise

        duration_ms = (time.perf_counter() - start_time) * 1000
        if status_code is None and response_started:
            status_code = 200
        elif status_code is None:
            status_code = 500

        self._log_request(
            method=method,
            path=path,
            client_host=client_host,
            user_label=user_label,
            status_code=status_code,
            duration_ms=duration_ms,
        )

    def _log_request(
        self,
        *,
        method: str,
        path: str,
        client_host: str,
        user_label: str,
        status_code: int,
        duration_ms: float,
    ) -> None:
        if duration_ms > self.slow_threshold_ms:
            logger.warning(
                "Slow request: %s %s | status=%s | elapsed=%.3fs | client=%s | user=%s",
                method,
                path,
                status_code,
                duration_ms / 1000,
                client_host,
                user_label,
            )

        if status_code >= 500:
            logger.error(
                "API request: %s %s | status=%s | elapsed=%.3fs | client=%s | user=%s",
                method,
                path,
                status_code,
                duration_ms / 1000,
                client_host,
                user_label,
            )
        elif status_code >= 400:
            logger.warning(
                "API request: %s %s | status=%s | elapsed=%.3fs | client=%s | user=%s",
                method,
                path,
                status_code,
                duration_ms / 1000,
                client_host,
                user_label,
            )
        else:
            logger.debug(
                "API request: %s %s | status=%s | elapsed=%.3fs | client=%s | user=%s",
                method,
                path,
                status_code,
                duration_ms / 1000,
                client_host,
                user_label,
            )
