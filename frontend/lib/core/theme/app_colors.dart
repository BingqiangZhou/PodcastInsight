import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';

/// ============================================================
/// App Design System
///
/// Design Philosophy:
/// Dark base theme with colorful gradient accents
/// combined with precise typography and spacing.
/// ============================================================

class AppColors {
  AppColors._();

  // ============================================================
  // LIGHT THEME - 亮色主题
  /// Arc+Linear surface colors
  // ============================================================

  // Background Colors - 背景色系
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF2F2F7);
  static const Color lightSurfaceElevated = Color(0xFFFFFFFF);
  static const Color lightOnBackground = Color(0xFF1a1a2e);
  static const Color lightOnSurface = Color(0x991a1a2e); // rgba 0.6
  static const Color lightOnSurfaceMuted = Color(0x8C1a1a2e); // rgba 0.55
  static const Color lightBorder = Color(0x0F000000); // rgba 0.06

  // Text Colors - 文字色系 (Apple HIG label colors)
  static const Color lightTextPrimary = Color(0xFF000000);
  static const Color lightTextSecondary = Color(0xFF3C3C43);
  static const Color lightTextTertiary = Color(0xFF3C3C43);

  // Outline Colors - 边框色系 (Apple HIG systemGray colors)
  static const Color lightOutline = Color(0xFFC7C7CC);
  static const Color lightOutlineVariant = Color(0xFFD1D1D6);


  // ============================================================
  // DARK THEME - 暗色主题
  /// Arc+Linear surface colors
  // ============================================================

  // Background Colors - 背景色系
  static const Color darkBackground = Color(0xFF0f0f1a);
  static const Color darkSurface = Color(0xFF1a1a2e);
  static const Color darkSurfaceVariant = Color(0xFF2C2C2E);
  static const Color darkSurfaceElevated = Color(0xFF252540);
  static const Color darkOnBackground = Color(0xE6FFFFFF); // rgba 0.9
  static const Color darkOnSurface = Color(0x80FFFFFF); // rgba 0.5
  static const Color darkOnSurfaceMuted = Color(0x80FFFFFF); // rgba 0.50
  static const Color darkBorder = Color(0x0FFFFFFF); // rgba 0.06
  static const Color darkBorderHover = Color(0x1FFFFFFF); // rgba 0.12

  // Text Colors - 文字色系 (Apple HIG label colors)
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFEBEBF5);
  static const Color darkTextTertiary = Color(0xFFEBEBF5);

  // Outline Colors - 边框色系 (Apple HIG systemGray colors)
  static const Color darkOutline = Color(0xFF48484A);
  static const Color darkOutlineVariant = Color(0xFF3A3A3C);


  // ============================================================
  // BRAND COLORS - 品牌色 (Apple HIG system tints)
  // ============================================================

  // Primary - System Indigo (Apple HIG)
  static const Color primary = Color(0xFF5856D6); // systemIndigo light
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color primaryLight = Color(0xFF5E5CE6); // systemIndigo dark
  static const Color primaryContainer = Color(0xFFE8E8FF);
  static const Color primaryContainerDark = Color(0xFF1E1B4B);

  // Warm accents - System Orange (Apple HIG)
  static const Color accentWarm = Color(0xFFFF9500); // systemOrange light
  static const Color accentWarmLight = Color(0xFFFF9500);
  static const Color accentWarmDark = Color(0xFFFF9F0A); // systemOrange dark
  static const Color accentCoral = Color(0xFFFF2D55); // systemPink light
  static const Color accentCoralLight = Color(0xFFFF375F); // systemPink dark
  static const Color warmYellowSurface = Color(0xFFFEF3C7);
  static const Color warmPinkSurface = Color(0xFFFCE7F3);

  // AI-specific accent tokens - using Apple system colors
  static const Color aiBubbleUser = Color(0xFFFFCC00); // systemYellow light
  static const Color aiBubbleUserDark = Color(0xFFFFD60A); // systemYellow dark
  static const Color aiBubbleAssistant = Color(0xFFFF2D55); // systemPink light
  static const Color aiBubbleAssistantDark = Color(0xFFFF375F); // systemPink dark
  static const Color aiChipBackground = Color(0xFFFF9500); // systemOrange light
  static const Color aiChipBackgroundDark = Color(0xFFFF9F0A); // systemOrange dark
  static const Color aiHighlightSurface = Color(0xFFFFF4D6); // light yellow surface
  static const Color aiHighlightSurfaceDark = Color(0xFF3D2D00); // dark yellow surface
  static const Color cosmicFilterActive = Color(0xFFFF9500); // systemOrange light
  static const Color cosmicFilterActiveDark = Color(0xFFFF9F0A); // systemOrange dark

  // Tertiary - System Green (Apple HIG)
  static const Color tertiary = Color(0xFF34C759); // systemGreen light
  static const Color tertiaryLight = Color(0xFF30D158); // systemGreen dark
  static const Color tertiaryDark = Color(0xFF248A3D);

  // ============================================================
  // SEMANTIC COLORS - 语义色彩 (Apple HIG system colors)
  // ============================================================

  static const Color success = Color(0xFF34C759); // systemGreen light
  static const Color warning = Color(0xFFFF9500); // systemOrange light
  static const Color error = Color(0xFFFF3B30); // systemRed light
  static const Color info = Color(0xFF5856D6); // systemIndigo light

  // ============================================================
  // LEGACY COLORS - 向后兼容
  // ============================================================

  static const Color riverAccent = Color(0xFF5AC8FA); // systemTeal light
  static const Color sunGlow = Color(0xFFFFCC00); // systemYellow light
  static const Color sunRay = Color(0xFFFF3B30); // systemRed light
  static const Color leaf = Color(0xFF34C759); // systemGreen light
  static const Color indigo = Color(0xFF5856D6); // systemIndigo light

  // Legacy gradients
  static const LinearGradient darkSubtleGradient = LinearGradient(
    colors: [Color(0xFF000000), Color(0xFF1C1C1E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient softBackgroundGradient = LinearGradient(
    colors: [Color(0xFFF2F2F7), Color(0xFFFFFFFF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ============================================================
  // GRADIENT PALETTE - 渐变色板 (Arc-style accents)
  // ============================================================

  static const List<Color> coralColors = [Color(0xFFFF6B6B), Color(0xFFE84545)];
  static const List<Color> violetColors = [Color(0xFF7C6AEF), Color(0xFF5845D6)];
  static const List<Color> cyanColors = [Color(0xFF4FC3D6), Color(0xFF389CAE)];
  static const List<Color> goldColors = [Color(0xFFF5A623), Color(0xFFD4901E)];
  static const List<Color> roseColors = [Color(0xFFFF6B8A), Color(0xFFD4536E)];
  static const List<Color> skyColors = [Color(0xFF5AC8FA), Color(0xFF4AA8D6)];

  static const List<List<Color>> podcastGradientColors = [
    coralColors,
    violetColors,
    cyanColors,
    goldColors,
    roseColors,
    skyColors,
  ];

  // ============================================================
  // DATA VISUALIZATION - 数据可视化色彩
  /// Using Apple HIG system tint colors
  // ============================================================

  static const Color chart1 = Color(0xFF5856D6); // systemIndigo
  static const Color chart2 = Color(0xFF5E5CE6); // systemIndigo dark
  static const Color chart3 = Color(0xFF34C759); // systemGreen
  static const Color chart4 = Color(0xFFFF9500); // systemOrange
  static const Color chart5 = Color(0xFFAF52DE); // systemPurple
  static const Color chart6 = Color(0xFFFF2D55); // systemPink
  static const Color chart7 = Color(0xFF5AC8FA); // systemTeal
  static const Color chart8 = Color(0xFF30D158); // systemGreen dark

  static const List<Color> chartColors = [
    chart1,
    chart2,
    chart3,
    chart4,
    chart5,
    chart6,
    chart7,
    chart8,
  ];
}

/// ============================================================
/// APP THEME EXTENSION
/// App Theme Extension
/// ============================================================

@immutable
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  const AppThemeExtension({
    required this.contentMaxWidth,
    required this.sectionGap,
    required this.cardRadius,
    required this.buttonRadius,
    required this.navItemRadius,
    required this.itemRadius,
    required this.sheetRadius,
    required this.pillRadius,
    required this.dialogRadius,
    required this.inputFillAlpha,
    required this.listTileHorizontalPadding,
    required this.listTileVerticalPadding,
    required this.listTileRadius,
    required this.centerTitle,
    required this.warmAccent,
    required this.coralAccent,
    required this.shadowXs,
    required this.shadowSm,
    required this.shadowMd,
    required this.shadowLg,
    required this.chartColors,
    required this.aiPrimary, // Legacy AI accent token (kept for compatibility)
    required this.podcastGradientColors, // Legacy properties for backwards compatibility (non-nullable with defaults)
    this.shellGradient,
  });

  // Layout
  final double contentMaxWidth;
  final double sectionGap;
  final double cardRadius;
  final double buttonRadius;
  final double navItemRadius;
  final double itemRadius;
  final double sheetRadius;
  final double pillRadius;
  final double dialogRadius;
  final double inputFillAlpha;
  final double listTileHorizontalPadding;
  final double listTileVerticalPadding;
  final double listTileRadius;
  final bool centerTitle;

  // Accent colors (theme-aware, light/dark variants)
  final Color warmAccent;
  final Color coralAccent;

  // Shadows
  final BoxShadow shadowXs;
  final BoxShadow shadowSm;
  final BoxShadow shadowMd;
  final BoxShadow shadowLg;

  // Data Visualization
  final List<Color> chartColors;

  // Legacy properties for backwards compatibility
  final Gradient? shellGradient;
  final Color aiPrimary; // Legacy AI accent token (kept for compatibility)
  final List<List<Color>> podcastGradientColors;

  @override
  AppThemeExtension copyWith({
    double? contentMaxWidth,
    double? sectionGap,
    double? cardRadius,
    double? buttonRadius,
    double? navItemRadius,
    double? itemRadius,
    double? sheetRadius,
    double? pillRadius,
    double? dialogRadius,
    double? inputFillAlpha,
    double? listTileHorizontalPadding,
    double? listTileVerticalPadding,
    double? listTileRadius,
    bool? centerTitle,
    Color? warmAccent,
    Color? coralAccent,
    BoxShadow? shadowXs,
    BoxShadow? shadowSm,
    BoxShadow? shadowMd,
    BoxShadow? shadowLg,
    List<Color>? chartColors,
    Gradient? shellGradient,
    Color? aiPrimary,
    List<List<Color>>? podcastGradientColors,
  }) {
    return AppThemeExtension(
      contentMaxWidth: contentMaxWidth ?? this.contentMaxWidth,
      sectionGap: sectionGap ?? this.sectionGap,
      cardRadius: cardRadius ?? this.cardRadius,
      buttonRadius: buttonRadius ?? this.buttonRadius,
      navItemRadius: navItemRadius ?? this.navItemRadius,
      itemRadius: itemRadius ?? this.itemRadius,
      sheetRadius: sheetRadius ?? this.sheetRadius,
      pillRadius: pillRadius ?? this.pillRadius,
      dialogRadius: dialogRadius ?? this.dialogRadius,
      inputFillAlpha: inputFillAlpha ?? this.inputFillAlpha,
      listTileHorizontalPadding: listTileHorizontalPadding ?? this.listTileHorizontalPadding,
      listTileVerticalPadding: listTileVerticalPadding ?? this.listTileVerticalPadding,
      listTileRadius: listTileRadius ?? this.listTileRadius,
      centerTitle: centerTitle ?? this.centerTitle,
      warmAccent: warmAccent ?? this.warmAccent,
      coralAccent: coralAccent ?? this.coralAccent,
      shadowXs: shadowXs ?? this.shadowXs,
      shadowSm: shadowSm ?? this.shadowSm,
      shadowMd: shadowMd ?? this.shadowMd,
      shadowLg: shadowLg ?? this.shadowLg,
      chartColors: chartColors ?? this.chartColors,
      shellGradient: shellGradient ?? this.shellGradient,
      aiPrimary: aiPrimary ?? this.aiPrimary,
      podcastGradientColors:
          podcastGradientColors ?? this.podcastGradientColors,
    );
  }

  @override
  AppThemeExtension lerp(
    ThemeExtension<AppThemeExtension>? other,
    double t,
  ) {
    if (other is! AppThemeExtension) {
      return this;
    }

    return AppThemeExtension(
      contentMaxWidth: lerpDouble(contentMaxWidth, other.contentMaxWidth, t)!,
      sectionGap: lerpDouble(sectionGap, other.sectionGap, t)!,
      cardRadius: lerpDouble(cardRadius, other.cardRadius, t)!,
      buttonRadius: lerpDouble(buttonRadius, other.buttonRadius, t)!,
      navItemRadius: lerpDouble(navItemRadius, other.navItemRadius, t)!,
      itemRadius: lerpDouble(itemRadius, other.itemRadius, t)!,
      sheetRadius: lerpDouble(sheetRadius, other.sheetRadius, t)!,
      pillRadius: lerpDouble(pillRadius, other.pillRadius, t)!,
      dialogRadius: lerpDouble(dialogRadius, other.dialogRadius, t)!,
      inputFillAlpha: lerpDouble(inputFillAlpha, other.inputFillAlpha, t)!,
      listTileHorizontalPadding: lerpDouble(listTileHorizontalPadding, other.listTileHorizontalPadding, t)!,
      listTileVerticalPadding: lerpDouble(listTileVerticalPadding, other.listTileVerticalPadding, t)!,
      listTileRadius: lerpDouble(listTileRadius, other.listTileRadius, t)!,
      centerTitle: t < 0.5 ? centerTitle : other.centerTitle,
      warmAccent: Color.lerp(warmAccent, other.warmAccent, t)!,
      coralAccent: Color.lerp(coralAccent, other.coralAccent, t)!,
      shadowXs: BoxShadow.lerp(shadowXs, other.shadowXs, t)!,
      shadowSm: BoxShadow.lerp(shadowSm, other.shadowSm, t)!,
      shadowMd: BoxShadow.lerp(shadowMd, other.shadowMd, t)!,
      shadowLg: BoxShadow.lerp(shadowLg, other.shadowLg, t)!,
      chartColors: other.chartColors,
      aiPrimary: Color.lerp(aiPrimary, other.aiPrimary, t)!,
      podcastGradientColors: other.podcastGradientColors,
    );
  }

  /// Light theme extension (const base)
  static const light = AppThemeExtension(
    contentMaxWidth: 1240,
    sectionGap: 24,
    cardRadius: 14,
    buttonRadius: 10,
    navItemRadius: 10,
    itemRadius: 8,
    sheetRadius: 20,
    pillRadius: 999,
    dialogRadius: 24,
    inputFillAlpha: 0.6,
    listTileHorizontalPadding: AppSpacing.md,
    listTileVerticalPadding: 0,
    listTileRadius: 14,
    centerTitle: false,
    warmAccent: AppColors.accentWarm,
    coralAccent: AppColors.accentCoral,
    shadowXs: BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 1,
      offset: Offset(0, 1),
    ),
    shadowSm: BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 2,
      offset: Offset(0, 2),
    ),
    shadowMd: BoxShadow(
      color: Color(0x14000000),
      blurRadius: 4,
      offset: Offset(0, 4),
    ),
    shadowLg: BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 8,
      offset: Offset(0, 8),
    ),
    chartColors: AppColors.chartColors,
    aiPrimary: Color(0xFF5856D6),
    podcastGradientColors: AppColors.podcastGradientColors,
  );

  /// Dark theme extension (const base)
  static const dark = AppThemeExtension(
    contentMaxWidth: 1240,
    sectionGap: 24,
    cardRadius: 14,
    buttonRadius: 10,
    navItemRadius: 10,
    itemRadius: 8,
    sheetRadius: 20,
    pillRadius: 999,
    dialogRadius: 24,
    inputFillAlpha: 0.6,
    listTileHorizontalPadding: AppSpacing.md,
    listTileVerticalPadding: 0,
    listTileRadius: 14,
    centerTitle: false,
    warmAccent: AppColors.accentWarmDark,
    coralAccent: AppColors.accentCoralLight,
    shadowXs: BoxShadow(
      color: Color(0x33000000),
      blurRadius: 1,
      offset: Offset(0, 1),
    ),
    shadowSm: BoxShadow(
      color: Color(0x4D000000),
      blurRadius: 2,
      offset: Offset(0, 2),
    ),
    shadowMd: BoxShadow(
      color: Color(0x66000000),
      blurRadius: 4,
      offset: Offset(0, 4),
    ),
    shadowLg: BoxShadow(
      color: Color(0x80000000),
      blurRadius: 8,
      offset: Offset(0, 8),
    ),
    chartColors: AppColors.chartColors,
    aiPrimary: Color(0xFFA5B4FC),
    podcastGradientColors: AppColors.podcastGradientColors,
  );

  /// Light theme extension for iOS (larger radii, no Material shadows).
  /// Derived from [light] via copyWith.
  static AppThemeExtension lightIOS() => light.copyWith(
    cardRadius: 16,
    buttonRadius: 14,
    navItemRadius: 12,
    itemRadius: 10,
    dialogRadius: 16,
    inputFillAlpha: 0.4,
    listTileHorizontalPadding: AppSpacing.mdLg,
    listTileVerticalPadding: AppSpacing.xs,
    listTileRadius: 10,
    centerTitle: true,
    shadowXs: const BoxShadow(color: Color(0x00000000)),
    shadowSm: const BoxShadow(color: Color(0x00000000)),
    shadowMd: const BoxShadow(color: Color(0x00000000)),
    shadowLg: const BoxShadow(color: Color(0x00000000)),
  );

  /// Dark theme extension for iOS (larger radii, no Material shadows).
  /// Derived from [dark] via copyWith.
  static AppThemeExtension darkIOS() => dark.copyWith(
    cardRadius: 16,
    buttonRadius: 14,
    navItemRadius: 12,
    itemRadius: 10,
    dialogRadius: 16,
    inputFillAlpha: 0.4,
    listTileHorizontalPadding: AppSpacing.mdLg,
    listTileVerticalPadding: AppSpacing.xs,
    listTileRadius: 10,
    centerTitle: true,
    shadowXs: const BoxShadow(color: Color(0x00000000)),
    shadowSm: const BoxShadow(color: Color(0x00000000)),
    shadowMd: const BoxShadow(color: Color(0x00000000)),
    shadowLg: const BoxShadow(color: Color(0x00000000)),
  );

  /// Light theme with gradient (non-const, for runtime use)
  static AppThemeExtension get lightWithGradient => light.copyWith(
    shellGradient: const LinearGradient(
      colors: [Color(0xFFF2F2F7), Color(0xFFFFFFFF)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  );

  /// Dark theme with gradient (non-const, for runtime use)
  static AppThemeExtension get darkWithGradient => dark.copyWith(
    shellGradient: const LinearGradient(
      colors: [Color(0xFF000000), Color(0xFF1C1C1E)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  );
}

/// Get the App theme extension from context
AppThemeExtension appThemeOf(BuildContext context) {
  return Theme.of(context).extension<AppThemeExtension>() ??
      (Theme.of(context).brightness == Brightness.dark
          ? AppThemeExtension.dark
          : AppThemeExtension.light);
}
