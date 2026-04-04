# Codebase Simplification Design

**Date:** 2026-04-04
**Status:** Approved
**Scope:** Large-scale simplification — all features retained, architecture and code streamlined
**Excluded:** Admin panel (frozen, no changes)

## Problem Statement

The codebase is ~2.5x over-built for its purpose (a personal AI assistant shared with a small group). Enterprise patterns (DDD bounded contexts, circuit breakers, Prometheus metrics, distributed rate limiting, multi-queue Celery) add complexity without proportional value. The podcast domain alone accounts for ~50% of both frontend and backend code, with significant boilerplate and over-abstraction.

## Current State

| Metric | Frontend | Backend | Docker |
|--------|----------|---------|--------|
| Lines of code | ~63K | ~48K | 7 containers |
| Podcast domain share | 52% (36K) | 49% (24K) | — |
| Infrastructure/glue share | — | 49% of non-test code | — |

## Target State

| Metric | Frontend | Backend | Docker |
|--------|----------|---------|--------|
| Lines of code | ~38K | ~25K | 5 containers |
| Reduction | ~40% | ~48% | 2 fewer |

---

## Part 1: Backend Architecture — DDD 5-Layer to 3-Layer

### Current (5 layers)
```
API Route → Provider (DI wiring) → Service → Repository → Model/DB
```

### Target (3 layers)
```
API Route → Service → Model/DB
```

### Layers Removed

| Layer | Current State | Disposition |
|-------|---------------|-------------|
| Repository | 13 repo files (podcast), mixin inheritance | Service uses SQLAlchemy async session directly |
| Provider/DI | 6 provider files, 283 lines of wiring | Routes use FastAPI native `Depends()`, services accept session via constructor |
| Projection | 4 files, 947 lines of boilerplate DTOs | Pydantic schemas handle serialization directly |

### Target Directory Structure

```
app/
  main.py
  bootstrap/              # Keep, simplify
  core/                   # Keep, significantly reduced
    config.py
    database.py           # Keep, remove pool warmup
    redis/                # 6 files → 2 files
      client.py
      cache.py
    security.py           # Keep
    celery_app.py         # Keep, merge queues
    middleware/            # Only CORS + GZip + minimal payload check
    exceptions.py         # Reduced ~545 → ~150 lines
  domains/
    podcast/
      routes/             # Former api/, calls service directly
      services/           # 21 → ~8 files (see merge plan below)
      models.py           # Keep
      schemas.py          # Keep, absorbs projection logic
      tasks/              # 19 → ~6 files
    subscription/
      routes.py
      service.py
      models.py
    user/
      routes.py
      service.py
      models.py
    ai/
      routes.py
      service.py
      models.py
  admin/                  # FROZEN — no changes
  http/                   # Simplified
```

### Podcast Service Merge Plan (21 → ~8)

| Before | After |
|--------|-------|
| `transcription_runtime_service.py` + `transcription_workflow_service.py` + `transcription_schedule_service.py` + `transcription_state_coordinator.py` | `transcription_service.py` |
| `summary_generation_service.py` + `summary_workflow_service.py` | `summary_service.py` |
| `highlight_extraction_service.py` + `highlight_service.py` | `highlight_service.py` |
| `playback_service.py` | `playback_service.py` (keep) |
| `subscription_service.py` | `subscription_service.py` (keep) |
| `feed_service.py` | `feed_service.py` (keep) |
| `search_service.py` | `search_service.py` (keep) |
| `daily_report_service.py` | `daily_report_service.py` (keep) |

---

## Part 2: Infrastructure Simplification

### Modules Deleted Entirely

| Module | Lines | Reason |
|--------|-------|--------|
| `core/circuit_breaker.py` | 280 | Used in exactly 1 place; unnecessary for personal project |
| `core/metrics.py` | 355 | Prometheus monitoring; unnecessary for personal project |
| `core/observability.py` | 309 | Alert thresholds with no actual alerting system |
| `core/etag.py` | 359 | Used by 3 routes, low value |
| `core/email.py` | 326 | Pure stub code — never sends email |
| `core/interfaces/` | 72 | Protocol with single implementation |
| `middleware/rate_limit.py` | 459 | Distributed rate limiting for 1 user is overkill |
| `middleware/response_optimization.py` | 219 | GZip already handled by FastAPI built-in |
| Request observability in `middleware/__init__.py` | 162 | Removed with monitoring stack |
| `tests/performance/` | All | Locust load testing for personal project |

**Total deleted: ~2,900+ lines**

### Modules Retained and Simplified

| Module | Disposition |
|--------|-------------|
| `middleware/` | Only CORS (FastAPI built-in) + payload size check (~10 lines) |
| `redis/` | 6 files 1050 lines → 2 files (`client.py` + `cache.py`), remove mixin metaprogramming, metrics collector, sorted_set abstraction |
| `celery_app.py` | 4 queues → 2 queues (`default` + `transcription`), simplify beat schedule |
| `exceptions.py` | 545 lines → ~150 lines, keep only exceptions actually raised |
| `database.py` | Remove pool warmup logic |

### Docker Simplification (7 → 5 containers)

| Before | After |
|--------|-------|
| postgres | postgres (unchanged) |
| redis | redis (unchanged) |
| backend (gunicorn + 4 uvicorn workers) | backend (single uvicorn, remove gunicorn) |
| celery_worker_core | celery_worker (merged, all queues) |
| celery_worker_transcription | ↑ merged |
| celery_beat | celery_beat (unchanged) |
| nginx | nginx (unchanged) |

### Dependencies Removed (pyproject.toml)

| Dependency | Reason |
|------------|--------|
| `gunicorn` | Zero imports; single uvicorn sufficient |
| `email-validator` | Zero imports |
| `prometheus-client` | Monitoring stack removed |
| `starlette` | Redundant transitive dependency via FastAPI |

---

## Part 3: Frontend Simplification

### Playback Refactor (2,748 lines → ~1,200 lines)

**Before:** `AudioPlayerNotifier` with 8 `part` files sharing private members.

**After:** 4 independent notifiers communicating via Riverpod `ref`:

| Notifier | Responsibility | Est. Lines |
|----------|---------------|------------|
| `AudioPlayerNotifier` | Core playback control + state | ~400 |
| `PlaybackQueueNotifier` | Queue management | ~250 |
| `PlaybackPersistenceNotifier` | Progress save + server sync | ~250 |
| `SleepTimerNotifier` | Sleep timer | ~100 |

### Model Consolidation

| Before | After |
|--------|-------|
| `PodcastEpisodeDetailResponse` duplicates 30+ fields from `PodcastEpisodeModel` | Single model with `copyWith` for variant scenarios |
| `PodcastFeedState` / `PodcastEpisodesState` / `PodcastSubscriptionState` share 90% structure | Extract generic `PaginatedState<T>` base class |

### Provider Reduction (59 → ~30)

- Merge single-purpose trivial providers (`podcast_core_providers.dart` 26 lines, `episode_provider_cache.dart` 16 lines)
- Remove barrel export files
- 5 `audio_*` part files → 4 independent notifier files

### Dead Code Cleanup

| Item | Lines Saved |
|------|-------------|
| Remove `dartz` dependency (zero imports) | — |
| Delete `AsyncValueWidget` (zero imports) | 227 |
| Delete `LazyIndexedStack` (zero imports) | 113 |
| Simplify `offline_indicator.dart` unused widgets | ~150 |
| Remove redundant direct `riverpod` dependency | — |
| Clean up debug logging | ~300 |

### Target Frontend Structure

```
lib/
  core/                # Keep, simplified
  features/
    podcast/
      data/            # Keep, merged models
      domain/          # Keep
      presentation/
        pages/         # Keep, split large files
        providers/     # 59 → ~30 independent files
        widgets/       # Keep
    auth/              # Keep
    profile/           # Keep
    settings/          # Keep
    home/              # Keep
  shared/              # Remove unused widgets
```

---

## Implementation Priority

1. **Backend infrastructure deletion** — Remove monitoring, circuit breaker, rate limiter, dead code (lowest risk, highest immediate impact)
2. **Backend architecture flattening** — Remove repo/provider/projection layers, merge services
3. **Docker simplification** — Merge celery workers, remove gunicorn
4. **Frontend dead code + model consolidation** — Remove unused code, merge duplicate models
5. **Frontend playback refactor** — Split monolithic notifier into independent notifiers
6. **Frontend provider reduction** — Consolidate providers

## Risk Mitigation

- Existing test suite (94 backend test files, 102 frontend test files) provides safety net
- Each phase should pass full test suite before proceeding
- Admin panel is explicitly excluded — no risk of regression there
- Small user base means deployment risk is minimal
