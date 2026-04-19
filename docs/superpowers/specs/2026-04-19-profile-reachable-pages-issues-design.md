# Profile Reachable Pages Issues — Design Spec (Round 2)

**Date:** 2026-04-19
**Scope:** External pages reachable from the Profile tab (Downloads, Episodes, Episode Detail, Daily Report, Highlights)

## Overview

Second audit pass found 23 issues in pages the Profile navigates to but that live outside the profile feature directory. No regressions introduced by the first round of fixes.

---

## Category 1: Concrete Bugs

### 1.1 Filter dialog Cancel does not restore previous state

**File:** `podcast_episodes_page_view.dart:368-443`
**Problem:** `_showFilterDialog` uses `StatefulBuilder` but the dialog controls mutate the parent widget's `_selectedFilter` and `_showOnlyWithSummary` fields directly via `setDialogState`. Pressing Cancel dismisses the dialog but the filter values are already changed — Cancel effectively applies the filter.
**Fix:** Capture the previous filter values before opening the dialog. On Cancel, restore them. On Apply, keep the new values.

### 1.2 "Mark all played/unplayed" actions are stubs

**File:** `podcast_episodes_page_view.dart:316-329`
**Problem:** Two action sheet items have `// TODO: Implement` bodies. Tapping them does nothing and the action sheet stays open.
**Fix:** Remove the stub items from the action sheet until the feature is implemented.

### 1.3 `_selectedSummaryText` not reset on episode switch

**File:** `podcast_episode_detail_page.dart:67`
**Problem:** When the user navigates between episodes (widget updates via `didUpdateWidget`), `_selectedSummaryText` retains the value from the previous episode.
**Fix:** Reset `_selectedSummaryText = ''` in `didUpdateWidget`.

---

## Category 2: Potential Crash

### 2.1 Missing mounted check in `_loadAndPlayEpisode`

**File:** `podcast_episode_detail_page.dart:161-193`
**Problem:** After `await ref.read(episodeDetailProvider(...).future)` (line 167), there is no `if (!mounted) return;` before proceeding to use `ref` again. If the widget is disposed during the async gap, this causes an error.
**Fix:** Add `if (!mounted) return;` after the await on line 169.

---

## Category 3: UX Issues

### 3.1 Empty `onTap` on download cards

**File:** `podcast_downloads_page.dart:255`
**Problem:** `_DownloadTaskCard` has `onTap: () {}` — produces a ripple effect but no action. Confusing for users.
**Fix:** Remove the `InkWell` wrapper or set `onTap: null` to disable the ripple. Alternatively, navigate to the episode detail page.

### 3.2 No pull-to-refresh on downloads list

**File:** `podcast_downloads_page.dart:203`
**Problem:** The `ListView.builder` is not wrapped in a refresh indicator. Users cannot manually refresh the download list.
**Fix:** Wrap the list in `AdaptiveRefreshIndicator` (matching the pattern used in history and subscriptions pages).

---

## Category 4: i18n / Hardcoded Strings

### 4.1 Hardcoded `'Episode #${task.episodeId}'` in downloads

**File:** `podcast_downloads_page.dart:287`
**Fix:** Add `podcast_episode_fallback_title` key to ARB files.

### 4.2 Hardcoded `'18+'` in episode detail header

**File:** `podcast_episode_detail_page_header.dart:73`
**Fix:** Add `podcast_explicit_label` key to ARB files.

### 4.3 Hardcoded `'Share'` tooltip in episode detail header

**File:** `podcast_episode_detail_page_header.dart:626`
**Fix:** Add `share` key to ARB files (or reuse existing if present).

### 4.4 Hardcoded `'Failed to share: $error'` in episode detail header

**File:** `podcast_episode_detail_page_header.dart:672`
**Fix:** Add `podcast_share_failed` key with `{error}` placeholder to ARB files.

### 4.5 Hardcoded `'More'` tooltip in episodes page view

**File:** `podcast_episodes_page_view.dart:307`
**Fix:** Add `more` key to ARB files (or reuse existing if present).

---

## Category 5: Dead Code / Code Quality

### 5.1 Dead `_buildTopButtonBar` method

**File:** `podcast_episode_detail_page_tabs.dart:13-16`
**Problem:** Marked as deprecated compatibility shim, never called.
**Fix:** Delete the method.

### 5.2 Duplicate switch in `_buildTabContent` / `_buildSingleTabContent`

**File:** `podcast_episode_detail_page_content.dart:36-79`
**Problem:** Two methods contain identical switch logic. `_buildTabContent` uses `_selectedTabIndex` directly; `_buildSingleTabContent` takes an `index` parameter.
**Fix:** Consolidate into a single `_buildTabWidget(episode, index)` method. `_buildTabContent` calls `_buildTabWidget(episode, _selectedTabIndex)`.

### 5.3 Redundant branches in `_formatPlaybackPosition`

**File:** `profile_history_page.dart:436-444`
**Problem:** Both `hours > 0` and `remainingSeconds > 0` branches return the same `TimeFormatter.formatDuration(duration)`.
**Fix:** Combine into `if (hours > 0 || remainingSeconds > 0)`.

---

## Category 6: Memory / Performance

### 6.1 CurvedAnimation leak in daily report and highlights calendar dialogs

**Files:** `podcast_daily_report_page.dart:495-496`, `podcast_highlights_page.dart:454-456`
**Problem:** `CurvedAnimation` created inside `transitionBuilder` of `showGeneralDialog` is never disposed. Each dialog open leaks a listener.
**Fix:** Use `AnimatedBuilder` with the parent animation directly, applying the curve via `Curves.easeOutCubic.transform()` instead of creating a `CurvedAnimation`. Or capture and dispose in the dialog's lifecycle.

### 6.2 `ref.read(highlightsProvider)` on every scroll event

**File:** `podcast_highlights_page.dart:74`
**Problem:** `_onScroll` calls `ref.read(highlightsProvider)` on every scroll event to check `hasMore`.
**Fix:** Cache `hasMore` as a local field, updated when the provider state changes (via `ref.listen` in `build` or a provider select).

---

## Category 7: Style / Consistency

### 7.1 Missing explicit `removeListener` before dispose

**File:** `profile_subscriptions_page.dart:47-49`
**Problem:** `initState` adds `_scrollController.addListener(_onScroll)` but `dispose` only calls `_scrollController.dispose()` without explicit `removeListener`. While `dispose()` cleans up internally, this is inconsistent with the highlights page pattern.
**Fix:** Add `_scrollController.removeListener(_onScroll)` before `_scrollController.dispose()`.

---

## Summary

| Category | Count |
|----------|-------|
| Concrete bugs | 3 |
| Potential crash | 1 |
| UX issues | 2 |
| i18n hardcoded strings | 5 |
| Dead code / code quality | 3 |
| Memory / performance | 2 |
| Style / consistency | 1 |
| **Total** | **17 unique issues** |

Note: Issues 5 and 7 from the exploration (CurvedAnimation in both daily report and highlights) are combined into issue 6.1. Issues 22 and 23 are included as 5.3 and 7.1 respectively. Total unique issues: 17.
