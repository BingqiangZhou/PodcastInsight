import 'package:flutter/material.dart';

import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/constants/breakpoints.dart';

/// ResponsiveHelpers - Utility methods for responsive layouts
class ResponsiveHelpers {
  ResponsiveHelpers._();

  /// Responsive padding helper
  static EdgeInsetsGeometry getResponsivePadding(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    if (screenWidth < Breakpoints.medium) {
      return const EdgeInsets.all(AppSpacing.md); // mobile
    } else if (screenWidth < Breakpoints.mediumLarge) {
      return const EdgeInsets.all(AppSpacing.lg); // tablet
    } else {
      return const EdgeInsets.all(AppSpacing.xl); // desktop
    }
  }

  /// Responsive horizontal padding helper
  static EdgeInsetsGeometry getResponsiveHorizontalPadding(
    BuildContext context,
  ) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    if (screenWidth < Breakpoints.medium) {
      return const EdgeInsets.symmetric(horizontal: AppSpacing.md); // mobile
    } else if (screenWidth < Breakpoints.mediumLarge) {
      return const EdgeInsets.symmetric(horizontal: AppSpacing.lg); // tablet
    } else {
      return const EdgeInsets.symmetric(horizontal: AppSpacing.xl); // desktop
    }
  }

  /// Responsive vertical padding helper
  static EdgeInsetsGeometry getResponsiveVerticalPadding(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    if (screenWidth < Breakpoints.medium) {
      return const EdgeInsets.symmetric(vertical: AppSpacing.sm); // mobile
    } else if (screenWidth < Breakpoints.mediumLarge) {
      return const EdgeInsets.symmetric(vertical: AppSpacing.smMd); // tablet
    } else {
      return const EdgeInsets.symmetric(vertical: AppSpacing.md); // desktop
    }
  }

  /// Get responsive max width
  static double getResponsiveMaxWidth(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    if (screenWidth < Breakpoints.medium) {
      return screenWidth; // mobile full width
    } else if (screenWidth < Breakpoints.mediumLarge) {
      return Breakpoints.mediumLarge; // tablet limited width
    } else {
      return Breakpoints.large; // desktop limited width
    }
  }
}
