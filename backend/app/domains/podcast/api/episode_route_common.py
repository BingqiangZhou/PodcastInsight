"""Shared helpers for podcast episode-related route modules."""

import base64
import binascii
import json
from datetime import datetime, timezone
from typing import Any

from fastapi import status

from app.http.errors import bilingual_http_exception


def encode_keyset_cursor(cursor_type: str, timestamp: datetime, episode_id: int) -> str:
    """Encode stable keyset cursor payload."""
    normalized = timestamp
    if normalized.tzinfo is not None:
        normalized = normalized.astimezone(timezone.utc).replace(tzinfo=None)

    payload = {
        "v": 2,
        "type": cursor_type,
        "ts": normalized.isoformat(),
        "id": episode_id,
    }
    raw = json.dumps(payload, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    return base64.urlsafe_b64encode(raw).decode("utf-8").rstrip("=")


def decode_cursor(cursor: str) -> dict[str, Any]:
    """Decode a keyset cursor token used by feed/history endpoints."""
    padding = "=" * (-len(cursor) % 4)
    try:
        decoded = base64.urlsafe_b64decode(f"{cursor}{padding}").decode("utf-8")
    except (ValueError, binascii.Error) as exc:
        raise bilingual_http_exception(
            "Invalid cursor",
            "娓告爣鍙傛暟鏃犳晥",
            status.HTTP_400_BAD_REQUEST,
        ) from exc

    try:
        payload = json.loads(decoded)
        if not isinstance(payload, dict):
            raise ValueError("payload must be object")

        cursor_type = payload.get("type")
        timestamp_raw = payload.get("ts")
        episode_id = payload.get("id")
        if cursor_type not in {"feed", "history"}:
            raise ValueError("unsupported cursor type")
        if not isinstance(timestamp_raw, str):
            raise ValueError("timestamp missing")
        if not isinstance(episode_id, int) or episode_id <= 0:
            raise ValueError("episode id missing")

        timestamp = datetime.fromisoformat(timestamp_raw)
        if timestamp.tzinfo is not None:
            timestamp = timestamp.astimezone(timezone.utc).replace(tzinfo=None)

        return {
            "type": cursor_type,
            "ts": timestamp,
            "id": episode_id,
        }
    except (ValueError, TypeError, json.JSONDecodeError) as exc:
        raise bilingual_http_exception(
            "Invalid cursor",
            "娓告爣鍙傛暟鏃犳晥",
            status.HTTP_400_BAD_REQUEST,
        ) from exc
