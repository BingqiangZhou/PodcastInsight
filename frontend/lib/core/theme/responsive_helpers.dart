import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import '../constants/breakpoints.dart';

/// ResponsiveHelpers - Utility methods for responsive layouts
/// ResponsiveHelpers - 响应式布局工具方法
class ResponsiveHelpers {
  ResponsiveHelpers._();

  /// 响应式边距助手
  static EdgeInsetsGeometry getResponsivePadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth < AppBreakpoints.medium) {
      return const EdgeInsets.all(AppSpacing.lg); // 移动端
    } else if (screenWidth < AppBreakpoints.mediumLarge) {
      return const EdgeInsets.all(AppSpacing.xl); // 平板端
    } else {
      return const EdgeInsets.all(AppSpacing.xxl); // 桌面端
    }
  }

  /// 响应式水平边距助手
  static EdgeInsetsGeometry getResponsiveHorizontalPadding(
    BuildContext context,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth < AppBreakpoints.medium) {
      return const EdgeInsets.symmetric(horizontal: AppSpacing.lg); // 移动端
    } else if (screenWidth < AppBreakpoints.mediumLarge) {
      return const EdgeInsets.symmetric(horizontal: AppSpacing.xl); // 平板端
    } else {
      return const EdgeInsets.symmetric(horizontal: AppSpacing.xxl); // 桌面端
    }
  }

  /// 响应式垂直边距助手
  static EdgeInsetsGeometry getResponsiveVerticalPadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth < AppBreakpoints.medium) {
      return const EdgeInsets.symmetric(vertical: AppSpacing.sm); // 移动端
    } else if (screenWidth < AppBreakpoints.mediumLarge) {
      return const EdgeInsets.symmetric(vertical: AppSpacing.md); // 平板端
    } else {
      return const EdgeInsets.symmetric(vertical: AppSpacing.lg); // 桌面端
    }
  }

  /// 获取响应式最大宽度
  static double getResponsiveMaxWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth < AppBreakpoints.medium) {
      return screenWidth; // 移动端全宽
    } else if (screenWidth < AppBreakpoints.mediumLarge) {
      return AppBreakpoints.mediumLarge; // 平板端限制宽度
    } else {
      return AppBreakpoints.large; // 桌面端限制宽度
    }
  }
}
