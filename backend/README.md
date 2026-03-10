# Personal AI Assistant - Backend

FastAPI backend service for Personal AI Assistant.

## Stack

- FastAPI + SQLAlchemy async
- PostgreSQL
- Redis
- Celery
- Alembic
- Ruff + Pytest
- uv package manager

## Quick Start

```bash
cd backend
uv sync --extra dev
```

Create `.env` from `.env.example`, then run migrations:

```bash
uv run alembic upgrade head
```

Run API locally:

```bash
uv run uvicorn app.main:app --reload
```

Run Celery workers (recommended split queues):

```bash
# Core queues (subscription_sync, ai_generation, maintenance)
uv run celery -A app.core.celery_app:celery_app worker --loglevel=info -Q subscription_sync,ai_generation,maintenance

# Transcription queue
uv run celery -A app.core.celery_app:celery_app worker --loglevel=info -Q transcription
```

Run Celery beat:

```bash
uv run celery -A app.core.celery_app:celery_app beat --loglevel=info
```

## Quality Gates

Lint and format check:

```bash
uv run ruff check .
uv run ruff format .
```

Run tests:

```bash
uv run pytest
```

## API Notes

- Primary API prefix: `/api/v1`
- Podcast subscription API lives under: `/api/v1/subscriptions/podcasts*`
- Admin panel lives under: `/super/*`

## Docker Verification

```bash
cd docker
docker-compose up -d
docker-compose ps
curl http://localhost:8000/api/v1/health
```

Verify Celery services are running in Docker:

- `celery_worker_core` (queues: `subscription_sync,ai_generation,maintenance`)
- `celery_worker_transcription` (queue: `transcription`)
- `celery_beat`

## Project Layout

```text
backend/
|- alembic/
|- app/
|  |- admin/
|  |- core/
|  |- domains/
|  `- shared/
|- scripts/
|- tests/
|- pyproject.toml
`- uv.lock
```
