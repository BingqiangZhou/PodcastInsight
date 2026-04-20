# Backend Simplification — Implementation Plan

**Date:** 2026-04-20
**Design doc:** `docs/2026-04-20-backend-simplification-design.md`

## Execution Tracks

The work is organized into 5 parallel tracks. Tracks A-D can run simultaneously. Track E depends on A and B.

---

## Track A: Standalone Deletions (Lowest Risk)

**Agent:** `deleter`
**Estimated changes:** ~1,500 lines removed, ~10 files deleted

### A1: EC256 stub + TokenOptimizer (trivial warmup)

**Files to modify:**
- `backend/app/core/security/encryption.py` — delete `enable_ec256_optimized()` function (bottom ~17 lines)
- `backend/app/core/security/jwt.py` — delete `TokenOptimizer` class (~lines 20-47) and `token_optimizer` instance (~line 49), inline `build_standard_claims` logic into `create_access_token` and `create_refresh_token`
- `backend/app/core/security/__init__.py` — remove `token_optimizer` and `enable_ec256_optimized` from re-exports

**Test update:**
- `backend/alembic/env.py` — remove `enable_ec256_optimized` mock

### A2: Admin Monitoring

**Files to delete:**
- `backend/app/admin/monitoring.py`
- `backend/app/admin/routes/monitoring.py`
- `backend/app/admin/templates/monitoring.html`
- `backend/tests/admin/test_monitoring_service.py` (if exists)

**Files to modify:**
- `backend/app/admin/router.py` — remove monitoring router import and registration

**Dependency:** Remove `psutil` from `pyproject.toml`

### A3: LLM Privacy Sanitizer

**Files to delete:**
- `backend/app/domains/ai/llm_privacy.py`

**Files to modify:**
- `backend/app/domains/ai/__init__.py` — remove `ContentSanitizer` export
- `backend/app/domains/podcast/integration/secure_rss_parser.py` — remove `ContentSanitizer` import and `self.privacy` initialization
- `backend/app/core/config.py` — remove `LLM_CONTENT_SANITIZE_MODE` field
- `backend/alembic/env.py` — remove `LLM_CONTENT_SANITIZE_MODE` mock
- `backend/.env.example` and `backend/.env.production.template` — remove `LLM_CONTENT_SANITIZE_MODE`
- `backend/tests/podcast/test_e2e_simulation.py` — remove ContentSanitizer usage
- `backend/tests/test_podcast_api.py` — remove ContentSanitizer usage

### A4: Admin Audit Logging + User Management

**Order: Audit first, then user management (user management depends on audit removal)**

**Audit — Files to delete:**
- `backend/app/admin/audit.py`
- `backend/app/admin/templates/audit_logs.html`

**Audit — Files to modify (remove `log_admin_action` import and all call sites):**
- `backend/app/admin/services/apikeys_service.py` (~6 call sites)
- `backend/app/admin/services/subscriptions_command_service.py` (~8 call sites)
- `backend/app/admin/services/subscriptions_opml_service.py` (~2 call sites)
- `backend/app/admin/services/settings_service.py` (~5 call sites)
- `backend/app/admin/services/users_audit_service.py` (~2 call sites)
- `backend/app/admin/models.py` — remove `AdminAuditLog` class
- `backend/app/admin/tests/test_settings_service.py` — remove `log_admin_action` monkeypatches
- `backend/app/admin/tests/test_subscriptions_command_service.py` — remove monkeypatch
- `backend/app/admin/tests/test_subscriptions_opml_service.py` — remove monkeypatch

**User Management — Files to delete:**
- `backend/app/admin/routes/users_audit.py`
- `backend/app/admin/services/users_audit_service.py`
- `backend/app/admin/tests/test_users_audit_routes.py`
- `backend/app/admin/templates/users.html`

**User Management — Files to modify:**
- `backend/app/admin/router.py` — remove `users_audit_router`
- `backend/app/admin/dependencies.py` — remove `get_admin_users_audit_service`
- `backend/app/admin/services/__init__.py` — remove `AdminUsersAuditService` export

**Migration:** Alembic migration to drop `admin_audit_logs` table

### A5: Admin 2FA

**Note:** This is the most interconnected deletion. Touches auth, setup, settings, user model.

**Files to delete:**
- `backend/app/admin/twofa.py`
- `backend/app/admin/security_settings.py`
- `backend/app/admin/templates/2fa_setup.html`
- `backend/app/admin/templates/2fa_verify.html`

**Files to modify:**
- `backend/app/admin/routes/setup_auth.py` — remove 2FA route handlers, simplify login handler
- `backend/app/admin/services/setup_auth_service.py` — remove all 2FA methods
- `backend/app/admin/auth.py` — remove 2FA enforcement block, remove `require_2fa` param, remove `admin_required_no_2fa`
- `backend/app/admin/services/settings_service.py` — remove security settings methods
- `backend/app/admin/routes/settings.py` — remove security settings routes
- `backend/app/admin/exception_handlers.py` — remove 2FA template entries
- `backend/app/core/config.py` — remove `ADMIN_2FA_ENABLED` and its validator
- `backend/app/domains/user/models.py` — remove `totp_secret` and `is_2fa_enabled` columns
- `backend/app/domains/user/repositories/user_repository.py` — remove `enable_2fa` and `disable_2fa` methods

**Migration:** Alembic migration to drop `totp_secret` and `is_2fa_enabled` from `users` table

**Dependency:** Remove `pyotp` and `qrcode[pil]` from `pyproject.toml`

### A6: Admin CSRF

**Do AFTER A5 (2FA removal) — fewer templates to update**

**Files to delete:**
- `backend/app/admin/csrf.py`

**Files to modify:**
- `backend/app/admin/services/setup_auth_service.py` — remove CSRF imports, remove `csrf_token` from all form handlers
- `backend/app/admin/exception_handlers.py` — remove `csrf_exception_handler`
- `backend/app/bootstrap/http.py` — remove CSRF exception handler registration
- `backend/app/admin/routes/setup_auth.py` — remove `csrf_token: str = Form(...)` from all POST handlers
- All admin templates — remove `csrf_token` hidden fields (setup.html, login.html)

**Note:** Keep `itsdangerous` — still used by `admin/auth.py` for session tokens

### A7: Config field cleanup (trailing)

**Files to modify:**
- `backend/app/core/config.py` — remove `ETAG_ENABLED`, `ETAG_DEFAULT_TTL`, SMTP fields (7 fields: `SMTP_SERVER`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_USE_TLS`, `FROM_EMAIL`, `FROM_NAME`)
- `backend/alembic/env.py` — remove corresponding mocks
- `backend/.env.example` and `backend/.env.production.template` — remove these fields

**Keep:** `EMAIL_RESET_TOKEN_EXPIRE_HOURS` (actively used by `password.py`)

### A8: Shared schema cleanup

**Files to modify:**
- `backend/app/shared/schemas.py` — remove `UserInDB` and `UserLogin` if confirmed unused

---

## Track B: Security Simplification

**Agent:** `security`
**Estimated changes:** ~400 lines removed, 1 file deleted

### B1: Remove RSA encryption (from encryption.py)

**Current:** 456 lines with Fernet + AES-256-GCM + RSA-2048
**Target:** ~255 lines with Fernet + AES-256-GCM only

**Files to modify:**
- `backend/app/core/security/encryption.py` — delete RSA section (~lines 254-436): `_RSA_PRIVATE_KEY`, `_RSA_PUBLIC_KEY`, `_derive_rsa_key_password`, `get_or_generate_rsa_keys`, `get_rsa_public_key_pem`, `decrypt_rsa_data`. Remove `Path`, `NamedTemporaryFile` imports.
- `backend/app/core/security/__init__.py` — remove RSA function re-exports
- `backend/tests/core/test_security.py` — remove RSA test classes (~lines 514-773)
- `backend/alembic/env.py` — remove RSA mock attributes

**Post-deploy:** `data/.rsa_keys` directory can be deleted

### B2: Remove token blacklist

**Files to delete:**
- `backend/app/core/security/token_blacklist.py`
- `backend/tests/test_token_blacklist.py` (if exists)

**Files to modify:**
- `backend/app/core/security/jwt.py` — remove `register_user_token` calls from `create_access_token` and `create_refresh_token`, remove `is_token_revoked` check from `verify_token`. Keep `jti` claim for logging.
- `backend/app/domains/user/services/auth_service.py` — remove `revoke_token` and `revoke_all_user_tokens` calls from `logout_user` and `logout_all_sessions`. Session `is_active` check already handles revocation.
- `backend/alembic/env.py` — remove `_mock_token_blacklist`

**Safety:** The `UserSession.is_active` flag already provides session-level revocation. Access tokens remain valid for their short TTL (acceptable for single-user).

---

## Track C: Structural Cleanup

**Agent:** `structural`
**Estimated changes:** ~600 lines removed, 2 files consolidated

### C1: Response assemblers (podcast domain)

**File:** `backend/app/domains/podcast/routes/response_assemblers.py` (403 lines)

**Plan:**
- Inline 17 trivial `return Schema(**payload)` functions at their call sites in route files
- Keep ~5 non-trivial functions (those with real logic: `build_feed_response`, `build_episode_list_response`, `build_summary_response`, `build_playback_state_response`, `build_highlight_list_response`) in the file
- Update imports in 8 route files

**Route files to update:**
- `routes_episodes.py`, `routes_subscriptions.py`, `routes_reports.py`, `routes_stats.py`, `routes_queue.py`, `routes_transcriptions.py`, `routes_highlights.py`, `routes_conversations.py`

**Subscription assemblers:** `backend/app/domains/subscription/api/response_assemblers.py` (80 lines) — keep as-is, has real serialization logic.

### C2: Admin subscription CQRS merge

**Current:** 3 files (command 576 + query 195 + facade 59 = 830 lines)
**Target:** 1 file (~500-600 lines)

**Files to delete:**
- `backend/app/admin/services/subscriptions_command_service.py`
- `backend/app/admin/services/subscriptions_query_service.py`

**Files to modify:**
- `backend/app/admin/services/subscriptions_service.py` — replace facade with actual merged logic from command + query
- `backend/app/admin/services/__init__.py` — update exports
- `backend/app/admin/tests/test_subscriptions_command_service.py` — update imports

**OPML service** (`subscriptions_opml_service.py`) stays separate.

---

## Track D: Redis Cache Refactoring

**Agent:** `cache`
**Status:** Needs additional analysis (planning agent hit rate limit)
**Estimated changes:** ~1,100 lines removed, core/redis/ rewritten

**Before starting:** Analyze all `app_cache` call sites to build complete method usage map. Then:
1. Design thin replacement interface (~200 lines)
2. Update all call sites to use new interface
3. Remove old AppCache, mixins, metaprogramming

**This is the highest-risk track.** Do incrementally with tests passing at each step.

---

## Track E: Verification & Integration (depends on A-D)

**Agent:** lead (me)
**Tasks:**
1. Run `uv run pytest` after all tracks complete
2. Run `uv run ruff check .` for lint
3. Verify `uv sync` works with cleaned dependencies
4. Manual smoke test: dev server starts, health endpoint responds
5. Create Alembic migrations for all model changes
6. Final commit

---

## Team Structure

```
Lead (me) — coordination, verification, final integration
  ├── deleter   — Track A (standalone deletions)
  ├── security  — Track B (encryption + JWT simplification)
  ├── structural — Track C (assemblers + CQRS)
  └── cache     — Track D (Redis cache refactor)
```

**Parallelism:** Tracks A, B, C, D run in parallel. Track E runs after all complete.
**Within Track A:** A1-A3 are independent; A4 depends on nothing but A5 depends on knowing auth patterns; A6 must follow A5.
**Conflicts:** Tracks B and A both modify `jwt.py`, `__init__.py`, `alembic/env.py`, `config.py`. Use worktree isolation or sequence carefully.
