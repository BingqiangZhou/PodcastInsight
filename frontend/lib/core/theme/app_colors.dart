import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ============================================================
  // Brand Colors - 品牌色（极简风格，更深的蓝）
  // ============================================================
  static const Color primary = Color(0xFF4DA8FF);
  static const Color primaryDark = Color(0xFF2B8FD9);
  static const Color brandDeep = Color(0xFF0F172A); // 深墨蓝，用于强调
  static const Color riverAccent = Color(0xFF86F0FF);
  static const Color aqua = Color(0xFF8EE6FF);
  static const Color indigo = Color(0xFF7A8DFF);

  static const Color sunGlow = Color(0xFFFFD8A8);
  static const Color sunRay = Color(0xFFFF8A6B);
  static const Color leaf = Color(0xFF6EE7B7);
  static const Color mint = Color(0xFFB6F5D8);

  // ============================================================
  // Light Theme - 亮色主题（更浅的背景，增加留白感）
  // ============================================================
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF1F5F9);
  static const Color lightOutline = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextTertiary = Color(0xFF94A3B8);

  // ============================================================
  // Dark Theme - 暗色主题
  // ============================================================
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkSurfaceVariant = Color(0xFF334155);
  static const Color darkOutline = Color(0xFF475569);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFFCBD5E1);
  static const Color darkTextTertiary = Color(0xFF94A3B8);

  static const Color error = Color(0xFFFF6B72);
  static const Color success = Color(0xFF59D49A);
  static const Color warning = Color(0xFFFFB84D);
  static const Color info = primary;

  // ============================================================
  // Semantic Colors - 功能语义色彩（极简风格，更克制）
  // ============================================================

  // AI & Intelligence - AI功能专属色（靛蓝紫，更克制）
  static const Color aiPrimary = Color(0xFF6366F1);
  static const Color aiSecondary = Color(0xFF818CF8);
  static const Color aiGlow = Color(0x336366F1);
  static const Color aiGradientStart = Color(0xFF818CF8);
  static const Color aiGradientEnd = Color(0xFF6366F1);

  // Achievement & Rewards - 成就/奖励色
  static const Color achievement = Color(0xFFFFB020);
  static const Color achievementGold = Color(0xFFFFD700);
  static const Color achievementBronze = Color(0xFFCD7F32);
  static const Color achievementSilver = Color(0xFFC0C0C0);

  // Notifications - 通知色
  static const Color notification = Color(0xFFFF6B6B);
  static const Color notificationSoft = Color(0xFFFFE5E5);

  // ============================================================
  // Data Visualization - 数据可视化色彩
  // ============================================================

  static const Color chart1 = Color(0xFF5CB8FF); // Primary blue
  static const Color chart2 = Color(0xFF8B7CF6); // AI purple
  static const Color chart3 = Color(0xFF59D49A); // Success green
  static const Color chart4 = Color(0xFFFFB84D); // Warning amber
  static const Color chart5 = Color(0xFFFF8A6B); // Sun ray coral
  static const Color chart6 = Color(0xFF7A8DFF); // Indigo
  static const Color chart7 = Color(0xFF6EE7B7); // Leaf green
  static const Color chart8 = Color(0xFFFFD8A8); // Sun glow

  // Chart color list for easy access
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
  // Gradients - 渐变（极简风格，更简洁）
  // ============================================================

  static const LinearGradient mindriverGradient = LinearGradient(
    colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient softBackgroundGradient = LinearGradient(
    colors: [Color(0xFFFAFBFC), Color(0xFFF4F6F8)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient riverGradient = LinearGradient(
    colors: [Color(0xFF4DA8FF), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient sunsetGradient = LinearGradient(
    colors: [Color(0xFFFFD6A5), Color(0xFFFF9A76)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient natureGradient = LinearGradient(
    colors: [Color(0xFFC8F7E4), Color(0xFF6EE7B7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkSubtleGradient = LinearGradient(
    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient darkBrandGradient = LinearGradient(
    colors: [Color(0xFF1E293B), Color(0xFF334155)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

@immutable
class MindriverThemeExtension extends ThemeExtension<MindriverThemeExtension> {
  const MindriverThemeExtension({
    required this.brandGradient,
    required this.riverGradient,
    required this.heroGradient,
    required this.shellGradient,
    required this.glassSurface,
    required this.glassSurfaceStrong,
    required this.glassBorder,
    required this.glassHighlight,
    required this.glassShadow,
    required this.heroGlow,
    required this.sunGlow,
    required this.sunRay,
    required this.leaf,
    required this.mint,
    required this.aiPrimary,
    required this.aiSecondary,
    required this.achievement,
    required this.achievementGold,
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

  final Gradient brandGradient;
  final Gradient riverGradient;
  final Gradient heroGradient;
  final Gradient shellGradient;
  final Color glassSurface;
  final Color glassSurfaceStrong;
  final Color glassBorder;
  final Color glassHighlight;
  final Color glassShadow;
  final Color heroGlow;
  final Color sunGlow;
  final Color sunRay;
  final Color leaf;
  final Color mint;

  // Semantic colors
  final Color aiPrimary;
  final Color aiSecondary;
  final Color achievement;
  final Color achievementGold;

  // Data visualization colors
  final Color chart1;
  final Color chart2;
  final Color chart3;
  final Color chart4;
  final List<Color> chartColors;

  final double contentMaxWidth;
  final double sectionGap;
  final double cardRadius;
  final double panelRadius;
  final double navBackdropOpacity;

  @override
  MindriverThemeExtension copyWith({
    Gradient? brandGradient,
    Gradient? riverGradient,
    Gradient? heroGradient,
    Gradient? shellGradient,
    Color? glassSurface,
    Color? glassSurfaceStrong,
    Color? glassBorder,
    Color? glassHighlight,
    Color? glassShadow,
    Color? heroGlow,
    Color? sunGlow,
    Color? sunRay,
    Color? leaf,
    Color? mint,
    Color? aiPrimary,
    Color? aiSecondary,
    Color? achievement,
    Color? achievementGold,
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
      brandGradient: brandGradient ?? this.brandGradient,
      riverGradient: riverGradient ?? this.riverGradient,
      heroGradient: heroGradient ?? this.heroGradient,
      shellGradient: shellGradient ?? this.shellGradient,
      glassSurface: glassSurface ?? this.glassSurface,
      glassSurfaceStrong: glassSurfaceStrong ?? this.glassSurfaceStrong,
      glassBorder: glassBorder ?? this.glassBorder,
      glassHighlight: glassHighlight ?? this.glassHighlight,
      glassShadow: glassShadow ?? this.glassShadow,
      heroGlow: heroGlow ?? this.heroGlow,
      sunGlow: sunGlow ?? this.sunGlow,
      sunRay: sunRay ?? this.sunRay,
      leaf: leaf ?? this.leaf,
      mint: mint ?? this.mint,
      aiPrimary: aiPrimary ?? this.aiPrimary,
      aiSecondary: aiSecondary ?? this.aiSecondary,
      achievement: achievement ?? this.achievement,
      achievementGold: achievementGold ?? this.achievementGold,
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
      brandGradient: Gradient.lerp(brandGradient, other.brandGradient, t)!,
      riverGradient: Gradient.lerp(riverGradient, other.riverGradient, t)!,
      heroGradient: Gradient.lerp(heroGradient, other.heroGradient, t)!,
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
      heroGlow: Color.lerp(heroGlow, other.heroGlow, t)!,
      sunGlow: Color.lerp(sunGlow, other.sunGlow, t)!,
      sunRay: Color.lerp(sunRay, other.sunRay, t)!,
      leaf: Color.lerp(leaf, other.leaf, t)!,
      mint: Color.lerp(mint, other.mint, t)!,
      aiPrimary: Color.lerp(aiPrimary, other.aiPrimary, t)!,
      aiSecondary: Color.lerp(aiSecondary, other.aiSecondary, t)!,
      achievement: Color.lerp(achievement, other.achievement, t)!,
      achievementGold: Color.lerp(achievementGold, other.achievementGold, t)!,
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

  static const light = MindriverThemeExtension(
    brandGradient: AppColors.mindriverGradient,
    riverGradient: AppColors.riverGradient,
    heroGradient: LinearGradient(
      colors: [Color(0xFFFAFBFC), Color(0xFFF1F5F9)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    shellGradient: AppColors.softBackgroundGradient,
    glassSurface: Color(0xCCFFFFFF),
    glassSurfaceStrong: Color(0xE6FFFFFF),
    glassBorder: Color(0x40E2E8F0), // 更含蓄的边框
    glassHighlight: Color(0xFFFFFFFF),
    glassShadow: Color(0x080F172A), // 更柔和的阴影
    heroGlow: Color(0x334DA8FF), // 更克制的光晕
    sunGlow: AppColors.sunGlow,
    sunRay: AppColors.sunRay,
    leaf: AppColors.leaf,
    mint: AppColors.mint,
    aiPrimary: AppColors.aiPrimary,
    aiSecondary: AppColors.aiSecondary,
    achievement: AppColors.achievement,
    achievementGold: AppColors.achievementGold,
    chart1: AppColors.chart1,
    chart2: AppColors.chart2,
    chart3: AppColors.chart3,
    chart4: AppColors.chart4,
    chartColors: AppColors.chartColors,
    contentMaxWidth: 1240,
    sectionGap: 24, // 增加留白
    cardRadius: 24,
    panelRadius: 28,
    navBackdropOpacity: 0.74,
  );

  static const dark = MindriverThemeExtension(
    brandGradient: AppColors.darkBrandGradient,
    riverGradient: AppColors.riverGradient,
    heroGradient: LinearGradient(
      colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    shellGradient: AppColors.darkSubtleGradient,
    glassSurface: Color(0xAA1E293B),
    glassSurfaceStrong: Color(0xCC1E293B),
    glassBorder: Color(0x33475569), // 更含蓄的边框
    glassHighlight: Color(0x1AFFFFFF),
    glassShadow: Color(0x40000000),
    heroGlow: Color(0x224DA8FF), // 更克制的光晕
    sunGlow: AppColors.sunGlow,
    sunRay: AppColors.sunRay,
    leaf: AppColors.leaf,
    mint: AppColors.mint,
    aiPrimary: AppColors.aiPrimary,
    aiSecondary: AppColors.aiSecondary,
    achievement: AppColors.achievement,
    achievementGold: AppColors.achievementGold,
    chart1: AppColors.chart1,
    chart2: AppColors.chart2,
    chart3: AppColors.chart3,
    chart4: AppColors.chart4,
    chartColors: AppColors.chartColors,
    contentMaxWidth: 1240,
    sectionGap: 24, // 增加留白
    cardRadius: 24,
    panelRadius: 28,
    navBackdropOpacity: 0.68,
  );
}
