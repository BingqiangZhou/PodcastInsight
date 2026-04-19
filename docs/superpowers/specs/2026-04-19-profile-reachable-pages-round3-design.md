# Profile Reachable Pages Issues — Design Spec (Round 3)

**Date:** 2026-04-19
**Scope:** Third audit pass of all pages reachable from Profile tab
**Preceding rounds:** Round 1 fixed 20 issues, Round 2 fixed 17 issues, no regressions

## Overview

Third audit pass found 14 remaining issues across 8 files. No regressions from previous rounds.

---

## Category 1: Concrete Bugs

### 1.1 Empty "more" action sheet in episodes page

**File:** `podcast_episodes_page_view.dart:311-318`
**Problem:** `_showMoreMenu` opens an action sheet with `actions: []` — user sees a title and cancel button but zero actions. Dead-end UX.
**Fix:** Remove the `_showMoreMenu` method and the more button that triggers it, since there are no actions to show.

### 1.2 No error feedback in highlights load-more

**File:** `podcast_highlights_page.dart:100-117`
**Problem:** `_loadMoreHighlights` has `try/finally` but no `catch` — errors are silently swallowed. The loading spinner disappears but the user gets no feedback that loading more failed.
**Fix:** Add a `catch` block that logs the error and shows a SnackBar with a localized error message.

### 1.3 Unbounded postFrameCallback scheduling in AI summary

**File:** `podcast_episode_detail_page_content.dart:214-222`
**Problem:** `addPostFrameCallback` is called during every `build` when the condition holds, with no deduplication. Rapid rebuilds queue multiple `updateSummary` calls.
**Fix:** Add a `_summaryUpdateScheduled` boolean guard. Set it to `true` when scheduling, reset to `false` inside the callback.

### 1.4 Duplicate error message in daily report

**File:** `podcast_daily_report_page.dart:208,213`
**Problem:** Same `l10n.podcast_failed_to_load_feed` key used as panel subtitle AND error body text — user sees the same message twice.
**Fix:** Use `l10n.podcast_failed_to_load_feed` as subtitle only. Replace the body text with `l10n.podcast_daily_report_error_hint` (new key, e.g., "Pull down or tap the button below to retry.").

### 1.5 Notification preference race condition

**File:** `profile_ui_providers.dart:16-25`
**Problem:** `_loadFromStorage` is fire-and-forget. If the user toggles the switch before the async load completes, the loaded value can overwrite the user's choice.
**Fix:** Add an `_isInitialized` flag. `build()` returns `false`. `_loadFromStorage` sets the flag after loading. `setEnabled` skips if not initialized (shouldn't happen in practice since the UI waits for build, but the guard prevents the race).

---

## Category 2: UX Issues

### 2.1 Bare error state in downloads page

**File:** `podcast_downloads_page.dart:78`
**Problem:** Error state shows raw `Text(e.toString())` — no styling, no retry button, no localization.
**Fix:** Replace with a proper error widget matching other pages: error icon + localized message + retry button that invalidates the provider.

### 2.2 No retry in history error state

**File:** `profile_history_page.dart:160-189`
**Problem:** Error state shows the error message but has no retry button. User must rely on pull-to-refresh.
**Fix:** Add a "Retry" `FilledButton.tonal` that invalidates the history provider, matching the pattern used in daily report page.

### 2.3 Auto-play on didUpdateWidget contradicts design intent

**File:** `podcast_episode_detail_page.dart:367-379`
**Problem:** `didUpdateWidget` calls `_loadAndPlayEpisode()` when episode ID changes, but `initState` has a comment saying "Don't auto-play episode when page loads." The auto-play on update contradicts this intent.
**Fix:** Replace `_loadAndPlayEpisode()` with a `_loadEpisodeData()` method that loads episode data without triggering playback. The original `_loadAndPlayEpisode` stays for explicit user-initiated play.

---

## Category 3: i18n / Hardcoded Strings

### 3.1 Hardcoded fallbacks in history page

**File:** `profile_history_page.dart:415,423-426`
**Problem:** `'--'` and `'--:--'` are hardcoded fallback strings not going through l10n.
**Fix:** Use `l10n.not_available` for `'--'` and `l10n.time_unknown` for `'--:--'`. Add both keys to ARB files.

### 3.2 Hardcoded 'Chat' fallback in episode detail

**File:** `podcast_episode_detail_page.dart:302`
**Problem:** `AppLocalizations.of(context)?.podcast_tab_chat ?? 'Chat'` uses hardcoded English fallback instead of `AppLocalizationsEn()`.
**Fix:** Replace fallback with `AppLocalizationsEn().podcast_tab_chat`.

---

## Category 4: Dead Code

### 4.1 Unused `source` parameter in daily report page

**File:** `podcast_daily_report_page.dart:29`
**Fix:** Remove `this.source` from constructor and `final String? source;` field.

### 4.2 Unused `source` parameter in highlights page

**File:** `podcast_highlights_page.dart:33`
**Fix:** Remove `this.source` from constructor and `final String? source;` field.

---

## Category 5: Code Quality

### 5.1 Repeated density pattern in episode detail header (12x)

**File:** `podcast_episode_detail_page_header.dart`
**Problem:** `_isCompactPhoneLayout ? HeaderCapsuleActionButtonDensity.compact : HeaderCapsuleActionButtonDensity.regular` repeated 12 times.
**Fix:** Extract a getter: `HeaderCapsuleActionButtonDensity get _buttonDensity => _isCompactPhoneLayout ? HeaderCapsuleActionButtonDensity.compact : HeaderCapsuleActionButtonDensity.regular;` and use `_buttonDensity` everywhere.

### 5.2 Calendar code duplication between daily report and highlights (~300 lines)

**Files:** `podcast_daily_report_page.dart`, `podcast_highlights_page.dart`
**Problem:** `_showCalendarPanel`, `_buildCalendarPanelContent`, `_buildCalendarDayCell`, `_handleCalendarDaySelected`, `_handleCalendarDaySelectedFromPanel` are near-identical with only provider/label differences.
**Fix:** Extract a shared `CalendarPanelMixin` or standalone widget that accepts providers and labels as parameters. Both pages then delegate to the shared implementation.

---

## Summary

| Category | Count |
|----------|-------|
| Concrete bugs | 5 |
| UX issues | 3 |
| i18n hardcoded strings | 2 |
| Dead code | 2 |
| Code quality | 2 |
| **Total** | **14 unique issues** |
