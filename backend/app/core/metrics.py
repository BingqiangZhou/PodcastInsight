"""Prometheus metrics collection and export.

Provides comprehensive metrics for monitoring backend performance,
database connections, cache operations, and API requests.
"""

import logging
from contextlib import asynccontextmanager

from prometheus_client import (
    CONTENT_TYPE_LATEST,
    Counter,
    Gauge,
    Histogram,
    generate_latest,
)
from starlette.responses import Response


logger = logging.getLogger(__name__)

# =============================================================================
# Database Metrics
# =============================================================================

db_pool_size = Gauge(
    "db_pool_size",
    "Database connection pool size",
    ["database"],
)

db_pool_checked_out = Gauge(
    "db_pool_checked_out",
    "Number of checked out database connections",
    ["database"],
)

db_pool_overflow = Gauge(
    "db_pool_overflow",
    "Number of overflow connections in pool",
    ["database"],
)

db_pool_occupancy_ratio = Gauge(
    "db_pool_occupancy_ratio",
    "Database pool occupancy ratio (0-1)",
    ["database"],
)

db_query_duration = Histogram(
    "db_query_duration_seconds",
    "Database query duration in seconds",
    ["database", "query_type"],
    buckets=[0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0],
)

db_errors = Counter(
    "db_errors_total",
    "Total database errors",
    ["database", "error_type"],
)

# =============================================================================
# Cache Metrics
# =============================================================================

cache_hits = Counter(
    "cache_hits_total",
    "Total cache hit count",
    ["cache_type"],
)

cache_misses = Counter(
    "cache_misses_total",
    "Total cache miss count",
    ["cache_type"],
)

cache_latency = Histogram(
    "cache_latency_seconds",
    "Cache operation latency in seconds",
    ["cache_type", "operation"],
    buckets=[0.001, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5],
)

cache_errors = Counter(
    "cache_errors_total",
    "Total cache errors",
    ["cache_type", "operation"],
)

cache_hit_rate = Gauge(
    "cache_hit_rate",
    "Current cache hit rate (0-1)",
    ["cache_type"],
)

# =============================================================================
# API Metrics
# =============================================================================

api_requests = Counter(
    "api_requests_total",
    "Total API requests",
    ["method", "endpoint", "status_code"],
)

api_latency = Histogram(
    "api_request_duration_seconds",
    "API request latency in seconds",
    ["method", "endpoint"],
    buckets=[0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0],
)

api_requests_in_progress = Gauge(
    "api_requests_in_progress",
    "Number of API requests currently being processed",
    ["method", "endpoint"],
)

api_errors = Counter(
    "api_errors_total",
    "Total API errors",
    ["method", "endpoint", "error_type"],
)

# =============================================================================
# Application Metrics
# =============================================================================

app_info = Gauge(
    "app_info",
    "Application information",
    ["version", "environment"],
)

celery_tasks_total = Counter(
    "celery_tasks_total",
    "Total Celery tasks",
    ["task_name", "status"],
)

celery_task_duration = Histogram(
    "celery_task_duration_seconds",
    "Celery task duration in seconds",
    ["task_name"],
    buckets=[0.1, 0.5, 1.0, 5.0, 10.0, 30.0, 60.0, 120.0, 300.0],
)

circuit_breaker_state = Gauge(
    "circuit_breaker_state",
    "Circuit breaker state (0=closed, 1=open, 2=half_open)",
    ["service"],
)

circuit_breaker_failures = Counter(
    "circuit_breaker_failures_total",
    "Total circuit breaker failures",
    ["service"],
)


# =============================================================================
# Helper Functions
# =============================================================================


def record_db_pool_metrics(
    pool_size: int,
    checked_out: int,
    overflow: int,
    occupancy_ratio: float,
    database: str = "primary",
) -> None:
    """Record database connection pool metrics."""
    db_pool_size.labels(database=database).set(pool_size)
    db_pool_checked_out.labels(database=database).set(checked_out)
    db_pool_overflow.labels(database=database).set(overflow)
    db_pool_occupancy_ratio.labels(database=database).set(occupancy_ratio)


def record_cache_operation(
    operation: str,
    hit: bool | None = None,
    duration: float | None = None,
    cache_type: str = "redis",
) -> None:
    """Record cache operation metrics."""
    if hit is not None:
        if hit:
            cache_hits.labels(cache_type=cache_type).inc()
        else:
            cache_misses.labels(cache_type=cache_type).inc()

    if duration is not None:
        cache_latency.labels(
            cache_type=cache_type,
            operation=operation,
        ).observe(duration)


def record_api_request(
    method: str,
    endpoint: str,
    status_code: int,
    duration: float,
) -> None:
    """Record API request metrics."""
    api_requests.labels(
        method=method,
        endpoint=endpoint,
        status_code=str(status_code),
    ).inc()

    api_latency.labels(
        method=method,
        endpoint=endpoint,
    ).observe(duration)


def record_celery_task(
    task_name: str,
    status: str,
    duration: float | None = None,
) -> None:
    """Record Celery task metrics."""
    celery_tasks_total.labels(
        task_name=task_name,
        status=status,
    ).inc()

    if duration is not None:
        celery_task_duration.labels(task_name=task_name).observe(duration)


def record_circuit_breaker_state(
    service: str,
    state: str,
) -> None:
    """Record circuit breaker state metrics."""
    state_value = {"closed": 0, "open": 1, "half_open": 2}.get(state, 0)
    circuit_breaker_state.labels(service=service).set(state_value)


# =============================================================================
# Metrics Endpoint
# =============================================================================


async def get_prometheus_metrics() -> Response:
    """Generate Prometheus metrics response.

    Returns:
        Response with Prometheus-formatted metrics.
    """
    # Update application info
    try:
        from app.core.config import get_settings

        settings = get_settings()
        app_info.labels(
            version=settings.VERSION,
            environment=settings.ENVIRONMENT,
        ).set(1)
    except Exception:
        pass

    # Update database pool metrics
    try:
        from app.core.database import get_db_pool_snapshot

        snapshot = get_db_pool_snapshot()
        record_db_pool_metrics(
            pool_size=snapshot.get("pool_size", 0),
            checked_out=snapshot.get("checked_out", 0),
            overflow=snapshot.get("overflow", 0),
            occupancy_ratio=snapshot.get("occupancy_ratio", 0),
            database="primary",
        )
    except Exception:
        pass

    # Update cache hit rate from runtime metrics collector
    try:
        from app.core.redis import get_redis_runtime_metrics

        redis_metrics = get_redis_runtime_metrics()
        if "cache" in redis_metrics and "hit_rate" in redis_metrics["cache"]:
            cache_hit_rate.labels(cache_type="redis").set(
                redis_metrics["cache"]["hit_rate"]
            )
    except Exception:
        pass

    # Update circuit breaker states
    try:
        from app.core.circuit_breaker import get_all_circuit_breaker_stats

        for name, stats in get_all_circuit_breaker_stats().items():
            record_circuit_breaker_state(
                service=name,
                state=stats.get("state", "closed"),
            )
    except Exception:
        pass

    # Generate and return metrics
    metrics_output = generate_latest()
    return Response(
        content=metrics_output,
        media_type=CONTENT_TYPE_LATEST,
        status_code=200,
    )


# =============================================================================
# Context Managers
# =============================================================================


@asynccontextmanager
async def track_api_request(method: str, endpoint: str):
    """Context manager to track API request duration."""
    api_requests_in_progress.labels(
        method=method,
        endpoint=endpoint,
    ).inc()

    import time

    start_time = time.time()
    status_code = 200

    try:
        yield
    except Exception as exc:
        status_code = 500
        api_errors.labels(
            method=method,
            endpoint=endpoint,
            error_type=type(exc).__name__,
        ).inc()
        raise
    finally:
        duration = time.time() - start_time
        record_api_request(
            method=method,
            endpoint=endpoint,
            status_code=status_code,
            duration=duration,
        )
        api_requests_in_progress.labels(
            method=method,
            endpoint=endpoint,
        ).dec()
