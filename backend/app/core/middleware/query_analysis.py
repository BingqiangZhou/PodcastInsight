"""Query analysis middleware for detecting N+1 queries and performance issues.

This middleware tracks database query counts per request and logs warnings
when potential N+1 query patterns are detected.
"""

import logging
import time
from collections import defaultdict
from contextlib import asynccontextmanager
from typing import Any

from starlette.types import ASGIApp, Receive, Scope, Send

logger = logging.getLogger(__name__)


class QueryCounter:
    """Thread-local query counter for tracking queries per request."""

    def __init__(self) -> None:
        self._counters: dict[int, dict[str, Any]] = defaultdict(
            lambda: {"count": 0, "queries": [], "start_time": None}
        )

    def start_request(self) -> None:
        """Start tracking a new request."""
        import threading

        thread_id = threading.get_ident()
        self._counters[thread_id] = {"count": 0, "queries": [], "start_time": time.time()}

    def end_request(self) -> dict[str, Any]:
        """End tracking and return stats."""
        import threading

        thread_id = threading.get_ident()
        stats = self._counters[thread_id].copy()
        if thread_id in self._counters:
            del self._counters[thread_id]
        return stats

    def increment(self, query: str | None = None) -> None:
        """Increment query counter for current thread."""
        import threading

        thread_id = threading.get_ident()
        if thread_id in self._counters:
            self._counters[thread_id]["count"] += 1
            if query:
                self._counters[thread_id]["queries"].append(query[:200])  # Truncate long queries

    @property
    def count(self) -> int:
        """Get current query count for this thread."""
        import threading

        thread_id = threading.get_ident()
        return self._counters[thread_id]["count"]


# Global query counter instance
query_counter = QueryCounter()


@asynccontextmanager
async def track_queries():
    """Context manager to track database queries in async code.

    Usage:
        async with track_queries():
            result = await session.execute(query)
    """
    query_counter.start_request()
    try:
        yield
    finally:
        stats = query_counter.end_request()
        if stats["count"] > 10:
            logger.warning(
                "High query count detected: %d queries in %.2fs",
                stats["count"],
                time.time() - stats["start_time"],
            )


class QueryAnalysisMiddleware:
    """Pure ASGI middleware to analyze database query patterns per request.

    Detects potential N+1 queries by tracking the number of database
    queries executed during each request.

    Avoids BaseHTTPMiddleware overhead by working directly with ASGI scope.
    """

    def __init__(
        self,
        app: ASGIApp,
        warning_threshold: int = 10,
        critical_threshold: int = 50,
        exclude_paths: set[str] | None = None,
    ) -> None:
        self.app = app
        self.warning_threshold = warning_threshold
        self.critical_threshold = critical_threshold
        self.exclude_paths = exclude_paths or {
            "/health",
            "/metrics",
            "/openapi.json",
            "/docs",
            "/redoc",
        }

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        """Track queries during request processing (pure ASGI)."""
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        # Skip excluded paths
        path = scope.get("path", "")
        if any(path.startswith(excluded) for excluded in self.exclude_paths):
            await self.app(scope, receive, send)
            return

        # Start tracking
        query_counter.start_request()
        start_time = time.time()

        try:
            await self.app(scope, receive, send)
        finally:
            # Analyze query patterns
            stats = query_counter.end_request()
            duration = time.time() - start_time
            query_count = stats["count"]
            method = scope.get("method", "UNKNOWN")

            # Log based on threshold
            if query_count >= self.critical_threshold:
                logger.error(
                    "CRITICAL: Potential N+1 query pattern detected - "
                    "Path: %s %s, Queries: %d, Duration: %.2fs",
                    method,
                    path,
                    query_count,
                    duration,
                    extra={
                        "query_count": query_count,
                        "path": path,
                        "method": method,
                        "duration_ms": round(duration * 1000, 2),
                        "sample_queries": stats["queries"][:5],  # First 5 queries
                    },
                )
            elif query_count >= self.warning_threshold:
                logger.warning(
                    "WARNING: High query count - "
                    "Path: %s %s, Queries: %d, Duration: %.2fs",
                    method,
                    path,
                    query_count,
                    duration,
                    extra={
                        "query_count": query_count,
                        "path": path,
                        "method": method,
                        "duration_ms": round(duration * 1000, 2),
                    },
                )
            elif query_count > 0:
                logger.debug(
                    "Request queries: %s %s - %d queries in %.2fs",
                    method,
                    path,
                    query_count,
                    duration,
                )


def setup_query_counter_hooks() -> None:
    """Setup SQLAlchemy event listeners to count queries.

    This should be called once during application startup.
    """
    from sqlalchemy import event
    from sqlalchemy.engine import Engine

    @event.listens_for(Engine, "before_cursor_execute")
    def before_cursor_execute(
        conn: Any, cursor: Any, statement: str, parameters: Any, context: Any, executemany: bool
    ) -> None:
        """Increment query counter before each query execution."""
        query_counter.increment(statement)

    logger.info("Query counter hooks configured successfully")
