# Spacing System Optimization Design

**Date**: 2026-04-15
**Status**: Approved
**Scope**: All Flutter frontend pages

## Problem

The `AppSpacing` token system is defined but unused — zero imports in any feature file. All ~327 `SizedBox` and ~305 `EdgeInsets` calls use hardcoded magic numbers. This causes:

1. **Inconsistent spacing** — same semantic gap uses different values across pages
2. **Some gaps too large** — the "minimalist" 18/28/36 values make sections feel airy
3. **Some gaps too small** — tight packing in places that need breathing room
4. **No maintainability** — changing spacing requires finding and editing scattered numbers

### Root Cause

The `AppSpacing` scale (4, 8, 12, 18, 28, 36) skips the most commonly used values:
- `16` (~69 uses) — no token
- `10` (~28 uses) — no token
- `6` (~26 uses) — no token
- `24` (~23 uses) — no token
- `20` (~18 uses) — no token

The non-standard "minimalist" values (18, 28, 36) deviate from the 4-point grid, making the scale unpredictable.

## Solution: Standard 4-Point Grid Scale

### New AppSpacing Definition

Replace the current scale with a standard 4-point grid:

```dart
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;    // tight: icon-text gap, compact elements
  static const double sm = 8;    // small: within-group spacing
  static const double smMd = 12; // medium-small: list item internal
  static const double md = 16;   // standard: default element gap (most used)
  static const double mdLg = 20; // medium-large: card content padding
  static const double lg = 24;   // large: section separators
  static const double xl = 32;   // extra-large: major block separators
  static const double xxl = 48;  // page-level whitespace
}
```

**Changes from current**:
| Token | Old | New | Reason |
|-------|-----|-----|--------|
| `xs` | 4 | 4 | unchanged |
| `sm` | 8 | 8 | unchanged |
| `smMd` | — | 12 | new — was `md` |
| `md` | 12 | 16 | align to 4-point grid, most common hardcoded value |
| `mdLg` | — | 20 | new — common hardcoded value |
| `lg` | 18 | 24 | 4-point grid, fixes "too large" feeling |
| `xl` | 28 | 32 | 4-point grid |
| `xxl` | 36 | 48 | 4-point grid, page-level whitespace |

### ResponsiveHelpers Update

```dart
// Mobile: lg(18) → md(16)
// Tablet: xl(28) → lg(24)
// Desktop: xxl(36) → xl(32)
```

## Replacement Mapping

### Hardcoded → Token

| Hardcoded | Maps To | Notes |
|-----------|---------|-------|
| 2, 3 | `xs` (4) or keep | Context-dependent, rare |
| 4 | `xs` | Exact match |
| 6 | `sm` (8) or keep | Most can merge to 8 |
| 8 | `sm` | Exact match |
| 10 | `smMd` (12) or `sm` (8) | Context-dependent |
| 12 | `smMd` | Exact match |
| 14 | `md` (16) or `smMd` (12) | Context-dependent |
| 16 | `md` | Exact match — most common |
| 18 | `md` (16) | Old minimalist value |
| 20 | `mdLg` | Exact match |
| 22 | `mdLg` (20) or `lg` (24) | Context-dependent |
| 24 | `lg` | Exact match |
| 28 | `xl` (32) or `lg` (24) | Old minimalist value, context-dependent |
| 32 | `xl` | Exact match |
| 36 | `xl` (32) | Old minimalist value |
| 40, 48 | `xxl` (48) | Context-dependent |

### Exclusions (Do NOT Replace)

- `BorderRadius.circular()` values — use `AppRadius` tokens instead
- Animation/physics values (e.g., spring calculations)
- `podcast_ui_constants.dart` — evaluate per constant whether to reference `AppSpacing`
- `ScrollConstants` — not a spacing concept
- Third-party library internals
- `MediaQuery`-derived calculations

## Execution Phases

### Phase 1: Token System
- Update `AppSpacing` definition in `app_spacing.dart`
- Update `ResponsiveHelpers` in `responsive_helpers.dart`
- Run `flutter test` to verify no breakage

### Phase 2: Core Infrastructure
- `core/widgets/app_shells.dart` — 27 hardcoded values
- `core/widgets/custom_adaptive_navigation.dart` — 22 hardcoded values
- These are highest-impact: all pages inherit from them

### Phase 3: Auth Feature
- `features/auth/` pages — relatively independent

### Phase 4: Profile & Settings
- `features/profile/` pages
- `features/settings/` pages

### Phase 5: Podcast Feature
- `features/podcast/` — largest feature, most complex
- Evaluate `podcast_ui_constants.dart` migration

### Phase 6: Home, Splash, Shared
- `features/home/`
- `features/splash/`
- `shared/`

### Phase 7: Verification
- Full `flutter test` run
- Visual inspection of all major pages
- Check mobile/tablet/desktop layouts

## Quality Assurance

- One commit per phase (easy to revert)
- `flutter test` after each phase
- Final visual verification on all breakpoints
- No functional behavior changes — only spacing values

## Files Modified (Estimated)

~80 files total across all phases, with ~600+ individual value replacements.

### Top Priority Files (Most Hardcoded Values)
1. `core/widgets/app_shells.dart` — 27 occurrences
2. `core/widgets/custom_adaptive_navigation.dart` — 22 occurrences
3. `features/settings/presentation/widgets/update_dialog.dart` — 24 occurrences
4. `features/profile/presentation/pages/profile_page.dart` — 20 occurrences
5. `features/podcast/presentation/widgets/ai_summary_control_widget.dart` — 19 occurrences
6. `features/podcast/presentation/widgets/highlight_detail_sheet.dart` — 19 occurrences
7. `features/podcast/presentation/widgets/transcript_display_widget.dart` — 23 occurrences
8. `features/profile/presentation/pages/profile_cache_management_page.dart` — 19 occurrences
9. `features/podcast/presentation/pages/podcast_episode_detail_page_header.dart` — 19 occurrences
10. `features/podcast/presentation/pages/podcast_episodes_page_view.dart` — 17 occurrences
