import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// ============================================================
/// Arctic Garden Design System - 北极花园设计系统
///
/// Design Philosophy:
/// "在冰冷的极地中，生命依然绽放"
///
/// 有机自然的柔和形态 + 冷峻科技的色彩
/// ============================================================

class AppColors {
  AppColors._();

  // ============================================================
  // LIGHT THEME - 亮色主题
  // 温暖的冰雪白底色 + 冷峻的科技强调色
  // ============================================================

  // Background Colors - 背景色系（温暖底色）
  static const Color lightBackground = Color(0xFFF8FAFC); // 冰雪白
  static const Color lightSurface = Color(0xFFFFFFFF); // 纯白
  static const Color lightSurfaceVariant = Color(0xFFF1F5F9); // 云灰

  // Text Colors - 文字色系
  static const Color lightTextPrimary = Color(0xFF0F172A); // 深夜蓝
  static const Color lightTextSecondary = Color(0xFF475569); // 石墨灰
  static const Color lightTextTertiary = Color(0xFF94A3B8); // 雾灰

  // Outline Colors - 边框色系
  static const Color lightOutline = Color(0xFFE2E8F0); // 冰晶边框
  static const Color lightOutlineVariant = Color(0xFFCBD5E1); // 雾蓝边框

  // ============================================================
  // DARK THEME - 暗色主题
  // 深邃的蓝黑背景 + 明亮的科技强调色
  // ============================================================

  // Background Colors - 背景色系（深邃蓝黑）
  static const Color darkBackground = Color(0xFF0A0F1C); // 深海蓝黑
  static const Color darkSurface = Color(0xFF111827); // 深夜蓝
  static const Color darkSurfaceVariant = Color(0xFF1E293B); // 深岩蓝

  // Text Colors - 文字色系
  static const Color darkTextPrimary = Color(0xFFF1F5F9); // 冰雪白
  static const Color darkTextSecondary = Color(0xFFCBD5E1); // 冰晶灰
  static const Color darkTextTertiary = Color(0xFF64748B); // 雾蓝

  // Outline Colors - 边框色系
  static const Color darkOutline = Color(0xFF334155); // 深岩边框
  static const Color darkOutlineVariant = Color(0xFF475569); // 石墨边框

  // ============================================================
  // BRAND COLORS - 品牌色（冷峻科技）
  // ============================================================

  // Primary - 天空蓝系
  static const Color primary = Color(0xFF0EA5E9); // 天空蓝
  static const Color primaryDark = Color(0xFF0284C7); // 深天蓝
  static const Color primaryLight = Color(0xFF38BDF8); // 电光蓝

  // Secondary - 青色系
  static const Color secondary = Color(0xFF06B6D4); // 青色
  static const Color secondaryLight = Color(0xFF22D3EE); // 亮青色

  // Accent - 极光绿
  static const Color accent = Color(0xFF10B981); // 极光绿
  static const Color accentLight = Color(0xFF34D399); // 亮极光绿

  // Warm - 琥珀金（用于重要操作，温暖点缀）
  static const Color warm = Color(0xFFF59E0B); // 琥珀金
  static const Color warmLight = Color(0xFFFBBF24); // 亮琥珀金

  // Legacy colors for backwards compatibility
  static const Color riverAccent = Color(0xFF22D3EE); // 亮青色（河流蓝）
  static const Color sunGlow = Color(0xFFFBBF24); // 亮琥珀金（日光）
  static const Color sunRay = Color(0xFFEF4444); // 珊瑚红（阳光射线）
  static const Color leaf = Color(0xFF10B981); // 极光绿（叶子）
  static const Color indigo = Color(0xFF6366F1); // 靛蓝紫

  // ============================================================
  // SEMANTIC COLORS - 语义色彩
  // ============================================================

  // Status Colors
  static const Color success = Color(0xFF10B981); // 极光绿
  static const Color warning = Color(0xFFF59E0B); // 琥珀金
  static const Color error = Color(0xFFEF4444); // 珊瑚红
  static const Color info = Color(0xFF0EA5E9); // 天空蓝

  // AI & Intelligence - AI 功能专属色（极光紫）
  static const Color aiPrimary = Color(0xFF8B5CF6); // 极光紫
  static const Color aiSecondary = Color(0xFFA78BFA); // 亮极光紫
  static const Color aiGlow = Color(0x338B5CF6); // AI 光晕
  static const Color aiGradientStart = Color(0xFFA78BFA);
  static const Color aiGradientEnd = Color(0xFF7C3AED);

  // ============================================================
  // DATA VISUALIZATION - 数据可视化色彩
  // ============================================================

  static const Color chart1 = Color(0xFF0EA5E9); // 天空蓝
  static const Color chart2 = Color(0xFF06B6D4); // 青色
  static const Color chart3 = Color(0xFF10B981); // 极光绿
  static const Color chart4 = Color(0xFFF59E0B); // 琥珀金
  static const Color chart5 = Color(0xFF8B5CF6); // 极光紫
  static const Color chart6 = Color(0xFFEC4899); // 粉红
  static const Color chart7 = Color(0xFF38BDF8); // 电光蓝
  static const Color chart8 = Color(0xFF34D399); // 亮极光绿

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

  // ============================================================
  // GRADIENTS - 渐变系统（极光效果）
  // ============================================================

  /// 极光渐变 - 用于头部、特殊区域
  static const LinearGradient auroraGradient = LinearGradient(
    colors: [Color(0xFF0EA5E9), Color(0xFF06B6D4), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 深海渐变 - 用于暗色背景
  static const LinearGradient deepSeaGradient = LinearGradient(
    colors: [Color(0xFF0A0F1C), Color(0xFF111827)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// 冰雪渐变 - 用于亮色背景
  static const LinearGradient iceGradient = LinearGradient(
    colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// AI 渐变 - 用于 AI 功能区域
  static const LinearGradient aiGradient = LinearGradient(
    colors: [Color(0xFFA78BFA), Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Legacy gradients for backwards compatibility
  static const LinearGradient mindriverGradient = iceGradient;
  static const LinearGradient softBackgroundGradient = iceGradient;
  static const LinearGradient riverGradient = auroraGradient;
  static const LinearGradient sunsetGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient natureGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient darkSubtleGradient = deepSeaGradient;
  static const LinearGradient darkBrandGradient = deepSeaGradient;
}

/// ============================================================
/// ARCTIC GARDEN THEME EXTENSION
/// 北极花园主题扩展
/// ============================================================

@immutable
class MindriverThemeExtension extends ThemeExtension<MindriverThemeExtension> {
  const MindriverThemeExtension({
    required this.auroraGradient,
    required this.deepSeaGradient,
    required this.iceGradient,
    required this.shellGradient,
    required this.glassSurface,
    required this.glassSurfaceStrong,
    required this.glassBorder,
    required this.glassHighlight,
    required this.glassShadow,
    required this.auroraGlow,
    required this.warmGlow,
    required this.aiPrimary,
    required this.aiSecondary,
    required this.warm,
    required this.chart1,
    required this.chart2,
    required this.chart3,
    required this.chart4,
    required this.chartColors,
    required this.contentMaxWidth,
    required this.sectionGap,
    required this.cardRadius,
    required this.panelRadius,
    required this.navBackdropOpacity,
  });

  // Gradients
  final Gradient auroraGradient;
  final Gradient deepSeaGradient;
  final Gradient iceGradient;
  final Gradient shellGradient;

  // Glass Effects
  final Color glassSurface;
  final Color glassSurfaceStrong;
  final Color glassBorder;
  final Color glassHighlight;
  final Color glassShadow;

  // Glow Effects
  final Color auroraGlow;
  final Color warmGlow;

  // Semantic Colors
  final Color aiPrimary;
  final Color aiSecondary;
  final Color warm;

  // Data Visualization
  final Color chart1;
  final Color chart2;
  final Color chart3;
  final Color chart4;
  final List<Color> chartColors;

  // Layout
  final double contentMaxWidth;
  final double sectionGap;
  final double cardRadius;
  final double panelRadius;
  final double navBackdropOpacity;

  @override
  MindriverThemeExtension copyWith({
    Gradient? auroraGradient,
    Gradient? deepSeaGradient,
    Gradient? iceGradient,
    Gradient? shellGradient,
    Color? glassSurface,
    Color? glassSurfaceStrong,
    Color? glassBorder,
    Color? glassHighlight,
    Color? glassShadow,
    Color? auroraGlow,
    Color? warmGlow,
    Color? aiPrimary,
    Color? aiSecondary,
    Color? warm,
    Color? chart1,
    Color? chart2,
    Color? chart3,
    Color? chart4,
    List<Color>? chartColors,
    double? contentMaxWidth,
    double? sectionGap,
    double? cardRadius,
    double? panelRadius,
    double? navBackdropOpacity,
  }) {
    return MindriverThemeExtension(
      auroraGradient: auroraGradient ?? this.auroraGradient,
      deepSeaGradient: deepSeaGradient ?? this.deepSeaGradient,
      iceGradient: iceGradient ?? this.iceGradient,
      shellGradient: shellGradient ?? this.shellGradient,
      glassSurface: glassSurface ?? this.glassSurface,
      glassSurfaceStrong: glassSurfaceStrong ?? this.glassSurfaceStrong,
      glassBorder: glassBorder ?? this.glassBorder,
      glassHighlight: glassHighlight ?? this.glassHighlight,
      glassShadow: glassShadow ?? this.glassShadow,
      auroraGlow: auroraGlow ?? this.auroraGlow,
      warmGlow: warmGlow ?? this.warmGlow,
      aiPrimary: aiPrimary ?? this.aiPrimary,
      aiSecondary: aiSecondary ?? this.aiSecondary,
      warm: warm ?? this.warm,
      chart1: chart1 ?? this.chart1,
      chart2: chart2 ?? this.chart2,
      chart3: chart3 ?? this.chart3,
      chart4: chart4 ?? this.chart4,
      chartColors: chartColors ?? this.chartColors,
      contentMaxWidth: contentMaxWidth ?? this.contentMaxWidth,
      sectionGap: sectionGap ?? this.sectionGap,
      cardRadius: cardRadius ?? this.cardRadius,
      panelRadius: panelRadius ?? this.panelRadius,
      navBackdropOpacity: navBackdropOpacity ?? this.navBackdropOpacity,
    );
  }

  @override
  MindriverThemeExtension lerp(
    ThemeExtension<MindriverThemeExtension>? other,
    double t,
  ) {
    if (other is! MindriverThemeExtension) {
      return this;
    }

    return MindriverThemeExtension(
      auroraGradient: Gradient.lerp(auroraGradient, other.auroraGradient, t)!,
      deepSeaGradient: Gradient.lerp(deepSeaGradient, other.deepSeaGradient, t)!,
      iceGradient: Gradient.lerp(iceGradient, other.iceGradient, t)!,
      shellGradient: Gradient.lerp(shellGradient, other.shellGradient, t)!,
      glassSurface: Color.lerp(glassSurface, other.glassSurface, t)!,
      glassSurfaceStrong: Color.lerp(
        glassSurfaceStrong,
        other.glassSurfaceStrong,
        t,
      )!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      glassHighlight: Color.lerp(glassHighlight, other.glassHighlight, t)!,
      glassShadow: Color.lerp(glassShadow, other.glassShadow, t)!,
      auroraGlow: Color.lerp(auroraGlow, other.auroraGlow, t)!,
      warmGlow: Color.lerp(warmGlow, other.warmGlow, t)!,
      aiPrimary: Color.lerp(aiPrimary, other.aiPrimary, t)!,
      aiSecondary: Color.lerp(aiSecondary, other.aiSecondary, t)!,
      warm: Color.lerp(warm, other.warm, t)!,
      chart1: Color.lerp(chart1, other.chart1, t)!,
      chart2: Color.lerp(chart2, other.chart2, t)!,
      chart3: Color.lerp(chart3, other.chart3, t)!,
      chart4: Color.lerp(chart4, other.chart4, t)!,
      chartColors: other.chartColors,
      contentMaxWidth: lerpDouble(contentMaxWidth, other.contentMaxWidth, t)!,
      sectionGap: lerpDouble(sectionGap, other.sectionGap, t)!,
      cardRadius: lerpDouble(cardRadius, other.cardRadius, t)!,
      panelRadius: lerpDouble(panelRadius, other.panelRadius, t)!,
      navBackdropOpacity: lerpDouble(
        navBackdropOpacity,
        other.navBackdropOpacity,
        t,
      )!,
    );
  }

  /// Light theme extension - 冰雪主题
  static const light = MindriverThemeExtension(
    auroraGradient: AppColors.auroraGradient,
    deepSeaGradient: AppColors.iceGradient,
    iceGradient: AppColors.iceGradient,
    shellGradient: AppColors.iceGradient,
    glassSurface: Color(0xE6FFFFFF),
    glassSurfaceStrong: Color(0xF2FFFFFF),
    glassBorder: Color(0x1A94A3B8), // 更精致: 0x33 → 0x1A
    glassHighlight: Color(0x14FFFFFF),
    glassShadow: Color(0x080F172A), // 更含蓄: 0x0A → 0x08
    auroraGlow: Color(0x140EA5E9), // 更含蓄: 0x22 → 0x14
    warmGlow: Color(0x14F59E0B), // 更含蓄: 0x22 → 0x14
    aiPrimary: AppColors.aiPrimary,
    aiSecondary: AppColors.aiSecondary,
    warm: AppColors.warm,
    chart1: AppColors.chart1,
    chart2: AppColors.chart2,
    chart3: AppColors.chart3,
    chart4: AppColors.chart4,
    chartColors: AppColors.chartColors,
    contentMaxWidth: 1240,
    sectionGap: 24,
    cardRadius: 20, // 更精致: 24 → 20
    panelRadius: 28, // 更精致: 32 → 28
    navBackdropOpacity: 0.72,
  );

  /// Dark theme extension - 深海主题
  static const dark = MindriverThemeExtension(
    auroraGradient: AppColors.auroraGradient,
    deepSeaGradient: AppColors.deepSeaGradient,
    iceGradient: AppColors.deepSeaGradient,
    shellGradient: AppColors.deepSeaGradient,
    glassSurface: Color(0xE61E293B),
    glassSurfaceStrong: Color(0xF21E293B),
    glassBorder: Color(0x1A475569), // 更精致: 0x33 → 0x1A
    glassHighlight: Color(0x0DFFFFFF),
    glassShadow: Color(0x38000000), // 更含蓄: 0x40 → 0x38
    auroraGlow: Color(0x1438BDF8), // 更含蓄: 0x22 → 0x14
    warmGlow: Color(0x14FBBF24), // 更含蓄: 0x22 → 0x14
    aiPrimary: AppColors.aiPrimary,
    aiSecondary: AppColors.aiSecondary,
    warm: AppColors.warmLight,
    chart1: AppColors.chart7,
    chart2: AppColors.chart2,
    chart3: AppColors.chart8,
    chart4: AppColors.chart8,
    chartColors: AppColors.chartColors,
    contentMaxWidth: 1240,
    sectionGap: 24,
    cardRadius: 20, // 更精致: 24 → 20
    panelRadius: 28, // 更精致: 32 → 28
    navBackdropOpacity: 0.68,
  );
}
