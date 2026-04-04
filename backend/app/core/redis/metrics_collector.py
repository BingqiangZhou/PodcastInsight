"""Runtime metrics collector for Redis cache operations."""

import logging
from collections import defaultdict
from threading import Lock


logger = logging.getLogger(__name__)


class RuntimeMetricsCollector:
    """Collects runtime metrics for cache operations.

    Thread-safe collector that tracks:
    - Command latency distribution (count, sum, min, max per operation)
    - Cache hit/miss counts
    - Error counts by operation type
    """

    def __init__(self) -> None:
        self._lock = Lock()
        self._command_counts: dict[str, int] = defaultdict(int)
        self._command_latencies: dict[str, list[float]] = defaultdict(list)
        self._cache_hits = 0
        self._cache_misses = 0
        self._error_counts: dict[str, int] = defaultdict(int)

    async def record_timing(self, operation: str, duration_ms: float) -> None:
        """Record timing for a cache operation.

        Args:
            operation: The operation name (e.g. "SET_NX", "GET", "TTL").
            duration_ms: Duration in milliseconds.
        """
        with self._lock:
            self._command_counts[operation] += 1
            # Keep only last 1000 latencies per operation to bound memory
            latencies = self._command_latencies[operation]
            latencies.append(duration_ms)
            if len(latencies) > 1000:
                self._command_latencies[operation] = latencies[-1000:]

    async def record_lookup(self, key: str, *, hit: bool) -> None:
        """Record a cache hit or miss.

        Args:
            key: The cache key that was looked up.
            hit: Whether the lookup was a cache hit.
        """
        with self._lock:
            if hit:
                self._cache_hits += 1
            else:
                self._cache_misses += 1

    def record_error(self, operation: str) -> None:
        """Record an error for a cache operation.

        Args:
            operation: The operation that failed.
        """
        with self._lock:
            self._error_counts[operation] += 1

    def get_metrics(self) -> dict:
        """Get current metrics snapshot.

        Returns:
            Dict with command_counts, latency_stats, cache hit/miss counts,
            cache_hit_rate, and error_counts.
        """
        with self._lock:
            total_commands = sum(self._command_counts.values())
            total_lookups = self._cache_hits + self._cache_misses

            latency_stats: dict[str, dict] = {}
            for op, latencies in self._command_latencies.items():
                if latencies:
                    latency_stats[op] = {
                        "count": len(latencies),
                        "avg_ms": sum(latencies) / len(latencies),
                        "min_ms": min(latencies),
                        "max_ms": max(latencies),
                    }

            # Build a flat summary for observability compatibility.
            # The observability module expects:
            #   "commands": {"total": int, "errors": int, "avg_ms": float, "max_ms": float}
            #   "cache": {"hits": int, "misses": int, "hit_rate": float}
            all_latencies: list[float] = []
            for latencies in self._command_latencies.values():
                all_latencies.extend(latencies)

            total_errors = sum(self._error_counts.values())

            return {
                "command_counts": dict(self._command_counts),
                "total_commands": total_commands,
                "latency_stats": latency_stats,
                "cache_hits": self._cache_hits,
                "cache_misses": self._cache_misses,
                "cache_hit_rate": (
                    self._cache_hits / total_lookups if total_lookups > 0 else 0.0
                ),
                "error_counts": dict(self._error_counts),
                # Flat shape expected by build_observability_snapshot
                "commands": {
                    "total": total_commands,
                    "total_count": total_commands,
                    "errors": total_errors,
                    "avg_ms": sum(all_latencies) / len(all_latencies) if all_latencies else 0.0,
                    "max_ms": max(all_latencies) if all_latencies else 0.0,
                },
                "cache": {
                    "hits": self._cache_hits,
                    "misses": self._cache_misses,
                    "hit_rate": (
                        self._cache_hits / total_lookups if total_lookups > 0 else 0.0
                    ),
                },
            }
