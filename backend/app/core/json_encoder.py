"""Custom JSON encoder

Handles datetime serialization, ensuring timestamps include timezone info.
"""

from datetime import UTC, datetime
from typing import Any

import orjson
from fastapi.responses import JSONResponse


def _default_serializer(obj: Any) -> Any:
    """Handle types that orjson can't serialize natively."""
    if isinstance(obj, datetime):
        if obj.tzinfo is None:
            obj = obj.replace(tzinfo=UTC)
        return obj.isoformat()
    raise TypeError(f"Object of type {type(obj).__name__} is not JSON serializable")


class CustomJSONResponse(JSONResponse):
    """Custom JSON response class using orjson for serialization."""

    # Explicitly declare media_type with charset=utf-8
    media_type = "application/json; charset=utf-8"

    def render(self, content: Any) -> bytes:
        return orjson.dumps(content, default=_default_serializer)
