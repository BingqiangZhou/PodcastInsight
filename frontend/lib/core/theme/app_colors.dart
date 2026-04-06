import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// ============================================================
/// Apple Liquid Glass Design System - 苹果液态玻璃设计系统
///
/// Design Philosophy:
/// Based on Apple Human Interface Guidelines (HIG) with
/// Liquid Glass visual effects for depth and vibrancy.
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
  static const Color lightOnSurfaceMuted = Color(0x591a1a2e); // rgba 0.35
  static const Color lightBorder = Color(0x0F000000); // rgba 0.06

  // Text Colors - 文字色系 (Apple HIG label colors)
  static const Color lightTextPrimary = Color(0xFF000000);
  static const Color lightTextSecondary = Color(0xFF3C3C43);
  static const Color lightTextTertiary = Color(0xFF3C3C43);

  // Outline Colors - 边框色系 (Apple HIG systemGray colors)
  static const Color lightOutline = Color(0xFFC7C7CC);
  static const Color lightOutlineVariant = Color(0xFFD1D1D6);

  // Light theme card tier colors
  static const Color lightSurfaceTierFill = Color(0x0A000000);
  static const Color lightCardTierFill = Color(0x0F000000);
  static const Color lightElevatedTierFill = Color(0x14000000);
  static const Color lightSurfaceTierBorder = Color(0x0F000000);
  static const Color lightCardTierBorder = Color(0x14000000);
  static const Color lightElevatedTierBorder = Color(0x1A000000);

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
  static const Color darkOnSurfaceMuted = Color(0x40FFFFFF); // rgba 0.25
  static const Color darkBorder = Color(0x0FFFFFFF); // rgba 0.06
  static const Color darkBorderHover = Color(0x1FFFFFFF); // rgba 0.12

  // Text Colors - 文字色系 (Apple HIG label colors)
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFEBEBF5);
  static const Color darkTextTertiary = Color(0xFFEBEBF5);

  // Outline Colors - 边框色系 (Apple HIG systemGray colors)
  static const Color darkOutline = Color(0xFF48484A);
  static const Color darkOutlineVariant = Color(0xFF3A3A3C);

  // Card tier colors (for dark theme)
  static const Color surfaceTierFill = Color(0x0AFFFFFF); // rgba 0.04
  static const Color cardTierFill = Color(0x0FFFFFFF); // rgba 0.06
  static const Color elevatedTierFill = Color(0x14FFFFFF); // rgba 0.08
  static const Color surfaceTierBorder = Color(0x0FFFFFFF); // rgba 0.06
  static const Color cardTierBorder = Color(0x14FFFFFF); // rgba 0.08
  static const Color elevatedTierBorder = Color(0x1AFFFFFF); // rgba 0.10

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

  static const List<Color> coralColors = [Color(0xFFFF6B6B), Color(0xFFFF8E53)];
  static const List<Color> violetColors = [Color(0xFF9B5DE5), Color(0xFF5B6BF0)];
  static const List<Color> cyanColors = [Color(0xFF00C9A7), Color(0xFF00D4FF)];
  static const List<Color> goldColors = [Color(0xFFFFC75F), Color(0xFFFFD93D)];
  static const List<Color> roseColors = [Color(0xFFF15BB5), Color(0xFFFF6B6B)];
  static const List<Color> skyColors = [Color(0xFF4CC9F0), Color(0xFF72EFDD)];

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
/// Apple Liquid Glass Theme Extension
/// ============================================================

@immutable
class AppThemeExtension extends ThemeExtension<AppThemeExtension> {
  const AppThemeExtension({
    required this.contentMaxWidth,
    required this.sectionGap,
    required this.cardRadius,
    required this.panelRadius,
    required this.buttonRadius,
    required this.inputRadius,
    required this.navItemRadius,
    required this.controlRadius,
    required this.sheetRadius,
    required this.pillRadius,
    required this.shadowXs,
    required this.shadowSm,
    required this.shadowMd,
    required this.shadowLg,
    required this.chartColors,
    // Legacy properties for backwards compatibility (non-nullable with defaults)
    this.shellGradient,
    required this.aiPrimary,
    // AI accent tokens
    required this.aiBubbleUserColor,
    required this.aiBubbleAssistantColor,
    required this.aiChipColor,
    required this.aiHighlightSurfaceColor,
    required this.cosmicFilterActiveColor,
    // Arc+Linear tier tokens
    required this.surfaceTierFill,
    required this.cardTierFill,
    required this.elevatedTierFill,
    required this.surfaceTierBorder,
    required this.cardTierBorder,
    required this.elevatedTierBorder,
    required this.podcastGradientColors,
  });

  // Layout
  final double contentMaxWidth;
  final double sectionGap;
  final double cardRadius;
  final double panelRadius;
  final double buttonRadius;
  final double inputRadius;
  final double navItemRadius;
  final double controlRadius;
  final double sheetRadius;
  final double pillRadius;

  // Shadows
  final BoxShadow shadowXs;
  final BoxShadow shadowSm;
  final BoxShadow shadowMd;
  final BoxShadow shadowLg;

  // Data Visualization
  final List<Color> chartColors;

  // Legacy properties for backwards compatibility
  final Gradient? shellGradient;
  final Color aiPrimary;

  // AI accent tokens - using Apple system colors
  final Color aiBubbleUserColor;
  final Color aiBubbleAssistantColor;
  final Color aiChipColor;
  final Color aiHighlightSurfaceColor;
  final Color cosmicFilterActiveColor;

  // Arc+Linear tier tokens
  final Color surfaceTierFill;
  final Color cardTierFill;
  final Color elevatedTierFill;
  final Color surfaceTierBorder;
  final Color cardTierBorder;
  final Color elevatedTierBorder;
  final List<List<Color>> podcastGradientColors;

  @override
  AppThemeExtension copyWith({
    double? contentMaxWidth,
    double? sectionGap,
    double? cardRadius,
    double? panelRadius,
    double? buttonRadius,
    double? inputRadius,
    double? navItemRadius,
    double? controlRadius,
    double? sheetRadius,
    double? pillRadius,
    BoxShadow? shadowXs,
    BoxShadow? shadowSm,
    BoxShadow? shadowMd,
    BoxShadow? shadowLg,
    List<Color>? chartColors,
    Gradient? shellGradient,
    Color? aiPrimary,
    Color? aiBubbleUserColor,
    Color? aiBubbleAssistantColor,
    Color? aiChipColor,
    Color? aiHighlightSurfaceColor,
    Color? cosmicFilterActiveColor,
    Color? surfaceTierFill,
    Color? cardTierFill,
    Color? elevatedTierFill,
    Color? surfaceTierBorder,
    Color? cardTierBorder,
    Color? elevatedTierBorder,
    List<List<Color>>? podcastGradientColors,
  }) {
    return AppThemeExtension(
      contentMaxWidth: contentMaxWidth ?? this.contentMaxWidth,
      sectionGap: sectionGap ?? this.sectionGap,
      cardRadius: cardRadius ?? this.cardRadius,
      panelRadius: panelRadius ?? this.panelRadius,
      buttonRadius: buttonRadius ?? this.buttonRadius,
      inputRadius: inputRadius ?? this.inputRadius,
      navItemRadius: navItemRadius ?? this.navItemRadius,
      controlRadius: controlRadius ?? this.controlRadius,
      sheetRadius: sheetRadius ?? this.sheetRadius,
      pillRadius: pillRadius ?? this.pillRadius,
      shadowXs: shadowXs ?? this.shadowXs,
      shadowSm: shadowSm ?? this.shadowSm,
      shadowMd: shadowMd ?? this.shadowMd,
      shadowLg: shadowLg ?? this.shadowLg,
      chartColors: chartColors ?? this.chartColors,
      shellGradient: shellGradient ?? this.shellGradient,
      aiPrimary: aiPrimary ?? this.aiPrimary,
      aiBubbleUserColor: aiBubbleUserColor ?? this.aiBubbleUserColor,
      aiBubbleAssistantColor:
          aiBubbleAssistantColor ?? this.aiBubbleAssistantColor,
      aiChipColor: aiChipColor ?? this.aiChipColor,
      aiHighlightSurfaceColor:
          aiHighlightSurfaceColor ?? this.aiHighlightSurfaceColor,
      cosmicFilterActiveColor:
          cosmicFilterActiveColor ?? this.cosmicFilterActiveColor,
      surfaceTierFill: surfaceTierFill ?? this.surfaceTierFill,
      cardTierFill: cardTierFill ?? this.cardTierFill,
      elevatedTierFill: elevatedTierFill ?? this.elevatedTierFill,
      surfaceTierBorder: surfaceTierBorder ?? this.surfaceTierBorder,
      cardTierBorder: cardTierBorder ?? this.cardTierBorder,
      elevatedTierBorder: elevatedTierBorder ?? this.elevatedTierBorder,
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
      panelRadius: lerpDouble(panelRadius, other.panelRadius, t)!,
      buttonRadius: lerpDouble(buttonRadius, other.buttonRadius, t)!,
      inputRadius: lerpDouble(inputRadius, other.inputRadius, t)!,
      navItemRadius: lerpDouble(navItemRadius, other.navItemRadius, t)!,
      controlRadius: lerpDouble(controlRadius, other.controlRadius, t)!,
      sheetRadius: lerpDouble(sheetRadius, other.sheetRadius, t)!,
      pillRadius: lerpDouble(pillRadius, other.pillRadius, t)!,
      shadowXs: BoxShadow.lerp(shadowXs, other.shadowXs, t)!,
      shadowSm: BoxShadow.lerp(shadowSm, other.shadowSm, t)!,
      shadowMd: BoxShadow.lerp(shadowMd, other.shadowMd, t)!,
      shadowLg: BoxShadow.lerp(shadowLg, other.shadowLg, t)!,
      chartColors: other.chartColors,
      aiPrimary: Color.lerp(aiPrimary, other.aiPrimary, t)!,
      aiBubbleUserColor:
          Color.lerp(aiBubbleUserColor, other.aiBubbleUserColor, t)!,
      aiBubbleAssistantColor:
          Color.lerp(aiBubbleAssistantColor, other.aiBubbleAssistantColor, t)!,
      aiChipColor: Color.lerp(aiChipColor, other.aiChipColor, t)!,
      aiHighlightSurfaceColor:
          Color.lerp(aiHighlightSurfaceColor, other.aiHighlightSurfaceColor, t)!,
      cosmicFilterActiveColor:
          Color.lerp(cosmicFilterActiveColor, other.cosmicFilterActiveColor, t)!,
      // Arc+Linear tier tokens
      surfaceTierFill:
          Color.lerp(surfaceTierFill, other.surfaceTierFill, t)!,
      cardTierFill: Color.lerp(cardTierFill, other.cardTierFill, t)!,
      elevatedTierFill:
          Color.lerp(elevatedTierFill, other.elevatedTierFill, t)!,
      surfaceTierBorder:
          Color.lerp(surfaceTierBorder, other.surfaceTierBorder, t)!,
      cardTierBorder:
          Color.lerp(cardTierBorder, other.cardTierBorder, t)!,
      elevatedTierBorder:
          Color.lerp(elevatedTierBorder, other.elevatedTierBorder, t)!,
      podcastGradientColors: other.podcastGradientColors,
    );
  }

  /// Light theme extension (const base)
  static const light = AppThemeExtension(
    contentMaxWidth: 1240,
    sectionGap: 24,
    cardRadius: 12,
    panelRadius: 16,
    buttonRadius: 10,
    inputRadius: 8,
    navItemRadius: 10,
    controlRadius: 14,
    sheetRadius: 28,
    pillRadius: 999,
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
    // Legacy properties with fallback values
    aiPrimary: Color(0xFF5856D6), // systemIndigo
    // AI accent tokens — light (Apple system colors)
    aiBubbleUserColor: Color(0xFFFFF4D6), // light yellow
    aiBubbleAssistantColor: Color(0xFFFFE5F0), // light pink
    aiChipColor: Color(0xFFFFE8CC), // light orange
    aiHighlightSurfaceColor: Color(0xFFFFF4D6), // light yellow surface
    cosmicFilterActiveColor: Color(0xFFFF9500), // systemOrange light
    // Arc+Linear tier tokens — light
    surfaceTierFill: AppColors.lightSurfaceTierFill,
    cardTierFill: AppColors.lightCardTierFill,
    elevatedTierFill: AppColors.lightElevatedTierFill,
    surfaceTierBorder: AppColors.lightSurfaceTierBorder,
    cardTierBorder: AppColors.lightCardTierBorder,
    elevatedTierBorder: AppColors.lightElevatedTierBorder,
    podcastGradientColors: AppColors.podcastGradientColors,
  );

  /// Dark theme extension (const base)
  static const dark = AppThemeExtension(
    contentMaxWidth: 1240,
    sectionGap: 24,
    cardRadius: 12,
    panelRadius: 16,
    buttonRadius: 10,
    inputRadius: 8,
    navItemRadius: 10,
    controlRadius: 14,
    sheetRadius: 28,
    pillRadius: 999,
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
    // Legacy properties with fallback values
    aiPrimary: Color(0xFFA5B4FC),
    // AI accent tokens — dark (Apple system colors)
    aiBubbleUserColor: Color(0xFF3D2D00), // dark yellow
    aiBubbleAssistantColor: Color(0xFF3D0014), // dark pink
    aiChipColor: Color(0xFF3D1E00), // dark orange
    aiHighlightSurfaceColor: Color(0xFF3D2D00), // dark yellow surface
    cosmicFilterActiveColor: Color(0xFFFF9F0A), // systemOrange dark
    // Arc+Linear tier tokens — dark
    surfaceTierFill: AppColors.surfaceTierFill,
    cardTierFill: AppColors.cardTierFill,
    elevatedTierFill: AppColors.elevatedTierFill,
    surfaceTierBorder: AppColors.surfaceTierBorder,
    cardTierBorder: AppColors.cardTierBorder,
    elevatedTierBorder: AppColors.elevatedTierBorder,
    podcastGradientColors: AppColors.podcastGradientColors,
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
