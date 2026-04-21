# Backend Round 3 Simplification Design

**Date:** 2026-04-21
**Context:** Third round of simplification for Stella's backend. Rounds 1-2 removed ~5,700 lines of enterprise patterns (2FA, CSRF, audit logging, RSA encryption, token blacklist, CQRS). This round targets dead code, structural coupling, and duplication left behind.

**Guiding principle:** Clean up structural debt — dead code, inverted dependencies, duplicated logic — rather than removing features. The admin panel stays as-is.

---

## 1. Dead Code Elimination

### 1.1 Delete `core/interfaces/` abstraction

**Files:** `core/interfaces/settings_provider.py`, `core/interfaces/settings_provider_impl.py`, `core/interfaces/__init__.py`
**Total:** 73 lines across 3 files

The `SettingsProvider` Protocol is never used for type hints. Both consumers (`content_repository.py`, `podcast_repository.py`) import the concrete `DatabaseSettingsProvider` directly.

**Action:** Move `DatabaseSettingsProvider` to `admin/settings_provider.py` (it depends on `admin.models.SystemSettings`, so it belongs in admin/). Delete the entire `core/interfaces/` directory. Update imports in `content_repository.py` and `podcast_repository.py`.

### 1.2 Clean `shared/schemas.py`

**File:** `shared/schemas.py` (99 lines)

Dead schemas (defined and exported but never imported by any consumer):
- `PaginationParams` — never used
- `APIResponse` — never used
- `ErrorResponse` — never used
- `SubscriptionResponse` — never used

Misplaced schemas (used only by podcast and admin domains):
- `SubscriptionBase`, `SubscriptionCreate`, `SubscriptionUpdate`

**Action:** Delete the 4 dead schemas. Move `SubscriptionBase`, `SubscriptionCreate`, `SubscriptionUpdate` to `domains/podcast/schemas.py`. Update imports in `content_repository.py`, `subscriptions_opml_service.py`, and admin subscription services. Keep `BaseSchema`, `TimestampedSchema`, `PaginatedResponse` in `shared/`.

### 1.3 Clean `shared/repository_helpers.py`

**File:** `shared/repository_helpers.py` (200 lines)

Dead helpers (never called outside their definition):
- `get_by_field_insensitive` — never imported
- `exists_by_id` — never imported
- `build_paginated_response` — never imported

**Action:** Delete the 3 dead functions. Update `shared/__init__.py` exports.

### 1.4 Delete `shared/retry_utils.py`

**File:** `shared/retry_utils.py` (107 lines)

`with_retry` decorator is never applied anywhere. Only `calculate_backoff` (4-line function) is used, by `transcriber.py` and `text_generation_service.py`.

**Action:** Move `calculate_backoff` to `core/utils.py` (alongside the existing utility functions). Delete `retry_utils.py`. Update imports in `transcriber.py` and `text_generation_service.py`.

### 1.5 Clean `core/datetime_utils.py`

**File:** `core/datetime_utils.py` (308 lines)

Dead functions (never imported by any consumer):
- `to_isoformat`, `parse_isoformat`, `format_datetime` — never used
- `is_expired` — never used
- `bulk_remove_timezone` — never used
- `calculate_age` — only called by dead `is_expired`
- `get_current_timestamp` — only called by dead `calculate_age`
- `ensure_timezone_aware` — only called by dead `calculate_age`

Keep: `sanitize_published_date`, `remove_timezone` (used by sanitize), `ensure_timezone_aware_fetch_time`.

Display utilities misplaced in this file (not datetime-related):
- `to_local_timezone`, `format_uptime`, `format_bytes`, `format_number`

**Action:** Delete 9 dead functions. Move 4 display utilities to `core/display_utils.py` (see section 3.1). Final file: ~50 lines.

### 1.6 Clean `core/http_client.py`

**File:** `core/http_client.py` (155 lines)

`http_request_with_retry` (85 lines) is never called. The retry logic that actually gets used lives in `ai_client.py`.

**Action:** Delete `http_request_with_retry`. File becomes ~70 lines (session management only).

### 1.7 Clean `core/json_encoder.py`

**File:** `core/json_encoder.py` (52 lines)

`CustomJSONEncoder` is never imported outside its definition. Only `CustomJSONResponse` is used (by `main.py` and `core/exceptions.py`).

**Action:** Delete `CustomJSONEncoder` class. File becomes ~20 lines.

---

## 2. Structural Duplication & Coupling

### 2.1 Unify error handling decorators

**File:** `http/decorators.py` (147 lines)

`handle_api_errors` and `handle_admin_errors` share ~90% code. The only differences:
- Parameter name: `error_message` vs `error_detail`
- Fallback message: `error_message or f"Failed to {operation}"` vs `error_detail or f"Failed to {operation}"`

These are functionally identical.

**Action:** Merge into single `handle_errors(operation, *, error_message=None)` decorator. Update all route files that import either decorator. Estimated: 147 lines → ~60 lines.

### 2.2 Fix `shared/` → `admin` dependency inversion

**File:** `shared/settings_helpers.py` (46 lines)

`persist_setting()` imports `SystemSettings` from `app.admin.models`. This creates a lower-layer dependency on an upper-layer package (shared → admin).

`persist_setting` is only used by:
- `admin/services/subscriptions_service.py`
- `admin/services/settings_service.py`

**Action:** Move `persist_setting()` to `admin/settings_helpers.py`. Delete `shared/settings_helpers.py`. Update imports in the 2 admin services.

### 2.3 Unify auth key extraction

**Files:** `core/auth.py` (88 lines), `admin/auth.py` (61 lines)

Both contain nearly identical API key extraction logic:
- `core/auth.py`: `_extract_api_key(request)` — checks `Authorization: Bearer` and `X-API-Key` headers
- `admin/auth.py`: `AdminAuthRequired.__call__()` — duplicates the same header checks, adds cookie support

**Action:** Refactor `admin/auth.py` to call `_extract_api_key()` from `core/auth.py`, then fall back to cookie check. Eliminate the duplicated header-extraction code.

### 2.4 Move `DatabaseSettingsProvider` to `admin/`

(Already covered in 1.1, noting the placement rationale here.)

`DatabaseSettingsProvider` queries `admin.models.SystemSettings`, so placing it in `admin/` keeps the dependency direction correct (admin depends on admin, podcast depends on admin).

**Final location:** `admin/settings_provider.py`

**Import path change:** `from app.core.interfaces.settings_provider_impl import DatabaseSettingsProvider` → `from app.admin.settings_provider import DatabaseSettingsProvider`

---

## 3. Miscellaneous Cleanup

### 3.1 Extract display utilities

**Files affected:** `core/datetime_utils.py`, `admin/storage_service.py`

Four functions in `datetime_utils.py` are not datetime-related:
- `to_local_timezone`, `format_uptime`, `format_bytes`, `format_number`

All are used only by `admin/routes/_shared.py` (as Jinja2 template filters). Additionally, `format_bytes` is duplicated in `admin/storage_service.py` as `_format_bytes`.

**Action:** Create `core/display_utils.py` with these 4 functions. Update `admin/routes/_shared.py` to import from there. Delete `_format_bytes` from `storage_service.py` and use the shared function.

### 3.2 Audit `core/config.py` for orphaned fields

**File:** `core/config.py` (245 lines)

After rounds 1-2, some config fields may be orphaned. Verify and remove any that are no longer referenced by production code.

**Check:**
- SMTP fields (should have been removed in round 1)
- ETag fields (`ETAG_ENABLED`, `ETAG_DEFAULT_TTL`)
- `ADMIN_2FA_ENABLED` (should have been removed in round 1)
- `validate_production_config()` and `_WEAK_PASSWORDS` — verify usage
- Celery worker tuning fields — verify usage

**Action:** Grep for each field's usage. Delete orphaned fields. Run tests to confirm no breakage.

---

## Summary

| Category | Items | Estimated Lines Removed |
|----------|-------|------------------------|
| Dead code elimination | 7 items (1.1–1.7) | ~500 |
| Structural duplication & coupling | 4 items (2.1–2.4) | ~130 |
| Miscellaneous cleanup | 2 items (3.1–3.2) | ~100 |
| **Total** | **13 changes** | **~730 lines** |

**Files deleted:** `core/interfaces/` (3 files), `shared/retry_utils.py`, `shared/settings_helpers.py`
**Files created:** `admin/settings_provider.py`, `admin/settings_helpers.py`, `core/display_utils.py`
**Files significantly modified:** `http/decorators.py`, `core/datetime_utils.py`, `shared/schemas.py`, `core/http_client.py`, `core/json_encoder.py`, `admin/auth.py`, `admin/storage_service.py`

**Risk:** Low. All changes are deletions or relocations. No business logic changes. Tests must pass after each change.

**Execution order:**
1. Dead code deletion (1.1–1.7) — safe deletions first
2. Structural changes (2.1–2.4) — fix coupling and duplication
3. Misc cleanup (3.1–3.2) — final polish
4. Run full test suite and verify
