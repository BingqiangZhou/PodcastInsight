"""Redis Metrics Recording.

Handles command timing, cache hit/miss tracking, and penetration metrics.
Uses batched recording to minimize Redis overhead.
"""

import asyncio
import atexit
import logging
import threading
import weakref
from collections import defaultdict
from time import perf_counter
from typing import Any

logger = logging.getLogger(__name__)

# Redis keys for distributed runtime metrics
_METRICS_COMMANDS_KEY = "podcast:metrics:commands"
_METRICS_CACHE_KEY = "podcast:metrics:cache"
_METRICS_CACHE_PENETRATION_KEY = "podcast:metrics:penetration"

# Batched metrics configuration
_METRICS_FLUSH_INTERVAL_SECONDS = 5.0  # Flush every 5 seconds
_METRICS_BUFFER_SIZE_THRESHOLD = 100  # Flush when buffer exceeds 100 items


class _MetricsBuffer:
    """Thread-safe buffer for batching metrics before flushing to Redis."""

    _instance: "_MetricsBuffer | None" = None
    _lock = threading.Lock()

    def __new__(cls) -> "_MetricsBuffer":
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
                    cls._instance._initialized = False
        return cls._instance

    def __init__(self) -> None:
        if self._initialized:
            return
        self._initialized = True

        # Thread-safe buffers
        self._command_buffer: dict[str, list[float]] = defaultdict(list)
        self._cache_buffer: dict[tuple[str, bool], int] = defaultdict(int)  # (namespace, hit) -> count
        self._penetration_buffer: dict[str, int] = defaultdict(int)  # namespace -> count
        self._buffer_lock = threading.Lock()

        # Flush task management
        self._flush_task: asyncio.Task | None = None
        self._redis_client_ref: weakref.ref | None = None
        self._running = False

        # Register cleanup on exit
        atexit.register(self._sync_flush_on_exit)

    def start_flush_task(self, redis_client: Any) -> None:
        """Start the background flush task."""
        self._redis_client_ref = weakref.ref(redis_client)
        if self._flush_task is None or self._flush_task.done():
            try:
                loop = asyncio.get_running_loop()
                self._running = True
                self._flush_task = loop.create_task(self._periodic_flush())
            except RuntimeError:
                # No running loop, will flush on demand
                pass

    async def _periodic_flush(self) -> None:
        """Periodically flush metrics to Redis."""
        while self._running:
            try:
                await asyncio.sleep(_METRICS_FLUSH_INTERVAL_SECONDS)
                await self._flush_to_redis()
            except asyncio.CancelledError:
                # Final flush on cancellation
                await self._flush_to_redis()
                break
            except Exception as e:
                logger.debug("Metrics flush error: %s", e)

    def record_command(self, command: str, elapsed_ms: float) -> None:
        """Record a command timing in the buffer."""
        with self._buffer_lock:
            self._command_buffer[command].append(elapsed_ms)

            # Check if we should flush due to buffer size
            total_commands = sum(len(v) for v in self._command_buffer.values())
            if total_commands >= _METRICS_BUFFER_SIZE_THRESHOLD:
                self._trigger_async_flush()

    def record_cache_lookup(self, key: str, hit: bool) -> None:
        """Record a cache lookup in the buffer."""
        namespace = self._extract_namespace(key)
        with self._buffer_lock:
            self._cache_buffer[(namespace, hit)] += 1

    def record_penetration(self, key: str) -> None:
        """Record a cache penetration event in the buffer."""
        namespace = self._extract_namespace(key)
        with self._buffer_lock:
            self._penetration_buffer[namespace] += 1

    def _extract_namespace(self, key: str) -> str:
        """Extract namespace from cache key."""
        parts = key.split(":")
        if len(parts) >= 3:
            return ":".join(parts[:3])
        if len(parts) >= 2:
            return ":".join(parts[:2])
        return parts[0] if parts else "unknown"

    def _trigger_async_flush(self) -> None:
        """Trigger an async flush if possible."""
        try:
            loop = asyncio.get_running_loop()
            loop.create_task(self._flush_to_redis())
        except RuntimeError:
            pass  # No running loop, will flush later

    async def _flush_to_redis(self) -> None:
        """Flush all buffered metrics to Redis."""
        if self._redis_client_ref is None:
            return

        client = self._redis_client_ref()
        if client is None:
            return

        # Swap buffers atomically
        with self._buffer_lock:
            command_buffer = dict(self._command_buffer)
            cache_buffer = dict(self._cache_buffer)
            penetration_buffer = dict(self._penetration_buffer)
            self._command_buffer.clear()
            self._cache_buffer.clear()
            self._penetration_buffer.clear()

        if not command_buffer and not cache_buffer and not penetration_buffer:
            return

        try:
            from app.core.cache_ttl import CacheTTL

            # Aggregate command metrics
            total_count = sum(len(timings) for timings in command_buffer.values())
            total_ms = sum(sum(timings) for timings in command_buffer.values())
            max_ms = max((max(timings) for timings in command_buffer.values() if timings), default=0.0)

            async with client.pipeline() as pipe:
                # Global command stats
                if total_count > 0:
                    pipe.hincrby(_METRICS_COMMANDS_KEY, "total_count", total_count)
                    pipe.hincrbyfloat(_METRICS_COMMANDS_KEY, "total_ms", total_ms)

                    # Update max_ms using Lua script (single call instead of per-command)
                    max_update_script = """
                        local current = redis.call('HGET', KEYS[1], 'max_ms')
                        local new_val = tonumber(ARGV[1])
                        if current then
                            current = tonumber(current)
                            if new_val > current then
                                redis.call('HSET', KEYS[1], 'max_ms', new_val)
                            end
                        else
                            redis.call('HSET', KEYS[1], 'max_ms', new_val)
                        end
                    """
                    pipe.eval(max_update_script, 1, _METRICS_COMMANDS_KEY, max_ms)

                # Per-command stats (batched)
                for command, timings in command_buffer.items():
                    cmd_count = len(timings)
                    cmd_total_ms = sum(timings)
                    cmd_max_ms = max(timings) if timings else 0.0
                    cmd_key = f"{_METRICS_COMMANDS_KEY}:by_command:{command}"

                    pipe.hincrby(cmd_key, "count", cmd_count)
                    pipe.hincrbyfloat(cmd_key, "total_ms", cmd_total_ms)
                    pipe.eval(max_update_script, 1, cmd_key, cmd_max_ms)
                    pipe.expire(cmd_key, CacheTTL.METRICS)

                # Cache stats (batched)
                for (namespace, hit), count in cache_buffer.items():
                    field = "hits" if hit else "misses"
                    pipe.hincrby(_METRICS_CACHE_KEY, field, count)
                    pipe.hincrby(f"{_METRICS_CACHE_KEY}:namespace:{namespace}", field, count)
                    pipe.expire(f"{_METRICS_CACHE_KEY}:namespace:{namespace}", CacheTTL.METRICS)

                # Penetration stats (batched)
                for namespace, count in penetration_buffer.items():
                    pipe.hincrby(_METRICS_CACHE_PENETRATION_KEY, "total_attempts", count)
                    pipe.hincrby(
                        f"{_METRICS_CACHE_PENETRATION_KEY}:namespace:{namespace}",
                        "attempts",
                        count,
                    )
                    pipe.expire(
                        f"{_METRICS_CACHE_PENETRATION_KEY}:namespace:{namespace}",
                        CacheTTL.METRICS,
                    )

                # Set TTL on global keys
                if total_count > 0 or cache_buffer or penetration_buffer:
                    pipe.expire(_METRICS_COMMANDS_KEY, CacheTTL.METRICS)
                    pipe.expire(_METRICS_CACHE_KEY, CacheTTL.METRICS)
                    pipe.expire(_METRICS_CACHE_PENETRATION_KEY, CacheTTL.METRICS)

                await pipe.execute()

            logger.debug(
                "Flushed metrics: %d commands, %d cache ops, %d penetrations",
                total_count,
                len(cache_buffer),
                len(penetration_buffer),
            )
        except Exception as e:
            logger.debug("Failed to flush metrics: %s", e)

    def _sync_flush_on_exit(self) -> None:
        """Synchronous flush on process exit."""
        self._running = False
        # Best effort - can't do async in atexit


# Global metrics buffer singleton
_metrics_buffer = _MetricsBuffer()


class MetricsOperations:
    """Records and retrieves Redis runtime metrics using batched recording."""

    @staticmethod
    def _cache_namespace(key: str) -> str:
        """Extract namespace from cache key for metrics grouping."""
        parts = key.split(":")
        if len(parts) >= 3:
            return ":".join(parts[:3])
        if len(parts) >= 2:
            return ":".join(parts[:2])
        return parts[0] if parts else "unknown"

    async def _init_metrics_buffer(self) -> None:
        """Initialize the metrics buffer with Redis client."""
        client = await self._get_client()
        _metrics_buffer.start_flush_task(client)

    async def _record_command_timing(
        self, command: str, elapsed_ms: float, client: Any = None
    ) -> None:
        """Record command timing using batched buffer.

        Metrics are accumulated locally and flushed to Redis periodically
        to minimize per-command overhead.
        """
        _metrics_buffer.record_command(command, elapsed_ms)

    async def _record_cache_lookup(self, key: str, *, hit: bool, client: Any = None) -> None:
        """Record cache lookup using batched buffer.

        Metrics are accumulated locally and flushed to Redis periodically
        to minimize per-operation overhead.
        """
        _metrics_buffer.record_cache_lookup(key, hit=hit)

    async def _record_cache_penetration(self, key: str, client: Any = None) -> None:
        """Record cache penetration event using batched buffer.

        Metrics are accumulated locally and flushed to Redis periodically.
        """
        _metrics_buffer.record_penetration(key)

    async def get_runtime_metrics(self, client: Any) -> dict[str, Any]:
        """Get runtime metrics from Redis (aggregated across all processes)."""
        started = perf_counter()

        try:
            # Get command metrics
            commands_data = await client.hgetall(_METRICS_COMMANDS_KEY) or {}
            total_count = int(commands_data.get("total_count", 0))
            total_ms = float(commands_data.get("total_ms", 0.0))
            max_ms = float(commands_data.get("max_ms", 0.0))
            avg_ms = (total_ms / total_count) if total_count else 0.0

            # Get per-command metrics
            by_command: dict[str, Any] = {}
            command_keys_pattern = f"{_METRICS_COMMANDS_KEY}:by_command:*"
            async for key in client.scan_iter(match=command_keys_pattern):
                command_name = key.split(":")[-1]
                cmd_data = await client.hgetall(key) or {}
                count = int(cmd_data.get("count", 0))
                cmd_total_ms = float(cmd_data.get("total_ms", 0.0))
                cmd_max_ms = float(cmd_data.get("max_ms", 0.0))
                by_command[command_name] = {
                    "count": count,
                    "avg_ms": (cmd_total_ms / count) if count else 0.0,
                    "max_ms": cmd_max_ms,
                }

            # Get cache metrics
            cache_data = await client.hgetall(_METRICS_CACHE_KEY) or {}
            hits = int(cache_data.get("hits", 0))
            misses = int(cache_data.get("misses", 0))
            lookups = hits + misses
            hit_rate = (hits / lookups) if lookups else 0.0

            # Get per-namespace metrics
            by_namespace: dict[str, Any] = {}
            namespace_pattern = f"{_METRICS_CACHE_KEY}:namespace:*"
            async for key in client.scan_iter(match=namespace_pattern):
                namespace = key.split(":")[-1]
                ns_data = await client.hgetall(key) or {}
                ns_hits = int(ns_data.get("hits", 0))
                ns_misses = int(ns_data.get("misses", 0))
                ns_total = ns_hits + ns_misses
                by_namespace[namespace] = {
                    "hits": ns_hits,
                    "misses": ns_misses,
                    "hit_rate": (ns_hits / ns_total) if ns_total else 0.0,
                }

            await self._record_command_timing(
                client, "HGETALL", (perf_counter() - started) * 1000
            )

            # Get cache penetration metrics
            penetration_data = await client.hgetall(_METRICS_CACHE_PENETRATION_KEY) or {}
            total_penetration = int(penetration_data.get("total_attempts", 0))

            # Get per-namespace penetration metrics
            penetration_by_namespace: dict[str, Any] = {}
            penetration_pattern = f"{_METRICS_CACHE_PENETRATION_KEY}:namespace:*"
            async for key in client.scan_iter(match=penetration_pattern):
                namespace = key.split(":")[-1]
                ns_data = await client.hgetall(key) or {}
                ns_attempts = int(ns_data.get("attempts", 0))
                penetration_by_namespace[namespace] = {
                    "attempts": ns_attempts,
                }

            return {
                "commands": {
                    "total_count": total_count,
                    "avg_ms": avg_ms,
                    "max_ms": max_ms,
                    "by_command": by_command,
                },
                "cache": {
                    "hits": hits,
                    "misses": misses,
                    "hit_rate": hit_rate,
                    "by_namespace": by_namespace,
                },
                "penetration": {
                    "total_attempts": total_penetration,
                    "by_namespace": penetration_by_namespace,
                },
            }
        except Exception:
            # Return empty metrics on error
            return {
                "commands": {
                    "total_count": 0,
                    "avg_ms": 0.0,
                    "max_ms": 0.0,
                    "by_command": {},
                },
                "cache": {
                    "hits": 0,
                    "misses": 0,
                    "hit_rate": 0.0,
                    "by_namespace": {},
                },
                "penetration": {
                    "total_attempts": 0,
                    "by_namespace": {},
                },
            }

    async def get_penetration_metrics(self, client: Any) -> dict[str, Any]:
        """Get cache penetration metrics."""
        try:
            penetration_data = await client.hgetall(_METRICS_CACHE_PENETRATION_KEY) or {}
            total_attempts = int(penetration_data.get("total_attempts", 0))

            # Get per-namespace penetration metrics
            by_namespace: dict[str, Any] = {}
            penetration_pattern = f"{_METRICS_CACHE_PENETRATION_KEY}:namespace:*"
            async for key in client.scan_iter(match=penetration_pattern):
                namespace = key.split(":")[-1]
                ns_data = await client.hgetall(key) or {}
                ns_attempts = int(ns_data.get("attempts", 0))
                by_namespace[namespace] = {
                    "attempts": ns_attempts,
                }

            return {
                "total_attempts": total_attempts,
                "by_namespace": by_namespace,
            }
        except Exception:
            return {
                "total_attempts": 0,
                "by_namespace": {},
            }


# Backward compatibility alias
RedisMetrics = MetricsOperations
