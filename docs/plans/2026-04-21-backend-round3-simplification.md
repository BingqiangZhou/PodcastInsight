# Backend Round 3 Simplification — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove ~730 lines of dead code, fix structural coupling, and eliminate duplication from the backend.

**Architecture:** Three phases executed sequentially — dead code deletion first (safest), then structural changes, then misc cleanup. Each task is independent and can be verified with `cd backend && uv run pytest`.

**Tech Stack:** Python 3.11+, FastAPI, SQLAlchemy async, Pydantic, ruff linter

---

## Phase 1: Dead Code Elimination (7 tasks)

### Task 1.1: Delete `core/interfaces/` abstraction

**Files:**
- Create: `backend/app/admin/settings_provider.py`
- Modify: `backend/app/domains/podcast/repositories/podcast_repository.py` (line 27 import)
- Modify: `backend/app/domains/podcast/repositories/content_repository.py` (line 10 import)
- Delete: `backend/app/core/interfaces/` (entire directory: 3 files)

- [ ] **Step 1: Create `backend/app/admin/settings_provider.py`**

```python
"""Database-backed settings provider for reading system settings."""

from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.admin.models import SystemSettings


class DatabaseSettingsProvider:
    """Read system settings from the ``system_settings`` table."""

    async def get_setting(self, db: AsyncSession, key: str) -> dict[str, Any] | None:
        result = await db.execute(
            select(SystemSettings).where(SystemSettings.key == key),
        )
        setting = result.scalar_one_or_none()
        if setting and setting.value:
            return setting.value
        return None

    async def get_setting_value(
        self,
        db: AsyncSession,
        key: str,
        default: Any = None,
    ) -> Any:
        data = await self.get_setting(db, key)
        if data is None:
            return default
        return data.get("value", default) if isinstance(data, dict) else default
```

- [ ] **Step 2: Update import in `backend/app/domains/podcast/repositories/podcast_repository.py` line 27**

Change: `from app.core.interfaces.settings_provider_impl import DatabaseSettingsProvider`
To: `from app.admin.settings_provider import DatabaseSettingsProvider`

- [ ] **Step 3: Update import in `backend/app/domains/podcast/repositories/content_repository.py` line 10**

Change: `from app.core.interfaces.settings_provider_impl import DatabaseSettingsProvider`
To: `from app.admin.settings_provider import DatabaseSettingsProvider`

- [ ] **Step 4: Delete `core/interfaces/` directory**

```bash
rm -r backend/app/core/interfaces/
```

- [ ] **Step 5: Verify**

```bash
cd backend && uv run pytest
```

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "refactor(backend): move DatabaseSettingsProvider to admin, delete core/interfaces/"
```

---

### Task 1.2: Clean `shared/schemas.py`

**Files:**
- Modify: `backend/app/shared/schemas.py`
- Modify: `backend/app/shared/__init__.py`
- Modify: `backend/app/domains/podcast/schemas.py` (add Subscription schemas after line 14)
- Modify: `backend/app/domains/podcast/repositories/content_repository.py` (line 18 import)
- Modify: `backend/app/admin/services/subscriptions_opml_service.py` (line 19 import)
- Modify: `backend/app/admin/tests/test_subscriptions_opml_service.py` (line 7 import)

- [ ] **Step 1: Add Subscription schemas to `backend/app/domains/podcast/schemas.py` after the alias block (after line 14)**

```python
# === Generic Subscription schemas (moved from shared) ===


class SubscriptionBase(BaseSchema):
    title: str
    description: str | None = None
    source_type: str
    source_url: str
    image_url: str | None = None
    config: dict[str, Any] | None = {}
    fetch_interval: int = 3600


class SubscriptionCreate(SubscriptionBase):
    pass


class SubscriptionUpdate(BaseSchema):
    title: str | None = None
    description: str | None = None
    image_url: str | None = None
    config: dict[str, Any] | None = None
    fetch_interval: int | None = None
    is_active: bool | None = None
```

- [ ] **Step 2: Update import in `content_repository.py` line 18**

Change: `from app.shared.schemas import SubscriptionCreate, SubscriptionUpdate`
To: `from app.domains.podcast.schemas import SubscriptionCreate, SubscriptionUpdate`

- [ ] **Step 3: Update import in `subscriptions_opml_service.py` line 19**

Change: `from app.shared.schemas import SubscriptionCreate`
To: `from app.domains.podcast.schemas import SubscriptionCreate`

- [ ] **Step 4: Update import in `test_subscriptions_opml_service.py` line 7**

Change: `from app.shared.schemas import SubscriptionCreate`
To: `from app.domains.podcast.schemas import SubscriptionCreate`

- [ ] **Step 5: Rewrite `backend/app/shared/schemas.py` — keep only BaseSchema, TimestampedSchema, PaginatedResponse**

```python
"""Shared Pydantic schemas."""

from datetime import datetime
from typing import Any

from pydantic import BaseModel, ConfigDict


class BaseSchema(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class TimestampedSchema(BaseSchema):
    created_at: datetime
    updated_at: datetime | None = None


class PaginatedResponse(BaseSchema):
    items: list[Any]
    total: int
    page: int
    size: int
    pages: int

    @classmethod
    def create(
        cls,
        items: list[Any],
        total: int,
        page: int,
        size: int,
    ) -> "PaginatedResponse":
        pages = (total + size - 1) // size
        return cls(
            items=items,
            total=total,
            page=page,
            size=size,
            pages=pages,
        )
```

- [ ] **Step 6: Rewrite `backend/app/shared/__init__.py`**

```python
"""Shared components used across domains."""

from .schemas import BaseSchema, PaginatedResponse, TimestampedSchema


__all__ = [
    "BaseSchema",
    "PaginatedResponse",
    "TimestampedSchema",
]
```

- [ ] **Step 7: Verify**

```bash
cd backend && uv run pytest
```

- [ ] **Step 8: Commit**

```bash
git add -A && git commit -m "refactor(backend): delete dead schemas, move Subscription schemas to podcast domain"
```

---

### Task 1.3: Clean `shared/repository_helpers.py`

**Files:**
- Modify: `backend/app/shared/repository_helpers.py`

- [ ] **Step 1: Delete 3 dead functions and remove unused import**

Remove: `get_by_field_insensitive` (lines 92-112), `exists_by_id` (lines 115-136), `build_paginated_response` (lines 175-199). Also remove the unused `from app.shared.schemas import PaginatedResponse` import (line 12).

```python
"""Shared repository helper functions."""

from typing import Any, TypeVar

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession


T = TypeVar("T")


async def resolve_window_total(
    db: AsyncSession,
    rows: list[Any],
    *,
    total_index: int,
    fallback_count_query: Any,
) -> int:
    if rows:
        return int(rows[0][total_index] or 0)
    return int(await db.scalar(fallback_count_query) or 0)


async def get_by_id(
    db: AsyncSession,
    model: type[T],
    id: int,
    *,
    id_column: str = "id",
) -> T | None:
    column = getattr(model, id_column)
    stmt = select(model).where(column == id)
    result = await db.execute(stmt)
    return result.scalar_one_or_none()


async def get_by_field(
    db: AsyncSession,
    model: type[T],
    field_name: str,
    value: Any,
) -> T | None:
    column = getattr(model, field_name)
    stmt = select(model).where(column == value)
    result = await db.execute(stmt)
    return result.scalar_one_or_none()


async def count_records(
    db: AsyncSession,
    model: type[Any],
    *,
    filters: list[Any] | None = None,
) -> int:
    stmt = select(func.count()).select_from(model)
    if filters:
        stmt = stmt.where(*filters)
    result = await db.scalar(stmt)
    return result or 0


def calculate_offset(page: int, size: int) -> int:
    return (page - 1) * size
```

- [ ] **Step 2: Verify**

```bash
cd backend && uv run pytest
```

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "refactor(backend): delete dead repository helpers"
```

---

### Task 1.4: Delete `shared/retry_utils.py`

**Files:**
- Modify: `backend/app/core/utils.py` (add `import random` and `calculate_backoff`)
- Modify: `backend/app/domains/ai/services/text_generation_service.py` (line 30 import)
- Modify: `backend/app/domains/podcast/transcription/transcriber.py` (line 12 import)
- Delete: `backend/app/shared/retry_utils.py`

- [ ] **Step 1: Add `calculate_backoff` to `backend/app/core/utils.py`**

Add `import random` to imports. Append after `filter_thinking_content`:

```python
def calculate_backoff(attempt: int, base_delay: float = 1.0) -> float:
    """Calculate backoff time with jitter for retry attempts."""
    backoff = base_delay * (2**attempt)
    jitter = random.uniform(0, 0.5 * backoff)
    return backoff + jitter
```

- [ ] **Step 2: Update imports (2 files)**

`text_generation_service.py` line 30: `from app.shared.retry_utils import calculate_backoff` → `from app.core.utils import calculate_backoff`

`transcriber.py` line 12: `from app.shared.retry_utils import calculate_backoff` → `from app.core.utils import calculate_backoff`

- [ ] **Step 3: Delete file**

```bash
rm backend/app/shared/retry_utils.py
```

- [ ] **Step 4: Verify**

```bash
cd backend && uv run pytest
```

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "refactor(backend): move calculate_backoff to core/utils, delete retry_utils.py"
```

---

### Task 1.5: Clean `core/datetime_utils.py`

**Files:**
- Modify: `backend/app/core/datetime_utils.py`

- [ ] **Step 1: Delete 8 dead functions, keep 3 live + 4 display (display moves in Phase 3)**

Delete: `ensure_timezone_aware`, `to_isoformat`, `parse_isoformat`, `format_datetime`, `get_current_timestamp`, `calculate_age`, `is_expired`, `bulk_remove_timezone`.

Keep: `remove_timezone`, `sanitize_published_date`, `ensure_timezone_aware_fetch_time`, `to_local_timezone`, `format_uptime`, `format_bytes`, `format_number`.

The file becomes (lines to keep reorganized):

```python
"""Date and time utility functions.

This module provides utility functions for handling datetime operations,
including timezone management, formatting, and conversions.
日期时间工具函数
"""

import logging
from datetime import UTC, datetime, timezone


logger = logging.getLogger(__name__)


def remove_timezone(dt: datetime | None) -> datetime | None:
    """Remove timezone information from a datetime object."""
    if dt is None:
        return None
    if dt.tzinfo is not None:
        return dt.replace(tzinfo=None)
    return dt


def sanitize_published_date(published_at: datetime | None) -> datetime | None:
    """Sanitize podcast episode published date by removing timezone."""
    return remove_timezone(published_at)


def ensure_timezone_aware_fetch_time(fetch_time: datetime | None) -> datetime | None:
    """Ensure fetch time is timezone-aware in UTC."""
    if fetch_time is None:
        return None
    if fetch_time.tzinfo is not None:
        return fetch_time.astimezone(UTC)
    return fetch_time.replace(tzinfo=UTC)


# Display utilities — will be moved to core/display_utils.py in Phase 3

def to_local_timezone(
    dt: datetime | None,
    format_str: str = "%Y-%m-%d %H:%M:%S",
    timezone: str = "Asia/Shanghai",
) -> str:
    """Convert UTC datetime to local timezone and format it."""
    if dt is None:
        return "-"
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=UTC)
    from zoneinfo import ZoneInfo

    local_tz = ZoneInfo(timezone)
    local_dt = dt.astimezone(local_tz)
    return local_dt.strftime(format_str)


def format_uptime(seconds: float | None) -> str:
    """Format uptime seconds to human readable string."""
    if seconds is None:
        return "-"
    days = int(seconds // 86400)
    hours = int((seconds % 86400) // 3600)
    minutes = int((seconds % 3600) // 60)
    if days > 0:
        return f"{days}天 {hours}小时"
    if hours > 0:
        return f"{hours}小时 {minutes}分钟"
    return f"{minutes}分钟"


def format_bytes(bytes_value: int | None) -> str:
    """Format bytes to human readable string."""
    if bytes_value is None:
        return "-"
    if bytes_value >= 1073741824:
        return f"{bytes_value / 1073741824:.1f} GB"
    if bytes_value >= 1048576:
        return f"{bytes_value / 1048576:.1f} MB"
    if bytes_value >= 1024:
        return f"{bytes_value / 1024:.1f} KB"
    return f"{bytes_value} B"


def format_number(value: int | None) -> str:
    """Format number with thousand separators."""
    if value is None:
        return "-"
    return f"{value:,}"
```

- [ ] **Step 2: Verify**

```bash
cd backend && uv run pytest
```

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "refactor(backend): delete 8 dead functions from datetime_utils"
```

---

### Task 1.6: Clean `core/http_client.py`

**Files:**
- Modify: `backend/app/core/http_client.py`

- [ ] **Step 1: Delete `http_request_with_retry` function (lines 70-155)**

Remove the entire function. The file becomes session management only:

```python
"""Shared aiohttp client session management."""

from __future__ import annotations

import asyncio
import threading

import aiohttp


_shared_http_session: aiohttp.ClientSession | None = None
_shared_http_session_loop_token: int | None = None
_http_session_lock = threading.Lock()


def _current_loop_token() -> int | None:
    try:
        return id(asyncio.get_running_loop())
    except RuntimeError:
        return None


async def get_shared_http_session() -> aiohttp.ClientSession:
    """Return a process-level shared aiohttp session for outbound HTTP calls."""
    global _shared_http_session, _shared_http_session_loop_token

    current_loop_token = _current_loop_token()

    with _http_session_lock:
        if (
            _shared_http_session is not None
            and _shared_http_session_loop_token == current_loop_token
            and not _shared_http_session.closed
        ):
            return _shared_http_session

        if _shared_http_session is not None and not _shared_http_session.closed:
            await _shared_http_session.close()

        timeout = aiohttp.ClientTimeout(
            total=120,
            connect=10,
            sock_read=30,
        )
        connector = aiohttp.TCPConnector(
            limit=100,
            limit_per_host=20,
            enable_cleanup_closed=True,
        )
        _shared_http_session = aiohttp.ClientSession(
            connector=connector,
            timeout=timeout,
        )
        _shared_http_session_loop_token = current_loop_token
        return _shared_http_session


async def close_shared_http_session() -> None:
    """Close and clear the shared aiohttp session."""
    global _shared_http_session, _shared_http_session_loop_token

    with _http_session_lock:
        if _shared_http_session is not None and not _shared_http_session.closed:
            await _shared_http_session.close()
        _shared_http_session = None
        _shared_http_session_loop_token = None
```

- [ ] **Step 2: Verify**

```bash
cd backend && uv run pytest
```

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "refactor(backend): delete unused http_request_with_retry from http_client"
```

---

### Task 1.7: Clean `core/json_encoder.py`

**Files:**
- Modify: `backend/app/core/json_encoder.py`

- [ ] **Step 1: Delete `CustomJSONEncoder` class and remove unused `from json import JSONEncoder`**

```python
"""Custom JSON response using orjson for datetime-aware serialization."""

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

    media_type = "application/json; charset=utf-8"

    def render(self, content: Any) -> bytes:
        return orjson.dumps(content, default=_default_serializer)
```

- [ ] **Step 2: Verify**

```bash
cd backend && uv run pytest
```

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "refactor(backend): delete unused CustomJSONEncoder from json_encoder"
```

---

## Phase 2: Structural Duplication & Coupling (3 tasks)

### Task 2.1: Unify error handling decorators

**Files:**
- Modify: `backend/app/http/decorators.py`
- Modify: `backend/app/admin/routes/settings.py`

- [ ] **Step 1: Rewrite `decorators.py` — single `handle_errors` with backward-compatible aliases**

```python
"""Standardized error handling decorator for routes."""

import asyncio
import logging
from collections.abc import Callable
from functools import wraps
from typing import TypeVar

from fastapi import HTTPException, status

logger = logging.getLogger(__name__)

F = TypeVar("F", bound=Callable)


def handle_errors(
    operation: str,
    *,
    error_message: str | None = None,
) -> Callable[[F], F]:
    """Decorator for consistent error handling in API and admin routes."""

    def decorator(func: F) -> F:
        @wraps(func)
        async def async_wrapper(*args, **kwargs):
            try:
                return await func(*args, **kwargs)
            except HTTPException:
                raise
            except Exception as exc:
                status_code = getattr(exc, "status_code", None)
                detail = getattr(exc, "message", None) or error_message or f"Failed to {operation}"
                if status_code is None:
                    status_code = status.HTTP_500_INTERNAL_SERVER_ERROR
                    detail = error_message or f"Failed to {operation}"

                if status_code >= 500:
                    logger.error("%s error: %s", operation, exc)
                else:
                    logger.warning("%s error: %s", operation, exc)

                raise HTTPException(status_code=status_code, detail=detail) from exc

        @wraps(func)
        def sync_wrapper(*args, **kwargs):
            try:
                return func(*args, **kwargs)
            except HTTPException:
                raise
            except Exception as exc:
                status_code = getattr(exc, "status_code", None)
                detail = getattr(exc, "message", None) or error_message or f"Failed to {operation}"
                if status_code is None:
                    status_code = status.HTTP_500_INTERNAL_SERVER_ERROR
                    detail = error_message or f"Failed to {operation}"

                if status_code >= 500:
                    logger.error("%s error: %s", operation, exc)
                else:
                    logger.warning("%s error: %s", operation, exc)

                raise HTTPException(status_code=status_code, detail=detail) from exc

        if asyncio.iscoroutinefunction(func):
            return async_wrapper  # type: ignore
        return sync_wrapper  # type: ignore

    return decorator


# Backward-compatible aliases
handle_api_errors = handle_errors
handle_admin_errors = handle_errors
```

- [ ] **Step 2: Update `admin/routes/settings.py` — change import and all 9 decorator usages**

Line 10: `from app.http.decorators import handle_admin_errors` → `from app.http.decorators import handle_errors`

Replace all `@handle_admin_errors(` with `@handle_errors(` (9 occurrences on lines 18, 34, 44, 64, 75, 97, 107, 117, 135).

- [ ] **Step 3: Verify**

```bash
cd backend && uv run pytest
```

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "refactor(backend): unify handle_api_errors and handle_admin_errors into handle_errors"
```

---

### Task 2.2: Move `shared/settings_helpers.py` to `admin/settings_helpers.py`

**Files:**
- Create: `backend/app/admin/settings_helpers.py`
- Modify: `backend/app/admin/services/subscriptions_service.py` (line 25 import)
- Modify: `backend/app/admin/services/settings_service.py` (line 14 import)
- Delete: `backend/app/shared/settings_helpers.py`

- [ ] **Step 1: Create `backend/app/admin/settings_helpers.py`**

```python
"""Helpers for system settings persistence.

Moved from shared/ to admin/ — this module depends on app.admin.models
and is only used by admin services.
"""

from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.admin.models import SystemSettings


async def persist_setting(
    db: AsyncSession,
    key: str,
    value: dict[str, Any],
    *,
    description: str | None = None,
    category: str | None = None,
) -> SystemSettings:
    result = await db.execute(select(SystemSettings).where(SystemSettings.key == key))
    setting = result.scalar_one_or_none()

    if setting:
        setting.value = value
    else:
        setting = SystemSettings(
            key=key,
            value=value,
            description=description,
            category=category,
        )
        db.add(setting)

    return setting
```

- [ ] **Step 2: Update imports (2 files)**

`subscriptions_service.py` line 25: `from app.shared.settings_helpers import persist_setting` → `from app.admin.settings_helpers import persist_setting`

`settings_service.py` line 14: `from app.shared.settings_helpers import persist_setting` → `from app.admin.settings_helpers import persist_setting`

- [ ] **Step 3: Delete file**

```bash
rm backend/app/shared/settings_helpers.py
```

- [ ] **Step 4: Verify**

```bash
cd backend && uv run pytest
```

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "refactor(backend): move settings_helpers from shared/ to admin/ to fix dependency inversion"
```

---

### Task 2.3: Unify auth key extraction

**Files:**
- Modify: `backend/app/admin/auth.py`

- [ ] **Step 1: Rewrite `backend/app/admin/auth.py` to import `_extract_api_key` from core**

```python
"""Admin authentication — API key based.

Checks X-API-Key header, Authorization header, or admin_session cookie
against settings.API_KEY.
"""

import logging

from fastapi import Cookie, HTTPException, Request, status

from app.core.auth import _extract_api_key
from app.core.config import get_settings


logger = logging.getLogger(__name__)


class AdminAuthRequired:
    """Dependency to require admin authentication via API key."""

    async def __call__(
        self,
        request: Request,
        admin_session: str | None = Cookie(None),
    ) -> int:
        settings = get_settings()

        api_key = _extract_api_key(request) or admin_session

        if not settings.API_KEY:
            return 1

        if api_key is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Not authenticated",
            )

        if api_key != settings.API_KEY:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid API key",
            )

        return 1


admin_required = AdminAuthRequired()
```

- [ ] **Step 2: Verify**

```bash
cd backend && uv run pytest
```

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "refactor(backend): reuse _extract_api_key in admin auth to eliminate duplication"
```

---

## Phase 3: Miscellaneous Cleanup (2 tasks)

### Task 3.1: Extract display utilities

**Files:**
- Create: `backend/app/core/display_utils.py`
- Modify: `backend/app/core/datetime_utils.py` (remove 4 display functions)
- Modify: `backend/app/admin/routes/_shared.py` (import from display_utils)
- Modify: `backend/app/admin/storage_service.py` (use shared format_bytes, delete `_format_bytes` method)

- [ ] **Step 1: Create `backend/app/core/display_utils.py`**

```python
"""Display formatting utilities for admin templates."""

from datetime import UTC, datetime


def to_local_timezone(
    dt: datetime | None,
    format_str: str = "%Y-%m-%d %H:%M:%S",
    timezone: str = "Asia/Shanghai",
) -> str:
    """Convert UTC datetime to local timezone and format it."""
    if dt is None:
        return "-"
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=UTC)
    from zoneinfo import ZoneInfo

    local_tz = ZoneInfo(timezone)
    local_dt = dt.astimezone(local_tz)
    return local_dt.strftime(format_str)


def format_uptime(seconds: float | None) -> str:
    """Format uptime seconds to human readable string."""
    if seconds is None:
        return "-"
    days = int(seconds // 86400)
    hours = int((seconds % 86400) // 3600)
    minutes = int((seconds % 3600) // 60)
    if days > 0:
        return f"{days}天 {hours}小时"
    if hours > 0:
        return f"{hours}小时 {minutes}分钟"
    return f"{minutes}分钟"


def format_bytes(bytes_value: int | None) -> str:
    """Format bytes to human readable string (supports up to PB)."""
    if bytes_value is None:
        return "-"
    for unit in ["B", "KB", "MB", "GB", "TB"]:
        if bytes_value < 1024.0:
            return f"{bytes_value:.1f} {unit}"
        bytes_value /= 1024.0
    return f"{bytes_value:.1f} PB"


def format_number(value: int | None) -> str:
    """Format number with thousand separators."""
    if value is None:
        return "-"
    return f"{value:,}"
```

- [ ] **Step 2: Remove 4 display functions from `datetime_utils.py`**

Delete `to_local_timezone`, `format_uptime`, `format_bytes`, `format_number` (the last 4 functions). The file ends after `ensure_timezone_aware_fetch_time`.

- [ ] **Step 3: Update import in `admin/routes/_shared.py`**

Change: `from app.core.datetime_utils import (format_bytes, format_number, format_uptime, to_local_timezone)`
To: `from app.core.display_utils import (format_bytes, format_number, format_uptime, to_local_timezone)`

- [ ] **Step 4: Update `admin/storage_service.py` — add import, delete `_format_bytes`, replace `self._format_bytes(` → `format_bytes(`**

Add import: `from app.core.display_utils import format_bytes`

Delete the `_format_bytes` method (lines 99-113). Replace all 14 occurrences of `self._format_bytes(` with `format_bytes(`.

- [ ] **Step 5: Verify**

```bash
cd backend && uv run pytest
```

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "refactor(backend): extract display utilities from datetime_utils, consolidate format_bytes"
```

---

### Task 3.2: Remove orphaned config fields

**Files:**
- Modify: `backend/app/core/config.py`
- Modify: `backend/alembic/env.py`
- Modify: `backend/.env.example`
- Modify: `backend/.env.production.template`

- [ ] **Step 1: Remove 3 orphaned fields from `backend/app/core/config.py`**

Delete from the `Settings` class:
```python
    # Frontend URL
    FRONTEND_URL: str = "http://localhost:3000"
```

```python
    # File storage
    MAX_FILE_SIZE: int = 10 * 1024 * 1024
    UPLOAD_DIR: str = "uploads"
```

These fields are not imported by any `app/` source file.

- [ ] **Step 2: Remove matching fields from `backend/alembic/env.py` MockConfig**

Delete: `FRONTEND_URL`, `MAX_FILE_SIZE`, `UPLOAD_DIR` fields from the MockConfig class.

- [ ] **Step 3: Remove from `backend/.env.example`**

Delete the `MAX_FILE_SIZE` and `UPLOAD_DIR` lines, and the section header comment if it becomes orphaned.

- [ ] **Step 4: Remove from `backend/.env.production.template`**

Delete the `MAX_FILE_SIZE` and `UPLOAD_DIR` lines, and the "File storage" comment.

- [ ] **Step 5: Verify**

```bash
cd backend && uv run pytest
```

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "refactor(backend): remove orphaned config fields FRONTEND_URL, MAX_FILE_SIZE, UPLOAD_DIR"
```

---

## Final Verification

After all 12 tasks complete:

```bash
cd backend && uv run ruff check . && uv run pytest -q
```

Both must pass with zero errors.
