# Platform-Adaptive UI Design

**Date:** 2026-04-16
**Status:** Approved
**Scope:** Replace pure Material 3 UI with platform-adaptive UI (Material on Android/desktop, Cupertino on iOS)

## Background

Stella is currently a pure Material 3 app with zero Cupertino widget usage. The goal is to make the app look and feel native on each platform:

- **iOS**: Cupertino-style controls, slide-in page transitions, frosted glass navigation
- **Android**: Material 3 (current style, preserved)
- **Desktop** (macOS/Windows/Linux): Material 3, sidebar navigation (current responsive layout preserved)

### Why Not flutter_platform_widgets

`flutter_platform_widgets` has been discontinued (marked on pub.dev). Flutter's official direction is to provide `.adaptive()` constructors and split Material/Cupertino into independent packages. We follow this direction.

## Architecture

### Three-Layer Adaptation Strategy

```
Layer 1: Flutter automatic (zero code changes)
  Scrolling physics, fonts, icons, text editing behavior

Layer 2: .adaptive() constructors (simple find-and-replace)
  Switch, Slider, Checkbox, Radio, CircularProgressIndicator, AlertDialog

Layer 3: Custom helper layer (~8 helper files)
  AppBar, buttons, dialogs, bottom sheets, page transitions, navigation bar, text field styling
```

### File Structure

New files under `frontend/lib/core/platform/`:

```
platform_helper.dart          — Platform detection utilities
adaptive_app_bar.dart         — Platform-adaptive AppBar helper
adaptive_dialog.dart          — Platform-adaptive dialog (showDialog → showCupertinoDialog)
adaptive_bottom_sheet.dart    — Platform-adaptive bottom sheet
adaptive_page_route.dart      — Platform-adaptive page route (Material zoom vs Cupertino slide)
```

Existing files to modify:

```
core/theme/app_theme.dart              — Add Cupertino theme data, platform-aware styles
core/widgets/page_transitions.dart     — Replace StellaPageRoute with adaptive transitions
core/widgets/custom_adaptive_navigation.dart — Add iOS CupertinoTabBar style
core/widgets/adaptive_sheet_helper.dart — Extend with Cupertino modal popup
core/app/app.dart                      — Add CupertinoTheme wrapper in MaterialApp
```

## Component Mapping

### Layer 2 — Direct .adaptive() Replacement

| Current | Replace With | iOS Renders As | Android/Desktop |
|---------|-------------|----------------|-----------------|
| `Switch(...)` | `Switch.adaptive(...)` | CupertinoSwitch | Material Switch |
| `Slider(...)` | `Slider.adaptive(...)` | CupertinoSlider | Material Slider |
| `Checkbox(...)` | `Checkbox.adaptive(...)` | CupertinoCheckbox | Material Checkbox |
| `Radio(...)` | `Radio.adaptive(...)` | CupertinoRadio | Material Radio |
| `CircularProgressIndicator(...)` | `CircularProgressIndicator.adaptive(...)` | CupertinoActivityIndicator | Material Circular |
| `AlertDialog(...)` | `AlertDialog.adaptive(...)` | CupertinoAlertDialog | Material AlertDialog |

Note: `LinearProgressIndicator` has no Cupertino equivalent — keep as-is.

### Layer 3 — Custom Helper Functions

#### 1. AppBar (33 usages / 20 files)

Create `adaptiveAppBar()` helper function:
- Android/desktop: Material 3 AppBar (preserved)
- iOS: Material AppBar with iOS-style adjustments (elevation 0, centered title, SF Pro text style, transparent surface tint)

```dart
PreferredSizeWidget adaptiveAppBar(BuildContext context, {
  required String title,
  List<Widget>? actions,
  Widget? leading,
  bool? centerTitle,
}) {
  final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
  return AppBar(
    title: Text(title),
    elevation: isIOS ? 0 : null,
    scrolledUnderElevation: isIOS ? 0.1 : null,
    centerTitle: centerTitle ?? isIOS,
    surfaceTintColor: isIOS ? Colors.transparent : null,
    actions: actions,
    leading: leading,
  );
}
```

#### 2. Buttons (156 usages / 48 files)

No wrapper widgets (YAGNI). Adjust styles through theme:

- iOS: Flat (elevation 0), rounded corners (8px), filled or text-only styles
- Android: Material 3 elevated/outlined/text as current

Apply via `ThemeData.elevatedButtonTheme`, `textButtonTheme`, `outlinedButtonTheme` with platform-conditional styles.

#### 3. Dialogs (16 usages / 8 files)

Create `showAdaptiveDialog()`:

```dart
Future<T?> showAdaptiveDialog<T>(BuildContext context, {
  required String title,
  required String content,
  List<AdaptiveDialogAction>? actions,
  bool barrierDismissible = true,
})
```

- Android/desktop: `showDialog` + Material AlertDialog
- iOS: `showCupertinoDialog` + CupertinoAlertDialog

#### 4. Text Fields (26 usages / 12 files)

Adjust via `ThemeData.inputDecorationTheme` for iOS:
- Flat border (no outlined rectangle)
- Light gray background fill
- Reduced content padding
- No floating label (placeholder style)

Keep Material TextField (preserves validator, decoration, error states). CupertinoTextField lacks these features.

#### 5. Page Transitions

Replace `StellaPageRoute` with adaptive transitions:
- Android/desktop: Material `ZoomPageTransitionsBuilder`
- iOS: Cupertino slide-in transition + edge swipe back gesture

Apply via `ThemeData.pageTransitionsTheme`.

#### 6. Bottom Sheet (2 usages / 1 file)

Extend existing `adaptive_sheet_helper.dart`:
- Android/desktop: `showModalBottomSheet`
- iOS: `showCupertinoModalPopup`

#### 7. SnackBar (6 usages / 2 files)

iOS has no SnackBar concept. Use existing `TopFloatingNotice` component on iOS, SnackBar on Android/desktop.

#### 8. Bottom Navigation Bar

Extend `CustomAdaptiveNavigation` for iOS mobile:
- iOS mobile: CupertinoTabBar style (frosted glass background, system icons)
- Android mobile: Material NavigationBar (preserved)
- Tablet/desktop: Sidebar (preserved, no change)

#### 9. Icons

Use `Icons.adaptive.*` for platform-adaptive icons where available (back button, share, more/overflow).

## Theme System Changes

### AppTheme Updates

```dart
// Add CupertinoThemeData getter
CupertinoThemeData get cupertinoThemeData => CupertinoThemeData(
  primaryColor: AppColors.primary,
  barBackgroundColor: AppColors.surfaceBackground,
  scaffoldBackgroundColor: AppColors.background,
);

// Platform-aware ThemeData
ThemeData buildThemeData(TargetPlatform platform) {
  final isIOS = platform == TargetPlatform.iOS;
  return ThemeData(
    platform: platform,
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      elevation: isIOS ? 0 : 3,
      scrolledUnderElevation: isIOS ? 0.1 : 3,
      centerTitle: isIOS,
    ),
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        TargetPlatform.android: const ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: const ZoomPageTransitionsBuilder(),
        TargetPlatform.windows: const ZoomPageTransitionsBuilder(),
        TargetPlatform.linux: const ZoomPageTransitionsBuilder(),
      },
    ),
    // ... platform-conditional button/input themes
  );
}
```

### What Does NOT Change

- `AppColors` — brand colors, semantic colors shared across all platforms
- `AppRadius`, `AppSpacing` — design tokens kept as constants
- `ThemeProvider` — light/dark/system mode logic unchanged
- `MaterialApp` remains the root widget (not replaced with CupertinoApp)
- Responsive breakpoint system — mobile/tablet/desktop layout unchanged

### CupertinoTheme Integration

Wrap `MaterialApp`'s builder with `CupertinoTheme`:

```dart
MaterialApp(
  theme: themeData,
  builder: (context, child) {
    return CupertinoTheme(
      data: cupertinoThemeData,
      child: child!,
    );
  },
)
```

This ensures `.adaptive()` widgets on iOS pick up correct Cupertino styling.

## Desktop Adaptation

Desktop platforms (macOS, Windows, Linux):

- **Controls**: Follow Material 3 (same as Android). No Cupertino on desktop.
- **Layout**: Existing responsive breakpoints continue (sidebar at >= 1200px).
- **Interactions**: Mouse hover, keyboard shortcuts, right-click menus preserved.
- **Page transitions**: Material zoom transition on all desktop platforms.
- **Rationale**: Cupertino is iOS/mobile design language; Material 3 is more appropriate for desktop.

## Migration Phases

### Phase 1: Foundation (5-8 files)

1. Create `platform_helper.dart`
2. Update `AppTheme` with platform-aware styles + Cupertino theme data
3. Replace page transitions with adaptive transitions (`page_transitions.dart`, `app_router.dart`)
4. Add `CupertinoTheme` wrapper in `app.dart`

**Validation**: iOS simulator shows Cupertino slide-in page transitions.

### Phase 2: Navigation Shell (3-5 files)

1. Extend `CustomAdaptiveNavigation` with iOS CupertinoTabBar style
2. Create `adaptive_app_bar.dart`
3. Replace AppBar calls in key pages

**Validation**: iOS bottom nav shows frosted glass CupertinoTabBar; iOS AppBar has flat style with centered title.

### Phase 3: Interactive Components (15-20 files)

1. `Switch` → `Switch.adaptive()` (5 files)
2. `Slider` → `Slider.adaptive()` (1 file)
3. `CircularProgressIndicator` → `.adaptive()` (33 files)
4. `AlertDialog` → `AlertDialog.adaptive()` (8 files)

**Validation**: iOS shows Cupertino switch, slider, activity indicator, and alert dialog.

### Phase 4: Dialogs and Bottom Sheets (8-10 files)

1. Create `adaptive_dialog.dart`
2. Extend `adaptive_sheet_helper.dart`
3. Replace `showDialog` calls (8 files)
4. Replace `showModalBottomSheet` calls (1 file)

**Validation**: iOS uses `showCupertinoDialog` and `showCupertinoModalPopup`.

### Phase 5: Button and Input Styling (30-40 files)

1. Button iOS styling via theme (automatic across all 48 files)
2. TextField iOS styling via `inputDecorationTheme` (automatic)
3. Optionally update key input files for iOS border style

**Validation**: iOS buttons are flat, inputs have iOS-style borders.

### Phase 6: Polish (5-10 files)

1. SnackBar → TopFloatingNotice on iOS (2 files)
2. Icons → `Icons.adaptive.*` where applicable
3. ListTile iOS style adjustments (7 files)

**Validation**: Full app looks native on iOS, Android, and desktop. No jarring Material artifacts on iOS.

## Success Criteria

1. iOS users see Cupertino-style controls, transitions, and navigation
2. Android users see Material 3 (no regression)
3. Desktop users see Material 3 with sidebar navigation (no regression)
4. Colors, branding, and design tokens remain consistent across platforms
5. All existing widget tests pass after migration
6. No third-party UI dependencies added
