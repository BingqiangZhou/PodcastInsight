# Unified Title Bar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unify all sub-page title bars to use platform-native navigation (CupertinoSliverNavigationBar on iOS, Material SliverAppBar on Android) by enhancing the existing unused `AdaptiveSliverAppBar` component and migrating 10 pages.

**Architecture:** Activate and enhance the existing `AdaptiveSliverAppBar` widget (currently unused), then migrate all sub-pages from `CompactHeaderPanel` (card-embedded titles) to `AdaptiveSliverAppBar` (platform-native nav bars). Auth pages and shells remain unchanged.

**Tech Stack:** Flutter 3.8+, Dart, Cupertino + Material libraries, Riverpod

**Design Spec:** `docs/superpowers/specs/2026-04-16-unified-title-bar-design.md`

---

## File Structure

| Action | File | Responsibility |
|--------|------|----------------|
| Modify | `lib/core/widgets/adaptive/adaptive_sliver_app_bar.dart` | Enhanced adaptive sliver nav bar |
| Modify | `lib/core/widgets/app_shells.dart` | Mark CompactHeaderPanel as deprecated |
| Modify | `lib/features/podcast/presentation/pages/podcast_highlights_page.dart` | Group A migration |
| Modify | `lib/features/podcast/presentation/pages/podcast_downloads_page.dart` | Group A migration |
| Modify | `lib/features/podcast/presentation/pages/podcast_daily_report_page.dart` | Group A migration |
| Modify | `lib/features/profile/presentation/pages/profile_history_page.dart` | Group A migration |
| Modify | `lib/features/profile/presentation/pages/profile_cache_management_page.dart` | Group A migration |
| Modify | `lib/features/profile/presentation/pages/profile_subscriptions_page.dart` | Group A migration |
| Modify | `lib/features/profile/presentation/pages/terms_page.dart` | Group A migration |
| Modify | `lib/features/profile/presentation/pages/privacy_page.dart` | Group A migration |
| Modify | `lib/features/podcast/presentation/pages/podcast_episodes_page_view.dart` | Group B migration |
| Modify | `lib/features/podcast/presentation/pages/podcast_episode_detail_page_header.dart` | Group C migration |
| Modify | `lib/features/podcast/presentation/pages/podcast_episode_detail_page_layout.dart` | Group C migration |

---

## Phase 1: Core Component Enhancement

### Task 1: Enhance AdaptiveSliverAppBar

**Files:**
- Modify: `lib/core/widgets/adaptive/adaptive_sliver_app_bar.dart`

- [ ] **Step 1: Replace the entire file with the enhanced version**

Replace `trailing` parameter with `actions` (List<Widget>), add `heroTag`, add Android-specific styling:

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:personal_ai_assistant/core/platform/platform_helper.dart';

/// Adaptive sliver app bar with large title collapsing.
///
/// iOS: [CupertinoSliverNavigationBar] with large title.
/// Android: Material [SliverAppBar] with theme-consistent styling.
class AdaptiveSliverAppBar extends StatelessWidget {
  const AdaptiveSliverAppBar({
    required this.title,
    super.key,
    this.actions,
    this.leading,
    this.largeTitle = true,
    this.bottom,
    this.backgroundColor,
    this.automaticallyImplyLeading = true,
    this.heroTag,
  });

  /// Page title displayed in the navigation bar.
  final String title;

  /// Action buttons displayed on the trailing side.
  /// iOS: wrapped in Row for CupertinoSliverNavigationBar.trailing.
  /// Android: passed directly to SliverAppBar.actions.
  final List<Widget>? actions;

  /// Optional leading widget (overrides automatic back button).
  final Widget? leading;

  /// Whether to show a large title on iOS. Defaults to true.
  final bool largeTitle;

  /// Optional widget to display below the navigation bar.
  final PreferredSizeWidget? bottom;

  /// Background color. Defaults to semi-transparent on both platforms.
  final Color? backgroundColor;

  /// Whether to automatically imply a leading back button. Defaults to true.
  final bool automaticallyImplyLeading;

  /// Hero tag for Cupertino transition animation.
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    if (PlatformHelper.isIOS(context)) {
      return CupertinoSliverNavigationBar(
        largeTitle: largeTitle ? Text(title) : null,
        middle: largeTitle ? null : Text(title),
        trailing: actions != null && actions!.isNotEmpty
            ? Row(mainAxisSize: MainAxisSize.min, children: actions!)
            : null,
        leading: leading,
        backgroundColor: backgroundColor ??
            CupertinoColors.systemBackground.withValues(alpha: 0.85),
        bottom: bottom,
        automaticallyImplyLeading: automaticallyImplyLeading,
        heroTag: heroTag,
      );
    }

    return SliverAppBar(
      title: Text(title),
      actions: actions,
      leading: leading,
      floating: true,
      snap: true,
      bottom: bottom,
      backgroundColor: backgroundColor,
      automaticallyImplyLeading: automaticallyImplyLeading,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    );
  }
}
```

- [ ] **Step 2: Verify compilation**

Run: `cd frontend && flutter analyze lib/core/widgets/adaptive/adaptive_sliver_app_bar.dart`

- [ ] **Step 3: Commit**

```bash
git add lib/core/widgets/adaptive/adaptive_sliver_app_bar.dart
git commit -m "feat(ui): enhance AdaptiveSliverAppBar with actions and platform styling"
```

---

## Group A Migration Template

All 8 Group A pages follow the same structural transformation:

**Import changes:**
- Add: `import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive_sliver_app_bar.dart';`
- Remove `go_router` import IF it was only used for the back button (check each page)

**Build method transformation (before → after):**

```dart
// BEFORE:
Scaffold(
  backgroundColor: Colors.transparent,
  body: Material(
    color: Colors.transparent,
    child: SafeArea(
      bottom: false,
      child: ResponsiveContainer(
        maxWidth: ???,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CompactHeaderPanel(
              title: 'Title',
              trailing: Row(... /* actions + back button */),
            ),
            const SizedBox(height: AppSpacing.smMd),
            Expanded(child: body),
          ],
        ),
      ),
    ),
  ),
)
```

```dart
// AFTER:
Scaffold(
  backgroundColor: Colors.transparent,
  body: Material(
    color: Colors.transparent,
    child: ResponsiveContainer(
      maxWidth: ???,
      alignment: Alignment.topCenter,
      child: CustomScrollView(
        slivers: [
          AdaptiveSliverAppBar(
            title: 'Title',
            actions: [... /* actions only, NO back button */],
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.smMd)),
          SliverFillRemaining(
            hasScrollBody: false,
            child: body,
          ),
        ],
      ),
    ),
  ),
)
```

**Key changes:**
1. Remove `SafeArea` wrapper (nav bars handle safe area internally)
2. `Column` → `CustomScrollView`
3. `CompactHeaderPanel(...)` → `AdaptiveSliverAppBar(...)`
4. `SizedBox(spacing)` → `SliverToBoxAdapter(child: SizedBox(spacing))`
5. `Expanded(child: body)` → `SliverFillRemaining(hasScrollBody: false, child: body)`
6. Remove back button from trailing actions (system provides it)
7. Remove `_buildBackButton` helper method if it exists
8. Remove `go_router` import if no longer needed

---

## Phase 2: Group A — Podcast Sub-Pages

### Task 2: Migrate PodcastHighlightsPage

**Files:**
- Modify: `lib/features/podcast/presentation/pages/podcast_highlights_page.dart`

- [ ] **Step 1: Update imports**

Add after existing imports:
```dart
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive_sliver_app_bar.dart';
```

Remove (back button was the only usage of go_router in the header — verify the page doesn't use go_router elsewhere first):
```dart
import 'package:go_router/go_router.dart';
```

- [ ] **Step 2: Replace `build` method body**

Replace the `build` method return value (lines ~119-141). Remove the `SafeArea` wrapper, change `Column` to `CustomScrollView`, replace `CompactHeaderPanel`:

```dart
Widget build(BuildContext context) {
  return Scaffold(
    key: const Key('highlights_page'),
    backgroundColor: Colors.transparent,
    body: Material(
      color: Colors.transparent,
      child: ResponsiveContainer(
        maxWidth: 1480,
        alignment: Alignment.topCenter,
        child: CustomScrollView(
          slivers: [
            AdaptiveSliverAppBar(
              title: context.l10n.podcast_highlights_title,
              actions: [
                _buildCalendarButton(context),
              ],
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.smMd)),
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildHighlightsPanel(context),
            ),
          ],
        ),
      ),
    ),
  );
}
```

- [ ] **Step 3: Remove `_buildHeaderPanel` method**

Delete the entire `_buildHeaderPanel` method (lines ~144-161). The title and actions are now handled by `AdaptiveSliverAppBar` in the build method.

- [ ] **Step 4: Remove `_buildBackButton` method**

Delete the `_buildBackButton` method if it exists (search for `context.canPop()` or `context.pop()` or `context.go('/')`). System back button handles this now.

- [ ] **Step 5: Verify compilation**

Run: `cd frontend && flutter analyze lib/features/podcast/presentation/pages/podcast_highlights_page.dart`

- [ ] **Step 6: Commit**

```bash
git add lib/features/podcast/presentation/pages/podcast_highlights_page.dart
git commit -m "feat(ui): migrate PodcastHighlightsPage to AdaptiveSliverAppBar"
```

---

### Task 3: Migrate PodcastDownloadsPage

**Files:**
- Modify: `lib/features/podcast/presentation/pages/podcast_downloads_page.dart`

- [ ] **Step 1: Update imports**

Add:
```dart
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive_sliver_app_bar.dart';
```

Remove `go_router` import if only used for back button.

- [ ] **Step 2: Replace `build` method body**

The `build` method is a ConsumerWidget (takes `WidgetRef ref`). Replace the Scaffold body structure. Remove `SafeArea`, change `Column` to `CustomScrollView`. The key difference from Highlights: the trailing action is a conditional delete button:

```dart
Widget build(BuildContext context, WidgetRef ref) {
  final l10n = context.l10n;
  final theme = Theme.of(context);
  final tokens = appThemeOf(context);
  final asyncDownloads = ref.watch(downloadsListProvider);
  final grouped = ref.watch(groupedDownloadsProvider);

  final deleteButton = grouped.completed.isNotEmpty
      ? HeaderCapsuleActionButton(
          icon: Icons.delete_sweep,
          tooltip: l10n.downloads_delete_all,
          circular: true,
          onPressed: () => _confirmDeleteAll(context, ref, grouped.completed),
        )
      : null;

  return Scaffold(
    backgroundColor: Colors.transparent,
    body: Material(
      color: Colors.transparent,
      child: ResponsiveContainer(
        maxWidth: 1480,
        alignment: Alignment.topCenter,
        child: CustomScrollView(
          slivers: [
            AdaptiveSliverAppBar(
              title: l10n.downloads_page_title,
              actions: [
                if (deleteButton != null) deleteButton,
              ],
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.smMd)),
            SliverFillRemaining(
              hasScrollBody: false,
              child: asyncDownloads.when(
                data: (tasks) {
                  // ... existing data handling code unchanged
                },
                loading: () => const Center(child: CircularProgressIndicator.adaptive()),
                error: (e, _) => Center(child: Text(e.toString())),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
```

Note: Move the `deleteButton` construction to the top of `build` (extracted from `_buildHeaderPanel`). The existing `asyncDownloads.when(data:...)` body code stays identical — only the wrapper changes.

- [ ] **Step 3: Remove `_buildHeaderPanel` method**

Delete the entire `_buildHeaderPanel` method.

- [ ] **Step 4: Remove `_buildBackButton` method**

Delete the `_buildBackButton` method if it exists.

- [ ] **Step 5: Verify compilation**

Run: `cd frontend && flutter analyze lib/features/podcast/presentation/pages/podcast_downloads_page.dart`

- [ ] **Step 6: Commit**

```bash
git add lib/features/podcast/presentation/pages/podcast_downloads_page.dart
git commit -m "feat(ui): migrate PodcastDownloadsPage to AdaptiveSliverAppBar"
```

---

### Task 4: Migrate PodcastDailyReportPage

**Files:**
- Modify: `lib/features/podcast/presentation/pages/podcast_daily_report_page.dart`

- [ ] **Step 1: Update imports**

Add:
```dart
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive_sliver_app_bar.dart';
```

Remove `go_router` import if only used for back button.

- [ ] **Step 2: Replace `build` method body**

Same pattern as Highlights. Remove `SafeArea`, `Column` → `CustomScrollView`:

```dart
Widget build(BuildContext context) {
  return Scaffold(
    key: const Key('daily_report_page'),
    backgroundColor: Colors.transparent,
    body: Material(
      color: Colors.transparent,
      child: ResponsiveContainer(
        maxWidth: 1480,
        alignment: Alignment.topCenter,
        child: CustomScrollView(
          slivers: [
            AdaptiveSliverAppBar(
              title: context.l10n.podcast_daily_report_title,
              actions: [
                _buildCalendarButton(context),
              ],
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.smMd)),
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildDailyReportPanel(context),
            ),
          ],
        ),
      ),
    ),
  );
}
```

- [ ] **Step 3: Remove `_buildHeaderPanel` method**

Delete the entire `_buildHeaderPanel` method.

- [ ] **Step 4: Remove `_buildBackButton` method**

Delete the `_buildBackButton` method if it exists.

- [ ] **Step 5: Verify compilation**

Run: `cd frontend && flutter analyze lib/features/podcast/presentation/pages/podcast_daily_report_page.dart`

- [ ] **Step 6: Commit**

```bash
git add lib/features/podcast/presentation/pages/podcast_daily_report_page.dart
git commit -m "feat(ui): migrate PodcastDailyReportPage to AdaptiveSliverAppBar"
```

---

## Phase 3: Group A — Profile Sub-Pages

### Task 5: Migrate ProfileHistoryPage

**Files:**
- Modify: `lib/features/profile/presentation/pages/profile_history_page.dart`

- [ ] **Step 1: Update imports**

Add:
```dart
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive_sliver_app_bar.dart';
```

Remove `go_router` import if only used for back button.

- [ ] **Step 2: Replace `build` method body**

No trailing actions on any platform (was back-button only on desktop):

```dart
Widget build(BuildContext context) {
  final l10n = context.l10n;
  final historyAsync = ref.watch(playbackHistoryLiteProvider);

  return Scaffold(
    backgroundColor: Colors.transparent,
    body: Material(
      color: Colors.transparent,
      child: ResponsiveContainer(
        maxWidth: 1480,
        alignment: Alignment.topCenter,
        child: CustomScrollView(
          slivers: [
            AdaptiveSliverAppBar(
              title: l10n.profile_viewed_title,
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.smMd)),
            SliverFillRemaining(
              hasScrollBody: false,
              child: RefreshIndicator(
                onRefresh: () => ref.read(playbackHistoryLiteProvider.notifier).load(forceRefresh: true),
                child: historyAsync.when(
                  data: (response) {
                    // ... existing data handling unchanged
                  },
                  loading: () => _buildPanelScaffold(/* existing args */),
                  error: (error, _) => _buildPanelScaffold(/* existing args */),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
```

- [ ] **Step 3: Remove `_buildHeaderPanel` method**

Delete the entire `_buildHeaderPanel` method.

- [ ] **Step 4: Verify compilation**

Run: `cd frontend && flutter analyze lib/features/profile/presentation/pages/profile_history_page.dart`

- [ ] **Step 5: Commit**

```bash
git add lib/features/profile/presentation/pages/profile_history_page.dart
git commit -m "feat(ui): migrate ProfileHistoryPage to AdaptiveSliverAppBar"
```

---

### Task 6: Migrate ProfileCacheManagementPage

**Files:**
- Modify: `lib/features/profile/presentation/pages/profile_cache_management_page.dart`

- [ ] **Step 1: Update imports**

Add:
```dart
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive_sliver_app_bar.dart';
```

Remove `go_router` import if only used for back button.

- [ ] **Step 2: Replace `build` method body**

Keep refresh button, remove desktop back button:

```dart
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.transparent,
    body: Material(
      color: Colors.transparent,
      child: ResponsiveContainer(
        maxWidth: 1480,
        alignment: Alignment.topCenter,
        child: CustomScrollView(
          slivers: [
            AdaptiveSliverAppBar(
              title: context.l10n.profile_cache_manage_title,
              actions: [
                HeaderCapsuleActionButton(
                  key: const Key('cache_manage_refresh_action'),
                  tooltip: context.l10n.refresh,
                  onPressed: _refresh,
                  icon: Icons.refresh_rounded,
                  circular: true,
                ),
              ],
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.smMd)),
            SliverFillRemaining(
              hasScrollBody: false,
              child: FutureBuilder<_MediaCacheStats>(
                future: _statsFuture,
                builder: (context, snapshot) {
                  final isLoading = snapshot.connectionState != ConnectionState.done;
                  final stats = snapshot.data ?? _emptyStats;
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: _buildContentPanel(context, stats: stats, isLoading: isLoading),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
```

- [ ] **Step 3: Remove `_buildHeaderPanel` method**

Delete the entire `_buildHeaderPanel` method (lines ~431-459).

- [ ] **Step 4: Verify compilation**

Run: `cd frontend && flutter analyze lib/features/profile/presentation/pages/profile_cache_management_page.dart`

- [ ] **Step 5: Commit**

```bash
git add lib/features/profile/presentation/pages/profile_cache_management_page.dart
git commit -m "feat(ui): migrate ProfileCacheManagementPage to AdaptiveSliverAppBar"
```

---

### Task 7: Migrate ProfileSubscriptionsPage

**Files:**
- Modify: `lib/features/profile/presentation/pages/profile_subscriptions_page.dart`

- [ ] **Step 1: Update imports**

Add:
```dart
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive_sliver_app_bar.dart';
```

Remove `go_router` import if only used for back button.

- [ ] **Step 2: Replace `build` method body**

Keep add-podcast button, remove desktop back button. Extract the add button from `_buildHeaderPanel`:

```dart
Widget build(BuildContext context) {
  final l10n = context.l10n;
  final state = ref.watch(podcastSubscriptionProvider.select((value) => (
    subscriptions: value.subscriptions,
    isLoading: value.isLoading,
    error: value.error,
  )));

  return Scaffold(
    backgroundColor: Colors.transparent,
    body: Material(
      color: Colors.transparent,
      child: ResponsiveContainer(
        maxWidth: 1480,
        alignment: Alignment.topCenter,
        child: CustomScrollView(
          slivers: [
            AdaptiveSliverAppBar(
              title: l10n.profile_subscriptions,
              actions: [
                _buildActionButton(
                  context,
                  key: const Key('profile_subscriptions_action_add'),
                  tooltip: l10n.podcast_add_podcast,
                  icon: Icons.add,
                  onPressed: () {
                    showAppDialog(
                      context: context,
                      builder: (context) => const AddPodcastDialog(),
                    );
                  },
                ),
              ],
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.smMd)),
            SliverFillRemaining(
              hasScrollBody: false,
              child: RefreshIndicator(
                onRefresh: () => ref.read(podcastSubscriptionProvider.notifier).refreshSubscriptions(),
                child: _buildBody(context, l10n, subscriptions: state.subscriptions, /* other args */),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
```

- [ ] **Step 3: Remove `_buildHeaderPanel` method**

Delete the entire `_buildHeaderPanel` method.

- [ ] **Step 4: Verify compilation**

Run: `cd frontend && flutter analyze lib/features/profile/presentation/pages/profile_subscriptions_page.dart`

- [ ] **Step 5: Commit**

```bash
git add lib/features/profile/presentation/pages/profile_subscriptions_page.dart
git commit -m "feat(ui): migrate ProfileSubscriptionsPage to AdaptiveSliverAppBar"
```

---

## Phase 4: Group A — Legal Pages

### Task 8: Migrate TermsPage and PrivacyPage

**Files:**
- Modify: `lib/features/profile/presentation/pages/terms_page.dart`
- Modify: `lib/features/profile/presentation/pages/privacy_page.dart`

Both pages are structurally identical — the only difference is the localization keys.

- [ ] **Step 1: Migrate TermsPage — update imports**

Add:
```dart
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive_sliver_app_bar.dart';
```

Remove:
```dart
import 'package:go_router/go_router.dart';
```

(go_router was only used for the back button)

- [ ] **Step 2: Migrate TermsPage — replace build method**

```dart
Widget build(BuildContext context) {
  final l10n = context.l10n;
  final theme = Theme.of(context);

  return Scaffold(
    backgroundColor: Colors.transparent,
    body: Material(
      color: Colors.transparent,
      child: ResponsiveContainer(
        maxWidth: 720,
        alignment: Alignment.topCenter,
        child: CustomScrollView(
          slivers: [
            AdaptiveSliverAppBar(
              title: l10n.terms_of_service_title,
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.smMd)),
            SliverFillRemaining(
              hasScrollBody: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.mdLg, vertical: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.terms_of_service_title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: AppSpacing.sm),
                    Text(l10n.terms_of_service_last_updated, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: AppSpacing.lg),
                    _buildSection(context, title: l10n.terms_section_acceptance, body: l10n.terms_section_acceptance_body),
                    _buildSection(context, title: l10n.terms_section_use, body: l10n.terms_section_use_body),
                    _buildSection(context, title: l10n.terms_section_ip, body: l10n.terms_section_ip_body),
                    _buildSection(context, title: l10n.terms_section_liability, body: l10n.terms_section_liability_body),
                    _buildSection(context, title: l10n.terms_section_changes, body: l10n.terms_section_changes_body),
                    _buildSection(context, title: l10n.terms_section_governing_law, body: l10n.terms_section_governing_law_body),
                    _buildSection(context, title: l10n.terms_section_contact, body: l10n.terms_section_contact_body),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
```

- [ ] **Step 3: Migrate PrivacyPage — update imports**

Same as Terms: add `adaptive_sliver_app_bar.dart`, remove `go_router`.

- [ ] **Step 4: Migrate PrivacyPage — replace build method**

Identical structure to Terms but with privacy localization keys:

```dart
Widget build(BuildContext context) {
  final l10n = context.l10n;
  final theme = Theme.of(context);

  return Scaffold(
    backgroundColor: Colors.transparent,
    body: Material(
      color: Colors.transparent,
      child: ResponsiveContainer(
        maxWidth: 720,
        alignment: Alignment.topCenter,
        child: CustomScrollView(
          slivers: [
            AdaptiveSliverAppBar(
              title: l10n.privacy_policy_title,
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.smMd)),
            SliverFillRemaining(
              hasScrollBody: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.mdLg, vertical: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.privacy_policy_title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: AppSpacing.sm),
                    Text(l10n.privacy_policy_last_updated, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: AppSpacing.lg),
                    _buildSection(context, title: l10n.privacy_section_intro, body: l10n.privacy_section_intro_body),
                    _buildSection(context, title: l10n.privacy_section_collection, body: l10n.privacy_section_collection_body),
                    _buildSection(context, title: l10n.privacy_section_usage, body: l10n.privacy_section_usage_body),
                    _buildSection(context, title: l10n.privacy_section_storage, body: l10n.privacy_section_storage_body),
                    _buildSection(context, title: l10n.privacy_section_sharing, body: l10n.privacy_section_sharing_body),
                    _buildSection(context, title: l10n.privacy_section_rights, body: l10n.privacy_section_rights_body),
                    _buildSection(context, title: l10n.privacy_section_children, body: l10n.privacy_section_children_body),
                    _buildSection(context, title: l10n.privacy_section_changes, body: l10n.privacy_section_changes_body),
                    _buildSection(context, title: l10n.privacy_section_contact, body: l10n.privacy_section_contact_body),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
```

- [ ] **Step 5: Verify compilation**

Run: `cd frontend && flutter analyze lib/features/profile/presentation/pages/terms_page.dart lib/features/profile/presentation/pages/privacy_page.dart`

- [ ] **Step 6: Commit**

```bash
git add lib/features/profile/presentation/pages/terms_page.dart lib/features/profile/presentation/pages/privacy_page.dart
git commit -m "feat(ui): migrate TermsPage and PrivacyPage to AdaptiveSliverAppBar"
```

---

## Phase 5: Group B — PodcastEpisodesPage

### Task 9: Migrate PodcastEpisodesPage Header

**Files:**
- Modify: `lib/features/podcast/presentation/pages/podcast_episodes_page.dart`
- Modify: `lib/features/podcast/presentation/pages/podcast_episodes_page_view.dart`

This page has a custom inline header with cover art, title, refresh button, filter chips, and more menu. We replace the custom header row with `AdaptiveSliverAppBar` and move the body into a `CustomScrollView`.

- [ ] **Step 1: Update imports in main file**

Add in `podcast_episodes_page.dart`:
```dart
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive_sliver_app_bar.dart';
```

- [ ] **Step 2: Replace `build` method in main file**

Change the `Column` layout to `CustomScrollView`. The body content (loading/error/empty/data) stays unchanged:

```dart
@override
Widget build(BuildContext context) {
  final l10n = context.l10n;
  final fallbackSubscriptionImageUrl = ref.watch(
    podcastEpisodesProvider.select(
      (state) =>
          state.episodes.isNotEmpty ? state.episodes.first.subscriptionImageUrl : null,
    ),
  );
  final episodesState = ref.watch(podcastEpisodesProvider);

  return AdaptiveScaffold(
    backgroundColor: Colors.transparent,
    child: CustomScrollView(
      slivers: [
        AdaptiveSliverAppBar(
          title: widget.podcastTitle ?? l10n.podcast_episodes,
          leading: _buildHeaderCover(fallbackSubscriptionImageUrl),
          actions: _buildHeaderActions(l10n, fallbackSubscriptionImageUrl),
        ),
        SliverToBoxAdapter(
          child: MediaQuery.sizeOf(context).width >= 700
              ? _buildFilterChips()
              : const SizedBox.shrink(),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
        SliverFillRemaining(
          hasScrollBody: false,
          child: episodesState.isLoading && episodesState.episodes.isEmpty
              ? const SkeletonCardList(itemCount: 6, compact: true, showDescription: false)
              : episodesState.error != null
                  ? _buildErrorState(episodesState.error!)
                  : episodesState.episodes.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _refreshEpisodes,
                          child: _buildEpisodesScrollable(episodesState),
                        ),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 3: Replace `_buildHeader` in view file**

In `podcast_episodes_page_view.dart`, replace `_buildHeader` with two new methods:

```dart
/// Builds the cover art thumbnail for the AppBar leading slot.
Widget _buildHeaderCover(String? fallbackImageUrl) {
  final extension = appThemeOf(context);
  return Container(
    width: 32,
    height: 32,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(extension.itemRadius),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(extension.itemRadius),
      child: Builder(
        builder: (context) {
          final sub = widget.subscription;
          if (sub?.imageUrl != null) {
            return PodcastImageWidget(
              imageUrl: sub!.imageUrl,
              width: 32, height: 32, iconSize: 20,
              iconColor: Theme.of(context).colorScheme.onPrimaryContainer,
            );
          }
          if (fallbackImageUrl != null) {
            return PodcastImageWidget(
              imageUrl: fallbackImageUrl,
              width: 32, height: 32, iconSize: 20,
              iconColor: Theme.of(context).colorScheme.onPrimaryContainer,
            );
          }
          return Icon(
            Icons.podcasts, size: 20,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          );
        },
      ),
    ),
  );
}

/// Builds the action buttons for the AppBar trailing slot.
List<Widget> _buildHeaderActions(AppLocalizations l10n, String? fallbackImageUrl) {
  return [
    IconButton(
      icon: _isReparsing
          ? SizedBox(
              width: AppSpacing.mdLg,
              height: AppSpacing.mdLg,
              child: Builder(
                builder: (context) {
                  final theme = Theme.of(context);
                  return Theme(
                    data: theme.copyWith(
                      colorScheme: theme.colorScheme.copyWith(
                        primary: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    child: const CircularProgressIndicator.adaptive(strokeWidth: 2),
                  );
                },
              ),
            )
          : const Icon(Icons.refresh),
      onPressed: _isReparsing ? null : _reparseSubscription,
      tooltip: l10n.podcast_reparse_tooltip,
    ),
    if (MediaQuery.sizeOf(context).width < 700) ...[
      IconButton(
        icon: const Icon(Icons.filter_list),
        onPressed: _showFilterDialog,
        tooltip: l10n.filter,
      ),
    ],
    _buildMoreMenu(),
  ];
}
```

- [ ] **Step 4: Remove old `_buildHeader` and `_buildHeaderCover` methods**

Delete the old `_buildHeader` method (the 56px Container > Row). The new `_buildHeaderCover` returns a smaller 32x32 thumbnail suitable for AppBar leading. The old `_buildHeaderCover` with 40x40 size is replaced.

- [ ] **Step 5: Verify compilation**

Run: `cd frontend && flutter analyze lib/features/podcast/presentation/pages/podcast_episodes_page.dart`

- [ ] **Step 6: Commit**

```bash
git add lib/features/podcast/presentation/pages/podcast_episodes_page.dart lib/features/podcast/presentation/pages/podcast_episodes_page_view.dart
git commit -m "feat(ui): migrate PodcastEpisodesPage header to AdaptiveSliverAppBar"
```

---

## Phase 6: Group C — PodcastEpisodeDetailPage

### Task 10: Add AdaptiveSliverAppBar to Episode Detail Page

**Files:**
- Modify: `lib/features/podcast/presentation/pages/podcast_episode_detail_page.dart`
- Modify: `lib/features/podcast/presentation/pages/podcast_episode_detail_page_layout.dart`
- Modify: `lib/features/podcast/presentation/pages/podcast_episode_detail_page_header.dart`

This page has a complex hero card with collapsing behavior. We take a minimal approach: add `AdaptiveSliverAppBar` as a proper nav bar and remove the back button + title from the hero card.

- [ ] **Step 1: Update imports in main file**

Add in `podcast_episode_detail_page.dart`:
```dart
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive_sliver_app_bar.dart';
```

- [ ] **Step 2: Modify `_buildNewLayout` in layout file**

Wrap the existing `Stack` in a `CustomScrollView` with an `AdaptiveSliverAppBar` sliver at the top. The key insight: the existing layout uses `Stack > Padding > Column` with manual safe area handling. We remove the safe area offset from `outerPadding` (the nav bar handles it now) and add the AdaptiveSliverAppBar as the first sliver:

In `podcast_episode_detail_page_layout.dart`, replace `_buildNewLayout`:

```dart
Widget _buildNewLayout(
  BuildContext context,
  PodcastEpisodeModel episode,
) {
  return LayoutBuilder(
    builder: (context, layoutConstraints) {
      final isWideScreen =
          layoutConstraints.maxWidth >
              _PodcastEpisodeDetailPageState._wideLayoutBreakpoint;

      return CustomScrollView(
        slivers: [
          AdaptiveSliverAppBar(
            title: episode.title,
          ),
          SliverToBoxAdapter(
            child: _buildLayoutContent(context, episode, isWideScreen, layoutConstraints),
          ),
        ],
      );
    },
  );
}
```

Then create `_buildLayoutContent` containing the old Stack > Padding > Column logic, but without the `safeTop` offset in `outerPadding`:

```dart
Widget _buildLayoutContent(
  BuildContext context,
  PodcastEpisodeModel episode,
  bool isWideScreen,
  BoxConstraints layoutConstraints,
) {
  final outerPadding = EdgeInsets.fromLTRB(
    layoutConstraints.maxWidth < Breakpoints.medium ? 16 : 20,
    layoutConstraints.maxWidth < Breakpoints.medium ? 12 : 16,
    layoutConstraints.maxWidth < Breakpoints.medium ? 16 : 20,
    16,
  );

  return Stack(
    fit: StackFit.expand,
    children: [
      const SizedBox(),
      Padding(
        padding: outerPadding,
        child: Column(
          children: [
            // Header (hero card)
            ValueListenableBuilder<bool>(
              valueListenable: _isHeaderExpandedNotifier,
              builder: (context, isExpanded, _) {
                if (!isExpanded) return const SizedBox.shrink();
                return Column(
                  children: [
                    isWideScreen
                        ? _buildAnimatedHeader(episode)
                        : _buildHeader(episode),
                    const SizedBox(height: AppSpacing.smMd),
                  ],
                );
              },
            ),
            // Tab bar
            isWideScreen
                ? _buildTopButtonBar(context, episode)
                : _buildMobileTopTextBar(context, episode),
            // Tab content
            Expanded(
              child: isWideScreen
                  ? Stack(
                      children: [
                        _buildTabContent(context, episode),
                        _buildScrollToTopButton(episode),
                      ],
                    )
                  : Stack(
                      children: [
                        PageView(
                          controller: _pageController,
                          onPageChanged: (index) => setState(() => _selectedTabIndex = index),
                          children: [
                            _buildTabContent(context, episode),
                            _buildTabContent(context, episode),
                            _buildTabContent(context, episode),
                          ],
                        ),
                        _buildScrollToTopButton(episode),
                      ],
                    ),
            ),
          ],
        ),
      ),
    ],
  );
}
```

- [ ] **Step 3: Remove title text from hero card in header file**

In `podcast_episode_detail_page_header.dart`, in `_buildHeroHeaderCard`:

**Wide layout:** Remove the `Text(title, ...)` widget and its `SizedBox(height: AppSpacing.sm)` spacer. The title is now in the AdaptiveSliverAppBar. Keep the metadata chips Row and the action column.

**Mobile layout:** Remove the `Text(title, ...)` widget. Keep the mobile metadata text and the source link action. Keep the action column.

The wide layout Row becomes:
```dart
Row(
  children: [
    _buildHeroArtwork(episode, isWide: true),
    SizedBox(width: AppSpacing.mdLg),
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title removed — now in AdaptiveSliverAppBar
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.smMd,
            children: metadata.whereType<Widget>().toList(growable: false),
          ),
        ],
      ),
    ),
    SizedBox(width: AppSpacing.mdLg),
    _buildWideHeaderActionColumn(episode, l10n),
  ],
)
```

The mobile layout Row becomes:
```dart
Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    _buildHeroArtwork(episode, isWide: false),
    SizedBox(width: AppSpacing.smMd),
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title removed — now in AdaptiveSliverAppBar
          Text(mobileMetadata, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.1,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (episode.itemLink case final link? when link.trim().isNotEmpty) ...[
            SizedBox(height: AppSpacing.smMd),
            _buildMobileSourceLinkAction(episode, l10n),
          ],
        ],
      ),
    ),
    SizedBox(width: AppSpacing.sm),
    _buildMobileHeroActionColumn(episode, l10n),
  ],
)
```

- [ ] **Step 4: Remove `_buildBackButton` and its usage**

In `_buildWideHeaderActionColumn`, remove the `_buildBackButton()` call and its preceding `SizedBox`. The wide action column becomes:

```dart
Widget _buildWideHeaderActionColumn(PodcastEpisodeModel episode, AppLocalizations l10n) {
  return ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 124, maxWidth: 168),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          _buildDownloadButton(episode),
          SizedBox(width: AppSpacing.sm),
          _buildQueueButton(),
          SizedBox(width: AppSpacing.sm),
          _buildShareButton(episode),
        ]),
        SizedBox(height: AppSpacing.sm),
        _buildPlayButton(episode, l10n, compact: false,
          density: HeaderCapsuleActionButtonDensity.compact,
          padding: EdgeInsets.symmetric(horizontal: 7, vertical: AppSpacing.xs)),
      ],
    ),
  );
}
```

Delete the `_buildBackButton` method entirely.

- [ ] **Step 5: Verify compilation**

Run: `cd frontend && flutter analyze lib/features/podcast/presentation/pages/podcast_episode_detail_page.dart`

- [ ] **Step 6: Commit**

```bash
git add lib/features/podcast/presentation/pages/podcast_episode_detail_page.dart lib/features/podcast/presentation/pages/podcast_episode_detail_page_layout.dart lib/features/podcast/presentation/pages/podcast_episode_detail_page_header.dart
git commit -m "feat(ui): add AdaptiveSliverAppBar to PodcastEpisodeDetailPage"
```

---

## Phase 7: Cleanup

### Task 11: Deprecate CompactHeaderPanel

**Files:**
- Modify: `lib/core/widgets/app_shells.dart`

- [ ] **Step 1: Add @Deprecated annotation to CompactHeaderPanel**

Add a deprecation notice to the class doc comment:

```dart
/// CompactHeaderPanel - 紧凑头部面板
///
/// @deprecated Use [AdaptiveSliverAppBar] instead.
/// This widget will be removed in a future version.
@Deprecated('Use AdaptiveSliverAppBar instead')
class CompactHeaderPanel extends StatelessWidget {
```

- [ ] **Step 2: Verify no remaining usages**

Run: `cd frontend && grep -r "CompactHeaderPanel" lib/`

Expected: Only the definition in `app_shells.dart` and the deprecation annotation. If any pages still reference it, migrate them first.

- [ ] **Step 3: Commit**

```bash
git add lib/core/widgets/app_shells.dart
git commit -m "chore(ui): deprecate CompactHeaderPanel in favor of AdaptiveSliverAppBar"
```

---

## Final Verification

### Task 12: Full Analysis and Test

- [ ] **Step 1: Run full Flutter analyze**

Run: `cd frontend && flutter analyze`

- [ ] **Step 2: Run all tests**

Run: `cd frontend && flutter test`

- [ ] **Step 3: Manual visual check**

Launch the app on both iOS simulator and Android emulator. Navigate to each migrated page and verify:
- iOS: Large title appears at top, collapses if scrolled, system back button visible
- Android: Material title bar appears, system back arrow visible
- All action buttons (calendar, delete, refresh, add) render correctly
- Page body content scrolls normally
- No visual regressions

- [ ] **Step 4: Final commit if any fixes needed**
