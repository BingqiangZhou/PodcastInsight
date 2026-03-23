# Backend Tests

## Directory

```text
tests/
|- admin/
|- core/
|- integration/
|- podcast/
|- tasks/
|- performance/
|- test_route_snapshot.py
`- test_celery_config_snapshot.py
```

## Run Tests

```bash
cd backend
uv run pytest -s
```

Run selected suites:

```bash
uv run pytest tests/admin/
uv run pytest tests/tasks/
uv run pytest tests/test_route_snapshot.py
```

Run performance baseline:

```bash
cd ../docker && docker-compose up -d
cd ../backend
$env:RUN_PERFORMANCE_TESTS='1'; uv run pytest tests/performance/test_api_performance.py -q
```

Performance test notes:

- HTTP clients use `trust_env=False` to avoid local/system proxy side effects.
- Cached-path assertions use ETag conditional requests (`If-None-Match` -> `304`).
- Latency assertions prefer server `X-Process-Time` when present.

Optional Locust load test:

```bash
# 1) Obtain a bearer token from /api/v1/auth/login or /api/v1/auth/register
# 2) Run Locust against running backend
$env:PERF_BEARER_TOKEN='<token>'; uv run locust -f tests/performance/locustfile.py --host=http://localhost:8000
```

## Required Gates

```bash
uv run ruff check .
$env:DATABASE_URL='postgresql+asyncpg://user:pass@localhost:5432/test'; uv run pytest -s
```

## Snapshot Coverage

- `tests/test_route_snapshot.py`: `/api/v1/subscriptions/podcasts*` route snapshot.
- `tests/admin/test_admin_route_snapshot.py`: `/api/v1/admin/*` route snapshot.
- `tests/tasks/test_task_registry.py`: Celery task registration + routes + beat schedule consistency.
- `tests/tasks/test_transcription_task_flow.py`: transcription success/retry/lock behavior.
- `tests/tasks/test_summary_task_flow.py`: summary task success/retry behavior.
- `tests/performance/test_api_performance.py`: API baseline report (p50/p95, error rate, cache hit rate).
