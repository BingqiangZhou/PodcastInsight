# Frontend Deep Scan Report

> Date: 2026-03-28
> Method: 4 parallel read-only agents
> Scope: Full frontend codebase (~190 Dart files, 7 feature modules)

---

## Executive Summary

| Scan Agent | HIGH | MEDIUM | LOW | Score |
|------------|------|--------|-----|-------|
| A6: Memory & Resource Leaks | 0 | 2 | 8 | GOOD |
| A7: Widget Lifecycle & Rendering | 5 | 11 | 11 | 7/10 |
| A8: State Management & Data Flow | 5 | 13 | 5 | 6.5/10 |
| A9: Navigation & Architecture | 4 | 10 | 8 | 6.5/10 |
| **TOTAL** | **14** | **36** | **32** | — |

**Overall Health: 6.5/10** — Solid foundation with notable gaps in error handling patterns and widget rebuild optimization.

---

## Top 10 Most Impactful Fixes (Cross-Cutting Priority)

### 1. Fix error clearing in `copyWith` for 3 core state classes [HIGH]
**Files:** `podcast_state_models.dart`, `audio_player_state_model.dart`
**Issue:** `PodcastEpisodesState`, `PodcastSubscriptionState`, `AudioPlayerState` use `error: error ?? this.error` in `copyWith`, so errors persist after successful operations.
**Fix:** Add `clearError` boolean sentinel (same pattern as `PodcastFeedState`).

### 2. Make `AuthState` extend `Equatable` [HIGH]
**File:** `auth_provider.dart`
**Issue:** `AuthState` lacks value equality. Every `copyWith` triggers rebuilds in router + all auth-watching widgets, even when no fields changed.
**Fix:** Extend `Equatable`, list all fields in `props`.

### 3. Split bottom player widget tree for rebuild isolation [HIGH]
**Files:** `podcast_bottom_player_widget.dart`, `podcast_bottom_player_controls.dart`
**Issue:** `_TransportRow` watches `audioMiniProgressProvider` (updates every 500ms) → entire transport row rebuilds including unrelated buttons.
**Fix:** Use `ref.watch(... .select())` at finer granularity; split `_TransportRow` into separate Consumer widgets per logical concern.

### 4. Add LRU bounds to iTunes/RSS service caches [MEDIUM]
**Files:** `itunes_search_service.dart`, `apple_podcast_rss_service.dart`
**Issue:** Three cache maps in iTunes service + one in RSS service have no size limit. `clearExpiredCache()` exists but is never called automatically.
**Fix:** Add max entry limit (50-100) or call `clearExpiredCache()` on every write.

### 5. Fix `ConversationNotifier._loadHistory` race condition [HIGH]
**File:** `conversation_providers.dart`
**Issue:** Completer-based guard silently drops new load requests when session ID changes. Results for old session may overwrite intended state.
**Fix:** Track target session ID; cancel/replace load if session changes.

### 6. Add `Equatable` to `ConversationState`, `SummaryState`, `PodcastSearchState` [MEDIUM]
**Files:** `conversation_providers.dart`, `summary_providers.dart`, `podcast_search_provider.dart`
**Issue:** These state classes are updated frequently during active use but lack value equality, causing unnecessary rebuilds.
**Fix:** Extend `Equatable` for each.

### 7. Stop error swallowing in `CachedAsyncNotifier` [MEDIUM]
**File:** `cached_async_notifier.dart`
**Issue:** When fetch fails and stale data exists, error is silently swallowed. Affects 6+ notifiers. Users never see that refresh failed.
**Fix:** Add optional error field to cached state, or briefly emit error state before falling back to stale data.

### 8. Add RepaintBoundary around mini dock progress + chat messages [MEDIUM]
**Files:** `podcast_bottom_player_layouts.dart`, `chat_messages_list.dart`
**Issue:** Mini player progress repaints cascade to entire dock. Chat message repaints cascade to siblings during streaming.
**Fix:** Wrap progress indicator and individual message bubbles in `RepaintBoundary`.

### 9. Add request deduplication to subscription/episode providers [MEDIUM]
**Files:** `podcast_subscription_providers.dart`, `podcast_episodes_providers.dart`
**Issue:** No concurrent invocation guard. Rapid user actions (pull-to-refresh, switching subscriptions) can cause stale data overwriting fresh data.
**Fix:** Add in-flight request guard (pattern exists in `PodcastFeedNotifier._inFlightInitialLoad`).

### 10. Consolidate duplicate episode detail routes [HIGH]
**File:** `app_router.dart`
**Issue:** Two routes (`/podcast/episodes/:subscriptionId/:episodeId` and `/podcast/episode/detail/:episodeId`) point to the same page. Confuses deep linking and maintenance.
**Fix:** Consolidate to single canonical route using episode ID only.

---

## Memory & Resource Leaks (Agent A6)

**Rating: GOOD** — No HIGH issues.

### MEDIUM Issues
| ID | File | Issue |
|----|------|-------|
| M6-1 | `itunes_search_service.dart` | 3 unbounded cache maps, `clearExpiredCache()` never auto-called |
| M6-2 | `apple_podcast_rss_service.dart` | Unbounded cache map, same pattern |

### Positive Findings
- `PodcastAudioHandler`: centralized `_subs` list with proper cancellation
- `AudioPlayerNotifier`: `_TimerManager` class for all timer lifecycle
- `ETagInterceptor`: `LinkedHashMap` with `_maxEntries` (256) LRU eviction
- `ResourceCleanupMixin`: well-designed mixin for auto cleanup
- `DioClient`: retry LRU bound of 50, `Completer`-based request dedup
- All `StreamSubscription` instances properly cancelled in `dispose()`
- All periodic timers have cancellation paths via `ref.onDispose()`

---

## Widget Lifecycle & Rendering (Agent A7)

**Rating: 7/10**

### HIGH Issues
| ID | File | Issue |
|----|------|-------|
| H7-1 | `podcast_bottom_player_widget.dart` | Watches 3 providers, any change rebuilds entire player tree |
| H7-2 | `podcast_bottom_player_controls.dart` | `_TransportRow` rebuilds on every position tick (~500ms) |
| H7-3 | `transcript_display_widget.dart` | 1013 lines, deeply nested build methods |
| H7-4 | `transcription_status_widget.dart` | 989 lines, monolithic widget |
| H7-5 | `podcast_queue_sheet.dart` | 977 lines, mixed UI + drag-and-drop logic |

### Key Metrics
- `const` usage: ~70% of eligible widgets
- `RepaintBoundary` count: 27 (good coverage, 2 gaps identified)
- `setState` usage: All instances are **legitimate local UI state** — no migration needed

---

## State Management & Data Flow (Agent A8)

**Rating: 6.5/10**

### HIGH Issues
| ID | File | Issue |
|----|------|-------|
| H8-1 | `podcast_state_models.dart` | `PodcastEpisodesState.copyWith` doesn't clear error |
| H8-2 | `podcast_state_models.dart` | `PodcastSubscriptionState.copyWith` doesn't clear error |
| H8-3 | `audio_player_state_model.dart` | `AudioPlayerState.copyWith` doesn't clear error |
| H8-4 | `auth_provider.dart` | `AuthState` lacks `Equatable` |
| H8-5 | `conversation_providers.dart` | Race condition in `_loadHistory` with session switching |

### Provider Dependency Graph
```
dioClientProvider (depth 0)
  └── podcastApiServiceProvider (1)
        └── podcastRepositoryProvider (2)
              └── [15+ feature notifiers] (3)

Max depth: 4 levels
Circular deps: None detected
Bidirectional: audioPlayerProvider ↔ PodcastQueueController (via ref.read)
```

### Error Handling Issues
- `episodeDetailProvider`: silently returns `null` on error
- `availableModelsProvider`: silently returns `[]` on error
- `episodeHighlightsProvider`: silently returns `null` on error
- `CachedAsyncNotifier`: silently swallows errors when stale data exists
- Summary polling: `ref.invalidate(episodeDetailProvider)` every 5s causes cascading rebuilds

---

## Navigation & Architecture (Agent A9)

**Rating: 6.5/10**

### HIGH Issues
| ID | File | Issue |
|----|------|-------|
| H9-1 | `core_providers.dart` | Core imports 4 feature providers (layer violation) |
| H9-2 | `app_router.dart` | Duplicate episode detail routes |
| H9-3 | Multiple | Test coverage gaps (profile: 0 unit tests, settings: thin) |
| H9-4 | `app_router.dart` | Deep link destination lost after auth redirect |

### Dependency Direction Violations
- `core/app` → `features/auth`, `features/settings` (4 imports)
- `core/providers` → `features/auth`, `features/podcast` (4 imports)
- `core/widgets` → `features/podcast` (1 import: UI constants)
- `core/network` → `features/auth` (1 import: auth events)
- `core/router` → ALL features (24 imports — expected for router)

### Test Coverage Matrix
| Module | Source | Tests | Est. Coverage |
|--------|--------|-------|---------------|
| podcast | 112 | 55 | ~45% |
| auth | 15 | 7 | ~40% |
| splash | 1 | 1 | ~50% |
| profile | 5 | 5 | ~35% (0 unit tests) |
| settings | 2 | 4 | ~25% |
| core | ~25 | 7 | ~25% |
| shared | 8 | 1 | ~15% |

### Code Duplication
- 2 competing empty-state widgets (`EmptyStateWidget` vs `AppEmptyState`)
- 7+ identical `Center(child: CircularProgressIndicator())` despite existing `AsyncValueWidget`
- Shared calendar UI duplicated between `PodcastHighlightsPage` and `PodcastDailyReportPage`

---

## Recommended Next Steps (Priority Order)

### Phase 3A: Stability Fixes (HIGH impact, ~1-2 days)
1. Fix `copyWith` error clearing in 3 state classes
2. Add `Equatable` to `AuthState`, `ConversationState`, `SummaryState`
3. Fix `ConversationNotifier` race condition
4. Add request guards to subscription/episode providers

### Phase 3B: Rendering Optimization (HIGH impact, ~1-2 days)
1. Split bottom player widget tree for rebuild isolation
2. Add RepaintBoundary gaps (mini dock progress, chat messages)
3. Decompose 3 large widget files (>900 lines each)

### Phase 3C: Architecture Cleanup (MEDIUM impact, ~2-3 days)
1. Fix core→features layer violations
2. Consolidate duplicate routes
3. Unify empty-state/loading widgets
4. Split podcast providers barrel file

### Phase 3D: Test Coverage (MEDIUM impact, ongoing)
1. Add unit tests for profile providers
2. Add widget tests for player controls, shownotes, transcription
3. Add integration tests for playback and subscription flows
