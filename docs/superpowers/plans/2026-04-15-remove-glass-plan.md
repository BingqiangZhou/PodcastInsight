# Remove Glass Effect — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Remove all glass/frosted-glass effects and replace with flat Material 3 styling.

**Architecture:** Delete `core/glass/` directory entirely. Replace `GlassContainer` → `Container` with `surfaceContainerHighest`, `SurfaceCard` → `Container` with theme surface colors, `GlassBackground` → remove wrapper (Scaffold already has background). Remove tier tokens from `AppThemeExtension`.

**Tech Stack:** Flutter/Dart, Material 3

---

## Phase 1: Core Infrastructure (must complete first)

### Task 1: Update SurfacePanel in app_shells.dart

**Files:**
- Modify: `frontend/lib/core/widgets/app_shells.dart`

Replace `SurfaceCard` usage inside `SurfacePanel._SurfacePanelState.build()` (lines 331-339) with a plain `Container`:

```dart
// In _SurfacePanelState.build(), replace:
child: SurfaceCard(
  borderRadius: radius,
  padding: widget.padding,
  backgroundColor: widget.backgroundColor,
  tier: widget.tier,
  child: widget.child,
),

// With:
child: Container(
  decoration: BoxDecoration(
    color: widget.backgroundColor ?? Theme.of(context).colorScheme.surfaceContainerLow,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.15),
    ),
  ),
  child: widget.padding != null
      ? Padding(padding: widget.padding!, child: widget.child)
      : widget.child,
),
```

Also remove `CardTier` from `SurfacePanel` constructor (line 303) — change `this.tier = CardTier.card` to just remove the parameter entirely. Remove the `tier` field (line 314). Remove the import of `surface_card.dart` (line 5). Remove the import of `glass_background.dart` (line 4).

Then remove `GlassBackground` wrappers from `ContentShell` (line 688), `ProfileShell` (line 743), `AuthShell` (line 828). Replace each `GlassBackground(child: Material(...))` with just `Material(...)`.

- [ ] Step 1: Edit SurfacePanel to use Container instead of SurfaceCard, remove CardTier param
- [ ] Step 2: Remove GlassBackground from ContentShell, ProfileShell, AuthShell
- [ ] Step 3: Remove glass imports (glass_background, surface_card)
- [ ] Step 4: Run `cd frontend && flutter analyze lib/core/widgets/app_shells.dart` to verify
- [ ] Step 5: Commit: `refactor: remove glass from core shells and SurfacePanel`

---

## Phase 2: Helper Widgets (parallel, after Phase 1)

### Task 2: Replace GlassContainer in adaptive_sheet_helper.dart

**Files:**
- Modify: `frontend/lib/core/widgets/adaptive_sheet_helper.dart`

Remove imports of `glass_container.dart` and `glass_tokens.dart` (lines 3-4).

Replace desktop dialog `GlassContainer(tier: GlassTier.overlay, borderRadius: 28, padding: EdgeInsets.zero, child: builder(dialogCtx))` with:
```dart
Container(
  decoration: BoxDecoration(
    color: Theme.of(dialogCtx).colorScheme.surfaceContainerHighest,
    borderRadius: BorderRadius.circular(28),
  ),
  child: builder(dialogCtx),
)
```

Replace mobile sheet `GlassContainer(tier: GlassTier.overlay, borderRadius: 28, padding: EdgeInsets.zero, child: builder(sheetCtx))` with:
```dart
Container(
  decoration: BoxDecoration(
    color: Theme.of(sheetCtx).colorScheme.surfaceContainerHighest,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
  ),
  child: builder(sheetCtx),
)
```

- [ ] Step 1: Edit adaptive_sheet_helper.dart
- [ ] Step 2: Commit: `refactor: remove glass from adaptive sheet helper`

### Task 3: Replace GlassContainer in glass_dialog_helper.dart

**Files:**
- Modify: `frontend/lib/core/widgets/glass_dialog_helper.dart`

Remove imports of `glass_container.dart` and `glass_tokens.dart` (lines 3-4).

In `showGlassDialog`: Remove `GlassTier` parameter, replace `GlassContainer(...)` with:
```dart
Container(
  decoration: BoxDecoration(
    color: Theme.of(dialogCtx).colorScheme.surfaceContainerHighest,
    borderRadius: BorderRadius.circular(borderRadius),
  ),
  child: builder(dialogCtx),
)
```

In `showGlassConfirmationDialog`: Remove `GlassTier` parameter.

- [ ] Step 1: Edit glass_dialog_helper.dart
- [ ] Step 2: Commit: `refactor: remove glass from dialog helper`

### Task 4: Replace GlassContainer in top_floating_notice.dart

**Files:**
- Modify: `frontend/lib/core/widgets/top_floating_notice.dart`

Remove import of `glass_container.dart` (line 4).

Replace `GlassContainer(borderRadius: 12, padding: ..., tint: ..., child: ...)` with:
```dart
Container(
  decoration: BoxDecoration(
    color: isError
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.surfaceContainerHighest,
    borderRadius: BorderRadius.circular(12),
  ),
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 18, color: foregroundColor),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          message,
          key: const Key('top_floating_notice_message'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelLarge?.copyWith(
            color: foregroundColor,
          ),
        ),
      ),
    ],
  ),
)
```

- [ ] Step 1: Edit top_floating_notice.dart
- [ ] Step 2: Commit: `refactor: remove glass from top floating notice`

---

## Phase 3: Consumer Files (parallel, after Phase 1)

### Task 5: SurfaceCard consumers in shared/settings

**Files:**
- Modify: `frontend/lib/shared/widgets/settings_section_card.dart`
- Modify: `frontend/lib/features/settings/presentation/widgets/font_combo_card.dart`

**Pattern — replace every `SurfaceCard(...)` with `Container(...)`:**

```dart
// Before:
SurfaceCard(
  borderRadius: 12,
  padding: EdgeInsets.zero,
  child: Column(children: children),
)

// After:
Container(
  decoration: BoxDecoration(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.15),
    ),
  ),
  child: Column(children: children),
)
```

For `font_combo_card.dart`: same pattern. When `backgroundColor` was set on SurfaceCard, keep it on Container's `color`.

Remove `import .../surface_card.dart` from both files.

- [ ] Step 1: Edit settings_section_card.dart
- [ ] Step 2: Edit font_combo_card.dart
- [ ] Step 3: Commit: `refactor: remove SurfaceCard from settings/shared widgets`

### Task 6: SurfaceCard consumers in podcast widgets

**Files:**
- Modify: `frontend/lib/features/podcast/presentation/widgets/shared/base_episode_card.dart`
- Modify: `frontend/lib/features/podcast/presentation/widgets/highlight_card.dart`
- Modify: `frontend/lib/features/podcast/presentation/widgets/highlight_detail_sheet.dart`
- Modify: `frontend/lib/features/podcast/presentation/widgets/transcription_status_widget.dart`
- Modify: `frontend/lib/features/podcast/presentation/widgets/transcription/transcript_result_widget.dart`

Same pattern as Task 5 — replace `SurfaceCard` with `Container` using `surfaceContainerLow` color + border. Remove `surface_card.dart` imports.

For `transcript_result_widget.dart`: two SurfaceCard instances have custom `backgroundColor` — keep those on the Container's `color`.

- [ ] Step 1: Edit all 5 files
- [ ] Step 2: Commit: `refactor: remove SurfaceCard from podcast widgets`

### Task 7: SurfaceCard consumers in podcast pages

**Files:**
- Modify: `frontend/lib/features/podcast/presentation/pages/podcast_downloads_page.dart`
- Modify: `frontend/lib/features/podcast/presentation/pages/podcast_highlights_page.dart`
- Modify: `frontend/lib/features/podcast/presentation/pages/podcast_daily_report_page.dart`

Same SurfaceCard → Container pattern. Also remove `GlassBackground` wrapper from these pages (look for `GlassBackground(child:` and unwrap to just the child widget).

- [ ] Step 1: Edit all 3 files
- [ ] Step 2: Commit: `refactor: remove SurfaceCard and GlassBackground from podcast pages`

### Task 8: GlassContainer consumers in podcast feature

**Files:**
- Modify: `frontend/lib/features/podcast/presentation/widgets/add_podcast_dialog.dart`
- Modify: `frontend/lib/features/podcast/presentation/widgets/podcast_bottom_player_layouts.dart`
- Modify: `frontend/lib/features/podcast/presentation/pages/podcast_episode_detail_page.dart`
- Modify: `frontend/lib/features/podcast/presentation/pages/podcast_episode_detail_page_content.dart`

**add_podcast_dialog.dart (line 71):** Replace `GlassContainer(tier: GlassTier.overlay, borderRadius: 28, padding: ..., child: ...)` with:
```dart
Container(
  decoration: BoxDecoration(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    borderRadius: BorderRadius.circular(28),
  ),
  padding: const EdgeInsets.all(24),
  child: ...
)
```

**podcast_bottom_player_layouts.dart (line 273):** Replace `GlassContainer(tier: GlassTier.overlay, borderRadius: ..., child: Material(...))` with:
```dart
Container(
  decoration: BoxDecoration(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    borderRadius: BorderRadius.circular(viewportSpec.mobileDrawerBorderRadius),
  ),
  child: Material(...)
)
```

Also in `_MiniDockBody` (line 128-136): replace `extension.cardTierFill`/`extension.cardTierBorder` with `theme.colorScheme.surfaceContainerLow` / `theme.colorScheme.outlineVariant.withValues(alpha: 0.15)`.

**podcast_episode_detail_page.dart (line 382):** Replace `GlassContainer(borderRadius: 16, ...)` with Container.

**podcast_episode_detail_page_content.dart (line 343):** Replace `GlassContainer(tier: GlassTier.overlay, borderRadius: 0, ...)` with:
```dart
Container(
  decoration: BoxDecoration(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
  ),
  child: SafeArea(...)
)
```

Remove all glass imports from these files.

- [ ] Step 1: Edit all 4 files
- [ ] Step 2: Commit: `refactor: remove GlassContainer from podcast widgets and pages`

### Task 9: GlassTokens direct usage in podcast pages

**Files:**
- Modify: `frontend/lib/features/podcast/presentation/pages/podcast_highlights_page.dart`
- Modify: `frontend/lib/features/podcast/presentation/pages/podcast_daily_report_page.dart`

Replace `GlassTokens.of(context).glassFill.withValues(alpha: X)` with `Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: X)`.

Occurrences:
- `podcast_highlights_page.dart:719` — 1 occurrence
- `podcast_daily_report_page.dart:188, 192, 766` — 3 occurrences

Remove glass imports.

- [ ] Step 1: Edit both files
- [ ] Step 2: Commit: `refactor: replace GlassTokens with theme surface colors in podcast pages`

### Task 10: Remaining GlassBackground pages

**Files:**
- Modify: `frontend/lib/features/podcast/presentation/pages/podcast_episodes_page.dart`
- Modify: `frontend/lib/features/auth/presentation/pages/auth_verify_page.dart`
- Modify: `frontend/lib/features/auth/presentation/pages/onboarding_page.dart`
- Modify: `frontend/lib/features/splash/presentation/pages/splash_page.dart`
- Modify: `frontend/lib/features/profile/presentation/pages/terms_page.dart`
- Modify: `frontend/lib/features/profile/presentation/pages/privacy_page.dart`

Remove `GlassBackground(child: X)` → `X`. Remove glass imports.

For `auth_verify_page.dart`: also replace `SurfaceCard` instances with Container.

- [ ] Step 1: Edit all 6 files
- [ ] Step 2: Commit: `refactor: remove GlassBackground from remaining pages`

### Task 11: Profile pages with SurfaceCard

**Files:**
- Modify: `frontend/lib/features/profile/presentation/pages/profile_subscriptions_page.dart`
- Modify: `frontend/lib/features/profile/presentation/pages/profile_history_page.dart`
- Modify: `frontend/lib/features/profile/presentation/pages/profile_cache_management_page.dart`

Remove `GlassBackground` wrappers. Replace `SurfaceCard` with Container pattern.

- [ ] Step 1: Edit all 3 files
- [ ] Step 2: Commit: `refactor: remove glass from profile pages`

### Task 12: Auth register page

**Files:**
- Modify: `frontend/lib/features/auth/presentation/pages/register_page.dart`

Replace `SurfaceCard` with Container.

- [ ] Step 1: Edit file
- [ ] Step 2: Commit: `refactor: remove SurfaceCard from register page`

---

## Phase 4: Cleanup (after all consumers are done)

### Task 13: Remove tier tokens from AppThemeExtension

**Files:**
- Modify: `frontend/lib/core/theme/app_colors.dart`

Remove from `AppColors`:
- Lines 41-46: `lightSurfaceTierFill`, `lightCardTierFill`, `lightElevatedTierFill`, `lightSurfaceTierBorder`, `lightCardTierBorder`, `lightElevatedTierBorder`
- Lines 74-79: `surfaceTierFill`, `cardTierFill`, `elevatedTierFill`, `surfaceTierBorder`, `cardTierBorder`, `elevatedTierBorder`

Remove from `AppThemeExtension` constructor (line 217):
- `required this.surfaceTierFill, required this.cardTierFill, required this.elevatedTierFill, required this.surfaceTierBorder, required this.cardTierBorder, required this.elevatedTierBorder`

Remove 6 fields (lines 244-250):
- `surfaceTierFill`, `cardTierFill`, `elevatedTierFill`, `surfaceTierBorder`, `cardTierBorder`, `elevatedTierBorder`

Remove from `copyWith` (lines 270-275): the 6 parameters and their assignments.

Remove from `lerp` (lines 330-340): the 6 Color.lerp calls.

Remove from `light` const (lines 379-384): the 6 light tier token assignments.

Remove from `dark` const (lines 422-427): the 6 dark tier token assignments.

Also update the class header comment from "Arc + Linear Design System" to just "App Design System" since glass is removed.

- [ ] Step 1: Edit app_colors.dart
- [ ] Step 2: Commit: `refactor: remove tier tokens from AppThemeExtension`

### Task 14: Delete glass directory and test files

**Files:**
- Delete: `frontend/lib/core/glass/` (entire directory: 5 files)
- Delete: `frontend/test/unit/core/glass/` (2 test files)
- Delete: `frontend/test/widget/core/glass/` (2 test files)

```bash
rm -rf frontend/lib/core/glass/
rm -rf frontend/test/unit/core/glass/
rm -rf frontend/test/widget/core/glass/
```

- [ ] Step 1: Delete directories
- [ ] Step 2: Commit: `refactor: delete glass directory and tests`

### Task 15: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

Remove from Project Structure section: `glass/ Arc+Linear design system (GlassBackground, GlassContainer, GlassTokens, SurfaceCard)` line.

Remove from Conventions > Frontend: `**Arc+Linear design system**: GlassContainer/SurfaceCard for card surfaces. GlassBackground for page backgrounds. Theme tokens in AppColors`.

Remove from Gotchas table: `Hardcoded colors/radii | AppColors tokens and AppRadius constants` (this stays actually — it's still valid without glass). Actually keep this row but remove Arc+Linear references.

- [ ] Step 1: Edit CLAUDE.md
- [ ] Step 2: Commit: `docs: update CLAUDE.md to remove glass references`

### Task 16: Final verification

- [ ] Step 1: Run `cd frontend && flutter analyze` to check for compilation errors
- [ ] Step 2: Run `cd frontend && flutter test` to verify all tests pass
- [ ] Step 3: Fix any remaining issues
- [ ] Step 4: Commit any fixes
