# Profile Reachable Pages Round 3 Fixes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix 14 remaining issues in pages reachable from Profile tab — bugs, UX, i18n, dead code, and code quality.

**Architecture:** Fix issues in priority order (bugs first, then UX, then i18n, then cleanup). Each task produces a self-contained commit.

**Tech Stack:** Flutter 3.8+, Dart, Riverpod, GoRouter, flutter_localizations (ARB files)

## Files Modified

| File | Issues |
|------|--------|
| `frontend/lib/features/podcast/presentation/pages/podcast_episodes_page_view.dart` | 1.1 |
| `frontend/lib/features/podcast/presentation/pages/podcast_highlights_page.dart` | 1.2, 4.2 |
| `frontend/lib/features/podcast/presentation/pages/podcast_episode_detail_page_content.dart` | 1.3 |
| `frontend/lib/features/podcast/presentation/pages/podcast_daily_report_page.dart` | 1.4, 4.1 |
| `frontend/lib/features/profile/presentation/providers/profile_ui_providers.dart` | 1.5 |
| `frontend/lib/features/podcast/presentation/pages/podcast_downloads_page.dart` | 2.1 |
| `frontend/lib/features/profile/presentation/pages/profile_history_page.dart` | 2.2, 3.1 |
| `frontend/lib/features/podcast/presentation/pages/podcast_episode_detail_page.dart` | 2.3, 3.2 |
| `frontend/lib/features/podcast/presentation/pages/podcast_episode_detail_page_header.dart` | 5.1 |
| `frontend/lib/core/localization/app_localizations_en.arb` | new i18n keys |
| `frontend/lib/core/localization/app_localizations_zh.arb` | new i18n keys |

---

## Task 1: Remove empty more menu (Spec 1.1)

**File:** `frontend/lib/features/podcast/presentation/pages/podcast_episodes_page_view.dart`

The `_showMoreMenu` method (line 311) opens an action sheet with `actions: []` — dead-end UX.

Delete the `_showMoreMenu` method entirely (lines 311-318):

```dart
  void _showMoreMenu(AppLocalizations l10n) {
    showAdaptiveActionSheet(
      context: context,
      title: Text(l10n.podcast_episodes),
      actions: [],
      cancelWidget: Text(l10n.cancel),
    );
  }
```

Then find the caller. The more button is likely in the AppBar actions. Search for `_showMoreMenu` usage and remove the IconButton or action that triggers it. The exact location needs to be found by searching for `_showMoreMenu` calls in the same file.

Steps:
- [ ] Find and remove the `_showMoreMenu` method
- [ ] Find and remove the button/action that calls `_showMoreMenu`
- [ ] Run: `cd frontend && flutter analyze lib/features/podcast/presentation/pages/podcast_episodes_page_view.dart`
- [ ] Commit: `fix(podcast): remove empty more menu from episodes page`

---

## Task 2: Add error feedback in highlights load-more (Spec 1.2)

**File:** `frontend/lib/features/podcast/presentation/pages/podcast_highlights_page.dart`

The `_loadMoreHighlights` method (lines 100-117) has `try/finally` but no `catch`. Add error handling.

Current:
```dart
  Future<void> _loadMoreHighlights() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final selectedDate = ref.read(selectedHighlightDateProvider);
      await ref.read(highlightsProvider.notifier).loadNextPage(date: selectedDate);
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }
```

Replace with:
```dart
  Future<void> _loadMoreHighlights() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final selectedDate = ref.read(selectedHighlightDateProvider);
      await ref.read(highlightsProvider.notifier).loadNextPage(date: selectedDate);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.podcast_highlights_load_more_error),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }
```

Add the ARB key `podcast_highlights_load_more_error`:
- EN: `"Failed to load more highlights. Please try again."`
- ZH: `"加载更多精选失败，请重试。"`

Steps:
- [ ] Add `podcast_highlights_load_more_error` ARB key to both EN and ZH files
- [ ] Run `cd frontend && flutter gen-l10n`
- [ ] Add `catch` block with SnackBar feedback in `_loadMoreHighlights`
- [ ] Run: `cd frontend && flutter analyze lib/features/podcast/presentation/pages/podcast_highlights_page.dart`
- [ ] Commit: `fix(podcast): add error feedback when loading more highlights fails`

---

## Task 3: Guard postFrameCallback scheduling in AI summary (Spec 1.3)

**File:** `frontend/lib/features/podcast/presentation/pages/podcast_episode_detail_page_content.dart`

Add a deduplication guard to prevent multiple `addPostFrameCallback` calls.

1. Add a field to the state class (after existing fields, near line 20):
```dart
  bool _summaryUpdateScheduled = false;
```

2. Wrap the existing `addPostFrameCallback` call (lines 214-222) with the guard. Current:
```dart
    if (episodeSummary != null &&
        episodeSummary.isNotEmpty &&
        !summaryState.hasSummary &&
        !summaryState.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          summaryNotifier.updateSummary(
            episodeSummary,
            modelUsed: episode.summaryModelUsed,
            processingTime: episode.summaryProcessingTime,
          );
        }
      });
    }
```

Replace with:
```dart
    if (episodeSummary != null &&
        episodeSummary.isNotEmpty &&
        !summaryState.hasSummary &&
        !summaryState.isLoading &&
        !_summaryUpdateScheduled) {
      _summaryUpdateScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _summaryUpdateScheduled = false;
        if (mounted) {
          summaryNotifier.updateSummary(
            episodeSummary,
            modelUsed: episode.summaryModelUsed,
            processingTime: episode.summaryProcessingTime,
          );
        }
      });
    }
```

Steps:
- [ ] Add `bool _summaryUpdateScheduled = false;` field
- [ ] Add `!_summaryUpdateScheduled` to condition and wrap callback with guard
- [ ] Run: `cd frontend && flutter analyze lib/features/podcast/presentation/pages/podcast_episode_detail_page_content.dart`
- [ ] Commit: `fix(podcast): prevent duplicate AI summary update callbacks`

---

## Task 4: Fix duplicate error message in daily report (Spec 1.4)

**File:** `frontend/lib/features/podcast/presentation/pages/podcast_daily_report_page.dart`

Lines 203-227 show the error state. The subtitle at line 208 and body text at line 213 use the same l10n key.

Current (line 213):
```dart
            Text(
              l10n.podcast_failed_to_load_feed,
```

Replace the body text with a new key. Add ARB key `podcast_daily_report_error_hint`:
- EN: `"An error occurred while loading the report."`
- ZH: `"加载报告时发生错误。"`

Then replace line 213:
```dart
            Text(
              l10n.podcast_daily_report_error_hint,
```

Steps:
- [ ] Add `podcast_daily_report_error_hint` ARB key to both EN and ZH files
- [ ] Run `cd frontend && flutter gen-l10n`
- [ ] Replace duplicate `l10n.podcast_failed_to_load_feed` with `l10n.podcast_daily_report_error_hint`
- [ ] Run: `cd frontend && flutter analyze lib/features/podcast/presentation/pages/podcast_daily_report_page.dart`
- [ ] Commit: `fix(podcast): use distinct error messages in daily report panel`

---

## Task 5: Fix notification preference race condition (Spec 1.5)

**File:** `frontend/lib/features/profile/presentation/providers/profile_ui_providers.dart`

Current `NotificationPreferenceNotifier` (lines 1-40):
```dart
class NotificationPreferenceNotifier extends Notifier<bool> {
  static const String _storageKey = 'profile_notifications_enabled';

  @override
  bool build() {
    _loadFromStorage();
    return false;
  }

  Future<void> _loadFromStorage() async {
    try {
      final storage = ref.read(localStorageServiceProvider);
      final saved = await storage.getBool(_storageKey);
      if (saved != null) {
        state = saved;
      }
    } catch (e) {
      logger.AppLogger.debug('Error loading notification preference: $e');
    }
  }

  Future<void> setEnabled(bool value) async {
    state = value;
    try {
      final storage = ref.read(localStorageServiceProvider);
      await storage.saveBool(_storageKey, value);
    } catch (e) {
      logger.AppLogger.debug('Error saving notification preference: $e');
    }
  }
}
```

Replace with:
```dart
class NotificationPreferenceNotifier extends Notifier<bool> {
  static const String _storageKey = 'profile_notifications_enabled';
  bool _isInitialized = false;

  @override
  bool build() {
    _loadFromStorage();
    return false;
  }

  Future<void> _loadFromStorage() async {
    try {
      final storage = ref.read(localStorageServiceProvider);
      final saved = await storage.getBool(_storageKey);
      if (saved != null) {
        state = saved;
      }
    } catch (e) {
      logger.AppLogger.warning('Error loading notification preference: $e');
    } finally {
      _isInitialized = true;
    }
  }

  Future<void> setEnabled(bool value) async {
    state = value;
    if (!_isInitialized) return;
    try {
      final storage = ref.read(localStorageServiceProvider);
      await storage.saveBool(_storageKey, value);
    } catch (e) {
      logger.AppLogger.warning('Error saving notification preference: $e');
    }
  }
}
```

Note: Also changed `debug` to `warning` for error logging.

Steps:
- [ ] Add `_isInitialized` flag and guard
- [ ] Change `logger.AppLogger.debug` to `logger.AppLogger.warning` for error cases
- [ ] Run: `cd frontend && flutter analyze lib/features/profile/presentation/providers/profile_ui_providers.dart`
- [ ] Commit: `fix(profile): prevent notification preference race condition`

---

## Task 6: Improve error states in downloads and history pages (Spec 2.1, 2.2)

**Files:**
- `frontend/lib/features/podcast/presentation/pages/podcast_downloads_page.dart`
- `frontend/lib/features/profile/presentation/pages/profile_history_page.dart`

### Downloads page (Spec 2.1)

Line 78, current:
```dart
                      error: (e, _) => Center(child: Text(e.toString())),
```

Replace with a proper error widget. Since this is inside a `SliverFillRemaining` child, the replacement should be:
```dart
                      error: (e, _) => Center(
                        child: Padding(
                          padding: EdgeInsets.all(context.spacing.lg),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 56,
                                color: theme.colorScheme.error,
                              ),
                              SizedBox(height: context.spacing.lg),
                              Text(
                                l10n.podcast_downloads_load_error,
                                style: theme.textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: context.spacing.md),
                              FilledButton.tonal(
                                onPressed: () => ref.invalidate(downloadsListProvider),
                                child: Text(l10n.retry),
                              ),
                            ],
                          ),
                        ),
                      ),
```

Add ARB key `podcast_downloads_load_error`:
- EN: `"Failed to load downloads. Please try again."`
- ZH: `"加载下载列表失败，请重试。"`

Also check if `l10n.retry` key already exists. If not, add it:
- EN: `"Retry"`
- ZH: `"重试"`

### History page (Spec 2.2)

The error state at lines 160-189 already has an error icon and message but no retry button. Add a retry button before the closing `]` of the Column (before line 189).

After the `Text(error.toString(), ...)` widget and its `SizedBox`, add:
```dart
                              SizedBox(height: context.spacing.md),
                              FilledButton.tonal(
                                onPressed: () => ref.invalidate(playbackHistoryLiteProvider),
                                child: Text(l10n.retry),
                              ),
```

Verify that `playbackHistoryLiteProvider` is the correct provider for the history page. Check the file's imports and `ref.watch` calls to confirm.

Steps:
- [ ] Add `podcast_downloads_load_error` and `retry` ARB keys (if `retry` doesn't exist) to both EN and ZH files
- [ ] Run `cd frontend && flutter gen-l10n`
- [ ] Replace bare error state in downloads page with proper error widget + retry
- [ ] Add retry button to history page error state
- [ ] Run: `cd frontend && flutter analyze`
- [ ] Commit: `fix(podcast): improve error states with retry buttons in downloads and history`

---

## Task 7: Fix auto-play on didUpdateWidget (Spec 2.3)

**File:** `frontend/lib/features/podcast/presentation/pages/podcast_episode_detail_page.dart`

The `didUpdateWidget` method (around line 367) calls `_loadAndPlayEpisode()` when the episode ID changes, which auto-plays. The `initState` comment says "Don't auto-play episode when page loads" but didUpdateWidget violates this.

**Important context:** `_loadAndPlayEpisode` does two things:
1. Loads episode detail data
2. Triggers playback

We need to split these concerns. However, looking at the method more carefully, the name is `_loadAndPlayEpisode` but it may be the primary way data gets loaded. The fix is to NOT call `_loadAndPlayEpisode` from `didUpdateWidget` — instead, just reload the providers without triggering playback.

In `didUpdateWidget` (around lines 367-379), change:
```dart
        _loadAndPlayEpisode();
        _loadTranscriptionStatus();
```

to:
```dart
        _loadTranscriptionStatus();
```

This removes the auto-play call. The provider will still reload data via `ref.watch` when the episode ID changes (through the family provider), so the episode data will load — just without auto-playing.

However, we need to verify that removing `_loadAndPlayEpisode()` doesn't break data loading. Read the method carefully to understand what it does beyond playback, and ensure providers are properly invalidated/watched on episode change.

Steps:
- [ ] Read `_loadAndPlayEpisode` to understand its full behavior
- [ ] Determine if removing the call breaks data loading
- [ ] If data loading is handled by watched providers, remove `_loadAndPlayEpisode()` from `didUpdateWidget`
- [ ] If data loading is NOT handled elsewhere, extract just the data-loading part
- [ ] Run: `cd frontend && flutter analyze lib/features/podcast/presentation/pages/podcast_episode_detail_page.dart`
- [ ] Commit: `fix(podcast): prevent auto-play when navigating between episodes`

---

## Task 8: Fix hardcoded fallback strings (Spec 3.1, 3.2)

**Files:**
- `frontend/lib/features/profile/presentation/pages/profile_history_page.dart`
- `frontend/lib/features/podcast/presentation/pages/podcast_episode_detail_page.dart`

### History page (Spec 3.1)

Add ARB keys:
- `not_available`: EN `"N/A"`, ZH `"暂无"`
- `time_unknown`: EN `"--:--"`, ZH `"--:--"`

Line 415, replace:
```dart
  String _formatPlayedAt(DateTime? lastPlayedAt) => lastPlayedAt == null
      ? '--'
      : TimeFormatter.formatFullDateTime(lastPlayedAt);
```
with:
```dart
  String _formatPlayedAt(BuildContext context, DateTime? lastPlayedAt) =>
      lastPlayedAt == null
          ? context.l10n.not_available
          : TimeFormatter.formatFullDateTime(lastPlayedAt);
```

Line 423-426, replace:
```dart
    final totalDuration = episode.audioDuration != null
        ? episode.formattedDuration
        : '--:--';
```
with:
```dart
    final totalDuration = episode.audioDuration != null
        ? episode.formattedDuration
        : context.l10n.time_unknown;
```

Then find the caller of `_formatPlayedAt` and update it to pass `context`.

### Episode detail page (Spec 3.2)

Line 302, replace:
```dart
                  tooltip: AppLocalizations.of(context)?.podcast_tab_chat ?? 'Chat',
```
with:
```dart
                  tooltip: AppLocalizations.of(context)?.podcast_tab_chat ?? const AppLocalizationsEn().podcast_tab_chat,
```

Or more simply, since `AppLocalizationsEn` has all keys:
```dart
                  tooltip: (AppLocalizations.of(context) ?? const AppLocalizationsEn()).podcast_tab_chat,
```

Steps:
- [ ] Add `not_available` and `time_unknown` ARB keys to both files
- [ ] Run `cd frontend && flutter gen-l10n`
- [ ] Fix `_formatPlayedAt` to accept context and use l10n
- [ ] Fix `_buildProgressText` to use l10n for `'--:--'`
- [ ] Update callers of `_formatPlayedAt` to pass context
- [ ] Fix episode detail page `'Chat'` fallback
- [ ] Run: `cd frontend && flutter analyze`
- [ ] Commit: `fix(i18n): replace hardcoded fallback strings with localized keys`

---

## Task 9: Remove dead code — unused source parameters (Spec 4.1, 4.2)

**Files:**
- `frontend/lib/features/podcast/presentation/pages/podcast_daily_report_page.dart`
- `frontend/lib/features/podcast/presentation/pages/podcast_highlights_page.dart`

### Daily report page (Spec 4.1)

Lines 27-29, change:
```dart
  const PodcastDailyReportPage({super.key, this.initialDate, this.source});

  final DateTime? initialDate;
  final String? source;
```
to:
```dart
  const PodcastDailyReportPage({super.key, this.initialDate});

  final DateTime? initialDate;
```

Then find and update all call sites that pass `source:` to the constructor. Check the router (app_router.dart) and any navigation helpers.

### Highlights page (Spec 4.2)

Lines 29-33, change:
```dart
  const PodcastHighlightsPage({super.key, this.initialDate, this.source});

  final DateTime? initialDate;
  final String? source;
```
to:
```dart
  const PodcastHighlightsPage({super.key, this.initialDate});

  final DateTime? initialDate;
```

Then find and update all call sites.

Steps:
- [ ] Remove `source` from daily report page constructor and field
- [ ] Remove `source` from highlights page constructor and field
- [ ] Update call sites in router and navigation helpers
- [ ] Run: `cd frontend && flutter analyze`
- [ ] Commit: `refactor(podcast): remove unused source parameter from daily report and highlights pages`

---

## Task 10: Extract density getter in episode detail header (Spec 5.1)

**File:** `frontend/lib/features/podcast/presentation/pages/podcast_episode_detail_page_header.dart`

The pattern `_isCompactPhoneLayout ? HeaderCapsuleActionButtonDensity.compact : HeaderCapsuleActionButtonDensity.regular` appears 12 times.

Add a getter near the existing `_isCompactPhoneLayout` getter (around line 4-5):
```dart
  HeaderCapsuleActionButtonDensity get _buttonDensity =>
      _isCompactPhoneLayout
          ? HeaderCapsuleActionButtonDensity.compact
          : HeaderCapsuleActionButtonDensity.regular;
```

Then replace all 12 occurrences of:
```dart
_isCompactPhoneLayout ? HeaderCapsuleActionButtonDensity.compact : HeaderCapsuleActionButtonDensity.regular
```
with:
```dart
_buttonDensity
```

Note: Skip the one occurrence that has additional logic (`_isCompactPhoneLayout || compact` on lines 452-456) — that one should remain as-is since it also checks the `compact` parameter.

Steps:
- [ ] Add `_buttonDensity` getter
- [ ] Replace 11 occurrences (skip the one at lines 452-456 with `compact` parameter)
- [ ] Run: `cd frontend && flutter analyze lib/features/podcast/presentation/pages/podcast_episode_detail_page_header.dart`
- [ ] Commit: `refactor(podcast): extract button density getter in episode detail header`

---

## Task 11: Extract shared calendar widget from daily report and highlights (Spec 5.2)

**Files:**
- `frontend/lib/features/podcast/presentation/pages/podcast_daily_report_page.dart`
- `frontend/lib/features/podcast/presentation/pages/podcast_highlights_page.dart`

This is the largest refactor. The two pages share ~300 lines of nearly identical calendar code. Extract a shared mixin or helper.

**Create:** `frontend/lib/features/podcast/presentation/widgets/calendar_panel_helper.dart`

The shared widget/mixin should accept:
- `calendarPanelKey` (String) — unique key for the panel
- `calendarKey` (String) — unique key for the calendar widget
- `datesPanelTitle` (String) — localized title for dates panel
- `datesProvider` — the provider that provides the list of available dates
- `selectedDateProvider` — the provider for the currently selected date
- `onDateSelected` — callback when a date is selected

Given the complexity and the fact that providers differ in type (one returns `PodcastDailyReportDateItem` list, the other returns `DateTime` list), the simplest approach is a shared static helper class with methods that take the varying parts as parameters.

Alternatively, since the main structural code is identical but the provider types differ, extract just the shared UI parts (`_showCalendarPanel` transition/animation code, `_buildCalendarDayCell` styling) as static methods, and keep the data-binding in each page.

**Pragmatic approach:** Extract `_buildCalendarDayCell` as a shared static method (since it's purely visual with identical logic), and extract the dialog transition/animation boilerplate. The data-binding parts stay in each page since they use different providers.

Steps:
- [ ] Create `calendar_panel_helper.dart` with shared calendar day cell builder
- [ ] Refactor both pages to use the shared helper for `_buildCalendarDayCell`
- [ ] Run: `cd frontend && flutter analyze`
- [ ] Commit: `refactor(podcast): extract shared calendar day cell builder`

---

## Task 12: Final verification

- [ ] Run full analysis: `cd frontend && flutter analyze`
- [ ] Run tests: `cd frontend && flutter test`
- [ ] Fix any issues found
