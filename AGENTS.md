# Repository Guidelines

## Project Structure & Module Organization
- `backend/`: FastAPI service (DDD layout) with core, shared, and domain modules in `backend/app/`.
- `backend/alembic/`: database migrations (23 migrations).
- `backend/tests/` and `backend/app/**/tests/`: backend test suites.
- `frontend/`: Flutter app with feature modules in `frontend/lib/` and tests in `frontend/test/`.
- `docker/`: Docker Compose files and deployment assets (6 services: postgres, redis, backend, celery_worker, celery_beat, nginx).
- `docs/` and `specs/`: detailed design notes and active requirements.
- `scripts/`: Utility scripts (SQL init, API test, optimization verify).

## Build, Test, and Development Commands
- Backend dependencies: `cd backend && uv sync --extra dev`
- Migrations: `uv run alembic upgrade head`
- Run API locally: `uv run uvicorn app.main:app --reload`
- Lint/format (backend): `uv run ruff check .` and `uv run ruff format .`
- Backend tests: `uv run pytest`
- Frontend deps: `cd frontend && flutter pub get`
- Frontend code gen: `cd frontend && dart run build_runner build` (required after modifying `@riverpod`, `@RestApi`, `@JsonSerializable`, or Drift files)
- Frontend tests: `flutter test` (unit: `test/unit/`, widget: `test/widget/`, integration: `test/integration/`)
- Frontend l10n: `flutter gen-l10n` (after editing both `app_localizations_en.arb` and `app_localizations_zh.arb`)
- Docker backend verification (required): `cd docker && docker compose up -d`

## Coding Style & Naming Conventions
- Backend uses `ruff` for linting/formatting; do not use `black`, `isort`, or `flake8`.
- Use `uv` for Python package management; avoid `pip install`.
- Follow async/await patterns for I/O in the backend (SQLAlchemy async, aiohttp, redis).
- Frontend uses Material 3 (`useMaterial3: true`) and `CustomAdaptiveNavigation` with `Breakpoints` class.
- Frontend uses platform-adaptive UI: CupertinoTheme wrapper and `.adaptive()` widgets for iOS-native feel.
- Use `AppColors`, `AppRadius`, and `AppSpacing` tokens — no hardcoded colors, radii, or spacing.
- Use `Color.withValues(alpha:)` instead of deprecated `Color.withOpacity()`.

## Testing Guidelines
- Backend: pytest with async tests; run `uv run pytest` before PRs.
- Frontend: widget tests are mandatory for page functionality; run `flutter test test/widget/`.
- Verify backend via Docker (not only local uvicorn).

## Commit & Pull Request Guidelines
- Commit messages follow a Conventional Commits style: `feat:`, `fix:`, `refactor:`, `chore:`, `style:` (examples in history).
- PRs should include: a clear description, linked issues/specs (see `specs/active/`), and test evidence (commands + results). Add screenshots for UI changes.

## Environment & Secrets
- Backend config lives in `backend/.env` (start from `.env.example`); never commit secrets.
- Local infrastructure is expected to run via Docker Compose in `docker/` (PostgreSQL, Redis, Celery).
- Use the health check once running: `curl http://localhost:8000/api/v1/health`.

## Configuration & Requirements Notes
- API endpoints are prefixed with `/api/v1/` and errors are bilingual: `{message_en, message_zh}`.
- Check `specs/active/` before implementing new work to avoid duplicating requirements.
