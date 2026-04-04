"""Tests for RuntimeMetricsCollector."""

import asyncio

from app.core.redis.metrics_collector import RuntimeMetricsCollector


def _run(coro):
    """Run an async coroutine on a fresh event loop (Python 3.14 compatible)."""
    loop = asyncio.new_event_loop()
    try:
        return loop.run_until_complete(coro)
    finally:
        loop.close()


def test_record_timing():
    collector = RuntimeMetricsCollector()
    _run(collector.record_timing("get", 5.0))
    _run(collector.record_timing("get", 10.0))
    _run(collector.record_timing("set", 3.0))

    metrics = collector.get_metrics()
    assert metrics["command_counts"]["get"] == 2
    assert metrics["command_counts"]["set"] == 1
    assert metrics["total_commands"] == 3
    assert metrics["latency_stats"]["get"]["count"] == 2
    assert 7.0 < metrics["latency_stats"]["get"]["avg_ms"] < 8.0


def test_record_lookup():
    collector = RuntimeMetricsCollector()
    _run(collector.record_lookup("key1", hit=True))
    _run(collector.record_lookup("key2", hit=True))
    _run(collector.record_lookup("key3", hit=False))

    metrics = collector.get_metrics()
    assert metrics["cache_hits"] == 2
    assert metrics["cache_misses"] == 1
    assert abs(metrics["cache_hit_rate"] - 0.6667) < 0.01


def test_record_error():
    collector = RuntimeMetricsCollector()
    collector.record_error("get")
    collector.record_error("get")
    collector.record_error("set")

    metrics = collector.get_metrics()
    assert metrics["error_counts"]["get"] == 2
    assert metrics["error_counts"]["set"] == 1


def test_empty_metrics():
    collector = RuntimeMetricsCollector()
    metrics = collector.get_metrics()
    assert metrics["total_commands"] == 0
    assert metrics["cache_hit_rate"] == 0.0
    assert metrics["cache_hits"] == 0


def test_latency_bounds():
    """Verify latencies are bounded to prevent memory growth."""
    collector = RuntimeMetricsCollector()
    for i in range(2000):
        _run(collector.record_timing("get", float(i)))

    metrics = collector.get_metrics()
    assert metrics["latency_stats"]["get"]["count"] == 1000


def test_get_metrics_backward_compat_shape():
    """Verify the returned dict includes the flat shape expected by observability."""
    collector = RuntimeMetricsCollector()
    _run(collector.record_timing("SET_NX", 2.5))
    _run(collector.record_timing("SET_NX", 7.5))
    _run(collector.record_lookup("k1", hit=True))
    _run(collector.record_lookup("k2", hit=False))
    collector.record_error("GET")

    metrics = collector.get_metrics()

    # Flat observability-compatible keys
    assert "commands" in metrics
    assert metrics["commands"]["total"] == 2
    assert metrics["commands"]["errors"] == 1
    assert metrics["commands"]["avg_ms"] == 5.0
    assert metrics["commands"]["max_ms"] == 7.5
    assert metrics["commands"]["total_count"] == 2

    assert "cache" in metrics
    assert metrics["cache"]["hits"] == 1
    assert metrics["cache"]["misses"] == 1
    assert abs(metrics["cache"]["hit_rate"] - 0.5) < 0.01


def test_get_null_redis_runtime_metrics_returns_real_data():
    """Verify the module-level function returns real collector data."""
    from app.core.redis import get_null_redis_runtime_metrics, get_redis_runtime_metrics

    # Both functions should return the same collector output
    result_null = get_null_redis_runtime_metrics()
    result_real = get_redis_runtime_metrics()

    # They should have the expected shape
    assert "commands" in result_null
    assert "cache" in result_null
    assert result_null == result_real
