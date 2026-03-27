"""Request observability middleware and runtime metrics store."""

import logging
import random
import time
from collections import deque

from starlette.datastructures import MutableHeaders
from starlette.types import ASGIApp, Message, Receive, Scope, Send

from app.core.config import get_settings


logger = logging.getLogger(__name__)

SLOW_API_THRESHOLD_MS = 500
SKIP_OBSERVABILITY_PATHS = {
    "/health",
    "/api/v1/health",
    "/api/v1/health/ready",
    "/metrics",
    "/metrics/summary",
    "/docs",
    "/redoc",
    "/openapi.json",
    "/api/v1/openapi.json",
}


class PerformanceMetricsStore:
    """Process-wide request metrics store."""

    _max_latency_samples = 1024
    _MAX_ENDPOINT_KEYS = 256

    def __init__(self):
        self.request_counts: dict[str, int] = {}
        self.response_times: dict[str, dict[str, float]] = {}
        self.error_counts: dict[str, int] = {}
        self.status_counts: dict[str, dict[str, int]] = {}
        self.latency_samples: dict[str, deque[float]] = {}
        self.global_latency_samples: deque[float] = deque(
            maxlen=self._max_latency_samples,
        )

    @staticmethod
    def _p95(samples: deque[float]) -> float:
        if not samples:
            return 0.0
        ordered = sorted(samples)
        index = int((len(ordered) - 1) * 0.95)
        return ordered[index]

    def track_request(
        self,
        key: str,
        duration_ms: float,
        status_code: int | None = None,
    ) -> None:
        # Evict least-recently-used endpoint key when limit is exceeded
        if (
            key not in self.request_counts
            and len(self.request_counts) >= self._MAX_ENDPOINT_KEYS
        ):
            self._evict_lru_key()

        self.request_counts[key] = self.request_counts.get(key, 0) + 1

        if key not in self.response_times:
            self.response_times[key] = {
                "count": 0,
                "total_ms": 0.0,
                "min_ms": float("inf"),
                "max_ms": 0.0,
            }

        stats = self.response_times[key]
        stats["count"] += 1
        stats["total_ms"] += duration_ms
        stats["min_ms"] = min(stats["min_ms"], duration_ms)
        stats["max_ms"] = max(stats["max_ms"], duration_ms)
        sample_bucket = self.latency_samples.get(key)
        if sample_bucket is None:
            sample_bucket = deque(maxlen=self._max_latency_samples)
            self.latency_samples[key] = sample_bucket
        sample_bucket.append(duration_ms)
        self.global_latency_samples.append(duration_ms)

        if status_code is not None:
            if key not in self.status_counts:
                self.status_counts[key] = {}
            status_key = str(status_code)
            status_map = self.status_counts[key]
            status_map[status_key] = status_map.get(status_key, 0) + 1

            if status_code >= 400:
                self.track_error(key)

    def track_error(self, key: str) -> None:
        self.error_counts[key] = self.error_counts.get(key, 0) + 1

    def _evict_lru_key(self) -> None:
        """Evict the least-recently-used endpoint key from all store dicts."""
        if not self.request_counts:
            return
        # Use request_counts as the canonical key set; pick the key with the
        # lowest count as a proxy for least-recently-used.
        lru_key = min(self.request_counts, key=self.request_counts.get)
        evicted = lru_key
        self.request_counts.pop(evicted, None)
        self.response_times.pop(evicted, None)
        self.error_counts.pop(evicted, None)
        self.status_counts.pop(evicted, None)
        self.latency_samples.pop(evicted, None)
        logger.warning(
            "Metrics store exceeded %d endpoint keys, evicted LRU key: %s",
            self._MAX_ENDPOINT_KEYS,
            evicted,
        )

    def get_metrics(self) -> dict:
        response_stats: dict[str, dict[str, float]] = {}
        for key, stats in self.response_times.items():
            count = stats["count"]
            response_stats[key] = {
                "count": count,
                "avg_ms": (stats["total_ms"] / count) if count else 0.0,
                "min_ms": stats["min_ms"],
                "max_ms": stats["max_ms"],
                "p95_ms": self._p95(self.latency_samples.get(key, deque())),
            }

        endpoint_error_rates: dict[str, float] = {}
        for key, count in self.request_counts.items():
            errors = self.error_counts.get(key, 0)
            endpoint_error_rates[key] = (errors / count) if count else 0.0

        total_requests = sum(self.request_counts.values())
        total_errors = sum(self.error_counts.values())
        global_error_rate = (total_errors / total_requests) if total_requests else 0.0

        return {
            "request_counts": self.request_counts.copy(),
            "response_times": response_stats,
            "error_counts": self.error_counts.copy(),
            "status_counts": {k: v.copy() for k, v in self.status_counts.items()},
            "endpoint_error_rates": endpoint_error_rates,
            "summary": {
                "total_requests": total_requests,
                "total_errors": total_errors,
                "global_error_rate": global_error_rate,
                "global_p95_ms": self._p95(self.global_latency_samples),
            },
        }

    def reset_metrics(self) -> None:
        self.request_counts.clear()
        self.response_times.clear()
        self.error_counts.clear()
        self.status_counts.clear()
        self.latency_samples.clear()
        self.global_latency_samples.clear()


_performance_metrics_store = PerformanceMetricsStore()


def _get_store_from_app(app: ASGIApp | None) -> PerformanceMetricsStore:
    """Return app-bound store when available, otherwise fallback store."""
    if app is not None:
        state = getattr(app, "state", None)
        if state is not None:
            store = getattr(state, "performance_metrics_store", None)
            if store is None:
                state.performance_metrics_store = _performance_metrics_store
                return _performance_metrics_store
            return store
    return _performance_metrics_store


class RequestObservabilityMiddleware:
    """Combined request metrics, request logging, and slow-request detection."""

    def __init__(
        self,
        app: ASGIApp,
        *,
        slow_threshold: float = 5.0,
    ):
        self.app = app
        self.slow_threshold_ms = slow_threshold * 1000
        self.success_log_sample_rate = get_settings().OBS_SUCCESS_LOG_SAMPLE_RATE

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        path = scope.get("path", "")
        if path in SKIP_OBSERVABILITY_PATHS:
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

        key = f"{method} {path}"
        start_time = time.perf_counter()
        store = _get_store_from_app(scope.get("app"))
        response_started = False
        status_code: int | None = None

        async def send_wrapper(message: Message) -> None:
            nonlocal response_started, status_code
            if message["type"] == "http.response.start":
                response_started = True
                status_code = int(message["status"])
                elapsed_ms = (time.perf_counter() - start_time) * 1000
                headers_obj = MutableHeaders(scope=message)
                headers_obj["X-Process-Time"] = f"{elapsed_ms / 1000:.3f}"
                headers_obj["X-Response-Time"] = f"{elapsed_ms:.2f}ms"
            await send(message)

        try:
            await self.app(scope, receive, send_wrapper)
        except Exception as exc:
            duration_ms = (time.perf_counter() - start_time) * 1000
            store.track_error(key)
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

        store.track_request(key, duration_ms, status_code)
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
                "API request completed: %s %s | status=%s | elapsed=%.3fs | client=%s | user=%s",
                method,
                path,
                status_code,
                duration_ms / 1000,
                client_host,
                user_label,
            )
            return

        if status_code >= 400:
            logger.warning(
                "API request completed: %s %s | status=%s | elapsed=%.3fs | client=%s | user=%s",
                method,
                path,
                status_code,
                duration_ms / 1000,
                client_host,
                user_label,
            )
            return

        logger.debug(
            "API request completed: %s %s | status=%s | elapsed=%.3fs | client=%s | user=%s",
            method,
            path,
            status_code,
            duration_ms / 1000,
            client_host,
            user_label,
        )

        if self.success_log_sample_rate <= 0:
            return

        if random.random() <= self.success_log_sample_rate:
            logger.info(
                "Sampled request: %s %s | status=%s | elapsed=%.3fs | client=%s | user=%s",
                method,
                path,
                status_code,
                duration_ms / 1000,
                client_host,
                user_label,
            )


def get_performance_middleware(app: ASGIApp | None = None) -> PerformanceMetricsStore:
    """Get performance metrics store bound to app state when possible."""
    return _get_store_from_app(app)
