from datetime import UTC, datetime
from types import SimpleNamespace

from app.domains.ai.api.response_mapper import (
    build_ai_model_config_list_response,
    build_ai_model_config_response,
)
from app.domains.ai.models import ModelType


def _make_model(**overrides):
    payload = {
        "id": 7,
        "name": "gpt-4o-mini",
        "display_name": "GPT 4o Mini",
        "description": "default model",
        "model_type": ModelType.TEXT_GENERATION,
        "api_url": "https://example.test/v1",
        "api_key": "encrypted",
        "api_key_encrypted": True,
        "model_id": "gpt-4o-mini",
        "provider": "openai",
        "max_tokens": 2048,
        "temperature": "0.4",
        "timeout_seconds": 30,
        "max_retries": 2,
        "max_concurrent_requests": 1,
        "rate_limit_per_minute": 60,
        "cost_per_input_token": "0.1",
        "cost_per_output_token": "0.2",
        "extra_config": {},
        "is_active": True,
        "is_default": False,
        "is_system": False,
        "usage_count": 8,
        "success_count": 6,
        "error_count": 2,
        "total_tokens_used": 1024,
        "created_at": datetime(2026, 3, 1, tzinfo=UTC),
        "updated_at": datetime(2026, 3, 2, tzinfo=UTC),
        "last_used_at": datetime(2026, 3, 3, tzinfo=UTC),
    }
    payload.update(overrides)
    return SimpleNamespace(**payload)


def test_build_ai_model_config_response_calculates_success_rate():
    response = build_ai_model_config_response(_make_model())

    assert response.id == 7
    assert response.success_rate == 75.0
    assert response.model_type == ModelType.TEXT_GENERATION


def test_build_ai_model_config_list_response_builds_pages():
    response = build_ai_model_config_list_response(
        models=[_make_model(id=1), _make_model(id=2)],
        total=9,
        page=2,
        size=4,
    )

    assert response.total == 9
    assert response.page == 2
    assert response.size == 4
    assert response.pages == 3
    assert [model.id for model in response.models] == [1, 2]
