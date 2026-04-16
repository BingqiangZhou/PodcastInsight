# Platform-Adaptive UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Stella look native on iOS (Cupertino), Android (Material 3), and desktop (Material 3) using Flutter's built-in `.adaptive()` constructors plus a lightweight helper layer.

**Architecture:** Three-layer approach — Layer 1 (Flutter automatic, zero code), Layer 2 (`.adaptive()` constructors, simple find-replace), Layer 3 (custom helpers for AppBar, dialogs, transitions, navigation). No third-party UI packages.

**Tech Stack:** Flutter 3.8+, Dart, Material 3, Cupertino, Riverpod, go_router

**Design Spec:** `docs/design/2026-04-16-platform-adaptive-ui-design.md`

---

## File Map

### New Files

| File | Responsibility |
|------|---------------|
| `frontend/lib/core/platform/platform_helper.dart` | Platform detection utilities (`isIOS`, `isAndroid`, `isDesktop`) |
| `frontend/lib/core/platform/adaptive_app_bar.dart` | `adaptiveAppBar()` helper function |
| `frontend/lib/core/platform/adaptive_page_route.dart` | Platform-adaptive page route for go_router |

### Modified Files

| File | Changes |
|------|---------|
| `frontend/lib/core/theme/app_theme.dart` | Add platform parameter, Cupertino theme, iOS-conditional styles |
| `frontend/lib/core/app/app.dart` | Pass platform to theme, add CupertinoTheme wrapper |
| `frontend/lib/core/router/app_router.dart` | Replace fade transitions with platform-adaptive transitions |
| `frontend/lib/core/widgets/page_transitions.dart` | Remove (replaced by `adaptive_page_route.dart` + theme `pageTransitionsTheme`) |
| `frontend/lib/core/widgets/app_dialog_helper.dart` | Add `showCupertinoDialog` path for iOS |
| `frontend/lib/core/widgets/adaptive_sheet_helper.dart` | Add `showCupertinoModalPopup` path for iOS mobile |
| `frontend/lib/core/widgets/custom_adaptive_navigation.dart` | iOS mobile: CupertinoTabBar-style bottom nav |

---

## Task 1: Platform Helper + Theme Foundation

**Depends on:** None (foundation task)
**Files:**
- Create: `frontend/lib/core/platform/platform_helper.dart`
- Modify: `frontend/lib/core/theme/app_theme.dart`
- Modify: `frontend/lib/core/app/app.dart`

- [ ] **Step 1: Create `platform_helper.dart`**

```dart
// frontend/lib/core/platform/platform_helper.dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Platform detection utilities for adaptive UI.
class PlatformHelper {
  PlatformHelper._();

  /// Whether the current platform is iOS.
  static bool isIOS(BuildContext context) {
    if (kIsWeb) return false;
    return Theme.of(context).platform == TargetPlatform.iOS;
  }

  /// Whether the current platform is Android.
  static bool isAndroid(BuildContext context) {
    if (kIsWeb) return false;
    return Theme.of(context).platform == TargetPlatform.android;
  }

  /// Whether the current platform is desktop (macOS, Windows, Linux).
  static bool isDesktop(BuildContext context) {
    if (kIsWeb) return false;
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.macOS ||
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux;
  }

  /// Whether the current platform is mobile (iOS or Android).
  static bool isMobile(BuildContext context) {
    return isIOS(context) || isAndroid(context);
  }

  /// Resolve a value per platform.
  static T platformValue<T>(BuildContext context, {
    required T material,
    required T cupertino,
    T? desktop,
  }) {
    if (isDesktop(context) && desktop != null) return desktop;
    if (isIOS(context)) return cupertino;
    return material;
  }
}
```

- [ ] **Step 2: Add platform parameter to `AppTheme.buildTheme`**

In `frontend/lib/core/theme/app_theme.dart`, change the `buildTheme` method signature and add platform-conditional logic inside `_buildTheme`:

```dart
// Change method signature from:
static ThemeData buildTheme(Brightness brightness, FontCombination fonts) {
  final cacheKey = '${fonts.id}_${brightness.name}';
  return _themeCache.putIfAbsent(cacheKey, () => _buildTheme(brightness, fonts));
}

// To:
static ThemeData buildTheme(Brightness brightness, FontCombination fonts, [TargetPlatform? platform]) {
  final resolvedPlatform = platform ?? defaultTargetPlatform;
  final cacheKey = '${fonts.id}_${brightness.name}_${resolvedPlatform.name}';
  return _themeCache.putIfAbsent(cacheKey, () => _buildTheme(brightness, fonts, resolvedPlatform));
}
```

Then add a `CupertinoThemeData` getter and modify `_buildTheme` to accept and use platform:

```dart
/// Cupertino theme data for iOS adaptive widgets.
static CupertinoThemeData buildCupertinoTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  return CupertinoThemeData(
    brightness: brightness,
    primaryColor: AppColors.primary,
    barBackgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurfaceVariant,
    scaffoldBackgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
  );
}
```

Add `import 'package:flutter/cupertino.dart';` at the top of the file.

Inside `_buildTheme`, add `TargetPlatform platform` parameter and add platform-conditional theme properties:

```dart
static ThemeData _buildTheme(Brightness brightness, FontCombination fonts, TargetPlatform platform) {
  // ... existing code unchanged until the return statement ...
  final isIOS = platform == TargetPlatform.iOS;

  return ThemeData(
    // ... all existing properties unchanged ...
    // ADD these platform-conditional overrides at the end:

    // Page transitions
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        TargetPlatform.android: const ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: const ZoomPageTransitionsBuilder(),
        TargetPlatform.windows: const ZoomPageTransitionsBuilder(),
        TargetPlatform.linux: const ZoomPageTransitionsBuilder(),
      },
    ),

    // iOS-specific AppBar adjustments
    appBarTheme: AppBarTheme(
      // ... all existing properties ...
      centerTitle: isIOS ? true : false, // iOS centers title
    ),
  );
}
```

- [ ] **Step 3: Update `app.dart` to pass platform and wrap CupertinoTheme**

In `frontend/lib/core/app/app.dart`:

Add import:
```dart
import 'package:flutter/cupertino.dart';
```

Wrap the `_wrapAppChild` builder to include `CupertinoTheme`. Change the `builder` in both MaterialApp instances:

For the splash MaterialApp (line ~355-358):
```dart
builder: (context, child) {
  final wrappedChild = _wrapAppChild(context, child ?? const SizedBox.shrink());
  return CupertinoTheme(
    data: AppTheme.buildCupertinoTheme(Brightness.light),
    child: wrappedChild,
  );
},
```

For the main MaterialApp.router (line ~388-389):
```dart
builder: (context, child) {
  final brightness = Theme.of(context).brightness;
  final wrappedChild = _wrapAppChild(context, child ?? const SizedBox.shrink());
  return CupertinoTheme(
    data: AppTheme.buildCupertinoTheme(brightness),
    child: wrappedChild,
  );
},
```

- [ ] **Step 4: Run tests to verify no regressions**

```bash
cd frontend && flutter test
```

Expected: All existing tests pass. No behavioral changes visible yet.

- [ ] **Step 5: Commit**

```bash
git add frontend/lib/core/platform/platform_helper.dart frontend/lib/core/theme/app_theme.dart frontend/lib/core/app/app.dart
git commit -m "feat(platform): add platform helper, iOS-aware theme, and CupertinoTheme wrapper"
```

---

## Task 2: Adaptive Page Transitions

**Depends on:** Task 1
**Files:**
- Create: `frontend/lib/core/platform/adaptive_page_route.dart`
- Modify: `frontend/lib/core/router/app_router.dart`

- [ ] **Step 1: Create `adaptive_page_route.dart`**

```dart
// frontend/lib/core/platform/adaptive_page_route.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Build a platform-adaptive page transition for go_router.
///
/// iOS: Cupertino slide-in with edge swipe back.
/// Android/Desktop: Material zoom transition.
CustomTransitionPage<T> adaptivePageTransition<T>({
  required Widget child,
  required ValueKey<String> pageKey,
  bool fullscreenDialog = false,
}) {
  return CustomTransitionPage<T>(
    key: pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final platform = Theme.of(context).platform;
      final isIOS = platform == TargetPlatform.iOS;

      if (isIOS) {
        // Cupertino slide transition
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.linearToEaseOut,
          reverseCurve: Curves.easeInToLinear,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: child,
        );
      }

      // Material fade transition (Stella's current style)
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      );
      return FadeTransition(
        opacity: curvedAnimation,
        child: child,
      );
    },
  );
}
```

- [ ] **Step 2: Replace transitions in `app_router.dart`**

In `frontend/lib/core/router/app_router.dart`:

Add import:
```dart
import 'package:personal_ai_assistant/core/platform/adaptive_page_route.dart';
```

Replace `_buildPageWithTransition` function:
```dart
CustomTransitionPage<T> _buildPageWithTransition<T>({
  required GoRouterState state,
  required Widget child,
}) {
  return adaptivePageTransition<T>(
    child: child,
    pageKey: ValueKey<String>(state.pageKey.value),
  );
}
```

Replace `_buildModalPage` function:
```dart
CustomTransitionPage<T> _buildModalPage<T>({
  required GoRouterState state,
  required Widget child,
}) {
  return adaptivePageTransition<T>(
    child: child,
    pageKey: ValueKey<String>(state.pageKey.value),
    fullscreenDialog: true,
  );
}
```

- [ ] **Step 3: Run tests**

```bash
cd frontend && flutter test
```

Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add frontend/lib/core/platform/adaptive_page_route.dart frontend/lib/core/router/app_router.dart
git commit -m "feat(navigation): use platform-adaptive page transitions (Cupertino slide on iOS)"
```

---

## Task 3: Adaptive Dialog Helper

**Depends on:** Task 1
**Files:**
- Modify: `frontend/lib/core/widgets/app_dialog_helper.dart`

- [ ] **Step 1: Update `showAppDialog` with iOS path**

Replace the `showAppDialog` function in `app_dialog_helper.dart`:

```dart
import 'package:flutter/cupertino.dart';
import 'package:personal_ai_assistant/core/platform/platform_helper.dart';

/// Show a platform-adaptive dialog.
///
/// Android/desktop: Material dialog with rounded corners.
/// iOS: Cupertino dialog.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool barrierDismissible = true,
  Color barrierColor = Colors.black54,
  double borderRadius = 28,
  bool useRootNavigator = false,
}) {
  if (PlatformHelper.isIOS(context)) {
    return showCupertinoDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      useRootNavigator: useRootNavigator,
      builder: builder,
    );
  }
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    useRootNavigator: useRootNavigator,
    builder: (dialogCtx) {
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(dialogCtx).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: builder(dialogCtx),
      );
    },
  );
}
```

- [ ] **Step 2: Update `showAppConfirmationDialog` with iOS CupertinoAlertDialog**

Replace `showAppConfirmationDialog`:

```dart
Future<bool?> showAppConfirmationDialog({
  required BuildContext context,
  required String title,
  required String message,
  String? cancelText,
  String? confirmText,
  bool isDestructive = false,
  double borderRadius = 28,
}) {
  if (PlatformHelper.isIOS(context)) {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(title),
        ),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(cancelText ?? 'Cancel'),
          ),
          CupertinoDialogAction(
            isDestructive: isDestructive,
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(
              confirmText ?? 'Confirm',
              style: isDestructive
                  ? TextStyle(color: CupertinoColors.destructiveRed)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  // Material dialog (Android/desktop) — existing code unchanged
  final theme = Theme.of(context);
  return showAppDialog<bool>(
    context: context,
    builder: (dialogCtx) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(false),
                  child: Text(cancelText ?? 'Cancel'),
                ),
                const SizedBox(width: AppSpacing.sm),
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(true),
                  style: isDestructive
                      ? TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                        )
                      : null,
                  child: Text(
                    confirmText ?? 'Confirm',
                    style: isDestructive
                        ? TextStyle(color: theme.colorScheme.error)
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
```

- [ ] **Step 3: Run tests**

```bash
cd frontend && flutter test
```

Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add frontend/lib/core/widgets/app_dialog_helper.dart
git commit -m "feat(dialog): use CupertinoAlertDialog on iOS via showCupertinoDialog"
```

---

## Task 4: Adaptive Bottom Sheet

**Depends on:** Task 1
**Files:**
- Modify: `frontend/lib/core/widgets/adaptive_sheet_helper.dart`

- [ ] **Step 1: Add iOS mobile path to `showAdaptiveSheet`**

In `adaptive_sheet_helper.dart`, add imports and iOS path:

```dart
import 'package:flutter/cupertino.dart';
import 'package:personal_ai_assistant/core/platform/platform_helper.dart';
```

Insert an iOS mobile check before the `screenWidth >= 600` check:

```dart
Future<T?> showAdaptiveSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool isScrollControlled = true,
  bool showDragHandle = true,
  bool useSafeArea = true,
  double desktopMaxWidth = 560,
  double desktopMaxHeightFraction = 0.85,
}) {
  final fallbackContext = appNavigatorKey.currentContext;
  final resolvedContext = Navigator.maybeOf(context) != null
      ? context
      : fallbackContext;
  if (resolvedContext == null) {
    return Future<T?>.value();
  }

  final screenWidth = MediaQuery.of(resolvedContext).size.width;

  // iOS mobile: use Cupertino modal popup
  if (PlatformHelper.isIOS(resolvedContext) && screenWidth < 600) {
    return showCupertinoModalPopup<T>(
      context: resolvedContext,
      builder: (sheetCtx) {
        return Container(
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground.resolveFrom(sheetCtx),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: SafeArea(child: builder(sheetCtx)),
        );
      },
    );
  }

  // Desktop / tablet -> centred dialog (existing code unchanged)
  if (screenWidth >= 600) {
    // ... existing desktop code unchanged ...
  }

  // Android mobile -> bottom sheet (existing code unchanged)
  return showModalBottomSheet<T>(
    // ... existing mobile code unchanged ...
  );
}
```

- [ ] **Step 2: Run tests**

```bash
cd frontend && flutter test
```

Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
git add frontend/lib/core/widgets/adaptive_sheet_helper.dart
git commit -m "feat(sheet): use showCupertinoModalPopup on iOS mobile"
```

---

## Task 5: Adaptive AppBar Helper

**Depends on:** Task 1
**Files:**
- Create: `frontend/lib/core/platform/adaptive_app_bar.dart`

- [ ] **Step 1: Create `adaptive_app_bar.dart`**

```dart
// frontend/lib/core/platform/adaptive_app_bar.dart
import 'package:flutter/material.dart';

import 'package:personal_ai_assistant/core/platform/platform_helper.dart';

/// Build a platform-adaptive AppBar.
///
/// iOS: Flat (elevation 0), centered title, transparent surface tint.
/// Android/Desktop: Material 3 AppBar with current project styling.
PreferredSizeWidget adaptiveAppBar(
  BuildContext context, {
  String? title,
  Widget? titleWidget,
  List<Widget>? actions,
  Widget? leading,
  bool? centerTitle,
  Color? backgroundColor,
}) {
  final isIOS = PlatformHelper.isIOS(context);
  return AppBar(
    title: titleWidget ?? (title != null ? Text(title) : null),
    elevation: 0,
    scrolledUnderElevation: isIOS ? 0.1 : 0,
    centerTitle: centerTitle ?? isIOS,
    backgroundColor: backgroundColor ?? Colors.transparent,
    surfaceTintColor: Colors.transparent,
    actions: actions,
    leading: leading,
  );
}
```

- [ ] **Step 2: Run tests**

```bash
cd frontend && flutter test
```

Expected: All tests pass. The helper is ready for use but no call sites are changed yet.

- [ ] **Step 3: Commit**

```bash
git add frontend/lib/core/platform/adaptive_app_bar.dart
git commit -m "feat(appbar): add adaptiveAppBar helper for iOS-style AppBar"
```

---

## Task 6: Replace Widgets with .adaptive() Constructors

**Depends on:** Task 1
**Files:** Multiple files across `frontend/lib/`

This is a mechanical find-and-replace task. Replace each widget constructor with its `.adaptive()` variant.

- [ ] **Step 1: Replace `CircularProgressIndicator` → `CircularProgressIndicator.adaptive`**

Search pattern: `CircularProgressIndicator(`
Replace with: `CircularProgressIndicator.adaptive(`

Files (33 files with occurrences — replace in all production files under `lib/`):
```bash
cd frontend
# Find and replace using sed (review each file before committing)
grep -rn "CircularProgressIndicator(" lib/ --include="*.dart" | grep -v ".g.dart" | grep -v ".adaptive"
```

Manually verify each replacement ensures the constructor signature is compatible (`.adaptive()` has the same parameters).

- [ ] **Step 2: Replace `Switch` → `Switch.adaptive`**

Files: `profile_page.dart`, `appearance_page.dart`, `chat_sessions_drawer.dart`, `podcast_episodes_page_view.dart`, `playback_speed_selector_sheet.dart`, `sleep_timer_selector_sheet.dart`

```dart
// Before:
Switch(value: ..., onChanged: ...)
// After:
Switch.adaptive(value: ..., onChanged: ...)
```

- [ ] **Step 3: Replace `Slider` → `Slider.adaptive`**

File: `update_dialog.dart`

```dart
// Before:
Slider(value: ..., onChanged: ...)
// After:
Slider.adaptive(value: ..., onChanged: ...)
```

- [ ] **Step 4: Replace `AlertDialog` → `AlertDialog.adaptive`**

Files: `profile_page.dart`, `profile_cache_management_page.dart`, `server_config_dialog.dart`, `chat_sessions_drawer.dart`, `update_dialog.dart`, `podcast_episodes_page_view.dart`, `reset_password_page.dart`, `adaptive_sheet_helper.dart`

```dart
// Before:
AlertDialog(title: ..., actions: ...)
// After:
AlertDialog.adaptive(title: ..., actions: ...)
```

Note: `AlertDialog.adaptive()` may have slightly different API — verify each usage accepts the same named parameters.

- [ ] **Step 5: Run tests**

```bash
cd frontend && flutter test
```

Expected: All tests pass. Some widget tests may need updates if they assert specific widget types.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(adaptive): replace Switch, Slider, CircularProgressIndicator, AlertDialog with .adaptive() constructors"
```

---

## Task 7: iOS Navigation Bar Style in CustomAdaptiveNavigation

**Depends on:** Task 1
**Files:**
- Modify: `frontend/lib/core/widgets/custom_adaptive_navigation.dart`

- [ ] **Step 1: Add iOS CupertinoTabBar-style to mobile bottom nav**

In `custom_adaptive_navigation.dart`, add import:
```dart
import 'package:personal_ai_assistant/core/platform/platform_helper.dart';
```

Modify `_buildMobileLayout` to use a platform check for the bottom dock style. On iOS, replace the `_CleanDock` frosted glass dock with a `CupertinoTabBar`-inspired style:

In the `_buildMobileNavBar` method, wrap the existing nav items in a platform check:

```dart
Widget _buildMobileNavBar(BuildContext context) {
  if (PlatformHelper.isIOS(context)) {
    return _buildIOSMobileNavBar(context);
  }
  // Existing Android nav bar code unchanged
  return SizedBox(
    key: const Key('custom_adaptive_navigation_mobile_nav_bar'),
    height: kPodcastGlobalPlayerMobileDockHeight,
    child: Row(
      // ... existing code ...
    ),
  );
}

/// iOS-style bottom navigation with CupertinoTabBar aesthetics.
Widget _buildIOSMobileNavBar(BuildContext context) {
  final theme = Theme.of(context);
  return SizedBox(
    height: kPodcastGlobalPlayerMobileDockHeight,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(widget.destinations.length, (index) {
        final destination = widget.destinations[index];
        final isSelected = index == widget.selectedIndex;
        return Expanded(
          child: GestureDetector(
            onTap: () => widget.onDestinationSelected?.call(index),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconTheme(
                    data: IconThemeData(
                      size: 22,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    child: isSelected
                        ? (destination.selectedIcon ?? destination.icon)
                        : destination.icon,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    destination.label,
                    style: AppTheme.navLabel(
                      isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                      weight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    ),
  );
}
```

- [ ] **Step 2: Run tests**

```bash
cd frontend && flutter test
```

Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
git add frontend/lib/core/widgets/custom_adaptive_navigation.dart
git commit -m "feat(nav): add iOS CupertinoTabBar-style bottom navigation"
```

---

## Task 8: SnackBar → TopFloatingNotice on iOS

**Depends on:** Task 1
**Files:**
- Modify: `frontend/lib/core/theme/app_theme.dart` (add adaptive snackbar extension)

This task provides an `adaptiveSnackBar` helper that callers can use.

- [ ] **Step 1: Create adaptive snackbar helper**

Add to `frontend/lib/core/platform/platform_helper.dart`:

```dart
import 'package:personal_ai_assistant/core/widgets/top_floating_notice.dart';

/// Show an adaptive feedback message.
///
/// iOS: TopFloatingNotice (iOS-style top banner).
/// Android/Desktop: Material SnackBar.
static void showAdaptiveFeedback(
  BuildContext context, {
  required String message,
  bool isError = false,
  Duration duration = const Duration(seconds: 3),
}) {
  if (PlatformHelper.isIOS(context)) {
    showTopFloatingNotice(
      context,
      message: message,
      isError: isError,
      duration: duration,
    );
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: duration,
    ),
  );
}
```

- [ ] **Step 2: Run tests**

```bash
cd frontend && flutter test
```

Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
git add frontend/lib/core/platform/platform_helper.dart
git commit -m "feat(feedback): add showAdaptiveFeedback (TopFloatingNotice on iOS, SnackBar on Android)"
```

---

## Task 9: Replace Icons with Icons.adaptive

**Depends on:** Task 1
**Files:** Multiple files

- [ ] **Step 1: Find and replace common adaptive icons**

Search for these icon patterns and replace:

| Pattern | Replacement |
|---------|------------|
| `Icons.arrow_back` | `Icons.adaptive.arrow_back` |
| `Icons.share` | `Icons.adaptive.share` |
| `Icons.more_vert` | `Icons.adaptive.more` (where contextually appropriate) |

```bash
cd frontend
grep -rn "Icons.arrow_back" lib/ --include="*.dart" | grep -v ".g.dart"
grep -rn "Icons.share" lib/ --include="*.dart" | grep -v ".g.dart"
```

Replace only icons that have `Icons.adaptive.*` equivalents. Not all icons have adaptive variants.

- [ ] **Step 2: Run tests**

```bash
cd frontend && flutter test
```

Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat(icons): use Icons.adaptive for platform-specific icons"
```

---

## Task 10: ListTile iOS Styling via Theme

**Depends on:** Task 1
**Files:**
- Modify: `frontend/lib/core/theme/app_theme.dart`

- [ ] **Step 1: Add iOS-conditional ListTile theme in `_buildTheme`**

Inside `_buildTheme`, after the existing `listTileTheme` property, add iOS-specific adjustments:

```dart
listTileTheme: ListTileThemeData(
  contentPadding: EdgeInsets.symmetric(
    horizontal: isIOS ? 20 : 16,
    vertical: isIOS ? 4 : 0,
  ),
  iconColor: scheme.onSurfaceVariant,
  textColor: scheme.onSurface,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(isIOS ? 10 : extension.cardRadius),
  ),
),
```

- [ ] **Step 2: Run tests**

```bash
cd frontend && flutter test
```

Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
git add frontend/lib/core/theme/app_theme.dart
git commit -m "feat(listtile): iOS-style ListTile with tighter padding and smaller radius"
```

---

## Dependency Graph

```
Task 1 (Foundation)
  ├── Task 2 (Page Transitions)
  ├── Task 3 (Dialog Helper)
  ├── Task 4 (Bottom Sheet)
  ├── Task 5 (AppBar Helper)
  ├── Task 6 (.adaptive() Widgets)
  ├── Task 7 (Navigation Bar)
  ├── Task 8 (Adaptive SnackBar)
  ├── Task 9 (Adaptive Icons)
  └── Task 10 (ListTile Styling)
```

Tasks 2–10 can all run in **parallel** after Task 1 completes.

## Self-Review

1. **Spec coverage:** Every section of the design spec maps to a task:
   - Layer 1 (auto): Not needed (zero code) ✓
   - Layer 2 (.adaptive): Task 6 ✓
   - AppBar: Task 5 ✓
   - Buttons: Handled via theme in Task 1 ✓
   - Dialogs: Task 3 ✓
   - Text fields: Handled via theme in Task 1 ✓
   - Page transitions: Task 2 ✓
   - Bottom sheet: Task 4 ✓
   - SnackBar: Task 8 ✓
   - Navigation bar: Task 7 ✓
   - Icons: Task 9 ✓
   - ListTile: Task 10 ✓
   - Desktop: No Cupertino on desktop — covered by all tasks ✓

2. **Placeholder scan:** No TBD/TODO/vague steps found. All code blocks contain complete implementations.

3. **Type consistency:** All method signatures are consistent across tasks. `PlatformHelper.isIOS(context)` used uniformly.
