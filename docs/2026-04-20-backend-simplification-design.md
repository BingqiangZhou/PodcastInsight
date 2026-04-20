# Backend Architecture Simplification Design

**Date:** 2026-04-20
**Context:** Stella is a single-user personal podcast assistant. The backend was built with enterprise-grade patterns (CQRS, RSA encryption, CSRF, 2FA, distributed locks, anti-stampede caching) that are disproportionate for its actual usage.

---

## Executive Summary

The backend contains ~15,000 lines across 180+ Python files. Approximately 7,500 lines (~50%) can be removed or simplified by stripping enterprise abstractions that serve no purpose in a single-user personal application. The core business logic (podcast management, transcription, AI summaries, feed sync) is preserved — the cuts target security theater, multi-user patterns, and over-abstracted infrastructure.

**Guiding principle:** Remove indirection that exists to scale or protect against threats that don't apply to a personal app. Keep infrastructure that solves real problems (async tasks, RSS parsing safety, API key encryption).

---

## Category 1: Delete Entirely (~1,500 lines)

These modules serve no purpose in a single-user context.

### 1.1 Admin Two-Factor Authentication

**Files:**
- `backend/app/admin/twofa.py` (~89 lines)
- `backend/app/admin/templates/2fa_setup.html`
- `backend/app/admin/templates/2fa_verify.html`
- Related route handlers in `admin/router.py` or `admin/routes/setup_auth.py`

**What it does:** Full TOTP 2FA with QR code provisioning via `pyotp` + `qrcode`.

**Why delete:** You are the only user. Password authentication is sufficient. If the admin panel is exposed to the internet, a VPN or HTTPS basic auth would be more practical than TOTP.

**Dependency cleanup:** Remove `pyotp` and `qrcode[pil]` from `pyproject.toml`.

### 1.2 Admin CSRF Protection

**File:** `backend/app/admin/csrf.py` (~112 lines)

**What it does:** Double-submit cookie CSRF protection with `itsdangerous` signed tokens.

**Why delete:** CSRF is a threat when other websites can trick a logged-in user's browser into submitting forms. For a single-user personal app, this threat model does not apply. Removing it eliminates expired token errors and "please refresh the page" friction.

**Dependency cleanup:** Consider removing `itsdangerous` if no other code uses it (check admin auth first — `admin/auth.py` uses `URLSafeTimedSerializer` from `itsdangerous`, so it stays).

### 1.3 Admin Audit Logging

**Files:**
- `backend/app/admin/audit.py` (~86 lines)
- `AdminAuditLog` model in `backend/app/admin/models.py`
- All `log_admin_action()` call sites across admin routes and services
- `backend/app/admin/routes/users_audit.py` (audit log viewer route)
- `backend/app/admin/services/users_audit_service.py`
- `backend/app/admin/templates/audit_logs.html`

**What it does:** Logs every admin action (user_id, action, resource, IP, user agent) to a database table.

**Why delete:** Only one user exists. Auditing your own actions has no value. The audit table grows indefinitely. Also contains a bug: the comment says "Don't fail the main operation if audit logging fails" but the code re-raises the exception.

**Migration note:** Add an Alembic migration to drop the `admin_audit_log` table.

### 1.4 Admin User Management Routes

**Files:**
- `backend/app/admin/routes/users_audit.py` (~145 lines, partially overlaps with audit cleanup)
- `backend/app/admin/services/users_audit_service.py`

**What it does:** User list with pagination, activate/deactivate users, reset user passwords.

**Why delete:** There is exactly one user. "Toggle active" on yourself means locking yourself out. "Reset password" for yourself is circular. Password reset should be a CLI command or env-var flow, not an admin panel feature.

**Note:** The audit log viewer route in this file is covered by 1.3 above.

### 1.5 LLM Privacy Sanitizer

**File:** `backend/app/domains/ai/llm_privacy.py` (~334 lines)

**What it does:** PII detection and sanitization for content sent to external LLMs. Includes `PrivacyAuditEntry` audit trail, batch log stats aggregator, `ContentSanitizer` with three modes (strict/standard/none), regex patterns for 8 PII types (US-centric), GDPR consent tracking.

**Why delete:** You are sanitizing your own podcast transcripts before sending them to an LLM you chose to use. GDPR audit trails and consent tracking for yourself make no sense. The US-centric regex (SSN, US phone format) is oddly specific for this use case.

**Config cleanup:** Remove `LLM_CONTENT_SANITIZE_MODE` from `config.py`. Remove any `ContentSanitizer` imports from AI services.

### 1.6 Admin Monitoring Dashboard

**Files:**
- `backend/app/admin/monitoring.py` (~143 lines)
- `backend/app/admin/routes/monitoring.py`
- `backend/app/admin/templates/monitoring.html`

**What it does:** Full server monitoring via `psutil`: per-core CPU, load averages, context switches, interrupts, memory, swap, disk partitions + I/O, per-interface network stats with error/drop counters.

**Why delete:** This is `htop`/`docker stats` territory. A personal app does not need per-core CPU breakdowns, context switch counts, or network interface error counters. Use system tools instead.

**Dependency cleanup:** Remove `psutil` from `pyproject.toml`.

### 1.7 TokenOptimizer Class

**File:** Inside `backend/app/core/security/jwt.py` (~30 lines)

**What it does:** Static-method wrapper around a dict literal. Docstring claims "optimized for 500+ req/s throughput." The "optimization" is using `time.time()` instead of `datetime.now()`.

**Why delete:** Pure theater. Inline the timestamp logic directly into `create_access_token`.

### 1.8 EC256 Optimization Stub

**File:** Inside `backend/app/core/security/encryption.py` (~17 lines at the bottom)

**What it does:** Commented-out `enable_ec256_optimized()` stub for "future scaling."

**Why delete:** Will never be used. Dead code.

---

## Category 2: Significantly Simplify (~4,000 lines reducible)

### 2.1 Encryption System

**File:** `backend/app/core/security/encryption.py` (456 lines → ~60 lines)

**Current:** Three encryption subsystems:
1. Fernet symmetric — API key storage (justified)
2. AES-256-GCM — API key export/import with PBKDF2 + password complexity rules (12+ chars, 3 of 4 character classes)
3. RSA-2048 — Frontend-to-backend API key transmission with encrypted-at-rest PEM files

**Simplified:**
- Keep Fernet for API key storage encryption
- If API key export is needed, simplify to Fernet-encrypted file (no PBKDF2, no 12-char password rules)
- Remove RSA entirely — HTTPS already protects data in transit, and you control both frontend and backend
- Remove `data/.rsa_keys` directory handling
- Remove key migration logic

### 2.2 Redis AppCache

**Files:**
- `backend/app/core/redis/__init__.py` (598 lines)
- `backend/app/core/redis/cache.py` (729 lines)

**Total: 1,327 lines → ~200 lines**

**Current:** God Object with 50+ public methods, 4 Mixin classes, metaprogramming delegation (`_apply_delegates`), anti-stampede locks with exponential backoff, stale-while-revalidate with background task spawning, sorted set operations, 12 domain-specific cache key patterns each with get/set/invalidate triples.

**Simplified:**
- Thin async wrapper around `redis.asyncio` with 5-10 helper methods:
  - `get(key)` / `set(key, value, ttl)` / `delete(key)`
  - `get_json(key)` / `set_json(key, value, ttl)`
  - `acquire_lock(key, timeout)` / `release_lock(key)`
- Remove anti-stampede protection (single user = no concurrent request bursts)
- Remove stale-while-revalidate (unnecessary complexity)
- Replace 12 domain-specific get/set/invalidate triples with namespaced keys: `cache.set("podcast:episodes:123", data, ttl)`
- Remove metaprogramming delegation — write methods directly
- Remove sorted set operations unless actively used (verify with grep)
- Remove null-value penetration prevention (single user won't cause cache penetration)

### 2.3 JWT Token Blacklist

**File:** `backend/app/core/security/token_blacklist.py` (141 lines → delete or ~20 lines)

**Current:** Redis-backed revocation with SSCAN pagination for bulk revocation, per-user JTI tracking sets, pipeline batching.

**Options:**
- **Option A (recommended):** Delete entirely. Use short token lifetimes (e.g., 15-minute access token) and a single `password_changed_at` column on the User model. On token verification, check `issued_at > password_changed_at`. This covers logout and password-change invalidation without Redis.
- **Option B:** Keep a simplified version — just `revoke_token(jti)` and `is_token_revoked(jti)` with TTL. Remove SSCAN, user tracking sets, and bulk revocation.

### 2.4 Response Assemblers

**File:** `backend/app/domains/podcast/routes/response_assemblers.py` (403 lines → delete)

**Current:** 25 `build_*` functions, most of which are `return SomeSchema(**payload)`. Import block alone is 47 lines.

**Simplified:** Construct response schemas directly in route handlers. For non-trivial assembly logic, keep the logic in the route or service — do not have a separate "assembler" file.

**Also check:** `backend/app/domains/subscription/api/response_assemblers.py` — apply the same simplification.

### 2.5 Admin Subscription Service CQRS Split

**Files:**
- `backend/app/admin/services/subscriptions_command_service.py` (576 lines)
- `backend/app/admin/services/subscriptions_query_service.py` (195 lines)

**Total: 771 lines → ~400-500 lines in a single service**

**Current:** Command/Query Responsibility Segregation (CQRS) — writes and reads are in separate services.

**Simplified:** Merge into a single `AdminSubscriptionsService`. CQRS is a pattern for systems with high read/write asymmetry at scale. A personal app has no such asymmetry. The actual operations (test feeds, batch delete, OPML) are worth keeping; the architectural wrapper is not.

### 2.6 AI Key Resolver

**File:** `backend/app/domains/podcast/ai_key_resolver.py` (121 lines → ~15 lines)

**Current:** Multi-level fallback chain (system key → primary model key → alternative model keys), encryption/decryption, placeholder key validation set, provider prefix validation.

**Simplified:** Direct key lookup from the AI model config. For a personal app with 1-2 API keys, the fallback chain and validation set are overkill.

---

## Category 3: Lightweight Adjustments (~2,000 lines reducible)

### 3.1 Admin Auth

**File:** `backend/app/admin/auth.py`

**Changes:**
- Remove IP binding — switching WiFi networks will invalidate sessions, causing frustration for no security gain
- Extend session timeout from 30 minutes to a more practical duration (e.g., 7 days)
- Simplify the dual-dependency pattern (`admin_required` vs `admin_required_no_2fa`) once 2FA is removed

### 3.2 Configuration

**File:** `backend/app/core/config.py` (313 lines, ~65 fields → ~30 fields)

**Fields to remove:**
- SMTP config (8 fields): `SMTP_SERVER`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_USE_TLS`, `FROM_EMAIL`, `FROM_NAME`, `EMAIL_RESET_TOKEN_EXPIRE_HOURS`
- Admin 2FA: `ADMIN_2FA_ENABLED`
- Task orchestration: `TASK_ORCHESTRATION_USER_BATCH_SIZE`
- Privacy: `LLM_CONTENT_SANITIZE_MODE`
- ETag: `ETAG_ENABLED`, `ETAG_DEFAULT_TTL` (evaluate if frontend uses these)
- Production validation: `validate_production_config()`, `_WEAK_PASSWORDS` frozenset
- Celery worker tuning: `CELERY_WORKER_PREFETCH_MULTIPLIER`, `CELERY_WORKER_MAX_TASKS_PER_CHILD`
- DB pool tuning: `DATABASE_MAX_OVERFLOW`, `DATABASE_POOL_TIMEOUT` (keep `DATABASE_POOL_SIZE` but reduce default)

**Fields to keep:** `SECRET_KEY`, `DATABASE_URL`, `REDIS_URL`, `CELERY_BROKER_URL`, basic JWT config, API-related config, path config.

### 3.3 Shared Schemas

**File:** `backend/app/shared/schemas.py` (271 lines, 30 schemas)

**Schemas to remove:**
- `ForgotPasswordRequest`, `ResetPasswordRequest`, `PasswordResetResponse` (no SMTP = no email-based password reset)
- Simplify User schema chain: `UserBase` + `UserCreate` + `UserResponse` instead of 5 separate schemas

### 3.4 Podcast Service Layer

**Files:** `backend/app/domains/podcast/services/` (16 files, 6,751 lines)

**Targeted simplifications:**
- `task_orchestration_service.py` (865 lines): Remove `USER_BATCH_SIZE=500` multi-user batching. Single user = direct processing.
- Transcription services (3 files, 1,459 lines): Consider merging `transcription_workflow_service.py`, `transcription_runtime_service.py`, and `transcription_schedule_service.py` into fewer files if boundaries are thin.
- Remove any `user_id` parameter that always receives the same value.

### 3.5 Repository Layer

**Files:** `backend/app/domains/podcast/repositories/` (13 files)

**Changes:**
- Remove 7 re-export shim files (`stats_search.py`, `subscription_feed.py`, `episode_query.py`, `playback.py`, `queue.py`, `transcription.py`, `daily_report.py` — each 11-22 lines of re-exports). Import directly from the actual module.
- Simplify base repository class if it adds abstraction without value.

### 3.6 Admin Auth Dependency on `itsdangerous`

**Note:** `admin/auth.py` uses `URLSafeTimedSerializer` from `itsdangerous` for session tokens. After CSRF removal, check if `itsdangerous` is still needed. If it's only used for admin sessions, consider simplifying to JWT-based admin sessions (reuse existing JWT infrastructure) or a simpler signed cookie approach.

---

## Category 4: Keep As-Is

These modules solve real problems regardless of user count.

| Module | Reason |
|--------|--------|
| Podcast security validation (`integration/security.py`) | XXE/SSRF/HTML sanitization protects against malicious RSS feeds — real threat |
| OPML import/export (`admin/subscriptions_opml_service.py`) | Core feature, well-implemented, handles real edge cases (malformed OPML) |
| Fernet encryption for API key storage | Necessary for protecting credentials at rest |
| Celery task framework | Async tasks (transcription, feed sync, summaries) are genuine requirements |
| Core JWT authentication (minus TokenOptimizer) | Authentication foundation |
| RequestLoggingMiddleware | Lightweight and useful for debugging |
| Feed parsing and sync | Core business logic |
| Database models and migrations | Keep all, remove only `AdminAuditLog` model |

---

## Dependency Cleanup Summary

After all changes, these packages can potentially be removed from `pyproject.toml`:

| Package | Currently Used By | After Cleanup |
|---------|-------------------|---------------|
| `pyotp` | `admin/twofa.py` | Remove |
| `qrcode[pil]` | `admin/twofa.py` | Remove |
| `psutil` | `admin/monitoring.py` | Remove |
| `itsdangerous` | `admin/csrf.py`, `admin/auth.py` | Keep if admin auth still uses it; otherwise remove |

---

## Estimated Impact

| Category | Lines Removable | Files Removable/Consolidatable |
|----------|-----------------|-------------------------------|
| Delete entirely | ~1,500 | ~10 files deleted |
| Significantly simplify | ~4,000 | ~5 files consolidated/rewritten |
| Lightweight adjustments | ~2,000 | ~10 files modified |
| **Total** | **~7,500 (~50% of backend)** | **~25 files affected** |

**Risk level:** Low. Most changes remove code rather than modify it. Core business logic is untouched. The primary risk is in the Redis cache refactoring (Category 2.2), which has many call sites — this should be done incrementally with tests.

---

## Recommended Execution Order

1. **Delete standalone modules first** (Category 1) — lowest risk, immediate payoff
2. **Simplify encryption and JWT** (Category 2.1, 2.3) — security-related, test carefully
3. **Refactor Redis cache** (Category 2.2) — highest impact, most call sites, do incrementally
4. **Remove response assemblers and CQRS** (Category 2.4, 2.5) — structural cleanup
5. **Config and schema cleanup** (Category 3.2, 3.3) — trailing cleanup
6. **Service layer thinning** (Category 3.4, 3.5) — optional, lower priority
