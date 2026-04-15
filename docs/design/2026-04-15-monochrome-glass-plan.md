# Monochrome Glass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace all colorful gradients and multi-brand colors with monochrome glass surfaces, keeping only Indigo as the accent color.

**Architecture:** Change color token values in the theme layer, update 4 independent UI areas (background, player, chat, podcast cards) to consume the new tokens. All tasks touch different files and can run in parallel.

**Tech Stack:** Flutter/Dart, Riverpod, Material 3

---

## File Structure

| File | Change | Task |
|------|--------|------|
| `frontend/lib/core/theme/app_colors.dart` | Update gradient values to gray, remove AI color tokens | 1 |
| `frontend/lib/core/glass/glass_background.dart` | Gray orb colors | 1 |
| `frontend/lib/core/glass/glass_container.dart` | Use GlassTokens instead of hardcoded fills | 1 |
| `frontend/lib/features/podcast/presentation/widgets/podcast_bottom_player_layouts.dart` | Replace gradient with SurfaceCard, remove Colors.white | 2 |
| `frontend/lib/features/podcast/presentation/widgets/podcast_bottom_player_controls.dart` | Replace 6x Colors.white with theme colors | 2 |
| `frontend/lib/features/podcast/presentation/widgets/conversation/chat_message_bubble.dart` | Replace violetColors with primary | 3 |
| `frontend/lib/features/podcast/presentation/widgets/conversation/chat_input_area.dart` | Theme-aware colors, replace violetColors with primary | 3 |
| `frontend/lib/features/podcast/presentation/widgets/conversation/chat_empty_state.dart` | Theme-aware colors | 3 |
| `frontend/lib/features/podcast/presentation/widgets/podcast_feed_episode_card.dart` | Replace gradient with gray version | 4 |

---

### Task 1: Theme Foundation — Color Tokens + GlassBackground + GlassContainer

**Files:**
- Modify: `frontend/lib/core/theme/app_colors.dart`
- Modify: `frontend/lib/core/glass/glass_background.dart`
- Modify: `frontend/lib/core/glass/glass_container.dart`

- [ ] **Step 1: Update podcastGradientColors to gray in `app_colors.dart`**

Replace lines 152-166 (the individual color lists and the podcastGradientColors list) with:

```dart
static const List<Color> coralColors = [Color(0xFF2a2a2e), Color(0xFF3a3a40)];
static const List<Color> violetColors = [Color(0xFF2a2a2e), Color(0xFF3a3a40)];
static const List<Color> cyanColors = [Color(0xFF2a2a2e), Color(0xFF3a3a40)];
static const List<Color> goldColors = [Color(0xFF2a2a2e), Color(0xFF3a3a40)];
static const List<Color> roseColors = [Color(0xFF2a2a2e), Color(0xFF3a3a40)];
static const List<Color> skyColors = [Color(0xFF2a2a2e), Color(0xFF3a3a40)];

static const List<List<Color>> podcastGradientColors = [
  coralColors,
  violetColors,
  cyanColors,
  goldColors,
  roseColors,
  skyColors,
];
```

This makes all 6 gradient variants identical gray — consumers don't need to change their hash-based selection logic.

- [ ] **Step 2: Remove unused AI color tokens from AppThemeExtension in `app_colors.dart`**

Remove these fields from `AppThemeExtension` (around lines 245-249):
```dart
final Color aiBubbleUserColor;
final Color aiBubbleAssistantColor;
final Color aiChipColor;
final Color aiHighlightSurfaceColor;
final Color cosmicFilterActiveColor;
```

Remove them from the constructor (around lines 285-290), the `copyWith` method (around lines 310-315), the `==` operator (around lines 340-345), `hashCode` (around lines 355-360), and the light/dark theme instances (light: ~lines 407-412, dark: ~lines 457-461).

Keep the static constants in `AppColors` class (`aiBubbleUser`, `aiBubbleAssistant`, etc., lines 99-109) for now — they may be referenced elsewhere. Just remove the theme extension wiring since no consumer uses them.

- [ ] **Step 3: Update GlassBackground orb colors to gray in `glass_background.dart`**

Replace the dark mode orb colors (around lines 87-91):
```dart
return const [
  Color(0xFF1a1a24), // cool gray
  Color(0xFF181818), // neutral gray
  Color(0xFF1c1c20), // blue-gray
];
```
These values are the same as what the spec defines. Keep them as-is.

Replace ALL light mode orb color sets. For podcast theme (~line 97):
```dart
return const [
  Color(0xFFe0e0e0),
  Color(0xFFd8d8dc),
  Color(0xFFe4e4e4),
];
```

For home theme (~line 104):
```dart
return const [
  Color(0xFFe0e0e0),
  Color(0xFFd8d8dc),
  Color(0xFFe4e4e4),
];
```

For neutral theme (~line 112):
```dart
return const [
  Color(0xFFe0e0e0),
  Color(0xFFd8d8dc),
  Color(0xFFe4e4e4),
];
```

All three themes now use identical gray orbs.

- [ ] **Step 4: Fix GlassContainer to use GlassTokens in `glass_container.dart`**

Replace the hardcoded fill and border colors (around lines 55-61). Currently:
```dart
decoration: BoxDecoration(
  color: tier == GlassTier.overlay
      ? const Color(0x0AFFFFFF)
      : const Color(0x0FFFFFFF),
  borderRadius: BorderRadius.circular(borderRadius),
  border: Border.all(
    color: const Color(0x0FFFFFFF),
    width: 0.5,
  ),
),
```

Replace with theme-aware version:
```dart
decoration: BoxDecoration(
  color: tier == GlassTier.overlay
      ? glassTokens.overlayFill
      : glassTokens.standardFill,
  borderRadius: BorderRadius.circular(borderRadius),
  border: Border.all(
    color: tier == GlassTier.overlay
        ? glassTokens.overlayBorder
        : glassTokens.standardBorder,
    width: 0.5,
  ),
),
```

Add `glassTokens` resolution at the top of the `build` method:
```dart
final glassTokens = GlassTokens.of(context);
```

Verify that `GlassTokens` has `overlayFill`, `standardFill`, `overlayBorder`, `standardBorder` getters — read `glass_tokens.dart` to check the exact API. If the field names differ, adapt accordingly.

- [ ] **Step 5: Run existing tests**

Run: `cd /Users/bingqiangzhou/Workspaces/Projects/Personal-AI-Assistant/frontend && flutter test`
Expected: All tests pass. No behavioral changes, only color values.

- [ ] **Step 6: Commit**

```bash
git add frontend/lib/core/theme/app_colors.dart frontend/lib/core/glass/glass_background.dart frontend/lib/core/glass/glass_container.dart
git commit -m "refactor: monochrome glass theme foundation — gray gradients, orbs, and theme-aware glass fills"
```

---

### Task 2: Mini Player — SurfaceCard Style + Remove Hardcoded White

**Files:**
- Modify: `frontend/lib/features/podcast/presentation/widgets/podcast_bottom_player_layouts.dart`
- Modify: `frontend/lib/features/podcast/presentation/widgets/podcast_bottom_player_controls.dart`

- [ ] **Step 1: Replace gradient background with SurfaceCard in `podcast_bottom_player_layouts.dart`**

In `_MiniDockBody.build()` (around lines 126-138), replace the gradient identity color resolution and gradient `Container`:

Remove:
```dart
final identityGradientColors =
    subscriptionTitle != null && subscriptionTitle.isNotEmpty
        ? AppColors.podcastGradientColors[
            subscriptionTitle.hashCode % AppColors.podcastGradientColors.length]
        : AppColors.violetColors;
```

And replace the `Container` decoration:
```dart
return Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: identityGradientColors,
    ),
    borderRadius: AppRadius.lgRadius,
  ),
```

With SurfaceCard-style decoration using theme extension:
```dart
final theme = Theme.of(context);
final extension = appThemeOf(context);

return Container(
  decoration: BoxDecoration(
    color: extension.cardTierFill,
    border: Border.all(
      color: extension.cardTierBorder,
      width: 0.5,
    ),
    borderRadius: AppRadius.lgRadius,
  ),
```

- [ ] **Step 2: Replace hardcoded Colors.white in mini dock layout**

In `podcast_bottom_player_layouts.dart`:

Line ~176 (title text), replace `color: Colors.white` with `color: theme.colorScheme.onSurface`.

Line ~222 (queue button icon), replace `color: Colors.white` with `color: theme.colorScheme.onSurface`.

Make sure `theme` is available (get it from `Theme.of(context)` at the top of the build method if not already).

- [ ] **Step 3: Replace all hardcoded Colors.white in mini player controls**

In `podcast_bottom_player_controls.dart`, add theme access at the top of the build methods that need it.

Replace these 6 occurrences:

1. Line ~241 (`_MiniPlayPauseButton`): `foregroundColor: Colors.white` → `foregroundColor: theme.colorScheme.onSurface`
2. Line ~249: `AlwaysStoppedAnimation<Color>(Colors.white)` → `AlwaysStoppedAnimation<Color>(theme.colorScheme.onSurface)`
3. Line ~257: `color: Colors.white` → `color: theme.colorScheme.onSurface`
4. Line ~274 (`_MiniProgressIndicator`): `color: Colors.white` → `color: theme.colorScheme.primary` (use primary for the active progress color)
5. Line ~275: `backgroundColor: Colors.white.withOpacity(0.3)` → `backgroundColor: theme.colorScheme.onSurface.withOpacity(0.2)`
6. Line ~293 (`_MiniProgressText`): `color: Colors.white` → `color: theme.colorScheme.onSurface`

- [ ] **Step 4: Run existing tests**

Run: `cd /Users/bingqiangzhou/Workspaces/Projects/Personal-AI-Assistant/frontend && flutter test`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/features/podcast/presentation/widgets/podcast_bottom_player_layouts.dart frontend/lib/features/podcast/presentation/widgets/podcast_bottom_player_controls.dart
git commit -m "refactor: mini player monochrome surface style — replace gradient with SurfaceCard, remove hardcoded whites"
```

---

### Task 3: Chat Components — Indigo Accent + Theme-Aware Colors

**Files:**
- Modify: `frontend/lib/features/podcast/presentation/widgets/conversation/chat_message_bubble.dart`
- Modify: `frontend/lib/features/podcast/presentation/widgets/conversation/chat_input_area.dart`
- Modify: `frontend/lib/features/podcast/presentation/widgets/conversation/chat_empty_state.dart`

- [ ] **Step 1: Replace violetColors gradient in `chat_message_bubble.dart`**

Around line 180, the assistant message left bar uses:
```dart
gradient: const LinearGradient(
  colors: AppColors.violetColors,
```

Replace with:
```dart
gradient: LinearGradient(
  colors: [theme.colorScheme.primary, theme.colorScheme.primary.withOpacity(0.6)],
```

Make sure `theme` is available via `Theme.of(context)`.

- [ ] **Step 2: Replace hardcoded colors in `chat_input_area.dart`**

Replace the following:

Line ~29-33 (send button gradient):
```dart
const gradient = LinearGradient(
  colors: AppColors.violetColors,
```
Replace with:
```dart
final gradient = LinearGradient(
  colors: [theme.colorScheme.primary, theme.colorScheme.primary.withOpacity(0.8)],
```

Line ~35 (input area background):
```dart
color: const Color(0xFF252540),
```
Replace with:
```dart
color: extension.cardTierFill,
```

Replace all `AppColors.darkOnBackground` → `theme.colorScheme.onSurface`
Replace all `AppColors.darkOnSurfaceMuted` → `theme.colorScheme.onSurfaceVariant`
Replace all `AppColors.darkSurfaceVariant` → `extension.surfaceTierFill`
Replace all `AppColors.darkBorder` → `extension.surfaceTierBorder`

Ensure `theme` and `extension` are obtained from context at the top of the build method.

- [ ] **Step 3: Replace hardcoded colors in `chat_empty_state.dart`**

Replace all `AppColors.darkOnBackground` → `theme.colorScheme.onSurface`
Replace all `AppColors.darkOnSurfaceMuted` → `theme.colorScheme.onSurfaceVariant`

Ensure `Theme.of(context)` is available in the relevant build methods.

- [ ] **Step 4: Run existing tests**

Run: `cd /Users/bingqiangzhou/Workspaces/Projects/Personal-AI-Assistant/frontend && flutter test`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/features/podcast/presentation/widgets/conversation/chat_message_bubble.dart frontend/lib/features/podcast/presentation/widgets/conversation/chat_input_area.dart frontend/lib/features/podcast/presentation/widgets/conversation/chat_empty_state.dart
git commit -m "refactor: chat components monochrome — replace violetColors with primary, remove hardcoded dark-mode colors"
```

---

### Task 4: Podcast Episode Card — Gray Gradient

**Files:**
- Modify: `frontend/lib/features/podcast/presentation/widgets/podcast_feed_episode_card.dart`

- [ ] **Step 1: Replace podcast gradient with gray version**

Around lines 35-36, replace:
```dart
final colorIndex = subscriptionTitle.hashCode % AppColors.podcastGradientColors.length;
final identityGradientColors = AppColors.podcastGradientColors[colorIndex];
```

Since all gradient variants are now identical gray, simplify to:
```dart
final identityGradientColors = AppColors.podcastGradientColors.first;
```

Or keep the hash logic — it will resolve to the same gray gradient regardless. The choice depends on whether you want to minimize diff or simplify. Prefer keeping the hash logic to minimize diff.

- [ ] **Step 2: Run existing tests**

Run: `cd /Users/bingqiangzhou/Workspaces/Projects/Personal-AI-Assistant/frontend && flutter test`
Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
git add frontend/lib/features/podcast/presentation/widgets/podcast_feed_episode_card.dart
git commit -m "refactor: podcast episode card monochrome gradient"
```

---

## Post-Implementation Verification

After all 4 tasks are complete:

- [ ] **Step 1: Run full test suite**

Run: `cd /Users/bingqiangzhou/Workspaces/Projects/Personal-AI-Assistant/frontend && flutter test`
Expected: All tests pass.

- [ ] **Step 2: Visual verification**

Run the app with `cd /Users/bingqiangzhou/Workspaces/Projects/Personal-AI-Assistant/frontend && flutter run` and verify:

1. Background orbs are gray (no colored tint)
2. Mini player dock is non-gradient SurfaceCard style (no colorful background)
3. Mini player text/icons are visible in both dark and light mode
4. Chat bubbles use Indigo/system surface style (no yellow/pink)
5. Chat send button uses Indigo instead of violet
6. Podcast episode cards use gray gradient instead of colored
7. No colorful gradients anywhere (Indigo interactive elements are OK)

- [ ] **Step 3: Final commit if any fixes needed**

```bash
git add -A
git commit -m "fix: monochrome glass visual polish"
```
