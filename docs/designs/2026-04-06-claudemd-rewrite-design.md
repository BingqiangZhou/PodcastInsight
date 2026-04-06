# CLAUDE.md Rewrite Design

## Goal
Rewrite CLAUDE.md following best practices from Anthropic official docs and community research. Target: ~120 lines, English, aggressive trim with progressive disclosure.

## Design Decisions

### What stays in CLAUDE.md (universally applicable)
1. **Project overview** (2 lines) — what the project is, key technologies
2. **Commands** (~15 lines) — build, test, lint, migrations, Docker. The exact commands Claude runs.
3. **Project structure** (~20 lines) — concise directory purpose descriptions (no file trees, no file-by-file listings)
4. **Conventions** (~40 lines) — only non-default rules Claude would get wrong:
   - Backend: uv not pip, ruff not black, async patterns, exception conventions, DI approach
   - Frontend: Material 3, CustomAdaptiveNavigation, Arc+Linear design system, Drift ORM, responsive breakpoints, build_runner, l10n
   - API: /api/v1/ prefix, error response shape, rate limits, health endpoints
   - General: specs/active/ check, commit message format
5. **Gotchas** (~15 lines) — table of common mistakes (proven to prevent real errors)
6. **Testing & completion** (~15 lines) — how to test, what "done" means
7. **Reference docs** (~10 lines) — progressive disclosure pointers to detailed docs

### What moves OUT of CLAUDE.md
- **Detailed architecture trees** — Claude can explore directories itself. Moved to `AGENTS.md` (already exists) or removed entirely.
- **Technology lists** — Claude can read pyproject.toml and pubspec.yaml. Redundant.
- **Docker services table** — Claude can read docker-compose.yml. Not needed in every session.
- **Code style enforced by linters** — ruff and dart analyzers handle this. Don't send an LLM to do a linter's job.
- **File-by-file descriptions** — Claude reads files when needed.

### Why each removed item is safe to remove
| Item | Reason |
|------|--------|
| Backend tech stack list | Claude reads pyproject.toml; these are standard technologies it already knows |
| Frontend tech stack list | Claude reads pubspec.yaml; same reasoning |
| Docker services table | Only relevant during deployment; Claude reads docker-compose.yml |
| Detailed architecture file trees | Goes stale immediately; Claude can ls/glob directories |
| security.py reference | It's now security/ directory; Claude can explore it |
| "Bilingual error responses" | Already changed to standard HTTPException |
| Completion criteria list | Can be condensed into 2-3 lines |

## Proposed CLAUDE.md Structure

```markdown
# Stella — Personal AI Assistant

FastAPI + Flutter podcast app with AI features. Backend: Python/FastAPI/PostgreSQL/Redis. Frontend: Flutter/Material 3/Riverpod.

## Commands

### Backend (uv — NEVER pip)
cd backend
uv sync --extra dev
uv run alembic upgrade head
uv run uvicorn app.main:app --reload
uv run ruff check .
uv run pytest

### Frontend (Flutter 3.8+, Dart)
cd frontend
flutter pub get
dart run build_runner build
flutter test
flutter gen-l10n

### Docker (full-stack verification)
cd docker
docker compose up -d
curl http://localhost:8000/api/v1/health

## Project Structure

backend/app/
  bootstrap/      — App lifecycle, middleware, routing, cache warming
  core/           — Config, database, redis, security (JWT/encryption/2FA), auth, exceptions, celery
  shared/         — Cross-domain utilities (repository helpers, schemas, retry, time)
  domains/        — user, subscription, podcast, ai
  http/           — Error helpers, route decorators
  admin/          — Admin panel (separate auth, 2FA, CSRF, templates)

frontend/lib/
  core/
    glass/          — Arc+Linear design system (GlassBackground, GlassContainer, GlassTokens, SurfaceCard)
    database/       — Drift ORM (AppDatabase, DownloadDao, PlaybackDao, EpisodeCacheDao)
    theme/          — AppTheme, AppColors (Arc+Linear tokens), ThemeProvider
    constants/      — AppRadius, AppSpacing, Breakpoints, ScrollConstants
    widgets/        — CustomAdaptiveNavigation (NOT flutter_adaptive_scaffold)
  features/        — auth, podcast (largest), profile, settings, splash, home
  shared/          — Cross-feature models, widgets

## Conventions

### Backend
- Package management: `uv` only (NEVER pip). Linting: `ruff` only (NOT black/isort/flake8)
- All I/O is async (SQLAlchemy async, httpx, redis)
- Exceptions: Service layer raises `BaseCustomError`. Routes use `HTTPException` from `app.http.errors`
- Dependency injection: FastAPI `Depends()`
- Migrations: `backend/alembic/` (20 files)

### Frontend
- Material 3 only (`useMaterial3: true`). Use `CustomAdaptiveNavigation` + `Breakpoints` (NOT flutter_adaptive_scaffold)
- Arc+Linear design system: `GlassContainer`/`SurfaceCard` for card surfaces. Theme tokens in `AppColors`. `GlassBackground` for page backgrounds
- Responsive breakpoints: mobile <600 | tablet 600-1200 | desktop >=1200
- Run `dart run build_runner build` after modifying `@riverpod`, `@RestApi`, `@JsonSerializable`, or Drift files
- i18n: Edit both `app_localizations_en.arb` and `app_localizations_zh.arb`, then `flutter gen-l10n`
- Widget tests MANDATORY for all pages

### API
- All endpoints: `/api/v1/` prefix. Standard HTTPException error responses
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
| Hardcoded colors/radii | `AppColors` tokens and `AppRadius` constants |
| Edit `.g.dart` by hand | Edit source, re-run `dart run build_runner build` |
| Bare ValueError for errors | `BaseCustomError` (service) or `HTTPException` (route) |
| Skip widget tests | Required for all pages |

## Testing & Completion

- Backend tests: `uv run pytest` (SQLite in-memory via aiosqlite, no Docker needed)
- Frontend tests: `flutter test` (unit: `test/unit/`, widget: `test/widget/`, integration: `test/integration/`)
- Full-stack: `cd docker && docker compose up -d` → verify health endpoint
- A task is NOT COMPLETE until: code compiles, tests pass, and modified functionality works end-to-end
```

## Line count estimate
~115 lines total — well under the 200-line recommendation.

## Reference Documents (Progressive Disclosure)
- `AGENTS.md` — Already contains build/test commands and coding style conventions for multi-agent contexts
- `docs/` — Design docs, optimization reports, deployment guides
- `specs/active/` — Active requirement specs to check before implementation
