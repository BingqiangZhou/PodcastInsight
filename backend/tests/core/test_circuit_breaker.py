"""Tests for the circuit breaker module.

Covers state transitions (CLOSED -> OPEN -> HALF_OPEN -> CLOSED),
failure counting, recovery timeout behaviour, async context manager,
call() method, decorator, and the global registry.
"""

import asyncio
import time
from unittest.mock import patch

import pytest

from app.core.circuit_breaker import (
    CircuitBreaker,
    CircuitOpenError,
    CircuitState,
    _circuit_breakers,
    circuit_breaker as circuit_breaker_decorator,
    get_all_circuit_breaker_stats,
    get_circuit_breaker,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_breaker(
    failure_threshold: int = 3,
    recovery_timeout: float = 1.0,
) -> CircuitBreaker:
    return CircuitBreaker(
        name="test",
        failure_threshold=failure_threshold,
        recovery_timeout=recovery_timeout,
    )


# ---------------------------------------------------------------------------
# 1. Initial state
# ---------------------------------------------------------------------------


class TestInitialState:
    def test_starts_in_closed_state(self) -> None:
        cb = _make_breaker()
        assert cb.state == CircuitState.CLOSED

    def test_state_property_returns_enum(self) -> None:
        cb = _make_breaker()
        assert cb.state is CircuitState.CLOSED

    def test_state_value_is_string(self) -> None:
        cb = _make_breaker()
        assert cb.state.value == "closed"

    def test_zero_failures_initially(self) -> None:
        cb = _make_breaker()
        assert cb._failure_count == 0

    def test_stats_initialised(self) -> None:
        cb = _make_breaker()
        assert cb.stats.total_calls == 0
        assert cb.stats.successful_calls == 0
        assert cb.stats.failed_calls == 0
        assert cb.stats.rejected_calls == 0


# ---------------------------------------------------------------------------
# 2. CLOSED -> OPEN transition (failure threshold)
# ---------------------------------------------------------------------------


class TestClosedToOpen:
    def test_opens_after_exact_failure_threshold(self) -> None:
        cb = _make_breaker(failure_threshold=3, recovery_timeout=60.0)
        for _ in range(3):
            cb._record_failure(RuntimeError("boom"))
        assert cb.state == CircuitState.OPEN

    def test_does_not_open_before_threshold(self) -> None:
        cb = _make_breaker(failure_threshold=3, recovery_timeout=60.0)
        cb._record_failure(RuntimeError("boom"))
        cb._record_failure(RuntimeError("boom"))
        assert cb.state == CircuitState.CLOSED

    def test_stays_closed_with_threshold_one(self) -> None:
        cb = _make_breaker(failure_threshold=1, recovery_timeout=60.0)
        assert cb.state == CircuitState.CLOSED

    def test_opens_with_threshold_one_after_single_failure(self) -> None:
        cb = _make_breaker(failure_threshold=1, recovery_timeout=60.0)
        cb._record_failure(RuntimeError("boom"))
        assert cb.state == CircuitState.OPEN

    def test_failure_count_increments(self) -> None:
        cb = _make_breaker(failure_threshold=5, recovery_timeout=60.0)
        cb._record_failure(RuntimeError("1"))
        assert cb._failure_count == 1
        cb._record_failure(RuntimeError("2"))
        assert cb._failure_count == 2

    def test_stats_track_failed_calls(self) -> None:
        cb = _make_breaker(failure_threshold=5, recovery_timeout=60.0)
        cb._record_failure(RuntimeError("a"))
        cb._record_failure(RuntimeError("b"))
        assert cb.stats.failed_calls == 2
        assert cb.stats.total_calls == 2

    def test_last_failure_time_updated(self) -> None:
        cb = _make_breaker(failure_threshold=5, recovery_timeout=60.0)
        before = time.time()
        cb._record_failure(RuntimeError("boom"))
        assert cb._last_failure_time is not None
        assert cb._last_failure_time >= before


# ---------------------------------------------------------------------------
# 3. OPEN state blocks requests
# ---------------------------------------------------------------------------


class TestOpenState:
    def test_should_allow_request_returns_false_when_open(self) -> None:
        cb = _make_breaker(failure_threshold=1, recovery_timeout=60.0)
        cb._record_failure(RuntimeError("boom"))
        assert cb.state == CircuitState.OPEN
        assert cb._should_allow_request() is False

    @pytest.mark.asyncio
    async def test_context_manager_raises_circuit_open_error(self) -> None:
        cb = _make_breaker(failure_threshold=1, recovery_timeout=60.0)
        cb._record_failure(RuntimeError("boom"))
        with pytest.raises(CircuitOpenError, match="is open"):
            async with cb:
                pass

    @pytest.mark.asyncio
    async def test_rejection_counted(self) -> None:
        cb = _make_breaker(failure_threshold=1, recovery_timeout=60.0)
        cb._record_failure(RuntimeError("boom"))
        with pytest.raises(CircuitOpenError):
            async with cb:
                pass
        assert cb.stats.rejected_calls == 1


# ---------------------------------------------------------------------------
# 4. OPEN -> HALF_OPEN after recovery timeout
# ---------------------------------------------------------------------------


class TestRecoveryTimeout:
    def test_transitions_to_half_open_after_timeout(self) -> None:
        cb = _make_breaker(failure_threshold=1, recovery_timeout=0.1)
        cb._record_failure(RuntimeError("boom"))
        assert cb.state == CircuitState.OPEN

        time.sleep(0.15)
        # _should_allow_request triggers the transition
        assert cb._should_allow_request() is True
        assert cb.state == CircuitState.HALF_OPEN

    def test_stays_open_before_timeout(self) -> None:
        cb = _make_breaker(failure_threshold=1, recovery_timeout=60.0)
        cb._record_failure(RuntimeError("boom"))
        assert cb._should_allow_request() is False
        assert cb.state == CircuitState.OPEN

    @pytest.mark.asyncio
    async def test_allows_one_request_after_timeout(self) -> None:
        cb = _make_breaker(failure_threshold=1, recovery_timeout=0.1)
        cb._record_failure(RuntimeError("boom"))
        time.sleep(0.15)

        # Should not raise -- request is allowed
        async with cb:
            pass  # success

    def test_half_open_allows_requests(self) -> None:
        cb = _make_breaker(failure_threshold=1, recovery_timeout=0.1)
        cb._record_failure(RuntimeError("boom"))
        time.sleep(0.15)
        cb._should_allow_request()  # triggers transition
        assert cb.state == CircuitState.HALF_OPEN
        assert cb._should_allow_request() is True


# ---------------------------------------------------------------------------
# 5. HALF_OPEN -> CLOSED on success
# ---------------------------------------------------------------------------


class TestHalfOpenToClosed:
    def test_success_in_half_open_closes_circuit(self) -> None:
        cb = _make_breaker(failure_threshold=1, recovery_timeout=0.1)
        cb._record_failure(RuntimeError("boom"))
        time.sleep(0.15)
        cb._should_allow_request()  # -> HALF_OPEN

        cb._record_success()
        assert cb.state == CircuitState.CLOSED

    @pytest.mark.asyncio
    async def test_context_success_in_half_open(self) -> None:
        cb = _make_breaker(failure_threshold=1, recovery_timeout=0.1)
        cb._record_failure(RuntimeError("boom"))
        time.sleep(0.15)

        async with cb:
            pass  # success

        assert cb.state == CircuitState.CLOSED

    def test_failure_count_reset_on_success(self) -> None:
        cb = _make_breaker(failure_threshold=1, recovery_timeout=0.1)
        cb._record_failure(RuntimeError("boom"))
        assert cb._failure_count == 1
        time.sleep(0.15)
        cb._should_allow_request()
        cb._record_success()
        assert cb._failure_count == 0


# ---------------------------------------------------------------------------
# 6. HALF_OPEN -> OPEN on failure
# ---------------------------------------------------------------------------


class TestHalfOpenToOpen:
    def test_failure_in_half_open_reopens(self) -> None:
        cb = _make_breaker(failure_threshold=1, recovery_timeout=0.1)
        cb._record_failure(RuntimeError("boom"))
        time.sleep(0.15)
        cb._should_allow_request()  # -> HALF_OPEN

        cb._record_failure(RuntimeError("still broken"))
        assert cb.state == CircuitState.OPEN

    @pytest.mark.asyncio
    async def test_context_failure_in_half_open(self) -> None:
        cb = _make_breaker(failure_threshold=1, recovery_timeout=0.1)
        cb._record_failure(RuntimeError("boom"))
        time.sleep(0.15)

        with pytest.raises(RuntimeError):
            async with cb:
                raise RuntimeError("still broken")

        assert cb.state == CircuitState.OPEN


# ---------------------------------------------------------------------------
# 7. Success resets failure count in CLOSED state
# ---------------------------------------------------------------------------


class TestSuccessResetsFailures:
    def test_success_resets_failure_count(self) -> None:
        cb = _make_breaker(failure_threshold=5, recovery_timeout=60.0)
        cb._record_failure(RuntimeError("1"))
        cb._record_failure(RuntimeError("2"))
        assert cb._failure_count == 2

        cb._record_success()
        assert cb._failure_count == 0

    def test_interleaved_success_prevents_open(self) -> None:
        cb = _make_breaker(failure_threshold=3, recovery_timeout=60.0)
        cb._record_failure(RuntimeError("1"))
        cb._record_failure(RuntimeError("2"))
        cb._record_success()  # resets count
        cb._record_failure(RuntimeError("3"))
        assert cb._failure_count == 1
        assert cb.state == CircuitState.CLOSED

    def test_stats_track_successes(self) -> None:
        cb = _make_breaker(failure_threshold=5, recovery_timeout=60.0)
        cb._record_success()
        cb._record_success()
        assert cb.stats.successful_calls == 2
        assert cb.stats.total_calls == 2


# ---------------------------------------------------------------------------
# 8. State property returns correct value at each stage
# ---------------------------------------------------------------------------


class TestStateProperty:
    def test_closed_value(self) -> None:
        cb = _make_breaker()
        assert cb.state == CircuitState.CLOSED
        assert cb.state.value == "closed"

    def test_open_value(self) -> None:
        cb = _make_breaker(failure_threshold=1, recovery_timeout=60.0)
        cb._record_failure(RuntimeError("boom"))
        assert cb.state == CircuitState.OPEN
        assert cb.state.value == "open"

    def test_half_open_value(self) -> None:
        cb = _make_breaker(failure_threshold=1, recovery_timeout=0.1)
        cb._record_failure(RuntimeError("boom"))
        time.sleep(0.15)
        cb._should_allow_request()
        assert cb.state == CircuitState.HALF_OPEN
        assert cb.state.value == "half_open"


# ---------------------------------------------------------------------------
# 9. Async context manager integration
# ---------------------------------------------------------------------------


class TestAsyncContextManager:
    @pytest.mark.asyncio
    async def test_success_path(self) -> None:
        cb = _make_breaker()
        async with cb:
            pass  # no exception -> success
        assert cb.stats.successful_calls == 1

    @pytest.mark.asyncio
    async def test_failure_path(self) -> None:
        cb = _make_breaker(failure_threshold=5, recovery_timeout=60.0)
        with pytest.raises(RuntimeError):
            async with cb:
                raise RuntimeError("fail")
        assert cb.stats.failed_calls == 1

    @pytest.mark.asyncio
    async def test_unexpected_exception_not_counted(self) -> None:
        """Exceptions not in expected_exceptions should not be recorded as failures."""

        class UnexpectedError(Exception):
            pass

        cb = CircuitBreaker(
            name="strict",
            failure_threshold=1,
            recovery_timeout=60.0,
            expected_exceptions=(RuntimeError,),
        )
        with pytest.raises(UnexpectedError):
            async with cb:
                raise UnexpectedError("not expected")
        # Not counted as failure because UnexpectedError is not in expected_exceptions
        assert cb.stats.failed_calls == 0
        assert cb._failure_count == 0


# ---------------------------------------------------------------------------
# 10. call() method
# ---------------------------------------------------------------------------


class TestCallMethod:
    @pytest.mark.asyncio
    async def test_call_returns_result(self) -> None:
        cb = _make_breaker()

        async def ok() -> str:
            return "done"

        result = await cb.call(ok)
        assert result == "done"
        assert cb.stats.successful_calls == 1

    @pytest.mark.asyncio
    async def test_call_records_failure(self) -> None:
        cb = _make_breaker(failure_threshold=5, recovery_timeout=60.0)

        async def fail() -> None:
            raise RuntimeError("boom")

        with pytest.raises(RuntimeError, match="boom"):
            await cb.call(fail)
        assert cb.stats.failed_calls == 1

    @pytest.mark.asyncio
    async def test_call_raises_circuit_open(self) -> None:
        cb = _make_breaker(failure_threshold=1, recovery_timeout=60.0)
        cb._record_failure(RuntimeError("boom"))

        async def never_called() -> None:
            raise AssertionError("should not be called")

        with pytest.raises(CircuitOpenError):
            await cb.call(never_called)

    @pytest.mark.asyncio
    async def test_call_passes_args_and_kwargs(self) -> None:
        cb = _make_breaker()

        async def add(a: int, b: int, extra: int = 0) -> int:
            return a + b + extra

        result = await cb.call(add, 1, 2, extra=10)
        assert result == 13


# ---------------------------------------------------------------------------
# 11. Decorator
# ---------------------------------------------------------------------------


class TestDecorator:
    @pytest.mark.asyncio
    async def test_decorator_success(self) -> None:
        @circuit_breaker_decorator("decor_test_ok", failure_threshold=3)
        async def ok() -> str:
            return "ok"

        result = await ok()
        assert result == "ok"

    @pytest.mark.asyncio
    async def test_decorator_propagates_error(self) -> None:
        breaker_name = "decor_test_fail"

        @circuit_breaker_decorator(breaker_name, failure_threshold=5)
        async def fail() -> None:
            raise ValueError("bad")

        with pytest.raises(ValueError, match="bad"):
            await fail()

    @pytest.mark.asyncio
    async def test_decorator_opens_circuit(self) -> None:
        breaker_name = "decor_test_open"

        @circuit_breaker_decorator(breaker_name, failure_threshold=1)
        async def fail() -> None:
            raise RuntimeError("boom")

        with pytest.raises(RuntimeError):
            await fail()

        with pytest.raises(CircuitOpenError):
            await fail()


# ---------------------------------------------------------------------------
# 12. Global registry
# ---------------------------------------------------------------------------


class TestGlobalRegistry:
    def setup_method(self) -> None:
        _circuit_breakers.clear()

    def test_get_or_create(self) -> None:
        cb1 = get_circuit_breaker("reg", failure_threshold=3, recovery_timeout=10.0)
        cb2 = get_circuit_breaker("reg", failure_threshold=99, recovery_timeout=99.0)
        assert cb1 is cb2
        # Original threshold preserved on second call
        assert cb1.failure_threshold == 3

    def test_different_names_different_instances(self) -> None:
        cb_a = get_circuit_breaker("a")
        cb_b = get_circuit_breaker("b")
        assert cb_a is not cb_b

    def test_get_all_stats(self) -> None:
        cb = get_circuit_breaker("stats_test", failure_threshold=5, recovery_timeout=10.0)
        cb._record_success()
        cb._record_failure(RuntimeError("boom"))

        stats = get_all_circuit_breaker_stats()
        assert "stats_test" in stats
        assert stats["stats_test"]["state"] == "closed"
        assert stats["stats_test"]["successful_calls"] == 1
        assert stats["stats_test"]["failed_calls"] == 1


# ---------------------------------------------------------------------------
# 13. Full lifecycle integration test
# ---------------------------------------------------------------------------


class TestFullLifecycle:
    def test_closed_open_half_open_closed(self) -> None:
        cb = _make_breaker(failure_threshold=2, recovery_timeout=0.1)

        # CLOSED
        assert cb.state == CircuitState.CLOSED

        # Fail up to threshold -> OPEN
        cb._record_failure(RuntimeError("1"))
        assert cb.state == CircuitState.CLOSED
        cb._record_failure(RuntimeError("2"))
        assert cb.state == CircuitState.OPEN

        # Wait for recovery -> HALF_OPEN
        time.sleep(0.15)
        assert cb._should_allow_request() is True
        assert cb.state == CircuitState.HALF_OPEN

        # Succeed -> CLOSED
        cb._record_success()
        assert cb.state == CircuitState.CLOSED
        assert cb._failure_count == 0

    @pytest.mark.asyncio
    async def test_async_lifecycle(self) -> None:
        cb = _make_breaker(failure_threshold=2, recovery_timeout=0.1)

        # CLOSED: record some successes
        for _ in range(3):
            async with cb:
                pass
        assert cb.state == CircuitState.CLOSED
        assert cb.stats.successful_calls == 3

        # OPEN: hit threshold
        for i in range(2):
            with pytest.raises(RuntimeError):
                async with cb:
                    raise RuntimeError(f"fail {i}")
        assert cb.state == CircuitState.OPEN

        # Reject
        with pytest.raises(CircuitOpenError):
            async with cb:
                pass
        assert cb.stats.rejected_calls == 1

        # Recover -> HALF_OPEN -> success -> CLOSED
        time.sleep(0.15)
        async with cb:
            pass
        assert cb.state == CircuitState.CLOSED

    def test_half_open_failure_goes_back_to_open(self) -> None:
        cb = _make_breaker(failure_threshold=1, recovery_timeout=0.1)

        cb._record_failure(RuntimeError("1"))
        assert cb.state == CircuitState.OPEN

        time.sleep(0.15)
        cb._should_allow_request()
        assert cb.state == CircuitState.HALF_OPEN

        cb._record_failure(RuntimeError("2"))
        assert cb.state == CircuitState.OPEN
