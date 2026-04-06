# Stella UI Redesign: Arc + Linear Fusion — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps Use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Apple Liquid Glass design system with an Arc + Linear fusion visual identity — dark base, colorful gradient accents, precise typography, simplified glass effects.

**Architecture:** Phase-based rollout. Each phase is independently committable and testable. Later phases depend on earlier ones for new tokens/components but don't break existing functionality between phases.

**Tech Stack:** Flutter 3.8+, Dart, Riverpod 3.x, Material 3, existing codegen toolchain (build_runner).

---

## Phase 1: Design Tokens & Theme Foundation

> No visual changes yet. Establish the new color, radius, and spacing tokens so later phases can reference them.

### Task 1: Rewrite color tokens

**Files:**
- Modify: `frontend/lib/core/theme/app_colors.dart` (lines 13-145 `AppColors`, lines 152-408 `AppThemeExtension`)
- Modify: `frontend/lib/core/theme/app_theme.dart` (lines 486-555 `_buildColorScheme`)

- [ ] **Step 1: Add new dark theme color constants to `AppColors`**

Replace the existing dark theme colors (lines 36-52) with the new Arc+Linear palette. Add gradient color constants as `LinearGradient` static getters:

```dart
// New dark theme surface tokens
static const Color darkBackground = Color(0xFF0f0f1a);
static const Color darkSurface = Color(0xFF1a1a2e);
static const Color darkSurfaceElevated = Color(0xFF252540);
static const Color darkOnBackground = Color(0xE6FFFFFF); // rgba 0.9
static const Color darkOnSurface = Color(0x80FFFFFF); // rgba 0.5
static const Color darkOnSurfaceMuted = Color(0x40FFFFFF); // rgba 0.25
static const Color darkBorder = Color(0x0FFFFFFF); // rgba 0.06
static const Color darkBorderHover = Color(0x1FFFFFFF); // rgba 0.12

// New light theme surface tokens
static const Color lightBackground = Color(0xFFF8F9FA);
static const Color lightSurface = Color(0xFFFFFFFF);
static const Color lightSurfaceElevated = Color(0xFFFFFFFF);
static const Color lightOnBackground = Color(0xFF1a1a2e);
static const Color lightOnSurface = Color(0x991a1a2e); // rgba 0.6
static const Color lightOnSurfaceMuted = Color(0x591a1a2e); // rgba 0.35
static const Color lightBorder = Color(0x0F000000); // rgba 0.06

// Card tier colors
static const Color surfaceTier = Color(0x0AFFFFFF); // rgba 0.04
static const Color cardTier = Color(0x0FFFFFFF); // rgba 0.06
static const Color elevatedTier = Color(0x14FFFFFF); // rgba 0.08
static const Color elevatedTierBorder = Color(0x1AFFFFFF); // rgba 0.10
static const Color surfaceTierBorder = Color(0x0FFFFFFF); // rgba 0.06
static const Color cardTierBorder = Color(0x14FFFFFF); // rgba 0.08

// Gradient palette
static const Gradient coralGradient = LinearGradient(
  colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
);
static const Gradient violetGradient = LinearGradient(
  colors: [Color(0xFF9B5DE5), Color(0xFF5B6BF0)],
);
static const Gradient cyanGradient = LinearGradient(
  colors: [Color(0xFF00C9A7), Color(0xFF00D4FF)],
);
static const Gradient goldGradient = LinearGradient(
  colors: [Color(0xFFFFC75F), Color(0xFFFFD93D)],
);
static const Gradient roseGradient = LinearGradient(
  colors: [Color(0xFFF15BB5), Color(0xFFFF6B6B)],
);
static const Gradient skyGradient = LinearGradient(
  colors: [Color(0xFF4CC9F0), Color(0xFF72EFDD)],
);
static const Gradient aiAccentGradient = LinearGradient(
  colors: [Color(0xFF9B5DE5), Color(0xFF5B6BF0)],
);
static const List<Gradient> podcastGradients = [
  coralGradient, violetGradient, cyanGradient,
  goldGradient, roseGradient, skyGradient,
];
```

- [ ] **Step 2: Update `AppThemeExtension` fields**

Add new fields to `AppThemeExtension` for surface tiers, gradient tokens, and updated radius values. Remove legacy `shellGradient`, `aiPrimary`, `aiBubbleUserColor`, `aiBubbleAssistantColor`, `aiChipColor`, `aiHighlightSurfaceColor`, `cosmicFilterActiveColor`. Replace with:

```dart
// Surface tier tokens
final Color surfaceTierFill;
final Color cardTierFill;
final Color elevatedTierFill;
final Color surfaceTierBorder;
final Color cardTierBorder;
final Color elevatedTierBorder;

// Gradient tokens
final List<LinearGradient> podcastGradients;
final LinearGradient aiAccentGradient;

// Updated radius (Arc-style: slightly larger)
@override
final double cardRadius; // 14
final double buttonRadius; // 10
final double itemRadius; // 8 (new)
final double navItemRadius; // 10
final double pillRadius; // 999
final double sheetRadius; // 20
```

Update `copyWith`, `lerp`, `light`, and `dark` factories to include new fields.

- [ ] **Step 3: Update `_buildColorScheme` in `app_theme.dart`**

Change the `ColorScheme.fromSeed()` calls to use the new dark/light background and surface colors as `surface`, `background`, `onSurface`, etc. Remove references to old Apple HIG color constants where they conflict.

- [ ] **Step 4: Run build_runner and verify compilation**

```bash
cd frontend
dart run build_runner build
flutter analyze
```

Expected: No compile errors. App still looks the same (tokens not yet consumed by widgets).

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/core/theme/
git commit -m "feat(theme): add Arc+Linear color tokens and gradient palette"
```

---

### Task 2: Merge `apple_colors.dart` into `app_colors.dart`

**Files:**
- Modify: `frontend/lib/core/theme/app_colors.dart` (add any missing Apple HIG colors needed)
- Modify: `frontend/lib/core/widgets/custom_adaptive_navigation.dart` (lines 6, 480 — replace `AppleColors` imports)
- Modify: `frontend/lib/core/widgets/page_transitions.dart` (replace `AppleColors` imports)
- Delete: `frontend/lib/core/theme/apple_colors.dart`

- [ ] **Step 1: Find all imports of `apple_colors.dart`**

```bash
cd frontend && grep -rn "apple_colors" lib/ --include="*.dart" -l
```

Expected: `custom_adaptive_navigation.dart` (line 6) and `page_transitions.dart`.

- [ ] **Step 2: Replace `AppleColors` usage in consumers**

In `custom_adaptive_navigation.dart` line ~480, replace `AppleColors.systemOrange.of(context)` with `AppColors.accentWarm` or the new gradient token.

In `page_transitions.dart`, replace any `AppleColors` references with equivalent `AppColors` constants.

- [ ] **Step 3: Delete `apple_colors.dart`**

Delete the file and remove it from any barrel exports.

- [ ] **Step 4: Verify compilation**

```bash
cd frontend && flutter analyze
```

- [ ] **Step 5: Commit**

```bash
git commit -m "refactor(theme): merge apple_colors into app_colors, eliminate dual color system"
```

---

### Task 3: Update radius tokens and remove hardcoded values

**Files:**
- Modify: `frontend/lib/core/constants/app_radius.dart` (lines 18-97)
- Modify: `frontend/lib/core/theme/app_colors.dart` (`AppThemeExtension` radius fields)

- [ ] **Step 1: Update `AppRadius` to match new tokens**

Change `cardValue` from 12 to 14, remove `panelValue` (merged into card), add `itemRadius = 8`. Remove unused `organicCard` and `organicButton` (lines 57-69).

- [ ] **Step 2: Update `AppThemeExtension` radius defaults**

Set `cardRadius: 14`, `sheetRadius: 20`, add `itemRadius: 8`.

- [ ] **Step 3: Verify no compile errors**

```bash
cd frontend && flutter analyze
```

- [ ] **Step 4: Commit**

```bash
git commit -m "refactor(tokens): unify radius tokens, remove hardcoded values"
```

---

## Phase 2: Simplify Glass System

> Reduce glass from 5-layer animated to 3-layer static. Delete painter files. Keep BackdropFilter blur for sidebar/overlays.

### Task 4: Delete glass painter and style files

**Files:**
- Delete: `frontend/lib/core/glass/glass_painter.dart` (189 lines — FresnelPainter, SpecularPainter, NoisePainter)
- Delete: `frontend/lib/core/glass/glass_style.dart` (168 lines — GlassStyle class)

- [ ] **Step 1: Verify no direct imports of glass_painter.dart remain outside glass_container.dart**

```bash
cd frontend && grep -rn "glass_painter" lib/ --include="*.dart" -l
```

Expected: only `glass_container.dart`. Same for `glass_style.dart`.

- [ ] **Step 2: Delete both files**

- [ ] **Step 3: Commit**

```bash
git commit -m "refactor(glass): delete custom painters and GlassStyle class"
```

---

### Task 5: Simplify GlassContainer (5-layer → 3-layer)

**Files:**
- Rewrite: `frontend/lib/core/glass/glass_container.dart` (543 → ~120 lines)

- [ ] **Step 1: Rewrite GlassContainer**

Replace the 5-layer, 5-animation-controller implementation with a simple 3-layer widget:

```dart
class GlassContainer extends StatelessWidget {
  final Widget child;
  final GlassTier tier;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final bool enableBlur; // defaults true

  // Simple constructor, no animation controllers
  // Build method:
  // 1. BackdropFilter (blur sigma from tier) — only if enableBlur
  // 2. Container with semi-transparent fill + border
  // 3. Padding with child
}
```

Remove: all `AnimationController` fields, `_GlassContainerState`, hover/press handlers, `RepaintBoundary`, all animated layers.

Use `GlassTierParams` from `glass_tokens.dart` only for sigma and fill opacity.

- [ ] **Step 2: Update GlassTierParams if needed**

In `glass_tokens.dart`, remove fields that only served the old painter system: `borderTop`, `borderBottom`, `innerGlow`, `saturationBoost`, `noiseOpacity`. Keep only: `fill`, `sigma`, `contentScrim`.

- [ ] **Step 3: Verify all consumers still compile**

```bash
cd frontend && flutter analyze
```

All 19 files importing `glass_container.dart` should still work since `GlassContainer` keeps the same constructor signature (tier, child, borderRadius, padding).

- [ ] **Step 4: Run existing widget tests**

```bash
cd frontend && flutter test test/widget/
```

Expected: Some tests may fail due to removed animations (no `Ticker` needed). Fix by removing animation expectations.

- [ ] **Step 5: Commit**

```bash
git commit -m "refactor(glass): simplify GlassContainer from 5-layer animated to 3-layer static"
```

---

### Task 6: Simplify GlassTokens (4-tier → 2-tier)

**Files:**
- Modify: `frontend/lib/core/glass/glass_tokens.dart` (229 lines)

- [ ] **Step 1: Reduce GlassTier enum to 2 values**

```dart
enum GlassTier {
  standard(20), // sidebar, cards
  overlay(30);  // full-screen overlays, dialogs
  final double sigma;
  const GlassTier(this.sigma);
}
```

- [ ] **Step 2: Simplify GlassTierParams**

Keep only `fill` (Color) and `sigma` (double). Remove all other fields.

- [ ] **Step 3: Update all consumers that reference `GlassTier.medium`, `GlassTier.heavy`, etc.**

```bash
cd frontend && grep -rn "GlassTier\." lib/ --include="*.dart"
```

Map: `ultraHeavy` → `overlay`, `heavy` → `overlay`, `medium` → `standard`, `light` → `standard`.

- [ ] **Step 4: Verify compilation**

```bash
cd frontend && flutter analyze
```

- [ ] **Step 5: Commit**

```bash
git commit -m "refactor(glass): reduce glass tiers from 4 to 2 (standard/overlay)"
```

---

### Task 7: Update GlassBackground for dark theme

**Files:**
- Modify: `frontend/lib/core/glass/glass_background.dart` (219 lines)

- [ ] **Step 1: Darken orbs and reduce saturation**

In `_getThemeColors` (lines 193-217), change all orb colors to much darker, desaturated variants that blend into `#0f0f1a`:

```dart
// Dark mode orbs — barely visible atmospheric depth
static const _darkOrbColors = [
  Color(0xFF1a1040), // deep indigo
  Color(0xFF0f2030), // deep teal
  Color(0xFF201020), // deep purple
];
```

For light mode, keep very pale pastels.

- [ ] **Step 2: Remove animation enable/disable complexity**

Simplify: always animate gently, or use a single slow controller (30s → 60s, even more subtle).

- [ ] **Step 3: Verify visually (manual check)**

App should show subtle, barely-there dark orbs on dark background.

- [ ] **Step 4: Commit**

```bash
git commit -m "refactor(glass): darken background orbs for Arc+Linear dark theme"
```

---

### Task 8: Update GlassVibrancy for new opacities

**Files:**
- Modify: `frontend/lib/core/glass/glass_vibrancy.dart` (111 lines)

- [ ] **Step 1: Update alpha boost thresholds**

Since surface opacities changed (0.04/0.06/0.08 instead of old values), update `_boostedAlpha` and `_boostedAlphaTertiary` to ensure text readability against new surfaces.

- [ ] **Step 2: Verify compilation**

- [ ] **Step 3: Commit**

```bash
git commit -m "refactor(glass): update vibrancy alpha thresholds for new surface opacities"
```

---

## Phase 3: Navigation Redesign

> Redesign the sidebar and mobile nav to Arc+Linear style.

### Task 9: Redesign expandable sidebar

**Files:**
- Rewrite: `frontend/lib/core/widgets/custom_adaptive_navigation.dart` (672 lines)

- [ ] **Step 1: Replace `_CleanSidebar` with Arc-style sidebar**

The `_CleanSidebar` (lines 633-649) currently wraps `GlassContainer(tier: GlassTier.heavy)`. Replace with:

```dart
// New sidebar: dark surface + blur + expand/collapse
Container(
  color: AppColors.darkSurface, // #1a1a2e
  child: ClipRRect(
    borderRadius: BorderRadius.horizontal(right: Radius.circular(14)),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: /* sidebar content */,
    ),
  ),
)
```

- [ ] **Step 2: Implement expand/collapse state**

Add a `ValueNotifier<bool>` for sidebar expanded state (default: expanded on desktop). Persist with `SharedPreferences` using key `sidebar_expanded`.

Collapsed (60px): icon-only nav items. Expanded (240px): icon + label + pinned section.

- [ ] **Step 3: Add pinned podcasts section to sidebar**

Below the navigation items, add a divider and a "Pinned" section that shows user's subscribed podcasts with their identity color blocks. Use the `podcastGradients` palette with hash-based assignment.

- [ ] **Step 4: Style navigation items with gradient active states**

Replace the current orange dot indicator with a gradient background on the active nav item. Use `violetGradient` for the active state.

- [ ] **Step 5: Verify sidebar renders on desktop/tablet breakpoints**

- [ ] **Step 6: Commit**

```bash
git commit -m "feat(nav): redesign sidebar with Arc+Linear expandable style"
```

---

### Task 10: Redesign mobile bottom navigation

**Files:**
- Modify: `frontend/lib/core/widgets/custom_adaptive_navigation.dart` (lines 493-576)

- [ ] **Step 1: Replace `_CleanDock` with dark bottom nav**

Replace `GlassContainer(tier: GlassTier.medium)` with a dark semi-transparent bottom bar using the new surface colors. Active tab uses gradient icon tinting.

- [ ] **Step 2: Verify mobile layout renders correctly**

- [ ] **Step 3: Commit**

```bash
git commit -m "feat(nav): redesign mobile bottom nav with Arc+Linear style"
```

---

### Task 11: Update page transitions

**Files:**
- Modify: `frontend/lib/core/widgets/page_transitions.dart`

- [ ] **Step 1: Remove Aurora/Arctic effects**

Replace all transition types with a simple 150ms fade. Remove `ArcticPageRoute` naming, rename to `StellaPageRoute`. Remove `ArcticPageTransitionType` enum variants for aurora, arctic, etc. Keep only: `fade`.

- [ ] **Step 2: Rename "Arctic Garden" references to "Stella"**

Search and replace all "Arctic Garden" / "Arctic" naming in this file and `app_radius.dart`.

- [ ] **Step 3: Verify transitions work**

- [ ] **Step 4: Commit**

```bash
git commit -m "refactor(transitions): simplify to 150ms fade, rename to Stella"
```

---

## Phase 4: Component Updates

> Update card hierarchy, shells, mini player, and AI chat to use new tokens.

### Task 12: Update card tier system

**Files:**
- Modify: `frontend/lib/core/glass/surface_card.dart` (108 lines)
- Modify: `frontend/lib/core/widgets/app_shells.dart` (`SurfacePanel` lines 301-367)

- [ ] **Step 1: Add card tier variants to SurfaceCard**

Add a `CardTier` enum: `surface`, `card`, `elevated`. Update `SurfaceCard` to accept a `tier` parameter that maps to the correct fill/border colors from `AppThemeExtension`.

- [ ] **Step 2: Update SurfacePanel to use new tiers**

- [ ] **Step 3: Verify compilation**

- [ ] **Step 4: Commit**

```bash
git commit -m "feat(components): add 3-tier card system (surface/card/elevated)"
```

---

### Task 13: Update shell widgets

**Files:**
- Modify: `frontend/lib/core/widgets/app_shells.dart` (903 lines — ContentShell, ProfileShell, AuthShell)

- [ ] **Step 1: Update ContentShell**

Replace `GlassBackground` orb colors with new dark variants. Use new surface tier colors for header/content areas. Increase page title to 48px display size.

- [ ] **Step 2: Update ProfileShell**

Same treatment as ContentShell.

- [ ] **Step 3: Update AuthShell**

Use dark surface background, add gradient accent to the auth card.

- [ ] **Step 4: Verify all shells render**

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(shells): update page shells with Arc+Linear dark theme"
```

---

### Task 14: Update mini player

**Files:**
- Modify: `frontend/lib/features/podcast/presentation/widgets/podcast_bottom_player_widget.dart`
- Modify: `frontend/lib/features/podcast/presentation/widgets/podcast_bottom_player_layouts.dart`

- [ ] **Step 1: Add gradient background to mini player**

Use the current podcast's identity gradient as background. Fall back to `violetGradient` if no podcast is playing.

- [ ] **Step 2: Update progress bar and controls**

White/light controls on gradient background. Progress bar: white semi-transparent track with bright white fill.

- [ ] **Step 3: Verify player renders and is functional**

- [ ] **Step 4: Commit**

```bash
git commit -m "feat(player): redesign mini player with gradient background"
```

---

### Task 15: Update AI chat bubbles

**Files:**
- Modify: `frontend/lib/features/podcast/presentation/widgets/conversation/chat_message_bubble.dart`
- Modify: `frontend/lib/features/podcast/presentation/widgets/conversation/chat_input_area.dart`

- [ ] **Step 1: Restyle user messages**

Right-aligned, `cardTierFill` background, no border.

- [ ] **Step 2: Restyle AI messages**

Left-aligned, `surfaceTierFill` background, 3px left border with `aiAccentGradient` (violet).

- [ ] **Step 3: Restyle input area**

Dark background `#252540`, rounded 14px, subtle border.

- [ ] **Step 4: Verify chat renders**

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(ai-chat): redesign chat bubbles with Arc+Linear style"
```

---

## Phase 5: Feature Page Updates

> Update all feature pages to use new tokens and visual style.

### Task 16: Update podcast pages

**Files:**
- Modify: `frontend/lib/features/podcast/presentation/pages/podcast_list_page.dart`
- Modify: `frontend/lib/features/podcast/presentation/pages/podcast_feed_page.dart`
- Modify: `frontend/lib/features/podcast/presentation/pages/podcast_episodes_page.dart`
- Modify: `frontend/lib/features/podcast/presentation/pages/podcast_episode_detail_page.dart` (+ part files)
- Modify: `frontend/lib/features/podcast/presentation/pages/podcast_downloads_page.dart`
- Modify: `frontend/lib/features/podcast/presentation/pages/podcast_highlights_page.dart`
- Modify: `frontend/lib/features/podcast/presentation/pages/podcast_daily_report_page.dart`

- [ ] **Step 1: Update page headers to 48px display titles**

Replace `headlineLarge` with `displaySmall` for page titles. Add Linear-style section headers (uppercase 11px, muted color, letter-spacing 1px).

- [ ] **Step 2: Replace old color references with new tokens**

Replace any `AppColors.textPrimary`, `AppColors.outline` etc. with new `AppThemeExtension` surface tier colors.

- [ ] **Step 3: Update episode cards with identity color left bar**

Add a 3px left border using the podcast's identity gradient to episode list items.

- [ ] **Step 4: Update podcast cover cards**

Use identity gradient as background when no actual cover image is available.

- [ ] **Step 5: Run podcast widget tests**

```bash
cd frontend && flutter test test/widget/features/podcast/
```

Fix any failures.

- [ ] **Step 6: Commit**

```bash
git commit -m "feat(podcast): update all podcast pages with Arc+Linear visual style"
```

---

### Task 17: Update auth, profile, and settings pages

**Files:**
- Modify: All pages under `frontend/lib/features/auth/presentation/pages/`
- Modify: All pages under `frontend/lib/features/profile/presentation/pages/`
- Modify: `frontend/lib/features/settings/presentation/pages/appearance_page.dart`
- Modify: `frontend/lib/features/splash/presentation/pages/splash_page.dart`
- Modify: `frontend/lib/features/home/presentation/pages/home_page.dart`

- [ ] **Step 1: Update auth pages**

Dark surface backgrounds, gradient accent on buttons, updated input fields with new border colors.

- [ ] **Step 2: Update profile pages**

Use new card tiers, surface colors, display titles.

- [ ] **Step 3: Update settings and splash**

New surface colors and simplified glass effects.

- [ ] **Step 4: Run all widget tests**

```bash
cd frontend && flutter test test/widget/
```

Fix any failures.

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(ui): update auth, profile, settings pages with Arc+Linear style"
```

---

### Task 18: Update shared widgets

**Files:**
- Modify: `frontend/lib/features/podcast/presentation/widgets/podcast_feed_episode_card.dart`
- Modify: `frontend/lib/features/podcast/presentation/widgets/simplified_episode_card.dart`
- Modify: `frontend/lib/features/podcast/presentation/widgets/highlight_card.dart`
- Modify: `frontend/lib/features/podcast/presentation/widgets/podcast_search_result_card.dart`
- Modify: Other widget files that import `glass_container.dart`

- [ ] **Step 1: Update all podcast widgets**

Replace old glass tier references, use new card tiers, add identity colors where appropriate.

- [ ] **Step 2: Update conversation/chat widgets**

Already done in Task 15, but verify `chat_sessions_drawer.dart`, `chat_empty_state.dart`, `chat_header.dart` use new tokens.

- [ ] **Step 3: Run full test suite**

```bash
cd frontend && flutter test
```

- [ ] **Step 4: Commit**

```bash
git commit -m "feat(ui): update shared podcast widgets with new design tokens"
```

---

## Phase 6: Polish & Testing

> Final visual polish, test fixes, and cleanup.

### Task 19: Run full test suite and fix failures

**Files:**
- Modify: Any test files that reference old color/glass APIs

- [ ] **Step 1: Run full test suite**

```bash
cd frontend && flutter test
```

- [ ] **Step 2: Fix all test failures**

Update test mocks and assertions for new color values, removed animations, new widget structures.

- [ ] **Step 3: Run static analysis**

```bash
cd frontend && flutter analyze
```

Zero warnings/errors.

- [ ] **Step 4: Commit**

```bash
git commit -m "test: fix all test failures after UI redesign"
```

---

### Task 20: Remove unused code and cleanup

**Files:**
- Delete or clean: any remaining unused imports, dead code
- Modify: `frontend/lib/core/glass/glass_tokens.dart` — remove unused params
- Modify: `frontend/lib/core/glass/glass_vibrancy.dart` — remove unused methods

- [ ] **Step 1: Search for unused imports**

```bash
cd frontend && dart fix --apply
```

- [ ] **Step 2: Remove any remaining "Arctic Garden" or "Apple Liquid Glass" comments**

- [ ] **Step 3: Verify clean build**

```bash
cd frontend && flutter analyze && flutter test
```

- [ ] **Step 4: Commit**

```bash
git commit -m "chore: cleanup unused code and naming after UI redesign"
```

---

## Summary

| Phase | Tasks | Description |
|-------|-------|-------------|
| 1 | Tasks 1-3 | Design tokens & theme foundation |
| 2 | Tasks 4-8 | Simplify glass system |
| 3 | Tasks 9-11 | Navigation redesign |
| 4 | Tasks 12-15 | Component updates |
| 5 | Tasks 16-18 | Feature page updates |
| 6 | Tasks 19-20 | Polish & testing |

Total: 20 tasks across 6 phases. Each task is independently committable.
