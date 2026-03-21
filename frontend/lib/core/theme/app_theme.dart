import 'package:flutter/material.dart';

import 'arctic_theme.dart';
import 'responsive_helpers.dart';

/// AppTheme - Main theme accessor
/// AppTheme - 主主题访问器
///
/// This class wraps the ArcticTheme (Arctic Garden Design System)
/// 此类包装 ArcticTheme（北极花园设计系统）
class AppTheme {
  AppTheme._();

  // ============================================================
  // RESPONSIVE HELPERS (re-exported from ResponsiveHelpers)
  // 响应式助手（从 ResponsiveHelpers 重新导出）
  // ============================================================

  /// 响应式边距助手
  static EdgeInsetsGeometry getResponsivePadding(BuildContext context) =>
      ResponsiveHelpers.getResponsivePadding(context);

  /// 响应式水平边距助手
  static EdgeInsetsGeometry getResponsiveHorizontalPadding(BuildContext context) =>
      ResponsiveHelpers.getResponsiveHorizontalPadding(context);

  /// 响应式垂直边距助手
  static EdgeInsetsGeometry getResponsiveVerticalPadding(BuildContext context) =>
      ResponsiveHelpers.getResponsiveVerticalPadding(context);

  /// 获取响应式最大宽度
  static double getResponsiveMaxWidth(BuildContext context) =>
      ResponsiveHelpers.getResponsiveMaxWidth(context);

  // ============================================================
  // THEME ACCESSORS / 主题访问器
  // ============================================================

  /// Light theme / 亮色主题
  ///
  /// Returns the Arctic Garden light theme with Material 3 design
  /// 返回北极花园亮色主题，使用 Material 3 设计
  static ThemeData get lightTheme => ArcticTheme.lightTheme;

  /// Dark theme / 暗色主题
  ///
  /// Returns the Arctic Garden dark theme with Material 3 design
  /// 返回北极花园暗色主题，使用 Material 3 设计
  static ThemeData get darkTheme => ArcticTheme.darkTheme;
}
