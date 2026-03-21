import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// ============================================================
/// Arctic Garden Design System - 形状与圆角系统
///
/// Design Philosophy:
/// - 有机形态：使用更大的圆角，避免尖锐的边角
/// - 柔和曲线：所有形状都应该感觉自然、流畅
/// ============================================================

/// Design tokens for border radius throughout the app.
///
/// These values align with [MindriverThemeExtension] and should be used
/// consistently instead of hardcoded values.
class AppRadius {
  AppRadius._();

  // ============================================================
  // CORE RADIUS VALUES - 核心圆角值（有机形态）
  // ============================================================

  // Primary shapes from MindriverThemeExtension
  static const double cardValue = 20.0; // 卡片圆角（更精致）
  static const double panelValue = 28.0; // 面板圆角（更精致）
  static const double buttonValue = 18.0; // 按钮圆角（更精致）

  // Additional common radius values - 精致递增
  static const double xs = 6.0; // 小元素
  static const double sm = 10.0; // 小组件（更精致）
  static const double md = 14.0; // 中等组件（更精致）
  static const double lg = 18.0; // 大组件（更精致）
  static const double xl = 24.0; // 超大组件（更精致）
  static const double xxl = 32.0; // 巨大组件（更精致）
  static const double pill = 999.0; // 胶囊形状

  // ============================================================
  // PRE-BUILT BORDER RADIUS INSTANCES - 预构建圆角实例
  // ============================================================

  static BorderRadius get xsRadius => BorderRadius.circular(xs);
  static BorderRadius get smRadius => BorderRadius.circular(sm);
  static BorderRadius get mdRadius => BorderRadius.circular(md);
  static BorderRadius get lgRadius => BorderRadius.circular(lg);
  static BorderRadius get xlRadius => BorderRadius.circular(xl);
  static BorderRadius get xxlRadius => BorderRadius.circular(xxl);
  static BorderRadius get card => BorderRadius.circular(cardValue);
  static BorderRadius get panel => BorderRadius.circular(panelValue);
  static BorderRadius get button => BorderRadius.circular(buttonValue);
  static BorderRadius get pillRadius => BorderRadius.circular(pill);

  // ============================================================
  // ORGANIC SHAPES - 有机形状（不对称圆角）
  // ============================================================

  /// 有机卡片形状 - 左上角稍大，更有动感
  static BorderRadius get organicCard => const BorderRadius.only(
    topLeft: Radius.circular(24),
    topRight: Radius.circular(20),
    bottomLeft: Radius.circular(20),
    bottomRight: Radius.circular(16),
  );

  /// 有机按钮形状 - 更圆润
  static BorderRadius get organicButton => BorderRadius.horizontal(
    left: const Radius.circular(20),
    right: const Radius.circular(14),
  );

  // ============================================================
  // ROUNDED RECTANGLE BORDER SHAPES - 预构建形状
  // ============================================================

  static RoundedRectangleBorder get xsShape =>
      RoundedRectangleBorder(borderRadius: xsRadius);
  static RoundedRectangleBorder get smShape =>
      RoundedRectangleBorder(borderRadius: smRadius);
  static RoundedRectangleBorder get mdShape =>
      RoundedRectangleBorder(borderRadius: mdRadius);
  static RoundedRectangleBorder get lgShape =>
      RoundedRectangleBorder(borderRadius: lgRadius);
  static RoundedRectangleBorder get xlShape =>
      RoundedRectangleBorder(borderRadius: xlRadius);
  static RoundedRectangleBorder get xxlShape =>
      RoundedRectangleBorder(borderRadius: xxlRadius);
  static RoundedRectangleBorder get cardShape =>
      RoundedRectangleBorder(borderRadius: card);
  static RoundedRectangleBorder get panelShape =>
      RoundedRectangleBorder(borderRadius: panel);
  static RoundedRectangleBorder get buttonShape =>
      RoundedRectangleBorder(borderRadius: button);
  static RoundedRectangleBorder get pillShape =>
      RoundedRectangleBorder(borderRadius: pillRadius);
  static RoundedRectangleBorder get organicCardShape =>
      RoundedRectangleBorder(borderRadius: organicCard);
}

/// Extension to easily access radius from BuildContext.
extension AppRadiusExtension on BuildContext {
  /// Get the card radius from the current theme.
  double get cardRadius {
    final extension =
        Theme.of(this).extension<MindriverThemeExtension>();
    return extension?.cardRadius ?? AppRadius.cardValue;
  }

  /// Get the panel radius from the current theme.
  double get panelRadius {
    final extension =
        Theme.of(this).extension<MindriverThemeExtension>();
    return extension?.panelRadius ?? AppRadius.panelValue;
  }
}
