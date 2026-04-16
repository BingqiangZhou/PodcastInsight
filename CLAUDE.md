# Stella — Personal AI Assistant

FastAPI + Flutter podcast app with AI features. Backend: Python/FastAPI/PostgreSQL/Redis. Frontend: Flutter/Material 3/Riverpod.

## Commands

### Backend (Python 3.11+, uses uv — NEVER pip)
```bash
cd backend
uv sync --extra dev                    # Install deps
uv run alembic upgrade head            # Run migrations
uv run uvicorn app.main:app --reload   # Dev server
uv run ruff check .                    # Lint (NOT black/isort/flake8)
uv run pytest                          # Tests (SQLite in-memory, no Docker needed)
```

### Frontend (Flutter 3.8+, Dart)
```bash
cd frontend
flutter pub get                        # Install deps
dart run build_runner build            # Code gen (required after @riverpod, @RestApi, @JsonSerializable, Drift)
flutter test                           # All tests
flutter gen-l10n                       # After editing both en.arb and zh.arb
```

### Docker (full-stack verification)
```bash
cd docker && docker compose up -d      # Start all 6 services
curl http://localhost:8000/api/v1/health
```

## Project Structure

```
backend/app/
  bootstrap/      Lifecycle, middleware, routing, cache warming
  core/           Config, database, redis, security (jwt/encryption/password/2FA), auth, exceptions, celery, ai_client, http_client, middleware
  shared/         Cross-domain utilities (repository helpers, schemas, retry, time)
  domains/        user, subscription, podcast, ai, media (transcription), content (reports/highlights/conversations)
  http/           Error helpers, route decorators
  admin/          Admin panel (separate auth, 2FA, CSRF, server-rendered HTML templates)

frontend/lib/
  core/
    database/       Drift ORM (AppDatabase, DownloadDao, PlaybackDao, EpisodeCacheDao)
    theme/          AppTheme, AppColors (design tokens), ThemeProvider, CupertinoTheme for iOS
    constants/      AppRadius, AppSpacing (4-point grid), Breakpoints, ScrollConstants
    widgets/        CustomAdaptiveNavigation (NOT flutter_adaptive_scaffold)
    platform/       Platform-aware page transitions, adaptive widgets (.adaptive())
    network/        Dio client with ETag caching, token refresh, retry
    services/       Cache, update check, download management
    storage/        SharedPreferences + SecureStorage wrappers
  features/        auth, podcast (largest), profile, settings, splash, home
  shared/          Cross-feature models, widgets
```

## Conventions

### Backend
- **uv only** (NEVER pip). **ruff only** for lint/format (NOT black/isort/flake8)
- All I/O is async (SQLAlchemy async, aiohttp, redis)
- Exceptions: Service layer raises `BaseCustomError`. Routes use `HTTPException` from `app.http.errors`
- DI: FastAPI `Depends()`. Migrations: `backend/alembic/` (23 migrations)

### Frontend
- **Material 3 only** (`useMaterial3: true`)
- Use `CustomAdaptiveNavigation` + `Breakpoints` (NOT flutter_adaptive_scaffold)
- Platform-adaptive UI: CupertinoTheme wrapper + `.adaptive()` widgets for iOS-native feel
- Responsive: mobile <600 | tablet 600-1200 | desktop >=1200
- Theme tokens in `AppColors`, spacing tokens in `AppSpacing` (4-point grid scale)
- Run `dart run build_runner build` after modifying `@riverpod`, `@RestApi`, `@JsonSerializable`, or Drift files
- i18n: Edit both `app_localizations_en.arb` and `app_localizations_zh.arb`, then `flutter gen-l10n`
- Widget tests MANDATORY for all pages

### API
- Endpoints: `/api/v1/` prefix. Standard HTTPException error responses
- Rate limiting: 60 req/min, 1000 req/hour
- Health: `GET /health` (liveness), `GET /api/v1/health/ready` (readiness)

### General
- Check `specs/active/` before implementing new features
- Conventional Commits: `feat:`, `fix:`, `refactor:`, `chore:`, `style:`

## Gotchas

| Wrong | Correct |
|-------|---------|
| `pip install` | `uv add` or `uv sync` |
| flutter_adaptive_scaffold | `CustomAdaptiveNavigation` + `Breakpoints` |
| Hardcoded colors/radii/spacing | `AppColors`, `AppRadius`, and `AppSpacing` tokens |
| Edit `.g.dart` by hand | Edit source, re-run `dart run build_runner build` |
| Bare ValueError for errors | `BaseCustomError` (service) or `HTTPException` (route) |
| `Color.withOpacity()` | `Color.withValues(alpha:)` (former is deprecated) |
| Skip widget tests | Required for all pages |

## Testing & Completion

- **Backend**: `uv run pytest` (SQLite in-memory via aiosqlite, no Docker needed)
- **Frontend**: `flutter test` (unit: `test/unit/`, widget: `test/widget/`, integration: `test/integration/`)
- **Full-stack**: `cd docker && docker compose up -d` then verify health endpoint
- A task is NOT COMPLETE until: code compiles, tests pass, modified functionality works end-to-end
