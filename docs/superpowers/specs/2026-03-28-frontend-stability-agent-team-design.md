# Frontend Stability & Performance Agent Team Design

> Date: 2026-03-28
> Status: Draft
> Approach: Autonomous Fix Agents (Approach C)

## Context

The frontend has two existing audit reports identifying significant stability and performance issues:
- `specs/active/frontend-optimization-report.md` — 1034 force-unwraps, 95 `late` keywords, 111 `setState` calls
- `docs/frontend-optimization-audit-report.md` — 75 categorized issues (18 HIGH, 30 MEDIUM, 27 LOW) across 5 areas

Despite substantial performance infrastructure already in place (ETag caching, CachedAsyncNotifier, ResourceCleanupMixin, request deduplication, offline queue), the codebase has systemic null safety issues and several memory leaks that need systematic remediation.

**Goal:** Use Claude Code's parallel Agent tool to autonomously scan and fix frontend stability issues in two phases.

## Design Overview

**Two-phase workflow** using temporary parallel agents (no persistent config files):

1. **Phase 1 — Fix Known Issues:** 5 parallel autonomous agents, each scanning + fixing a specific domain
2. **Phase 2 — Deep Scan:** 4 parallel scan-only agents covering dimensions not in existing reports

Each Phase 1 agent works end-to-end: verify issue exists → apply fix → verify fix compiles. All agents work in isolated worktrees to avoid conflicts. A final verification step runs after all agents complete.

---

## Phase 1: Fix Known Issues (5 Agents)

### Agent 1: Playback Null Safety

**Scope:** Audio playback providers and related files

**Target files:**
- `frontend/lib/features/podcast/presentation/providers/audio/audio_player_notifier.dart`
- `frontend/lib/features/podcast/presentation/providers/audio/podcast_playback_providers.dart`
- `frontend/lib/features/podcast/presentation/providers/audio/audio_playback_selectors.dart`
- `frontend/lib/features/podcast/presentation/providers/audio/playback_progress_policy.dart`
- Other playback-related provider files in `audio/` directory

**Known issues:** 103 force-unwraps in `podcast_playback_providers.dart` alone

**Fix rules:**
| Pattern | Fix |
|---------|-----|
| `obj!.property` | `obj?.property ?? defaultValue` |
| `list.first!` | `list.firstOrNull ?? default` |
| `map[key]!` | `map[key] ?? defaultValue` |
| `as Type` (where Type is non-nullable) | `is Type` pattern match with fallback |
| `late` where initialization timing uncertain | Convert to nullable + lazy init |

**Constraints:**
- Do NOT modify generated files (`*.g.dart`)
- Preserve existing behavior — null fallbacks must be semantically correct
- Add tests for any new null-handling logic

---

### Agent 2: Podcast Providers Null Safety

**Scope:** Non-playback podcast providers and services

**Target files:**
- `frontend/lib/features/podcast/presentation/providers/feed/` — feed providers
- `frontend/lib/features/podcast/presentation/providers/episode/` — episode detail providers
- `frontend/lib/features/podcast/presentation/providers/transcription/` — transcription providers
- `frontend/lib/features/podcast/presentation/providers/conversation/` — conversation providers
- `frontend/lib/features/podcast/presentation/providers/highlight/` — highlight providers
- `frontend/lib/features/podcast/presentation/providers/daily_report/` — daily report providers
- `frontend/lib/features/podcast/presentation/providers/subscription/` — subscription providers
- `frontend/lib/features/podcast/presentation/providers/discover/` — discover/search providers

**Fix rules:** Same as Agent 1

**Additional focus:**
- `summary_providers.dart` — SM-H2: `ref.watch` → `ref.read` for stable dependencies
- `podcast_stats_providers.dart` — SM-M2/M3: Add refresh mechanism
- `country_selector_provider.dart` — SM-M8: Fix fire-and-forget initialization

---

### Agent 3: Memory & Provider Lifecycle

**Scope:** Provider lifecycle, memory management, resource cleanup

**Target fixes (from audit report):**

| ID | Issue | Fix |
|----|-------|-----|
| SM-H1 | Manual `Map<int, Provider>` cache in summary/transcription/conversation providers never shrinks | Convert to Riverpod `family.autoDispose` pattern |
| SM-H4 | `conversation_providers.dart` session change fires overlapping requests | Add request deduplication via `Completer` pattern |
| NW-H3 | `authEventStream` getter creates new listener on every access, never cancelled | Cache the stream as single instance with proper cancellation |
| SM-M6 | Token refresh Timer.periodic every 60s | Increase interval to 3-5 minutes |
| SM-M7 | Summary/Transcription polling timers never stop | Ensure timers are cancelled on provider disposal |

**Target files:**
- `frontend/lib/features/podcast/presentation/providers/episode/episode_providers_cache.dart`
- `frontend/lib/features/podcast/presentation/providers/summary/`
- `frontend/lib/features/podcast/presentation/providers/transcription/`
- `frontend/lib/features/podcast/presentation/providers/conversation/`
- `frontend/lib/features/auth/data/auth_event.dart`
- `frontend/lib/features/auth/providers/auth_provider.dart`

> Note: `dio_client.dart` is NOT in this agent's scope to avoid merge conflicts with Agent 4.

---

### Agent 4: Network & Core

**Scope:** Network configuration, token management, offline infrastructure

**Target fixes:**

| ID | Issue | Fix |
|----|-------|-----|
| NW-H1 | Timeout config conflict: `ApiConstants` (300s) vs `AppConstants` (60s) | Consolidate to single source: 60s connect, 60s receive |
| NW-H2 | `_retryAttempts` map in `dio_client.dart` never evicts entries | Add LRU limit (max 50 entries) with periodic cleanup |
| NW-H6 | `SecureStorage.read()` on every request via platform channel | Add in-memory token cache with write-through |
| NW-H4 | `dio_cache_interceptor` in pubspec.yaml but never used | Remove from dependencies |
| NW-H5 | Offline queue not wired to connectivity changes | Connect `OfflineQueueService` to `ConnectivityNotifier` |
| NW-M6 | `loadPersistedQueue()` never called on startup | Call during `OfflineQueueService` initialization |
| NW-M7 | Duplicate `ApiConstants`/`AppConstants` classes | Consolidate into single `AppConfig` |

**Target files:**
- `frontend/lib/core/network/dio_client.dart`
- `frontend/lib/core/app/config/app_constants.dart`
- `frontend/lib/core/app/config/app_config.dart`
- `frontend/lib/core/network/offline/offline_queue_service.dart`
- `frontend/lib/core/network/connectivity/connectivity_provider.dart`
- `frontend/pubspec.yaml`

---

### Agent 5: UI Performance Quick Wins

**Scope:** High-impact UI rendering improvements

**Target fixes:**

| ID | Issue | Fix |
|----|-------|-----|
| UI-H1 | `GoogleFonts.outfit()`/`plusJakartaSans()` called 20+ times per theme build | Load fonts once at app startup, cache `TextStyle` instances |
| UI-H3 | Transcript search fires on every keystroke, no debounce | Add `DebounceTimer` (300ms) to search input |
| UI-M3 | Discover search fires API on every keystroke | Add `DebounceTimer` (500ms) to search field |
| SM-H3 | Audio player emits state every 500ms; widgets watching without `.select()` rebuild constantly | Ensure all consumers use `.select()` for granular rebuilds |
| UI-H4 | Highlights list re-sorted in every `build()` | Move sort to state change, cache result |
| UI-H2 | Transcript segments double-wrapped with RepaintBoundary | Remove outer wrapper, keep inner |

**Target files:**
- `frontend/lib/core/theme/app_theme.dart`
- `frontend/lib/features/podcast/presentation/widgets/transcript_display_widget.dart`
- `frontend/lib/features/podcast/presentation/pages/podcast_list_page.dart`
- `frontend/lib/features/podcast/presentation/widgets/global_podcast_player_host.dart`

---

## Phase 1 Verification

After all 5 agents complete, run in sequence:

1. `cd frontend && flutter analyze` — zero errors
2. `cd frontend && flutter test` — all existing tests pass
3. Manual review of changes in each worktree before merge
4. Merge worktrees one at a time, re-run tests after each merge

---

## Phase 2: Deep Scan (4 Scan-Only Agents)

Phase 2 launches after Phase 1 is fully verified and merged. These agents only scan and report — no code changes.

### Agent 6: Memory & Resource Leak Scanner

**Scan dimensions:**
- `StreamSubscription` cancellation in `dispose()`
- `Timer`/`AnimationController` proper cleanup
- Large object lifecycle (image cache, audio buffers)
- Riverpod `autoDispose` coverage
- Event listener accumulation in long-lived objects

**Output:** Issue list with severity, file location, line numbers, fix suggestion

### Agent 7: Widget Lifecycle & Rendering

**Scan dimensions:**
- `initState`/`dispose` pairing
- Unnecessary rebuilds in `didUpdateWidget`
- Missing `const` constructors
- `RepaintBoundary` placement effectiveness
- Large widgets that should be split
- `setState` candidates for Riverpod migration

**Output:** Widget rebuild frequency analysis + optimization suggestions

### Agent 8: State Management & Data Flow

**Scan dimensions:**
- Provider dependency cycle risks
- `ref.watch` vs `ref.read` correctness
- Race conditions in async operations (stale request overwrites)
- `Equatable` implementation on state classes
- Error state handling completeness

**Output:** Provider dependency graph + risk matrix

### Agent 9: Navigation & Architecture Quality

**Scan dimensions:**
- Route configuration rebuild overhead
- Deep link support completeness
- Inter-feature dependency direction violations
- Cross-feature code duplication
- Test coverage gap analysis

**Output:** Architecture health scorecard + improvement roadmap

---

## Phase 2 Output

A consolidated report at `docs/superpowers/specs/YYYY-MM-DD-frontend-deep-scan-report.md` containing:
- All findings categorized by severity (HIGH/MEDIUM/LOW)
- Cross-references to Phase 1 fixes
- Prioritized fix recommendations for the next iteration

---

## Execution Model

```
Phase 1:
  ┌─────────────────────┐
  │  Dispatch 5 Agents   │  (parallel, isolated worktrees)
  │  A1: Playback Null   │
  │  A2: Podcast Null    │
  │  A3: Memory/Lifecycle│
  │  A4: Network/Core    │
  │  A5: UI Perf         │
  └──────────┬──────────┘
             │
  ┌──────────▼──────────┐
  │  Verification Gate   │  flutter analyze + flutter test
  │  Merge worktrees     │
  └──────────┬──────────┘
             │
Phase 2:
  ┌─────────────────────┐
  │  Dispatch 4 Agents   │  (parallel, read-only)
  │  A6: Memory Scan     │
  │  A7: Widget Scan     │
  │  A8: State Mgmt Scan │
  │  A9: Architecture    │
  └──────────┬──────────┘
             │
  ┌──────────▼──────────┐
  │  Consolidated Report │
  │  → Decide next steps │
  └─────────────────────┘
```

## Agent Prompt Template

Each Phase 1 agent receives a structured prompt containing:

1. **Role definition** — what this agent is responsible for
2. **File list** — exact files to scan and modify
3. **Issue list** — specific issues from audit reports to verify and fix
4. **Fix rules** — patterns and examples for each fix type
5. **Constraints** — files NOT to modify (generated files, unrelated modules)
6. **Verification** — run `flutter analyze` on changed files before completing
7. **Output** — summary of changes made with before/after counts

Each Phase 2 agent receives:

1. **Role definition** — scan dimension and scope
2. **Scan rules** — what patterns to look for, how to assess severity
3. **Scope** — which directories/files to scan
4. **Output format** — structured findings with file, line, severity, suggestion
5. **Constraint** — NO code modifications, read-only analysis

## Constraints

- Generated files (`*.g.dart`) are NOT modified — regenerate with `build_runner` if needed
- Test files are updated only if existing tests break from changes
- Each agent works in an isolated git worktree to prevent merge conflicts
- The main conversation coordinates agent dispatch and result aggregation
- Phase 2 requires Phase 1 completion as prerequisite
