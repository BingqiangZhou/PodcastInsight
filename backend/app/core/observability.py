"""Observability snapshot and alert evaluation helpers."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any


@dataclass(frozen=True)
class ObservabilityThresholds:
    """Alert thresholds for runtime observability checks."""

    api_p95_ms: float = 800.0
    api_error_rate: float = 0.05
    db_pool_occupancy_ratio: float = 0.9
    redis_command_avg_ms: float = 20.0
    redis_command_max_ms: float = 100.0
    redis_cache_hit_rate_min: float = 0.5
    redis_cache_lookups_min: int = 20
    # Circuit breaker thresholds
    circuit_breaker_failure_threshold: int = 3
    circuit_breaker_open_count_max: int = 0  # Alert if any breakers are open
    circuit_breaker_rejected_calls_max: int = 10  # Alert on too many rejections
    # Rate limiting thresholds
    rate_limit_rejection_rate_max: float = 0.1  # 10% rejection rate warning


def _safe_float(value: Any, default: float = 0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _safe_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _check_upper_bound(
    *,
    name: str,
    value: float,
    threshold: float,
    critical_multiplier: float = 1.0,
    unit: str = "",
    message_ok: str,
    message_warn: str,
    message_critical: str,
) -> dict[str, Any]:
    critical_threshold = threshold * critical_multiplier
    if value > critical_threshold and critical_multiplier > 1.0:
        status = "critical"
        message = message_critical
    elif value > threshold:
        status = "warning"
        message = message_warn
    else:
        status = "ok"
        message = message_ok

    return {
        "name": name,
        "status": status,
        "value": value,
        "threshold": threshold,
        "unit": unit,
        "message": message,
    }


def _check_lower_bound(
    *,
    name: str,
    value: float,
    threshold: float,
    unit: str = "",
    enabled: bool = True,
    message_ok: str,
    message_warn: str,
    message_disabled: str,
) -> dict[str, Any]:
    if not enabled:
        return {
            "name": name,
            "status": "ok",
            "value": value,
            "threshold": threshold,
            "unit": unit,
            "message": message_disabled,
        }

    if value < threshold:
        status = "warning"
        message = message_warn
    else:
        status = "ok"
        message = message_ok

    return {
        "name": name,
        "status": status,
        "value": value,
        "threshold": threshold,
        "unit": unit,
        "message": message,
    }


def _overall_status(checks: list[dict[str, Any]]) -> str:
    statuses = {check["status"] for check in checks}
    if "critical" in statuses:
        return "critical"
    if "warning" in statuses:
        return "warning"
    return "ok"


def get_circuit_breaker_metrics() -> dict[str, Any]:
    """Get aggregated circuit breaker statistics."""
    from app.core.circuit_breaker import get_all_circuit_breaker_stats

    stats = get_all_circuit_breaker_stats()
    if not stats:
        return {
            "total_breakers": 0,
            "open_count": 0,
            "half_open_count": 0,
            "closed_count": 0,
            "total_calls": 0,
            "total_failures": 0,
            "total_rejected": 0,
            "breakers": {},
        }

    open_count = sum(1 for s in stats.values() if s["state"] == "open")
    half_open_count = sum(1 for s in stats.values() if s["state"] == "half_open")
    closed_count = sum(1 for s in stats.values() if s["state"] == "closed")
    total_calls = sum(s["total_calls"] for s in stats.values())
    total_failures = sum(s["failed_calls"] for s in stats.values())
    total_rejected = sum(s["rejected_calls"] for s in stats.values())

    return {
        "total_breakers": len(stats),
        "open_count": open_count,
        "half_open_count": half_open_count,
        "closed_count": closed_count,
        "total_calls": total_calls,
        "total_failures": total_failures,
        "total_rejected": total_rejected,
        "breakers": stats,
    }


def get_rate_limit_metrics() -> dict[str, Any]:
    """Get rate limiting statistics from the rate limit middleware.

    The current RateLimitMiddleware (app.core.middleware.rate_limit) does not
    expose aggregate request/rejection counters.  To populate real metrics the
    following changes are needed (tracked as TODO):

    TODO:
    1. Add class-level counters to RateLimitMiddleware:
       - _total_requests: int  (incremented on every checked request)
       - _rejected_requests: int  (incremented when 429 is returned)
    2. Expose a class method or module-level helper (e.g.
       ``get_rate_limit_stats()``) that returns those counters.
    3. Import and call that helper here instead of returning placeholders.
    """
    try:
        from app.core.redis import get_shared_redis

        redis = get_shared_redis()
        # Rate limiter does not yet expose stats counters; return placeholders
        return {
            "enabled": True,
            "total_requests": 0,
            "rejected_requests": 0,
            "rejection_rate": 0.0,
        }
    except Exception:
        return {
            "enabled": False,
            "total_requests": 0,
            "rejected_requests": 0,
            "rejection_rate": 0.0,
        }


def build_observability_snapshot(
    *,
    performance_metrics: dict[str, Any],
    db_pool: dict[str, Any],
    redis_runtime: dict[str, Any],
    thresholds: ObservabilityThresholds | None = None,
) -> dict[str, Any]:
    """Build a compact observability snapshot from runtime metrics."""
    effective_thresholds = thresholds or ObservabilityThresholds()

    perf_summary = performance_metrics.get("summary", {})
    redis_commands = redis_runtime.get("commands", {})
    redis_cache = redis_runtime.get("cache", {})

    api_p95_ms = _safe_float(perf_summary.get("global_p95_ms"))
    api_error_rate = _safe_float(perf_summary.get("global_error_rate"))
    total_requests = _safe_int(perf_summary.get("total_requests"))
    total_errors = _safe_int(perf_summary.get("total_errors"))

    db_pool_occupancy = _safe_float(db_pool.get("occupancy_ratio"))

    redis_command_avg_ms = _safe_float(redis_commands.get("avg_ms"))
    redis_command_max_ms = _safe_float(redis_commands.get("max_ms"))
    redis_total_commands = _safe_int(redis_commands.get("total_count"))
    redis_cache_hit_rate = _safe_float(redis_cache.get("hit_rate"))
    redis_cache_lookups = _safe_int(redis_cache.get("hits")) + _safe_int(
        redis_cache.get("misses"),
    )

    checks = [
        _check_upper_bound(
            name="api_latency_p95",
            value=api_p95_ms,
            threshold=effective_thresholds.api_p95_ms,
            critical_multiplier=1.5,
            unit="ms",
            message_ok="API p95 latency is within threshold",
            message_warn="API p95 latency exceeds warning threshold",
            message_critical="API p95 latency exceeds critical threshold",
        ),
        _check_upper_bound(
            name="api_error_rate",
            value=api_error_rate,
            threshold=effective_thresholds.api_error_rate,
            critical_multiplier=2.0,
            unit="ratio",
            message_ok="API error rate is within threshold",
            message_warn="API error rate exceeds warning threshold",
            message_critical="API error rate exceeds critical threshold",
        ),
        _check_upper_bound(
            name="db_pool_occupancy",
            value=db_pool_occupancy,
            threshold=effective_thresholds.db_pool_occupancy_ratio,
            critical_multiplier=1.1,
            unit="ratio",
            message_ok="DB pool occupancy is healthy",
            message_warn="DB pool occupancy is high",
            message_critical="DB pool occupancy is near exhaustion",
        ),
        _check_upper_bound(
            name="redis_command_avg",
            value=redis_command_avg_ms,
            threshold=effective_thresholds.redis_command_avg_ms,
            critical_multiplier=2.0,
            unit="ms",
            message_ok="Redis average command latency is within threshold",
            message_warn="Redis average command latency exceeds warning threshold",
            message_critical="Redis average command latency exceeds critical threshold",
        ),
        _check_upper_bound(
            name="redis_command_max",
            value=redis_command_max_ms,
            threshold=effective_thresholds.redis_command_max_ms,
            critical_multiplier=2.0,
            unit="ms",
            message_ok="Redis max command latency is within threshold",
            message_warn="Redis max command latency exceeds warning threshold",
            message_critical="Redis max command latency exceeds critical threshold",
        ),
        _check_lower_bound(
            name="redis_cache_hit_rate",
            value=redis_cache_hit_rate,
            threshold=effective_thresholds.redis_cache_hit_rate_min,
            unit="ratio",
            enabled=redis_cache_lookups >= effective_thresholds.redis_cache_lookups_min,
            message_ok="Redis cache hit rate is within threshold",
            message_warn="Redis cache hit rate is below threshold",
            message_disabled="Redis cache hit-rate check skipped due to low sample size",
        ),
    ]

    # Add circuit breaker metrics
    circuit_breaker_metrics = get_circuit_breaker_metrics()
    circuit_open_count = circuit_breaker_metrics["open_count"]

    checks.append(
        _check_upper_bound(
            name="circuit_breaker_open",
            value=circuit_open_count,
            threshold=effective_thresholds.circuit_breaker_open_count_max,
            critical_multiplier=1.0,
            unit="count",
            message_ok="All circuit breakers are closed",
            message_warn="Some circuit breakers are open",
            message_critical="Circuit breakers are open - external services unavailable",
        ),
    )

    alerts = [check for check in checks if check["status"] != "ok"]

    return {
        "generated_at": datetime.now(UTC).isoformat(),
        "summary": {
            "overall_status": _overall_status(checks),
            "api_p95_ms": api_p95_ms,
            "api_error_rate": api_error_rate,
            "total_requests": total_requests,
            "total_errors": total_errors,
            "db_pool_occupancy_ratio": db_pool_occupancy,
            "redis_command_avg_ms": redis_command_avg_ms,
            "redis_command_max_ms": redis_command_max_ms,
            "redis_total_commands": redis_total_commands,
            "redis_cache_hit_rate": redis_cache_hit_rate,
            "redis_cache_lookups": redis_cache_lookups,
            "circuit_breaker_open_count": circuit_open_count,
            "circuit_breaker_total": circuit_breaker_metrics["total_breakers"],
            "alerts_count": len(alerts),
        },
        "checks": checks,
        "alerts": alerts,
        "circuit_breakers": circuit_breaker_metrics,
    }
