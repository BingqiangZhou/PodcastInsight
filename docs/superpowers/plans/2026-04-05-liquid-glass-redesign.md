# Liquid Glass Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Complete rewrite of the glass design system to match Apple Liquid Glass principles, adapted for Flutter.

**Architecture:** 5-layer composited rendering pipeline (Optical, Material, Specular, Dynamic, Content) using BackdropFilter + CustomPaint. New core/glass/ module replaces core/theme/liquid_glass/ and stella_background.dart. 4-phase migration.

**Tech Stack:** Flutter 3.8+, Dart, BackdropFilter, CustomPainter, dart:ui

**Spec:** docs/superpowers/specs/2026-04-05-liquid-glass-redesign-design.md

---

## Phase 1: Foundation (Tasks 1-5)

### Task 1: Create GlassTokens

**Files:**
- Create: frontend/lib/core/glass/glass_tokens.dart
- Test: frontend/test/unit/core/glass/glass_tokens_test.dart

- [ ] Write GlassTokens class with GlassTier enum (ultraHeavy/28, heavy/20, medium/14, light/8), immutable tokens per tier+brightness, static of(context) resolver, glassFill convenience getter
- [ ] Write unit tests: tier sigma values, dark/light factories, context resolution
- [ ] Run: cd frontend && flutter test test/unit/core/glass/glass_tokens_test.dart
- [ ] Commit: feat(glass): add GlassTier enum and GlassTokens

### Task 2: Create GlassStyle

**Files:**
- Create: frontend/lib/core/glass/glass_style.dart
- Test: frontend/test/unit/core/glass/glass_style_test.dart

- [ ] Write GlassStyle data class with forTier() factory, withHover() (+2 sigma, border x1.5), withPress() (+4 sigma), copyWith()
- [ ] Write unit tests: tier resolution, hover/press modifiers, dark/light differences
- [ ] Run: cd frontend && flutter test test/unit/core/glass/glass_style_test.dart
- [ ] Commit: feat(glass): add GlassStyle data class

### Task 3: Create GlassBackground

**Files:**
- Create: frontend/lib/core/glass/glass_background.dart
- Test: frontend/test/widget/core/glass/glass_background_test.dart

- [ ] Write GlassBackground widget: neutral base (#0A0A0F dark / #F0F0F5 light) + 4 drifting gradient orbs (30s cycle, easeInOutSine, staggered), RepaintBoundary, theme-based color adaptation (podcast/home/neutral), disableAnimations fallback
- [ ] Write widget tests: renders in dark/light, respects disableAnimations
- [ ] Run: cd frontend && flutter test test/widget/core/glass/glass_background_test.dart
- [ ] Commit: feat(glass): add GlassBackground with dynamic gradient orbs

### Task 4: Update AppColors backgrounds

**Files:**
- Modify: frontend/lib/core/theme/app_colors.dart

- [ ] Update darkBackground to #0A0A0F, darkSurface to #0F0F18, darkSurfaceVariant to #141420, lightBackground to #F0F0F5, lightSurface to #F5F5FA
- [ ] Run: cd frontend && flutter test
- [ ] Commit: refactor(theme): update background colors for neutral glass palette

### Task 5: Wire GlassBackground into app

**Files:**
- Modify: frontend/lib/core/widgets/app_shells.dart
- Modify: frontend/lib/features/auth/presentation/pages/onboarding_page.dart
- Modify: frontend/lib/features/splash/presentation/pages/splash_page.dart

- [ ] Replace StellaBackground with GlassBackground in ContentShell, ProfileShell, AuthShell
- [ ] Replace StellaBackground with GlassBackground in onboarding and splash pages
- [ ] Run: cd frontend && flutter test
- [ ] Commit: feat(glass): wire GlassBackground into app shells

---

## Phase 2: Core Painters + Container (Tasks 6-7)

### Task 6: Create Glass Painters

**Files:**
- Create: frontend/lib/core/glass/glass_painter.dart
- Test: frontend/test/unit/core/glass/glass_painter_test.dart

- [ ] Write FresnelPainter: gradient stroke along rounded rect border, brightness increases toward edges, 1.5px stroke
- [ ] Write SpecularPainter: moving radial gradient highlight following animation value, 3-5% opacity
- [ ] Write NoisePainter: tiled 64x64 procedural noise, handles null image
- [ ] Write tests for all 3 painters
- [ ] Run: cd frontend && flutter test test/unit/core/glass/glass_painter_test.dart
- [ ] Commit: feat(glass): add FresnelPainter, SpecularPainter, NoisePainter

### Task 7: Create GlassContainer

**Files:**
- Create: frontend/lib/core/glass/glass_container.dart
- Test: frontend/test/widget/core/glass/glass_container_test.dart

- [ ] Write GlassContainer StatefulWidget with 5-layer pipeline: Optical (BackdropFilter + saturation), Material (gradient border + fill + shadow), Specular (FresnelPainter + SpecularPainter), Dynamic (NoisePainter + light flow + tint), Content (child)
- [ ] AnimationControllers: lightFlow 4s, hover 200ms, press 150ms, entry 400ms (once)
- [ ] MouseRegion + GestureDetector for interactive mode, respects disableAnimations
- [ ] Write widget tests: renders child, all tiers, interactive mode, disableAnimations
- [ ] Run: cd frontend && flutter test test/widget/core/glass/glass_container_test.dart
- [ ] Commit: feat(glass): add GlassContainer with 5-layer rendering pipeline

---

## Phase 3: Navigation + Player + Theme (Tasks 8-11)

### Task 8: Migrate CustomAdaptiveNavigation

**Files:**
- Modify: frontend/lib/core/widgets/custom_adaptive_navigation.dart

- [ ] Replace liquid_glass imports with core/glass imports
- [ ] _CleanSidebar: LiquidGlassContainer(medium) to GlassContainer(heavy)
- [ ] _CleanDock: LiquidGlassContainer(medium) to GlassContainer(medium)
- [ ] Run: cd frontend && flutter test
- [ ] Commit: refactor(nav): migrate navigation to new GlassContainer

### Task 9: Migrate SurfacePanel in app_shells

**Files:**
- Modify: frontend/lib/core/widgets/app_shells.dart

- [ ] Replace liquid_glass imports with core/glass imports
- [ ] SurfacePanel: LiquidGlassContainer(light) to GlassContainer(light)
- [ ] Run: cd frontend && flutter test
- [ ] Commit: refactor(shells): migrate SurfacePanel to new GlassContainer

### Task 10: Migrate podcast player

**Files:**
- Modify: frontend/lib/features/podcast/presentation/widgets/podcast_bottom_player_widget.dart
- Modify: frontend/lib/features/podcast/presentation/widgets/podcast_bottom_player_layouts.dart

- [ ] Replace liquid_glass imports with core/glass imports
- [ ] Expanded player: LiquidGlassContainer(heavy) to GlassContainer(ultraHeavy)
- [ ] Run: cd frontend && flutter test
- [ ] Commit: refactor(player): migrate podcast player to new GlassContainer

### Task 11: Update app_theme component themes

**Files:**
- Modify: frontend/lib/core/theme/app_theme.dart

- [ ] Set dialogTheme, bottomSheetTheme, appBarTheme, navigationBarTheme backgrounds to transparent with 0 elevation
- [ ] Run: cd frontend && flutter test
- [ ] Commit: refactor(theme): set component backgrounds transparent for glass

---

## Phase 4: All Pages + Cleanup (Tasks 12-14)

### Task 12: Migrate podcast feature pages

**Files:**
- Modify: frontend/lib/features/podcast/presentation/widgets/highlight_card.dart
- Modify: frontend/lib/features/podcast/presentation/pages/podcast_highlights_page.dart
- Modify: frontend/lib/features/podcast/presentation/pages/podcast_daily_report_page.dart

- [ ] highlight_card: replace imports, LiquidGlassContainer(light) to GlassContainer(light, interactive: true)
- [ ] highlights_page: replace imports, LiquidGlassContainer and LiquidGlassTokens to new equivalents
- [ ] daily_report_page: replace all imports and references
- [ ] Run: cd frontend && flutter test
- [ ] Commit: refactor(podcast): migrate all podcast pages to new glass system

### Task 13: Clean up old glass system

**Files:**
- Delete: frontend/lib/core/theme/liquid_glass/ (entire directory)
- Delete: frontend/lib/core/widgets/stella_background.dart
- Modify: frontend/lib/core/theme/app_colors.dart

- [ ] Delete old liquid_glass directory and stella_background.dart
- [ ] Remove glassSurfaceStrong, glassShadow, glassBorder from AppThemeExtension
- [ ] Verify no dangling imports: grep returns nothing
- [ ] Run: cd frontend && flutter test
- [ ] Commit: chore: remove old liquid_glass module and StellaBackground

### Task 14: Final verification

- [ ] cd frontend && flutter build web --no-tree-shake-icons
- [ ] cd frontend && flutter test
- [ ] grep -rn "LiquidGlass\|StellaBackground\|glassSurfaceStrong" frontend/lib/ returns nothing
- [ ] cd backend && uv run ruff check .
- [ ] Final commit if needed

---

## Execution Strategy

Phases MUST run sequentially. Within phases some tasks can parallelize:
- Phase 1: Tasks 1+2 parallel, Task 3 after 1, Tasks 4+5 after 3
- Phase 2: Tasks 6 then 7 (sequential)
- Phase 3: Tasks 8-11 can run in parallel
- Phase 4: Tasks 12 then 13 then 14 (sequential)
