import 'package:flutter/material.dart';

import 'package:personal_ai_assistant/core/theme/app_colors.dart';

/// ============================================================
/// Arc+Linear Design System - 形状与圆角系统
///
/// Design Philosophy:
/// - Clean geometric radii aligned with Apple HIG
/// - Arc+Linear: consistent, intentional radius scale
/// ============================================================

/// Design tokens for border radius throughout the app.
///
/// Values are aligned with [AppThemeExtension] as the single source of truth.
/// Use the pre-built [BorderRadius] and [RoundedRectangleBorder] getters
/// for convenience, or access [AppThemeExtension] directly for theme-aware values.
class AppRadius {
  AppRadius._();

  // ============================================================
  // CORE RADIUS VALUES — aligned with AppThemeExtension
  // ============================================================

  static const double cardValue = 14;
  static const double buttonValue = 10;
  static const double itemValue = 8;

  // Incremental scale
  static const double xs = 6;
  static const double sm = 8;
  static const double md = 10;
  static const double mdLg = 12;
  static const double lg = 14;
  static const double lgXl = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double xxlCard = 22;
  static const double chip = 18;
  static const double pill = 999;

  // ============================================================
  // PRE-BUILT BORDER RADIUS INSTANCES - 预构建圆角实例
  // ============================================================

  static BorderRadius get xsRadius => BorderRadius.circular(xs);
  static BorderRadius get smRadius => BorderRadius.circular(sm);
  static BorderRadius get mdRadius => BorderRadius.circular(md);
  static BorderRadius get mdLgRadius => BorderRadius.circular(mdLg);
  static BorderRadius get lgRadius => BorderRadius.circular(lg);
  static BorderRadius get lgXlRadius => BorderRadius.circular(lgXl);
  static BorderRadius get xlRadius => BorderRadius.circular(xl);
  static BorderRadius get xxlRadius => BorderRadius.circular(xxl);
  static BorderRadius get xxlCardRadius => BorderRadius.circular(xxlCard);
  static BorderRadius get chipRadius => BorderRadius.circular(chip);
  static BorderRadius get card => BorderRadius.circular(cardValue);
  static BorderRadius get button => BorderRadius.circular(buttonValue);
  static BorderRadius get item => BorderRadius.circular(itemValue);
  static BorderRadius get pillRadius => BorderRadius.circular(pill);

  // ============================================================
  // ROUNDED RECTANGLE BORDER SHAPES - 预构建形状
  // ============================================================

  static RoundedRectangleBorder get xsShape =>
      RoundedRectangleBorder(borderRadius: xsRadius);
  static RoundedRectangleBorder get smShape =>
      RoundedRectangleBorder(borderRadius: smRadius);
  static RoundedRectangleBorder get mdShape =>
      RoundedRectangleBorder(borderRadius: mdRadius);
  static RoundedRectangleBorder get mdLgShape =>
      RoundedRectangleBorder(borderRadius: mdLgRadius);
  static RoundedRectangleBorder get lgShape =>
      RoundedRectangleBorder(borderRadius: lgRadius);
  static RoundedRectangleBorder get lgXlShape =>
      RoundedRectangleBorder(borderRadius: lgXlRadius);
  static RoundedRectangleBorder get xlShape =>
      RoundedRectangleBorder(borderRadius: xlRadius);
  static RoundedRectangleBorder get xxlShape =>
      RoundedRectangleBorder(borderRadius: xxlRadius);
  static RoundedRectangleBorder get cardShape =>
      RoundedRectangleBorder(borderRadius: card);
  static RoundedRectangleBorder get buttonShape =>
      RoundedRectangleBorder(borderRadius: button);
  static RoundedRectangleBorder get pillShape =>
      RoundedRectangleBorder(borderRadius: pillRadius);
}

/// Extension to easily access radius from BuildContext.
extension AppRadiusExtension on BuildContext {
  /// Get the card radius from the current theme.
  double get cardRadius {
    final extension =
        Theme.of(this).extension<AppThemeExtension>();
    return extension?.cardRadius ?? AppRadius.cardValue;
  }
}
