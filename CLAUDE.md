# CLAUDE.md — Stella (Personal AI Assistant)

## Critical Commands

### Backend (Python 3.11+, uses uv — NEVER pip)
```bash
cd backend
uv sync --extra dev                    # Install deps
uv run alembic upgrade head            # Run migrations
uv run uvicorn app.main:app --reload   # Dev server (local)
uv run ruff check .                    # Lint (NOT black/isort/flake8)
uv run ruff format .                   # Format
uv run pytest                          # Run tests (SQLite in-memory, no Docker needed)
```

### Frontend (Flutter 3.8+, Dart)
```bash
cd frontend
flutter pub get                        # Install deps
dart run build_runner build            # Code gen (Riverpod, Retrofit, JSON)
dart run build_runner watch            # Code gen in watch mode
flutter test                           # All tests
flutter test test/unit/                # Unit tests only
flutter test test/widget/              # Widget tests only (MANDATORY for pages)
flutter test test/integration/         # Integration tests only
flutter gen-l10n                       # Regenerate l10n (en, zh)
```

### Docker (integration/deployment verification)
```bash
cd docker
docker compose up -d                   # Start all 6 services
docker compose build backend && docker compose up -d  # After backend changes
curl http://localhost:8000/api/v1/health              # Verify health
```

## Architecture

### Backend (FastAPI, DDD layout)
```
app/
  main.py              # create_application() factory
  bootstrap/            # App lifecycle & wiring
    lifecycle.py        # async lifespan (DB init, Redis, cache warming)
    http.py             # Middleware stack, exception handlers, CORS
    routers.py          # Route registration per domain
  core/                 # Shared infrastructure
    config.py           # pydantic-settings (env-based Settings)
    database.py         # SQLAlchemy 2.x async engine + session factory
    redis/              # Shared Redis client
    celery_app.py       # Celery beat schedule + task registry
    security.py         # JWT, password hashing, 2FA
    middleware/          # rate_limit, query_analysis (N+1), response_optimization (gzip)
    metrics.py          # Prometheus counters/gauges/histograms
    observability.py    # Alert thresholds, health snapshot
  domains/              # Business domains
    user/               # Auth, profile (api, repositories, services, tests)
    subscription/       # Podcast subscriptions
    podcast/            # Episodes, transcription, playback, AI summaries
    ai/                 # LLM integration, conversations
  contexts/             # Bounded contexts (DDD hexagonal, scaffolded)
    content/ ingestion/ playback/ shared/
  http/                 # Shared HTTP helpers
    errors.py           # Bilingual HTTPException helpers
    responses.py        # ETag response builder
    decorators.py       # Auth, rate limit decorators
  admin/                # Admin panel (separate auth, 2FA, CSRF, templates)
```

### Frontend (Flutter, feature-based)
```
lib/
  main.dart             # Entry (ProviderScope, audio handler init)
  core/
    app/                # AppConfig, root App widget ("Stella")
    constants/          # AppConstants, Breakpoints, AppSpacing, CacheConstants
    localization/       # gen-l10n (en.arb, zh.arb)
    network/            # DioClient, ETag interceptor, token refresh
    offline/            # Connectivity provider, offline queue
    providers/          # Riverpod global providers
    router/             # go_router (StatefulShellRoute.indexedStack)
    services/           # AppCacheService, AppUpdateService
    storage/            # LocalStorageService, SecureStorageService
    theme/              # AppTheme (Material 3), AppColors, ThemeProvider
    widgets/            # CustomAdaptiveNavigation, page transitions, shells
  features/             # Feature modules
    auth/               # data/ domain/ presentation/
    podcast/            # core/ data/ presentation/ (largest feature)
    profile/ settings/ splash/ home/
  shared/               # Cross-feature models, widgets
```

### Docker Services (6 containers)
| Service | Description |
|---------|-------------|
| postgres | PostgreSQL 15 (primary + optional read replica) |
| redis | Redis 7 (cache + Celery broker) |
| backend | Uvicorn ASGI server |
| celery_worker | Queues: default, transcription (merged worker) |
| celery_beat | Scheduled tasks (feed refresh hourly, summaries 30min, cleanup daily) |
| nginx | Reverse proxy, SSL termination |

## Key Technologies

### Backend
- **Framework:** FastAPI + Uvicorn
- **ORM:** SQLAlchemy 2.x async (asyncpg driver)
- **Validation:** Pydantic v2, pydantic-settings
- **Database:** PostgreSQL 15 (async, read replica support)
- **Cache:** Redis 7 (distributed rate limiting, session cache)
- **Task Queue:** Celery 5 (Redis broker, 1 worker with 2 queues)
- **Auth:** JWT (python-jose), bcrypt, 2FA (pyotp + qrcode)
- **AI:** OpenAI API, SiliconFlow transcription
- **Monitoring:** prometheus-client, custom observability with alert thresholds
- **Linting:** ruff (replaces black, isort, flake8)
- **Testing:** pytest + pytest-asyncio (asyncio_mode=auto), aiosqlite, httpx
- **Package Mgmt:** uv (NEVER pip)

### Frontend
- **Framework:** Flutter 3.8+ (Material 3)
- **State:** Riverpod 3.x (flutter_riverpod + riverpod_annotation + code-gen)
- **Navigation:** go_router (StatefulShellRoute.indexedStack)
- **HTTP:** Dio 5.x + Retrofit (code-gen'd API clients)
- **Serialization:** json_annotation + json_serializable (build_runner)
- **Audio:** audioplayers + audio_service
- **Fonts:** google_fonts — Outfit (headings), Plus Jakarta Sans (body)
- **i18n:** Flutter gen-l10n (en, zh)
- **Testing:** flutter_test, mocktail, mockito
- **Linting:** very_good_analysis + flutter_lints

## Project-Specific Rules

### Backend
- Use `uv` for package management, NEVER `pip install`
- Use `ruff` for linting/formatting (replaces black, isort, flake8)
- Follow async/await patterns for all I/O (SQLAlchemy async, httpx, redis)
- Exception convention:
  - Service/Repository layer: raise `BaseCustomError` subclasses
  - Route layer: use `bilingual_http_exception()` from `app.http.errors`
  - NEVER use bare ValueError/string comparison for control flow
- Dependency injection: FastAPI native `Depends()`
- Migrations: Alembic in `backend/alembic/` (16 migration files)

### Frontend
- Material 3 required: `useMaterial3: true` in ThemeData
- Use `CustomAdaptiveNavigation` widget (NOT flutter_adaptive_scaffold)
  - Located at `core/widgets/custom_adaptive_navigation.dart`
  - Uses `Breakpoints` class from `core/constants/breakpoints.dart`
- Responsive breakpoints: mobile <600 | tablet 600–1200 | desktop >=1200
- Widget tests are MANDATORY for page functionality
- Run `dart run build_runner build` after modifying `@riverpod`, `@RestApi`, or `@JsonSerializable` files
- i18n: Add strings to both `app_localizations_en.arb` and `app_localizations_zh.arb`, then `flutter gen-l10n`

### API
- All endpoints prefixed with `/api/v1/`
- Bilingual error responses: `{"message_en": str, "message_zh": str}`
- Rate limiting: 60 req/min, 1000 req/hour (configurable)
- Response compression: gzip for responses > 1KB
- Payload limit: 10MB max
- ETag support: conditional responses
- Health endpoints:
  - `GET /health` — liveness
  - `GET /api/v1/health/ready` — readiness (checks DB + Redis)
  - `GET /metrics/prometheus` — Prometheus format

### General
- Check `specs/active/` for existing requirements before implementing
- Commit messages follow Conventional Commits: `feat:`, `fix:`, `refactor:`, `chore:`, `style:`

## Gotchas (Common Mistakes)

| Wrong | Correct |
|-------|---------|
| `pip install` | `uv add` or `uv sync` |
| flutter_adaptive_scaffold | `CustomAdaptiveNavigation` + `Breakpoints` |
| Material 2 components | Material 3 only |
| Skip `build_runner` after model/provider changes | Must run `dart run build_runner build` |
| Edit `.g.dart` files by hand | Generated files — edit source and re-run build_runner |
| Skip widget tests | Required for all pages |
| Bare ValueError for error handling | `BaseCustomError` (service) or `bilingual_http_exception` (route) |

### Testing Clarification
- **Unit/integration tests:** Run locally with `uv run pytest` (uses SQLite in-memory via aiosqlite)
- **Full-stack verification:** Run via Docker (`cd docker && docker compose up -d`) to test against PostgreSQL + Redis
- **Performance tests:** Set `RUN_PERFORMANCE_TESTS=1`, point to Docker instance
- Use local for fast iteration, Docker for full-stack verification before merge

## Completion Criteria

A task is **NOT COMPLETE** until:
- Code compiles without errors
- `dart run build_runner build` succeeds (if `.g.dart` files affected)
- Backend: `uv run ruff check .` passes
- Backend: `uv run pytest` passes (or Docker integration tests if applicable)
- Frontend: `flutter test` passes
- Docker stack starts and health check passes: `curl http://localhost:8000/api/v1/health`
- Modified functionality works end-to-end
