import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// ============================================================
/// Refined Minimal Design System - 简约现代设计系统
///
/// Design Philosophy:
/// "Less is more" - 功能性优先，精致的间距和微妙的阴影
/// ============================================================

class AppColors {
  AppColors._();

  // ============================================================
  // LIGHT THEME - 亮色主题
  // 温暖的近白底色 + 专业的蓝色强调
  // ============================================================

  // Background Colors - 背景色系
  static const Color lightBackground = Color(0xFFF0F0F5);
  static const Color lightSurface = Color(0xFFF5F5FA);
  static const Color lightSurfaceVariant = Color(0xFFF5F5F5);

  // Text Colors - 文字色系
  static const Color lightTextPrimary = Color(0xFF1A1A1A);
  static const Color lightTextSecondary = Color(0xFF5C5C5C);
  static const Color lightTextTertiary = Color(0xFF8C8C8C);

  // Outline Colors - 边框色系
  static const Color lightOutline = Color(0xFFE5E5E5);
  static const Color lightOutlineVariant = Color(0xFFD4D4D4);

  // ============================================================
  // DARK THEME - 暗色主题
  // 纯黑背景 + 明亮的蓝色强调
  // ============================================================

  // Background Colors - 背景色系 (neutral for Liquid Glass palette)
  static const Color darkBackground = Color(0xFF0A0A0F);
  static const Color darkSurface = Color(0xFF0F0F18);
  static const Color darkSurfaceVariant = Color(0xFF141420);

  // Text Colors - 文字色系
  static const Color darkTextPrimary = Color(0xFFFAFAFA);
  static const Color darkTextSecondary = Color(0xFFA3A3A3);
  static const Color darkTextTertiary = Color(0xFF737373);

  // Outline Colors - 边框色系
  static const Color darkOutline = Color(0xFF2A2A2A);
  static const Color darkOutlineVariant = Color(0xFF404040);

  // ============================================================
  // BRAND COLORS - 品牌色
  // ============================================================

  // Primary - Indigo-violet (Cosmic Editorial palette)
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryContainer = Color(0xFFEEF2FF);
  static const Color primaryContainerDark = Color(0xFF1E1B4B);

  // Warm accents - star/constellation highlights
  static const Color accentWarm = Color(0xFFF59E0B);
  static const Color accentWarmLight = Color(0xFFFBBF24);
  static const Color accentWarmDark = Color(0xFFD97706);
  static const Color accentCoral = Color(0xFFF472B6);
  static const Color accentCoralLight = Color(0xFFF9A8D4);

  // AI-specific accent tokens - warm amber for AI highlights
  static const Color aiBubbleUser = Color(0xFFFBBF24);       // Warm amber for user AI bubbles
  static const Color aiBubbleUserDark = Color(0xFFD97706);    // Dark mode user AI bubble
  static const Color aiBubbleAssistant = Color(0xFFF472B6);   // Coral for assistant AI bubbles
  static const Color aiBubbleAssistantDark = Color(0xFFEC4899); // Dark mode assistant AI bubble
  static const Color aiChipBackground = Color(0xFFFBBF24);    // Amber chip background (discover results)
  static const Color aiChipBackgroundDark = Color(0xFF92400E); // Dark mode amber chip
  static const Color aiHighlightSurface = Color(0xFFFFFBEB);  // Light amber surface for AI panels
  static const Color aiHighlightSurfaceDark = Color(0xFF451A03); // Dark amber surface for AI panels
  static const Color cosmicFilterActive = Color(0xFFF59E0B);  // Cosmic filter active state
  static const Color cosmicFilterActiveDark = Color(0xFFD97706);

  // Tertiary - 绿色 (用于成功状态)
  static const Color tertiary = Color(0xFF22C55E);
  static const Color tertiaryLight = Color(0xFF4ADE80);
  static const Color tertiaryDark = Color(0xFF16A34A);

  // ============================================================
  // SEMANTIC COLORS - 语义色彩
  // ============================================================

  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF6366F1);

  // ============================================================
  // LEGACY COLORS - 向后兼容
  // ============================================================

  static const Color riverAccent = Color(0xFF22D3EE);
  static const Color sunGlow = Color(0xFFFBBF24);
  static const Color sunRay = Color(0xFFEF4444);
  static const Color leaf = Color(0xFF22C55E);
  static const Color indigo = Color(0xFF6366F1);

  // Legacy gradients
  static const LinearGradient darkSubtleGradient = LinearGradient(
    colors: [Color(0xFF0A0A0F), Color(0xFF0F0F18)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient softBackgroundGradient = LinearGradient(
    colors: [Color(0xFFF0F0F5), Color(0xFFF5F3FF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ============================================================
  // DATA VISUALIZATION - 数据可视化色彩
  // ============================================================

  static const Color chart1 = Color(0xFF6366F1);
  static const Color chart2 = Color(0xFF818CF8);
  static const Color chart3 = Color(0xFF22C55E);
  static const Color chart4 = Color(0xFFF59E0B);
  static const Color chart5 = Color(0xFF8B5CF6);
  static const Color chart6 = Color(0xFFEC4899);
  static const Color chart7 = Color(0xFF06B6D4);
  static const Color chart8 = Color(0xFF10B981);

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
/// 简约现代主题扩展
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

  // AI accent tokens - warm amber & coral for AI-related elements
  final Color aiBubbleUserColor;
  final Color aiBubbleAssistantColor;
  final Color aiChipColor;
  final Color aiHighlightSurfaceColor;
  final Color cosmicFilterActiveColor;

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
      aiBubbleAssistantColor: aiBubbleAssistantColor ?? this.aiBubbleAssistantColor,
      aiChipColor: aiChipColor ?? this.aiChipColor,
      aiHighlightSurfaceColor: aiHighlightSurfaceColor ?? this.aiHighlightSurfaceColor,
      cosmicFilterActiveColor: cosmicFilterActiveColor ?? this.cosmicFilterActiveColor,
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
      aiBubbleUserColor: Color.lerp(aiBubbleUserColor, other.aiBubbleUserColor, t)!,
      aiBubbleAssistantColor: Color.lerp(aiBubbleAssistantColor, other.aiBubbleAssistantColor, t)!,
      aiChipColor: Color.lerp(aiChipColor, other.aiChipColor, t)!,
      aiHighlightSurfaceColor: Color.lerp(aiHighlightSurfaceColor, other.aiHighlightSurfaceColor, t)!,
      cosmicFilterActiveColor: Color.lerp(cosmicFilterActiveColor, other.cosmicFilterActiveColor, t)!,
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
    aiPrimary: Color(0xFF6366F1),
    // AI accent tokens — light
    aiBubbleUserColor: Color(0xFFE0E7FF),
    aiBubbleAssistantColor: Color(0xFFF5F3FF),
    aiChipColor: Color(0xFFEEF2FF),
    aiHighlightSurfaceColor: Color(0xFFFFFBEB),
    cosmicFilterActiveColor: Color(0xFFF59E0B),
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
    // AI accent tokens — dark
    aiBubbleUserColor: Color(0xFF1E1B4B),
    aiBubbleAssistantColor: Color(0xFF1E1B35),
    aiChipColor: Color(0xFF312E81),
    aiHighlightSurfaceColor: Color(0xFF2D2006),
    cosmicFilterActiveColor: Color(0xFFF59E0B),
  );

  /// Light theme with gradient (non-const, for runtime use)
  static AppThemeExtension get lightWithGradient => light.copyWith(
    shellGradient: const LinearGradient(
      colors: [Color(0xFFFAFAFA), Color(0xFFF5F3FF)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  );

  /// Dark theme with gradient (non-const, for runtime use)
  static AppThemeExtension get darkWithGradient => dark.copyWith(
    shellGradient: const LinearGradient(
      colors: [Color(0xFF0A0A0F), Color(0xFF0F0F18)],
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
