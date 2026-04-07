# Stella Full-Stack Incremental Optimization

**Date**: 2026-04-07
**Scope**: Performance + reliability + security improvements across backend and frontend
**Risk**: Low — no breaking changes, all additive improvements

---

## 1. Database Indexes (Backend)

Add 4 composite indexes via Alembic migration.

| Table | Index Columns | Query Pattern |
|---|---|---|
| `podcast_episodes` | `(subscription_id, published_at)` | Fetch recent episodes per subscription |
| `podcast_playback_states` | `(user_id, last_updated_at)` | Playback history sorted by time |
| `subscriptions` | `(source_type, status)` | Feed refresh filtering |
| `transcription_tasks` | `(episode_id, status)` | Find failed/cancelled transcriptions for episode |

**Files changed**: 1 new Alembic migration file.

---

## 2. Redis Caching (Backend)

Add short-lived Redis caching for frequently-queried, rarely-changing data.

| Cache Item | TTL | Key Pattern | Invalidated By |
|---|---|---|---|
| Episode detail (with summary) | 5 min | `episode:detail:{episode_id}` | Episode update, summary generation |
| Highlight dates | 10 min | `highlights:dates:{user_id}` | Highlight extraction, favorite toggle |
| Effective playback rate | 30 min | `playback:rate:{user_id}:{episode_id}` | Rate change |

**Implementation**: Extend existing `core/redis/cache.py` `PodcastCacheOperations`. Use `get_or_set` pattern already established in the codebase.

**Files changed**: `core/redis/cache.py`, `domains/content/services/summary_service.py` (or equivalent), `domains/podcast/repositories/` relevant mixins, `domains/podcast/services/highlight_service.py`.

---

## 3. Security Fix (Backend)

Remove partial API key logging in `highlight_service.py` line ~557-558:

```python
# REMOVE:
logger.info(f"[KEY] Decrypted API key for model {model_config.name} (first 10 chars): {api_key[:10]}...")
```

Replace with a generic log message that doesn't expose any key material.

**Files changed**: `domains/podcast/services/highlight_service.py`.

---

## 4. Exception Narrowing (Backend)

Narrow 6 high-priority `except Exception` blocks in business logic paths to specific exception types:

| File | Line | Current | Target |
|---|---|---|---|
| `summary_service.py` | ~338 | `except Exception` | `except (SQLAlchemyError, IOError)` |
| `task_orchestration_service.py` | ~618 | `except Exception` | `except (ExternalServiceError, TimeoutError)` |
| `transcription_workflow_service.py` | ~347 | `except Exception` | `except (ExternalServiceError, OSError)` |
| `transcription_state.py` | ~354 | `except Exception` | `except (RedisError, ValueError)` |
| `model_runtime_service.py` | ~279 | `except Exception` | `except (ExternalServiceError, TimeoutError, JSONDecodeError)` |
| `highlight_service.py` AI calls | multiple | `except Exception` | `except (ExternalServiceError, JSONDecodeError)` |

The remaining 13 low-priority instances in best-effort paths (cache ops, token blacklist, file cleanup) are acceptable as-is — they properly degrade gracefully.

**Files changed**: 5-6 service files.

---

## 5. Response Model Completion (Backend)

Add typed Pydantic response models for 3 endpoints currently returning raw dicts:

| Endpoint | New Model |
|---|---|
| `DELETE /subscriptions/{id}` | `SubscriptionDeleteResponse(message: str, subscription_id: int)` |
| `POST /subscriptions/{id}/refresh` | `SubscriptionRefreshResponse(message: str, episode_count: int)` |
| `POST /subscriptions/{id}/reparse` | `SubscriptionReparseResponse(message: str, episode_count: int)` |

**Files changed**: `domains/podcast/schemas.py`, `domains/podcast/routes/routes_subscriptions.py`.

---

## 6. ListView.builder Migration (Frontend)

Replace `ListView(children:)` with `ListView.builder` in 4 locations where lists can grow large:

| File | Line | Notes |
|---|---|---|
| `podcast_feed_page.dart` | ~246 | Episode list — potentially hundreds of items |
| `podcast_queue_sheet.dart` | ~339 | Queue list |
| `podcast_downloads_page.dart` | ~245 | Download list |
| `profile_cache_management_page.dart` | ~662 | Cache file list |

**Files changed**: 4 widget files.

---

## 7. Design Token Migration (Frontend)

Replace 30+ hardcoded `BorderRadius.circular(N)` calls with `AppRadius` tokens.

**Approach**:
1. Audit existing `AppRadius` constants in `core/constants/`
2. Add any missing radius values (8, 10, 14, 16, 18, 20)
3. Replace hardcoded values using find-and-replace

**Files changed**: 15-20 widget files.

---

## 8. Large Widget File Splits (Frontend)

Split 2 oversized widget files into focused sub-widgets:

### `podcast_queue_sheet.dart` (1024 lines)
Split into:
- `podcast_queue_sheet.dart` — main sheet scaffold (~200 lines)
- `queue_list_widget.dart` — list rendering + reorder logic
- `queue_controls_widget.dart` — play controls, clear button
- `queue_empty_state_widget.dart` — empty/loading states

### `transcription_status_widget.dart` (972 lines)
Split into:
- `transcription_status_widget.dart` — main tab scaffold (~200 lines)
- `transcript_tab_widget.dart` — transcript display tab
- `highlights_tab_widget.dart` — highlights list tab
- `transcription_progress_widget.dart` — progress indicator

**Files changed**: 2 existing + 6-8 new widget files.

---

## Out of Scope

These were identified but excluded from incremental scope:
- `transcription/service.py` (1547 lines) decomposition — too large for incremental
- `podcast/schemas.py` (952 lines) split — high risk, many imports
- Frontend missing widget tests — separate initiative
- API rate limiting — user preference to skip
- Chinese-language comments cleanup — cosmetic, low priority

---

## Estimated Changes

- **Backend**: ~12 files (1 migration, 5 services, 1 cache, 1 schemas, 2 routes, 1 security fix, 1 misc)
- **Frontend**: ~20 files (4 ListView, 15 token replacements, 2 splits + 6 new files)
- **Total**: ~32 files
- **Risk**: Low — no breaking API changes, no schema changes (indexes are additive)
