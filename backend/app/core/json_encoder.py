"""Custom JSON encoder

Handles datetime serialization, ensuring timestamps include timezone info.
"""

import orjson
from datetime import UTC, datetime
from json import JSONEncoder
from typing import Any

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


class CustomJSONEncoder(JSONEncoder):
    """Custom JSON encoder (kept for backward compatibility).

    - datetime objects are serialized to timezone-aware ISO 8601 format
    - Other types use default encoding
    """

    def default(self, obj: Any) -> Any:
        # Handle datetime objects
        if isinstance(obj, datetime):
            # If datetime is naive (no timezone info), assume UTC
            if obj.tzinfo is None:
                # Add UTC timezone info
                obj = obj.replace(tzinfo=UTC)
            # Serialize to ISO format (includes timezone, e.g. +00:00)
            return obj.isoformat()

        # Delegate to parent for other types
        return super().default(obj)
