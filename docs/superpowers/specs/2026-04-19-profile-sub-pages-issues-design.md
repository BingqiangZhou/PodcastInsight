# Profile Sub-Pages Issues — Design Spec

**Date:** 2026-04-19
**Scope:** All pages reachable from the Profile tab

## Overview

Audit of all profile sub-pages identified 20 issues across 7 severity categories. This spec covers fixes for all of them.

## Navigation Map

```
ProfilePage (/profile) — tab 2
  ├── ProfileSubscriptionsPage (/profile/subscriptions)
  ├── ProfileHistoryPage (/profile/history)
  ├── ProfileCacheManagementPage (/profile/cache)
  ├── PodcastDownloadsPage (/profile/downloads)
  ├── AppearancePage (/settings/appearance)
  ├── PodcastDailyReportPage (/reports/daily)
  ├── PodcastHighlightsPage (/highlights)
  └── Various dialogs (edit profile, security, language, about, etc.)

Orphaned (no route): PrivacyPage, TermsPage
```

---

## Category 1: Crashes / Wrong Behavior

### 1.1 Empty displayName causes RangeError

**File:** `profile_page.dart:847`
**Problem:** `(user?.displayName ?? l10n.profile_guest_user).characters.first.toUpperCase()` throws `StateError` when `displayName` is `""` — the null-coalescing doesn't protect against empty strings.
**Fix:** Use `characters.firstOrNull ?? '?'`.

### 1.2 CachedAsyncNotifier._isDisposed is never set to true

**File:** `core/shared/cached_async_notifier.dart` (or wherever the base class lives)
**Problem:** `markDisposed()` exists but is never called. All `_isDisposed` guards are no-ops, meaning state writes can still happen after widget disposal.
**Fix:** Wire up `ref.onDispose(() => markDisposed())` in all notifiers that extend `CachedAsyncNotifier`.

### 1.3 Double data fetch in ProfileHistoryPage

**File:** `profile_history_page.dart:30-37`
**Problem:** `initState` explicitly calls `load()`, but the provider's `build()` already calls `load()` on initialization, causing a double fetch.
**Fix:** Remove the manual `load()` call from `initState`.

---

## Category 2: Missing Error Handling

### 2.1 TextEditingController leak in change-password dialog

**File:** `profile_page.dart:496-498`
**Problem:** Three `TextEditingController` instances created per dialog open, never disposed.
**Fix:** Extract to a stateful dialog widget with proper `dispose()`, or use `StatefulBuilder` with manual cleanup on close.

### 2.2 _clearAll() dialog can get stuck

**File:** `profile_cache_management_page.dart:294-342`
**Problem:** If the widget is disposed during the clear operation, the blocking dialog (`barrierDismissible: false`) remains on screen with no dismissal path.
**Fix:** Use `mounted` checks in a `try/finally` block. Ensure dialog is always dismissed even on error or disposal.

---

## Category 3: i18n / Hardcoded Strings

### 3.1 Hardcoded subtitle in ProfileHistoryPage (3 occurrences)

**File:** `profile_history_page.dart:77,164,177`
**Problem:** `'Resume episodes and review recently played content.'` is hardcoded English.
**Fix:** Add `profile_history_subtitle` key to both `en.arb` and `zh.arb`, use `l10n.profile_history_subtitle`.

### 3.2 Hardcoded episode count in ProfileHistoryPage

**File:** `profile_history_page.dart:130`
**Problem:** `'${episodes.length} recently played episodes'` is hardcoded. A localized key `profile_history_episode_count` already exists in ARB files.
**Fix:** Replace with the existing localized key.

### 3.3 Hardcoded 'Loading...' and 'Unknown' in version provider

**File:** `profile_ui_providers.dart:51,60`
**Problem:** `return 'Loading...'` and `state = 'Unknown'` are hardcoded English.
**Fix:** Return empty string `''` during loading, and use a localized fallback or `'—'` for unknown.

### 3.4 Hardcoded subscription count format

**File:** `profile_subscriptions_page.dart:447`
**Problem:** `'${l10n.profile_subscriptions}: $total'` has a hardcoded format.
**Fix:** Add `profile_subscriptions_count` key with `{count}` placeholder to ARB files.

### 3.5 Hardcoded byte units in cache management

**File:** `profile_cache_management_page.dart:202,213,216,474`
**Problem:** `'0 B'`, `'0 MB'`, unit arrays `['B', 'KB', 'MB', 'GB', 'TB']` are hardcoded.
**Fix:** These are standard SI units acceptable in most locales. Only fix the display literals (`'0 B'`, `'0 MB'`) by computing them from the formatting function rather than hardcoding.

---

## Category 4: UX Problems

### 4.1 Change-password flow is misleading

**File:** `profile_page.dart:593-665`
**Problem:** Collects current/new/confirm passwords but calls `forgotPassword()` — the current password is collected but ignored. The user expects an in-app change but gets a reset email.
**Fix:** Simplify to a single "Send password reset email" button that calls `forgotPassword()` with the user's email. Remove the three-field form since the current password is never validated.

### 4.2 Edit Profile dialog is non-functional

**File:** `profile_page.dart:351-423`
**Problem:** All fields are `enabled: false` with "coming soon" text. The user taps through an action sheet to reach a dead-end.
**Fix:** Replace the full dialog with a simple info notice: "Profile editing is coming soon." Or hide the menu option entirely until the feature is implemented.

### 4.3 Tappable vs non-tappable activity cards look identical

**File:** `profile_activity_cards.dart:59-188`
**Problem:** Cards with `onTap` (chevron) and cards without look the same. Users can't distinguish interactive from static cards.
**Fix:** For non-tappable cards, remove the `InkWell` ripple effect or use a different visual treatment (e.g., no chevron, no elevation on tap).

### 4.4 Notification switch flashes on load

**File:** `profile_ui_providers.dart:12-25`
**Problem:** `NotificationPreferenceNotifier.build()` returns `true` as default, then asynchronously loads the stored value, causing a visible switch toggle flash.
**Fix:** Use `AsyncValue<bool>` pattern — return `AsyncLoading` initially, then `AsyncData(storedValue)`. The switch should show a loading indicator until the real value loads.

### 4.5 Poor subscriptions end-of-list indicator

**File:** `profile_subscriptions_page.dart:442-454`
**Problem:** Footer shows `"Subscriptions: 15"` which reads like a label, not an end-of-list indicator.
**Fix:** Replace with `l10n.profile_subscriptions_all_loaded` (e.g., "All {count} subscriptions loaded") or simply remove the footer when all items are loaded.

---

## Category 5: Dead Code

### 5.1-5.2 Orphaned PrivacyPage and TermsPage

**Files:** `privacy_page.dart`, `terms_page.dart`
**Problem:** Neither page is registered in `app_router.dart` and no navigation calls reference them. They are unreachable dead code.
**Fix:** Register routes in `app_router.dart` and add navigation entries from the About section of ProfilePage (add "Privacy Policy" and "Terms of Service" items).

### 5.3 Unused _buildCard method

**File:** `profile_page.dart:301-303`
**Problem:** `_buildCard` is unused, suppressed with `// ignore: unused_element`.
**Fix:** Remove the dead method.

---

## Category 6: Performance

### 6.1 Sequential await in _loadStats()

**File:** `profile_cache_management_page.dart:172-173`
**Problem:** `_objectBytes(obj)` is `async` and awaited sequentially in a `for` loop. Each call just reads a property.
**Fix:** Make `_objectBytes` synchronous (it only reads `object.length` with a null check).

---

## Category 7: Code Duplication

### 7.1 Activity cards duplicated for mobile/desktop

**File:** `profile_activity_cards.dart:59-188`
**Problem:** The same 6 cards are defined twice — once for mobile layout and once for desktop. Any card change must be made in two places.
**Fix:** Extract card definitions to a `_buildCardList()` method that returns a `List<Widget>`, then use it in both mobile and desktop layouts.

---

## Implementation Notes

- All i18n changes require editing both `app_localizations_en.arb` and `app_localizations_zh.arb`, then running `flutter gen-l10n`
- Router changes go in `app_router.dart`
- Provider changes may require `dart run build_runner build` if `@riverpod` annotations are affected
- Widget tests are required for any modified pages
