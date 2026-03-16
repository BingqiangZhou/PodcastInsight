"""Circuit Breaker Pattern Implementation.

Provides fault tolerance for external service calls by preventing cascading failures.
When a service fails repeatedly, the circuit opens and fast-fails subsequent calls
until a recovery timeout passes.
"""

import asyncio
import logging
import time
from dataclasses import dataclass, field
from enum import Enum
from functools import wraps
from typing import Any, Callable, TypeVar

logger = logging.getLogger(__name__)

T = TypeVar("T")


class CircuitState(Enum):
    """Circuit breaker states."""

    CLOSED = "closed"  # Normal operation, requests pass through
    OPEN = "open"  # Failing, requests are rejected immediately
    HALF_OPEN = "half_open"  # Testing if service recovered


@dataclass
class CircuitStats:
    """Statistics for circuit breaker monitoring."""

    total_calls: int = 0
    successful_calls: int = 0
    failed_calls: int = 0
    rejected_calls: int = 0
    last_failure_time: float | None = None
    last_state_change: float = field(default_factory=time.time)


class CircuitBreaker:
    """Circuit breaker for protecting external service calls.

    Usage:
        breaker = CircuitBreaker(name="redis", failure_threshold=5, recovery_timeout=30)

        async with breaker:
            result = await external_service_call()

        # Or with decorator:
        @circuit_breaker("api")
        async def call_external_api():
            ...
    """

    def __init__(
        self,
        name: str,
        failure_threshold: int = 5,
        recovery_timeout: float = 30.0,
        expected_exceptions: tuple[type[Exception], ...] = (Exception,),
    ):
        """Initialize circuit breaker.

        Args:
            name: Identifier for logging and monitoring
            failure_threshold: Number of failures before opening circuit
            recovery_timeout: Seconds to wait before trying half-open state
            expected_exceptions: Exceptions that count as failures
        """
        self.name = name
        self.failure_threshold = failure_threshold
        self.recovery_timeout = recovery_timeout
        self.expected_exceptions = expected_exceptions

        self._state = CircuitState.CLOSED
        self._failure_count = 0
        self._last_failure_time: float | None = None
        self._lock = asyncio.Lock()
        self._stats = CircuitStats()

    @property
    def state(self) -> CircuitState:
        """Current circuit state."""
        return self._state

    @property
    def stats(self) -> CircuitStats:
        """Circuit breaker statistics."""
        return self._stats

    def _should_allow_request(self) -> bool:
        """Check if request should be allowed based on current state."""
        if self._state == CircuitState.CLOSED:
            return True

        if self._state == CircuitState.OPEN:
            # Check if recovery timeout has passed
            if (
                self._last_failure_time
                and time.time() - self._last_failure_time >= self.recovery_timeout
            ):
                # Transition to half-open
                self._transition_to(CircuitState.HALF_OPEN)
                return True
            return False

        # HALF_OPEN: allow one request to test
        return True

    def _transition_to(self, new_state: CircuitState) -> None:
        """Transition to a new state."""
        if self._state != new_state:
            old_state = self._state
            self._state = new_state
            self._stats.last_state_change = time.time()
            logger.info(
                "Circuit breaker '%s' transitioned: %s -> %s",
                self.name,
                old_state.value,
                new_state.value,
            )

    def _record_success(self) -> None:
        """Record a successful call."""
        self._stats.total_calls += 1
        self._stats.successful_calls += 1
        self._failure_count = 0

        if self._state == CircuitState.HALF_OPEN:
            self._transition_to(CircuitState.CLOSED)

    def _record_failure(self, error: Exception) -> None:
        """Record a failed call."""
        self._stats.total_calls += 1
        self._stats.failed_calls += 1
        self._stats.last_failure_time = time.time()
        self._failure_count += 1
        self._last_failure_time = time.time()

        if self._failure_count >= self.failure_threshold:
            if self._state != CircuitState.OPEN:
                self._transition_to(CircuitState.OPEN)

        logger.warning(
            "Circuit breaker '%s' recorded failure %d/%d: %s",
            self.name,
            self._failure_count,
            self.failure_threshold,
            str(error),
        )

    def _record_rejection(self) -> None:
        """Record a rejected call (circuit open)."""
        self._stats.rejected_calls += 1
        logger.debug(
            "Circuit breaker '%s' rejected request (state: %s)",
            self.name,
            self._state.value,
        )

    async def __aenter__(self) -> "CircuitBreaker":
        """Enter async context manager."""
        async with self._lock:
            if not self._should_allow_request():
                self._record_rejection()
                raise CircuitOpenError(
                    f"Circuit breaker '{self.name}' is open. "
                    f"Service temporarily unavailable."
                )
        return self

    async def __aexit__(
        self,
        exc_type: type[BaseException] | None,
        exc_val: BaseException | None,
        exc_tb: Any,
    ) -> None:
        """Exit async context manager."""
        if exc_type is None:
            self._record_success()
        elif issubclass(exc_type, self.expected_exceptions):
            self._record_failure(exc_val)  # type: ignore
        # Other exceptions are not counted as failures

    async def call(self, func: Callable[..., T], *args: Any, **kwargs: Any) -> T:
        """Execute a function with circuit breaker protection.

        Args:
            func: Async function to call
            *args: Positional arguments for func
            **kwargs: Keyword arguments for func

        Returns:
            Result of func

        Raises:
            CircuitOpenError: If circuit is open
            Any exception raised by func
        """
        async with self:
            return await func(*args, **kwargs)


class CircuitOpenError(Exception):
    """Raised when circuit breaker is open."""

    pass


# Global circuit breakers registry
_circuit_breakers: dict[str, CircuitBreaker] = {}


def get_circuit_breaker(
    name: str,
    failure_threshold: int = 5,
    recovery_timeout: float = 30.0,
) -> CircuitBreaker:
    """Get or create a circuit breaker by name.

    Args:
        name: Unique identifier for the circuit breaker
        failure_threshold: Failures before opening (default: 5)
        recovery_timeout: Seconds before retry (default: 30)

    Returns:
        CircuitBreaker instance
    """
    if name not in _circuit_breakers:
        _circuit_breakers[name] = CircuitBreaker(
            name=name,
            failure_threshold=failure_threshold,
            recovery_timeout=recovery_timeout,
        )
    return _circuit_breakers[name]


def circuit_breaker(
    name: str,
    failure_threshold: int = 5,
    recovery_timeout: float = 30.0,
) -> Callable:
    """Decorator to protect a function with a circuit breaker.

    Usage:
        @circuit_breaker("external_api", failure_threshold=3)
        async def call_external_api():
            ...
    """

    def decorator(func: Callable[..., T]) -> Callable[..., T]:
        breaker = get_circuit_breaker(name, failure_threshold, recovery_timeout)

        @wraps(func)
        async def wrapper(*args: Any, **kwargs: Any) -> T:
            return await breaker.call(func, *args, **kwargs)

        return wrapper

    return decorator


def get_all_circuit_breaker_stats() -> dict[str, dict[str, Any]]:
    """Get statistics for all circuit breakers."""
    return {
        name: {
            "state": breaker.state.value,
            "total_calls": breaker.stats.total_calls,
            "successful_calls": breaker.stats.successful_calls,
            "failed_calls": breaker.stats.failed_calls,
            "rejected_calls": breaker.stats.rejected_calls,
            "failure_count": breaker._failure_count,
            "last_failure_time": breaker.stats.last_failure_time,
            "last_state_change": breaker.stats.last_state_change,
        }
        for name, breaker in _circuit_breakers.items()
    }
