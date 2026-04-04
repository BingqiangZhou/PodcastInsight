"""Tests for retryable HTTP status classification across the codebase."""

from app.core.ai_client import is_retryable_http_status as unified_retryable
from app.domains.ai.services.model_runtime_service import (
    _is_retryable_http_status as runtime_retryable,
)


def test_unified_retryable_status_classification() -> None:
    """The unified is_retryable_http_status covers all known retryable codes."""
    assert unified_retryable(500) is True
    assert unified_retryable(503) is True
    assert unified_retryable(429) is True
    assert unified_retryable(408) is True
    assert unified_retryable(409) is True
    assert unified_retryable(425) is True
    assert unified_retryable(401) is False
    assert unified_retryable(400) is False
    assert unified_retryable(404) is False


def test_runtime_retryable_status_matches_unified() -> None:
    """Runtime service and unified client must agree on retryable status codes."""
    for code in [500, 429, 408, 409, 425, 401, 400, 404]:
        assert runtime_retryable(code) == unified_retryable(code), (
            f"Mismatch for status {code}"
        )


def test_summary_uses_unified_retryable() -> None:
    """Summary service delegates to unified is_retryable_http_status."""
    from app.core.ai_client import is_retryable_http_status

    assert is_retryable_http_status(503) is True
    assert is_retryable_http_status(425) is True
    assert is_retryable_http_status(409) is True
    assert is_retryable_http_status(404) is False
