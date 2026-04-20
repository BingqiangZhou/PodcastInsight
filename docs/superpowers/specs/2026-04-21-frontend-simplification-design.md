# Frontend Deep Simplification Design

Date: 2026-04-21

## Context

The frontend (~70,000 lines, 265 Dart files) has grown to enterprise-level complexity for a personal app. This design covers a deep refactoring to simplify architecture while preserving all 5 platforms (iOS/Android/Linux/macOS/Windows), Cupertino native style on iOS, and bilingual i18n (EN/ZH).

**Estimated total reduction: ~3,500 lines across 5 areas.**

---

## Area 1: Dead Code Removal (~290 lines)

### Files to delete

| File | Lines | Reason |
|------|-------|--------|
| `core/services/spotlight_service.dart` | 147 | All methods are TODO stubs with no implementation |
| `core/services/home_widget_service.dart` | 114 | Defines widget IDs but no native implementations exist in android/ or ios/ |
| `core/events/server_config_events.dart` | ~30 | Single-server personal app doesn't need server-switch event bus |

### Cleanup required after deletion

- Remove all imports of these 3 files across the codebase
- Remove `ServerConfigVersionNotifier` listener from any provider that watches server config changes
- Remove any registration/calls in `main.dart` or bootstrap code
- Remove `ResourceCleanupMixin` from `core/utils/resource_cleanup_mixin.dart` (~60 lines) — replace usages with Riverpod's `ref.onDispose` and `ref.listen` lifecycle

---

## Area 2: Podcast Providers Merge (25 files → ~12 files, ~2,000 lines reduced)

### Current structure

```
providers/
  base/cached_async_notifier.dart          (131 lines)
  base/deduplicating_notifier.dart         (50 lines)
  audio_handler.dart
  audio_persistence_notifier.dart
  audio_playback_rate_notifier.dart
  audio_playback_selectors.dart
  audio_server_sync_notifier.dart
  audio_sleep_timer_notifier.dart
  podcast_core_providers.dart
  podcast_providers.dart
  podcast_feed_providers.dart
  podcast_episodes_providers.dart
  podcast_subscription_providers.dart
  podcast_playback_providers.dart
  podcast_playback_helpers.dart
  podcast_playback_queue_controller.dart
  podcast_player_host_layout_provider.dart
  podcast_player_ui_state.dart
  podcast_search_provider.dart
  podcast_discover_provider.dart
  podcast_highlights_providers.dart
  podcast_stats_providers.dart
  podcast_daily_report_providers.dart
  conversation_providers.dart
  transcription_providers.dart
  summary_providers.dart
  country_selector_provider.dart
```

### Target structure

```
providers/
  audio_player_provider.dart       ← audio_handler + persistence + rate + selectors + sync
  audio_sleep_timer_provider.dart  ← kept separate (independent timer logic)
  podcast_providers.dart           ← core + subscription + stats
  podcast_feed_providers.dart      ← kept (independent feed logic)
  podcast_episodes_providers.dart  ← kept (independent episodes logic)
  podcast_playback_providers.dart  ← playback + helpers + queue + ui_state + host_layout
  podcast_search_provider.dart     ← search + discover + country_selector
  podcast_highlights_providers.dart ← kept (independent)
  podcast_daily_report_providers.dart ← kept (independent)
  conversation_providers.dart      ← conversation + transcription + summary
```

### Key changes

1. **Delete `CachedAsyncNotifier` and `DeduplicatingNotifier` base classes** (181 lines combined)
   - Replace with `@riverpod` annotation + `keepAlive` for caching
   - Replace request deduplication with simple `Map<String, Future>` in providers that need it

2. **Audio subsystem: 6 files → 2 files**
   - `audio_player_provider.dart`: merge handler + persistence + rate + selectors + server sync
   - `audio_sleep_timer_provider.dart`: kept as-is (timer is self-contained)

3. **AI features: 3 files → 1 file**
   - Merge conversation, transcription, and summary providers (all relate to AI content generation)

4. **Search: 3 files → 1 file**
   - Merge search, discover, and country_selector (all relate to podcast discovery)

5. **Core + subscription + stats: 3 files → 1 file**
   - These are thin providers that share podcast data sources

6. **Playback: 5 files → 1 file**
   - Merge playback providers, helpers, queue controller, ui_state, and host_layout provider

### Migration approach

- Merge one group at a time in this order: (1) delete base classes, (2) audio, (3) AI, (4) search, (5) core+subscription, (6) playback
- After each merge, run `flutter test` to verify
- Update all imports after each merge

---

## Area 3: Network Layer Simplification (881 → ~300 lines)

### Current state

`DioClient` (881 lines) manages: base config, token refresh/caching/injection, ETag caching (in-memory + expiry), retry with exponential backoff, request deduplication, cancel tokens, 8 custom exception types.

### Changes

1. **Exceptions: 8 types → 4 types**
   - `NetworkException` — network unavailable, timeout, DNS failure
   - `AuthException` — merge 401 AuthenticationException + 403 AuthorizationException
   - `ServerException` — merge all 4xx/5xx (NotFoundException, ConflictException, ValidationException, ServerException)
   - `UnknownException` — catch-all
   - Delete `NetworkErrorCode` enum, simplify `exception_parser.dart`

2. **ETag caching** — Replace manual implementation with `dio_cache_interceptor` package

3. **Retry logic** — Replace manual exponential backoff with `dio_retry_plus` or a simple 20-line interceptor

4. **Request deduplication** — Simplify to a `Map<String, Future>` with 15-20 lines of code, remove the complex abstraction

5. **Token management** — Keep as-is (genuinely needed), but remove unnecessary caching layer

### Files affected

- `core/network/dio_client.dart` (881 → ~300 lines)
- `core/network/exceptions/` (2 files → 1 file, ~80 → ~40 lines)
- `pubspec.yaml` — add `dio_cache_interceptor`, optionally `dio_retry_plus`

---

## Area 4: Theme System Simplification (~210 lines reduced)

### What stays unchanged

- `buildCupertinoTheme()` — independent, clean
- `theme_provider.dart` — clear logic, no changes
- `app_spacing.dart` — complete 4-point grid system
- `_buildColorScheme()` — already platform-agnostic
- `_buildTextTheme()` — already platform-agnostic
- Adaptive widget library (15 files) — fully preserved

### Changes to `app_colors.dart` (AppThemeExtension)

1. **4 const variants → 2 base + 2 derived methods**
   - Keep `light` and `dark` as const instances
   - Replace `lightIOS` and `darkIOS` with factory methods that call `light.copyWith(...)` and `dark.copyWith(...)` overriding only radii and shadows
   - The differences are only: cardRadius (16 vs 14), buttonRadius (14 vs 10), navItemRadius (12 vs 10), itemRadius (10 vs 8), and zero shadows

### Changes to `app_theme.dart`

2. **Delete responsive re-exports** (lines 88-105)
   - Remove 4 static methods that just proxy `ResponsiveHelpers`
   - Update callers to use `ResponsiveHelpers` directly

3. **Extract named style helpers to `AppTextStyles`** (lines 20-84, ~65 lines)
   - Move `monoStyle`, `transcriptBody`, `caption`, `metaSmall`, `navLabel` to a new `core/constants/app_text_styles.dart`
   - These are pure functions with no theme dependency

4. **Consolidate `isIOS` hardcoded values in `_buildTheme()`**
   - Replace scattered `isIOS ? X : Y` with `extension.cardRadius`, `extension.buttonRadius` etc.
   - This makes all platform differences driven by `AppThemeExtension`, not hardcoded in theme building

### Changes to `app_radius.dart`

5. **Delete `AppRadiusExtension`** (lines 89-116, 28 lines)
   - This context extension duplicates `appThemeOf(context)` functionality
   - Update callers to use `appThemeOf(context).cardRadius` etc.

---

## Area 5: Utility Simplification (~300 lines reduced)

### TextProcessingCache (385 → ~80 lines)

Current: Full LRU cache with memory pressure awareness, periodic cleanup, HTML entity decoding, CSS noise removal, sentence splitting, CJK text recovery.

Simplification:
- Replace LRU cache with simple `Map<String, _Entry>` with timestamp expiry (20 lines)
- Replace hand-written HTML sanitization with `html` package's `parse()` + simple selectors (already a dependency)
- Remove memory pressure monitoring, periodic cleanup timer, CSS property stripping
- Keep only what's actually used: HTML → plain text conversion + basic caching

### ResourceCleanupMixin → delete

- Remove mixin entirely (~60 lines)
- Replace usages in StatefulWidgets with Riverpod's `ref.onDispose` pattern
- This mixin is redundant in a Riverpod project

---

## Execution Order

1. Dead code removal (lowest risk, no behavior change)
2. Utility simplification (isolated changes)
3. Theme system simplification (visual but low-risk)
4. Network layer simplification (requires careful testing)
5. Podcast providers merge (highest risk, largest change, do last in sub-groups)

Each step: implement → `flutter test` → verify on at least one platform → proceed.

---

## What We Are NOT Changing

- All 5 platform targets (iOS, Android, Linux, macOS, Windows)
- Cupertino native style on iOS (adaptive widget library fully preserved)
- Bilingual i18n (EN/ZH, 637 strings)
- Material 3 design system foundation
- GoRouter navigation
- Drift database layer
- Test coverage (all existing tests must continue to pass)
