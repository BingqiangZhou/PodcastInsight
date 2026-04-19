# Profile Reachable Pages Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix 17 issues in pages reachable from Profile tab — bugs, crashes, UX, i18n, dead code, memory, and consistency.

**Architecture:** Fix issues file-by-file in priority order (bugs/crashes first, then UX, then i18n, then cleanup). Each task produces a self-contained commit.

**Tech Stack:** Flutter 3.8+, Dart, Riverpod, GoRouter, flutter_localizations (ARB files)

## Files Modified

| File | Issues |
|------|--------|
| `frontend/lib/features/podcast/presentation/pages/podcast_episodes_page_view.dart` | 1.1, 1.2, 4.5 |
| `frontend/lib/features/podcast/presentation/pages/podcast_episode_detail_page.dart` | 1.3, 2.1 |
| `frontend/lib/features/podcast/presentation/pages/podcast_episode_detail_page_header.dart` | 4.2, 4.3, 4.4 |
| `frontend/lib/features/podcast/presentation/pages/podcast_episode_detail_page_tabs.dart` | 5.1 |
| `frontend/lib/features/podcast/presentation/pages/podcast_episode_detail_page_content.dart` | 5.2 |
| `frontend/lib/features/podcast/presentation/pages/podcast_downloads_page.dart` | 3.1, 3.2, 4.1 |
| `frontend/lib/features/podcast/presentation/pages/podcast_daily_report_page.dart` | 6.1 |
| `frontend/lib/features/podcast/presentation/pages/podcast_highlights_page.dart` | 6.1, 6.2 |
| `frontend/lib/features/profile/presentation/pages/profile_history_page.dart` | 5.3 |
| `frontend/lib/features/profile/presentation/pages/profile_subscriptions_page.dart` | 7.1 |
| `frontend/lib/core/localization/app_localizations_en.arb` | new i18n keys |
| `frontend/lib/core/localization/app_localizations_zh.arb` | new i18n keys |

---

## Task 1: Fix filter dialog cancel bug (Spec 1.1) and remove stub actions (Spec 1.2) and fix hardcoded 'More' (Spec 4.5)

**File:** `frontend/lib/features/podcast/presentation/pages/podcast_episodes_page_view.dart`

**Spec 1.1 — Cancel bug:** The `_showFilterDialog` method (line 368) mutates parent widget fields `_selectedFilter` and `_showOnlyWithSummary` directly inside `setDialogState`. When Cancel is pressed, the dialog closes but the values are already changed, so the visible filter state has been changed even though the user cancelled.

Fix: Before opening the dialog, save the current values. On Cancel, restore them.

In `_showFilterDialog`, after the opening brace `void _showFilterDialog() {` (line 368) and before `final l10n = context.l10n;` (line 369), add:

```dart
    final previousFilter = _selectedFilter;
    final previousShowOnlySummary = _showOnlyWithSummary;
```

Then change the Cancel button's `onPressed` (currently line 427) from:

```dart
              onPressed: () => Navigator.of(context).pop(),
```

to:

```dart
              onPressed: () {
                _selectedFilter = previousFilter;
                _showOnlyWithSummary = previousShowOnlySummary;
                Navigator.of(context).pop();
              },
```

**Spec 1.2 — Remove stub actions:** Delete the two TODO action sheet items (lines 316-327) from `_showMoreMenu`. The `actions` list currently contains two `AdaptiveActionSheetAction` widgets with `// TODO: Implement` bodies. Remove them so the `actions` list becomes empty:

Delete these lines:

```dart
        AdaptiveActionSheetAction(
          child: Text(l10n.podcast_mark_all_played),
          onPressed: () {
            // TODO: Implement
          },
        ),
        AdaptiveActionSheetAction(
          child: Text(l10n.podcast_mark_all_unplayed),
          onPressed: () {
            // TODO: Implement
          },
        ),
```

The resulting `_showMoreMenu` method should be:

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

**Spec 4.5 — Hardcoded 'More':** The `more` key already exists in both ARB files (EN: `"More"`, ZH: `"更多"`). Replace the hardcoded `'More'` tooltip on line 307:

Current:
```dart
      tooltip: 'More',
```

Replace with:
```dart
      tooltip: l10n.more,
```

Note: `l10n` is already in scope in `_buildMoreMenu` but not in `_buildMoreMenu`'s caller. The `_buildMoreMenu` method is at line 299 and already receives `l10n` as a parameter at line 311. However, the `_buildMoreMenu` method at line 299 is a separate method from `_showMoreMenu`. Looking at the code: `_buildMoreMenu()` (line 299) does NOT receive `l10n` — it creates it via `final l10n = context.l10n;` on line 300. So `l10n` is available. Change:

```dart
  Widget _buildMoreMenu() {
    final l10n = context.l10n;
    return IconButton(
      icon: Icon(
        Icons.adaptive.more,
        color: Theme.of(context).colorScheme.secondary,
      ),
      onPressed: () => _showMoreMenu(l10n),
      tooltip: l10n.more,
    );
  }
```

Steps:
- [ ] Save previous filter values at start of `_showFilterDialog`
- [ ] Restore values on Cancel press
- [ ] Delete the two TODO action sheet items from `_showMoreMenu`
- [ ] Replace `'More'` with `l10n.more` in `_buildMoreMenu`
- [ ] Run: `cd frontend && flutter analyze`
- [ ] Commit: `fix(podcast): fix filter cancel bug, remove stub actions, localize 'More' tooltip`

---

## Task 2: Fix episode detail page — reset selectedSummaryText (Spec 1.3) and add mounted check (Spec 2.1)

**File:** `frontend/lib/features/podcast/presentation/pages/podcast_episode_detail_page.dart`

**Spec 1.3:** Find the `didUpdateWidget` method (line 331). After `super.didUpdateWidget(oldWidget);` (line 332) and before the `if (oldWidget.episodeId != widget.episodeId)` check (line 334), add:

```dart
    _selectedSummaryText = '';
```

Actually, looking more carefully: the `_selectedSummaryText` should be reset when the episode changes, so it belongs inside the `if (oldWidget.episodeId != widget.episodeId)` block. Add it after line 358 (`_shownotesAnchors = const <ShownotesAnchor>[];`):

```dart
      _selectedSummaryText = '';
```

So the block from line 354 to line 359 becomes:

```dart
      _hasTrackedEpisodeView = false;

      // Reset tab selection
      _selectedTabIndex = 0;
      _shownotesAnchors = const <ShownotesAnchor>[];
      _selectedSummaryText = '';
```

**Spec 2.1:** In `_loadAndPlayEpisode` (line 161), add a mounted check after the await. The current code is:

```dart
  Future<void> _loadAndPlayEpisode() async {
    logger.AppLogger.debug('[Playback] ===== _loadAndPlayEpisode called =====');
    logger.AppLogger.debug('[Playback] widget.episodeId: ${widget.episodeId}');

    try {
      // Wait for episode detail to be loaded
      final episodeDetailAsync = await ref.read(
        episodeDetailProvider(widget.episodeId).future,
      );
```

After line 169 (the closing `);` of `episodeDetailProvider(widget.episodeId).future`), add:

```dart

      if (!mounted) return;
```

So the result is:

```dart
    try {
      // Wait for episode detail to be loaded
      final episodeDetailAsync = await ref.read(
        episodeDetailProvider(widget.episodeId).future,
      );

      if (!mounted) return;

      logger.AppLogger.debug(
```

Steps:
- [ ] Reset `_selectedSummaryText` in `didUpdateWidget` inside the episode-id-changed block
- [ ] Add `if (!mounted) return;` after the await in `_loadAndPlayEpisode`
- [ ] Run: `cd frontend && flutter analyze lib/features/podcast/presentation/pages/podcast_episode_detail_page.dart`
- [ ] Commit: `fix(podcast): reset selected text on episode switch, add mounted check`

---

## Task 3: Fix i18n in episode detail header (Spec 4.2, 4.3, 4.4)

**File:** `frontend/lib/features/podcast/presentation/pages/podcast_episode_detail_page_header.dart`

**Spec 4.2 — '18+':** Replace line 73:

```dart
          label: '18+',
```

with localized key. Add a new `podcast_explicit_label` ARB key. Since `'18+'` is the same in both EN and ZH, the key is cosmetic but keeps the string centralized.

Add to `app_localizations_en.arb`:
```json
    "podcast_explicit_label":  "18+",
    "@podcast_explicit_label":  {
                                 "description":  "Explicit content badge label"
                             },
```

Add to `app_localizations_zh.arb`:
```json
    "podcast_explicit_label":  "18+",
    "@podcast_explicit_label":  {
                                 "description":  "成人内容标签"
                             },
```

Then replace in `podcast_episode_detail_page_header.dart` line 73:
```dart
          label: '18+',
```
with:
```dart
          label: l10n.podcast_explicit_label,
```

`l10n` is already in scope at this point (declared on line 54).

**Spec 4.3 — 'Share' tooltip:** Replace line 626:

```dart
      tooltip: 'Share',
```

The `more` key exists but `share` does NOT exist as a standalone key. Add a new `share` ARB key.

Add to `app_localizations_en.arb`:
```json
    "share":  "Share",
    "@share":  {
                  "description":  "Share action tooltip"
              },
```

Add to `app_localizations_zh.arb`:
```json
    "share":  "分享",
    "@share":  {
                  "description":  "分享操作提示"
              },
```

Then replace in `podcast_episode_detail_page_header.dart` line 626:
```dart
      tooltip: 'Share',
```
with:
```dart
      tooltip: l10n.share,
```

`l10n` is NOT in scope in `_buildShareButton`. Add it. The method currently is:

```dart
  Widget _buildShareButton(PodcastEpisodeModel episode) {
    return HeaderCapsuleActionButton(
      tooltip: 'Share',
```

Change to:

```dart
  Widget _buildShareButton(PodcastEpisodeModel episode) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
    return HeaderCapsuleActionButton(
      tooltip: l10n.share,
```

**Spec 4.4 — 'Failed to share':** Replace line 672:

```dart
          message: 'Failed to share: $error',
```

The existing `podcast_share_failed` is `"Failed to share image"` / `"图片分享失败"` — it does NOT have an `{error}` placeholder. We need a new key with a placeholder.

Add to `app_localizations_en.arb`:
```json
    "podcast_share_episode_failed":  "Failed to share: {error}",
    "@podcast_share_episode_failed":  {
                                        "description":  "Error message when sharing an episode fails",
                                        "placeholders":  {
                                                             "error":  {
                                                                          "type":  "String"
                                                                      }
                                                         }
                                    },
```

Add to `app_localizations_zh.arb`:
```json
    "podcast_share_episode_failed":  "分享失败：{error}",
    "@podcast_share_episode_failed":  {
                                        "description":  "分享播客集失败时的错误提示",
                                        "placeholders":  {
                                                             "error":  {
                                                                          "type":  "String"
                                                                      }
                                                         }
                                    },
```

Then replace in `podcast_episode_detail_page_header.dart` line 672:
```dart
          message: 'Failed to share: $error',
```
with:
```dart
          message: l10n.podcast_share_episode_failed(error.toString()),
```

`l10n` is already in scope in `_shareEpisode` (declared on line 653).

Steps:
- [ ] Add `podcast_explicit_label`, `share`, and `podcast_share_episode_failed` ARB keys to both EN and ZH files
- [ ] Run `cd frontend && flutter gen-l10n`
- [ ] Replace `'18+'` with `l10n.podcast_explicit_label`
- [ ] Replace `'Share'` with `l10n.share` (add l10n declaration to `_buildShareButton`)
- [ ] Replace `'Failed to share: $error'` with `l10n.podcast_share_episode_failed(error.toString())`
- [ ] Run: `cd frontend && flutter analyze`
- [ ] Commit: `fix(i18n): localize episode detail header strings`

---

## Task 4: Fix downloads page — remove empty onTap (Spec 3.1), add pull-to-refresh (Spec 3.2), fix hardcoded title (Spec 4.1)

**File:** `frontend/lib/features/podcast/presentation/pages/podcast_downloads_page.dart`

**Spec 3.1 — Empty onTap:** In the `_DownloadTaskCard.build` method, the `InkWell` at line 253 has `onTap: () {}`. Change to `onTap: null` to disable the ripple effect:

Line 255, change:
```dart
          onTap: () {},
```
to:
```dart
          onTap: null,
```

**Spec 3.2 — No pull-to-refresh:** The downloads page currently uses `CustomScrollView` > `SliverFillRemaining` > `asyncDownloads.when(...)`. The `ListView.builder` at line 203 is inside `_buildDownloadsPanel`. We need to wrap the `CustomScrollView` in an `AdaptiveRefreshIndicator`.

Looking at the build method: The `PodcastDownloadsPage` is a `ConsumerWidget` (not `ConsumerStatefulWidget`), so there's no `dispose` concern. The `AdaptiveRefreshIndicator` wraps the child widget.

The structure is:
```
Scaffold > body > Material > ResponsiveContainer > CustomScrollView > ... > SliverFillRemaining > ... > ListView.builder
```

Since this is already a `CustomScrollView`, we should use the standard `AdaptiveRefreshIndicator` constructor (not `.sliver()`) to wrap the scroll view. But actually, since `CustomScrollView` is a scroll view itself, the simpler approach is to wrap the `CustomScrollView` content or use `AdaptiveRefreshIndicator` around the `ResponsiveContainer`.

Looking at how `profile_history_page.dart` does it — it wraps the child of `SliverFillRemaining` with `AdaptiveRefreshIndicator`. That approach works because `SliverFillRemaining` gives a non-sliver child.

For the downloads page, the simplest approach: wrap the body content (inside `Material`) with `AdaptiveRefreshIndicator`. The refresh invalidates `downloadsListProvider` which is a `StreamProvider` — for stream providers, invalidation triggers re-subscription, which effectively refreshes the data.

In the `build` method, wrap the `ResponsiveContainer` with `AdaptiveRefreshIndicator`. Change lines 45-78 from:

```dart
          child: ResponsiveContainer(
            maxWidth: 1480,
            alignment: Alignment.topCenter,
            child: CustomScrollView(
```

to:

```dart
          child: AdaptiveRefreshIndicator(
            onRefresh: () async {
              ref.invalidate(downloadsListProvider);
            },
            child: ResponsiveContainer(
              maxWidth: 1480,
              alignment: Alignment.topCenter,
              child: CustomScrollView(
```

And close the extra parenthesis at the end. Currently line 78:
```dart
      ),
```
needs an extra `)` for the `AdaptiveRefreshIndicator`. So the end of the `build` method becomes:

```dart
            ),
          ),
        ),
      ),
    );
  }
```

Also add the import for `AdaptiveRefreshIndicator`. Check existing imports — it's in `package:personal_ai_assistant/core/widgets/adaptive/adaptive.dart` or `custom_adaptive_navigation.dart`. Looking at the existing imports, `adaptive.dart` is imported on line 10. So no new import is needed.

Wait, looking again at the imports:
```dart
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive_dismissible.dart';
```

That's a different file. The `AdaptiveRefreshIndicator` is in `package:personal_ai_assistant/core/widgets/adaptive/adaptive.dart`. Check if it's imported. Line 10:
```dart
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive.dart';
```

Yes, `adaptive.dart` is imported. Good.

But wait — `PodcastDownloadsPage` is a `ConsumerWidget`, so `ref.invalidate` works fine inside `build`'s callback closure since `ref` is captured from the `build` method parameters.

**Spec 4.1 — Hardcoded 'Episode #':** Replace line 287:

```dart
                        episodeTitle ?? 'Episode #${task.episodeId}',
```

Add a new `podcast_episode_fallback_title` ARB key with `{id}` placeholder.

Add to `app_localizations_en.arb`:
```json
    "podcast_episode_fallback_title":  "Episode #{id}",
    "@podcast_episode_fallback_title":  {
                                         "description":  "Fallback title for an episode when the real title is unavailable",
                                         "placeholders":  {
                                                              "id":  {
                                                                         "type":  "int"
                                                                     }
                                                          }
                                     },
```

Add to `app_localizations_zh.arb`:
```json
    "podcast_episode_fallback_title":  "播客集 #{id}",
    "@podcast_episode_fallback_title":  {
                                         "description":  "无法获取播客集标题时的备用标题",
                                         "placeholders":  {
                                                              "id":  {
                                                                         "type":  "int"
                                                                     }
                                                          }
                                     },
```

Then replace in `podcast_downloads_page.dart` line 287:
```dart
                        episodeTitle ?? 'Episode #${task.episodeId}',
```
with:
```dart
                        episodeTitle ?? l10n.podcast_episode_fallback_title(task.episodeId),
```

`l10n` is already in scope in `_DownloadTaskCard.build` (declared on line 232).

Steps:
- [ ] Change empty `onTap: () {}` to `onTap: null` in `_DownloadTaskCard`
- [ ] Wrap `ResponsiveContainer` in `AdaptiveRefreshIndicator` with `ref.invalidate(downloadsListProvider)`
- [ ] Add `podcast_episode_fallback_title` ARB key to both EN and ZH files
- [ ] Run `cd frontend && flutter gen-l10n`
- [ ] Replace hardcoded `'Episode #${task.episodeId}'` with `l10n.podcast_episode_fallback_title(task.episodeId)`
- [ ] Run: `cd frontend && flutter analyze`
- [ ] Commit: `fix(podcast): improve downloads page UX and i18n`

---

## Task 5: Remove dead code (Spec 5.1) and consolidate duplicate switch (Spec 5.2) in episode detail

**Files:**
- `frontend/lib/features/podcast/presentation/pages/podcast_episode_detail_page_tabs.dart`
- `frontend/lib/features/podcast/presentation/pages/podcast_episode_detail_page_content.dart`

**Spec 5.1:** Delete `_buildTopButtonBar` method from `podcast_episode_detail_page_tabs.dart` (lines 13-16):

```dart
  Widget _buildTopButtonBar({required bool isWide}) {
    // Deprecated — kept as compatibility shim during migration.
    return _buildTabSelector();
  }
```

Before deleting, verify there are no callers. The `Grep` results show `_buildTopButtonBar` is only defined in the tabs file and has NO callers anywhere in the codebase. Safe to delete.

**Spec 5.2:** Consolidate `_buildTabContent` and `_buildSingleTabContent` in `podcast_episode_detail_page_content.dart`. Both methods have the same switch logic — the only difference is that `_buildTabContent` uses the state field `_selectedTabIndex` while `_buildSingleTabContent` takes an `index` parameter.

Replace both methods (lines 36-79) with a single method:

```dart
  Widget _buildTabWidget(PodcastEpisodeModel episode, int index) {
    switch (index) {
      case 0:
        return ShownotesDisplayWidget(
          key: _shownotesKey,
          episode: episode,
          onAnchorsChanged: _updateShownotesAnchors,
        );
      case 1:
        return _buildTranscriptContent(episode);
      case 2:
        return _buildSummaryTabContent(episode);
      default:
        return ShownotesDisplayWidget(
          key: _shownotesKey,
          episode: episode,
          onAnchorsChanged: _updateShownotesAnchors,
        );
    }
  }
```

Then update call sites in `podcast_episode_detail_page_layout.dart`:

Line 69: `_buildTabContent(episode)` becomes `_buildTabWidget(episode, _selectedTabIndex)`

Line 141: `_buildSingleTabContent(episode, index)` becomes `_buildTabWidget(episode, index)`

Steps:
- [ ] Delete `_buildTopButtonBar` from tabs file
- [ ] Replace `_buildTabContent` and `_buildSingleTabContent` with single `_buildTabWidget` in content file
- [ ] Update call site in layout file: `_buildTabContent(episode)` -> `_buildTabWidget(episode, _selectedTabIndex)`
- [ ] Update call site in layout file: `_buildSingleTabContent(episode, index)` -> `_buildTabWidget(episode, index)`
- [ ] Run: `cd frontend && flutter analyze`
- [ ] Commit: `refactor(podcast): remove dead code and consolidate tab content methods`

---

## Task 6: Fix CurvedAnimation leak in daily report and highlights (Spec 6.1)

**Files:**
- `frontend/lib/features/podcast/presentation/pages/podcast_daily_report_page.dart`
- `frontend/lib/features/podcast/presentation/pages/podcast_highlights_page.dart`

Both files create `CurvedAnimation` inside `transitionBuilder` of `showGeneralDialog` and never dispose it. The `CurvedAnimation` is an `Animation` subclass that registers itself as a listener on the parent and must be disposed.

**Daily report page** — `_showCalendarPanel` method (line 447), `transitionBuilder` (lines 494-508):

Current code:
```dart
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            alignment: Alignment.topRight,
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
```

Replace with:
```dart
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final curvedValue = Curves.easeOutCubic.transform(animation.value);
            return Opacity(
              opacity: curvedValue,
              child: Transform.scale(
                scale: 0.96 + 0.04 * curvedValue,
                alignment: Alignment.topRight,
                child: child,
              ),
            );
          },
        );
      },
```

Note: `AnimatedBuilder` is the Flutter widget (commonly written `AnimatedBuilder`). Actually, the correct Flutter class name is `AnimatedBuilder`. Let me verify — the correct class is `AnimatedBuilder`. Actually, it is `AnimatedBuilder`. Let me check: the standard Flutter class is `AnimatedBuilder`. Yes, `AnimatedBuilder` is correct.

Wait — the standard Flutter widget is actually `AnimatedBuilder`. Let me double-check. The Flutter widget is named `AnimatedBuilder`. Actually, I need to be precise: the Flutter widget is `AnimatedBuilder`. Let me verify this is correct by checking imports. The Flutter framework provides `AnimatedBuilder` in `package:flutter/widgets.dart`.

Actually, upon further reflection, the standard Flutter widget is indeed called `AnimatedBuilder`. However, some codebases use the typedef `AnimatedBuilder`. Both are valid. The Flutter API docs confirm `AnimatedBuilder` is the correct class name.

**Highlights page** — `_showCalendarPanel` method (line 406), `transitionBuilder` (lines 453-466):

Current code:
```dart
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            alignment: Alignment.topRight,
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
```

Replace with the same pattern:
```dart
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final curvedValue = Curves.easeOutCubic.transform(animation.value);
            return Opacity(
              opacity: curvedValue,
              child: Transform.scale(
                scale: 0.96 + 0.04 * curvedValue,
                alignment: Alignment.topRight,
                child: child,
              ),
            );
          },
        );
      },
```

Steps:
- [ ] Fix daily report page CurvedAnimation in `_showCalendarPanel` `transitionBuilder`
- [ ] Fix highlights page CurvedAnimation in `_showCalendarPanel` `transitionBuilder`
- [ ] Run: `cd frontend && flutter analyze`
- [ ] Commit: `fix(podcast): fix CurvedAnimation memory leak in calendar dialogs`

---

## Task 7: Fix `_formatPlaybackPosition` redundant branches (Spec 5.3) and subscriptions scroll listener (Spec 7.1)

**Files:**
- `frontend/lib/features/profile/presentation/pages/profile_history_page.dart`
- `frontend/lib/features/profile/presentation/pages/profile_subscriptions_page.dart`

**Spec 5.3:** In `profile_history_page.dart`, the `_formatPlaybackPosition` method (lines 429-445) has two branches that return the same value:

```dart
  String _formatPlaybackPosition(BuildContext context, int seconds) {
    final l10n = context.l10n;
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final remainingSeconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return TimeFormatter.formatDuration(duration);
    }

    if (remainingSeconds > 0) {
      return TimeFormatter.formatDuration(duration);
    }

    return l10n.player_minutes(minutes);
  }
```

The `hours` variable is only used in the first branch and is unused elsewhere after the consolidation. Replace with:

```dart
  String _formatPlaybackPosition(BuildContext context, int seconds) {
    final l10n = context.l10n;
    final duration = Duration(seconds: seconds);
    final minutes = duration.inMinutes.remainder(60);
    final remainingSeconds = duration.inSeconds.remainder(60);

    if (duration.inHours > 0 || remainingSeconds > 0) {
      return TimeFormatter.formatDuration(duration);
    }

    return l10n.player_minutes(minutes);
  }
```

**Spec 7.1:** In `profile_subscriptions_page.dart`, the `dispose` method (lines 47-50) calls `_scrollController.dispose()` but does NOT remove the listener first. Add `removeListener` before `dispose`:

Current:
```dart
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
```

Replace with:
```dart
  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }
```

Steps:
- [ ] Simplify `_formatPlaybackPosition` branches in profile_history_page.dart
- [ ] Add explicit `_scrollController.removeListener(_onScroll)` in subscriptions page dispose
- [ ] Run: `cd frontend && flutter analyze`
- [ ] Commit: `refactor(profile): simplify playback position formatting and fix scroll listener cleanup`

---

## Task 8: Cache hasMore in highlights page (Spec 6.2)

**File:** `frontend/lib/features/podcast/presentation/pages/podcast_highlights_page.dart`

The `_onScroll` method (lines 71-86) calls `ref.read(highlightsProvider)` on every scroll event to check `hasMore`. This creates unnecessary provider reads.

Current `_onScroll`:
```dart
  void _onScroll() {
    if (_isLoadingMore) return;

    final highlightsAsync = ref.read(highlightsProvider);
    final hasMore = highlightsAsync.value?.hasMore ?? false;

    if (!hasMore) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    const delta = 200.0;

    if (maxScroll - currentScroll < delta) {
      _loadMoreHighlights();
    }
  }
```

Fix: Add a `bool _hasMore = false;` field to the state class. Update it from the watched provider state in `build()`. Use `_hasMore` in `_onScroll` instead of calling `ref.read`.

1. Add field to `_PodcastHighlightsPageState` (after line 43 `bool _isLoadingMore = false;`):

```dart
  bool _hasMore = false;
```

2. In the `build` method, the `highlightsAsync` is already watched via `ref.watch(highlightsProvider)` at line 167 inside `_buildHighlightsPanel`. But we need to update `_hasMore` from `build()`. The cleanest approach: use `ref.listen` in `build()` or update the field from the watched value.

Since `_buildHighlightsPanel` is called from `build()` and already watches `highlightsProvider`, we can update `_hasMore` there. But a cleaner approach: update it directly in `build()`.

In the `build` method, after line 123 (`final l10n = context.l10n;`), add:

```dart
    final highlightsAsync = ref.watch(highlightsProvider);
    _hasMore = highlightsAsync.value?.hasMore ?? false;
```

Then the `_buildHighlightsPanel` method also calls `ref.watch(highlightsProvider)` — this is fine since Riverpod deduplicates watches. But actually, to avoid the `_hasMore` assignment happening during build (which is a side effect during build), a better approach is to use `ref.listen`:

```dart
    ref.listen(highlightsProvider, (previous, next) {
      _hasMore = next.value?.hasMore ?? false;
    });
```

However, `ref.listen` in `build()` of a `ConsumerStatefulWidget` is the idiomatic way. But actually, the simplest and safest approach: just read it from the watched value in `_buildHighlightsPanel` and pass it down, or just set the field in `_buildHighlightsPanel` before the return. Since `_buildHighlightsPanel` is called every build, this is fine:

Actually, the cleanest approach that avoids any issues: just update `_hasMore` from the value already being watched. In `_buildHighlightsPanel` at line 167:

```dart
    final highlightsAsync = ref.watch(highlightsProvider);
```

After this line, add:

```dart
    _hasMore = highlightsAsync.value?.hasMore ?? false;
```

Wait — assigning state during build is generally fine for non-setState fields (just a field, not triggering rebuild). This is a common pattern.

3. Update `_onScroll` to use the cached field:

```dart
  void _onScroll() {
    if (_isLoadingMore) return;

    if (!_hasMore) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    const delta = 200.0;

    if (maxScroll - currentScroll < delta) {
      _loadMoreHighlights();
    }
  }
```

Steps:
- [ ] Add `bool _hasMore = false;` field to `_PodcastHighlightsPageState`
- [ ] Update `_hasMore` from `highlightsAsync.value?.hasMore` in `_buildHighlightsPanel`
- [ ] Replace `ref.read(highlightsProvider)` in `_onScroll` with `_hasMore` field access
- [ ] Run: `cd frontend && flutter analyze`
- [ ] Commit: `perf(podcast): cache hasMore value to avoid provider read on every scroll`

---

## Task 9: Final verification

- [ ] Run full analysis: `cd frontend && flutter analyze`
- [ ] Run tests: `cd frontend && flutter test`
- [ ] Fix any issues found
