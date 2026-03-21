import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Utility class for accessibility-related calculations and helpers.
///
/// Provides tools for ensuring WCAG compliance and improving
/// the overall accessibility of the application.
class AccessibilityUtils {
  AccessibilityUtils._();

  /// Minimum contrast ratio for normal text (WCAG AA).
  static const double minContrastRatioNormal = 4.5;

  /// Minimum contrast ratio for large text (WCAG AA).
  static const double minContrastRatioLarge = 3.0;

  /// Minimum contrast ratio for enhanced contrast (WCAG AAA).
  static const double minContrastRatioEnhanced = 7.0;

  /// Calculate the relative luminance of a color.
  ///
  /// Based on WCAG 2.0 definition:
  /// https://www.w3.org/TR/WCAG20/#relativeluminancedef
  static double calculateLuminance(Color color) {
    final r = _linearize(color.r);
    final g = _linearize(color.g);
    final b = _linearize(color.b);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// Linearize a color component value.
  static double _linearize(double value) {
    final normalized = value / 255.0;
    if (normalized <= 0.03928) {
      return normalized / 12.92;
    }
    return math.pow((normalized + 0.055) / 1.055, 2.4).toDouble();
  }

  /// Calculate the contrast ratio between two colors.
  ///
  /// Returns a value between 1 and 21.
  /// - 1: No contrast (same color)
  /// - 21: Maximum contrast (black on white)
  static double calculateContrastRatio(Color foreground, Color background) {
    final l1 = calculateLuminance(foreground);
    final l2 = calculateLuminance(background);

    final lighter = math.max(l1, l2);
    final darker = math.min(l1, l2);

    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Check if the contrast ratio meets WCAG AA standards.
  ///
  /// [isLargeText] should be true for text >= 18pt or >= 14pt bold.
  static bool meetsContrastStandard(
    Color foreground,
    Color background, {
    bool isLargeText = false,
  }) {
    final ratio = calculateContrastRatio(foreground, background);
    final minRatio = isLargeText ? minContrastRatioLarge : minContrastRatioNormal;
    return ratio >= minRatio;
  }

  /// Find a color that meets the minimum contrast ratio.
  ///
  /// If the foreground color doesn't meet the standard, it will be
  /// adjusted (lightened or darkened) until it does.
  static Color ensureContrast(
    Color foreground,
    Color background, {
    double minRatio = minContrastRatioNormal,
  }) {
    final currentRatio = calculateContrastRatio(foreground, background);
    if (currentRatio >= minRatio) {
      return foreground;
    }

    // Determine if we should lighten or darken
    final bgLuminance = calculateLuminance(background);
    final shouldLighten = bgLuminance < 0.5;

    // Binary search for the right adjustment
    Color adjustedColor = foreground;
    double adjustment = 0.0;
    double step = 0.5;

    for (int i = 0; i < 10; i++) {
      final testAdjustment = shouldLighten
          ? adjustment + step
          : adjustment - step;

      final hsl = HSLColor.fromColor(foreground);
      adjustedColor = hsl
          .withLightness((hsl.lightness + testAdjustment).clamp(0.0, 1.0))
          .toColor();

      final testRatio = calculateContrastRatio(adjustedColor, background);
      if (testRatio >= minRatio) {
        // Try to find a less extreme adjustment
        step /= 2;
        if (step < 0.01) break;
      } else {
        adjustment = testAdjustment;
      }
    }

    return adjustedColor;
  }
}

/// A widget that provides accessible focus styling.
///
/// Wraps any widget with a visible focus indicator that follows
/// accessibility guidelines.
class AccessibleFocus extends StatelessWidget {
  const AccessibleFocus({
    super.key,
    required this.child,
    this.focusNode,
    this.onFocus,
    this.onBlur,
    this.borderRadius,
    this.focusColor,
  });

  final Widget child;
  final FocusNode? focusNode;
  final VoidCallback? onFocus;
  final VoidCallback? onBlur;
  final BorderRadius? borderRadius;
  final Color? focusColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveFocusColor = focusColor ?? scheme.primary;

    return Focus(
      focusNode: focusNode,
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          onFocus?.call();
        } else {
          onBlur?.call();
        }
      },
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              borderRadius: borderRadius ?? BorderRadius.circular(8),
              border: hasFocus
                  ? Border.all(color: effectiveFocusColor, width: 2)
                  : null,
            ),
            child: child,
          );
        },
      ),
    );
  }
}

/// A widget that provides semantic labeling for screen readers.
///
/// Use this to wrap interactive elements that need better
/// descriptions for assistive technologies.
class SemanticAction extends StatelessWidget {
  const SemanticAction({
    super.key,
    required this.child,
    required this.label,
    this.hint,
    this.onTap,
    this.isEnabled = true,
  });

  final Widget child;
  final String label;
  final String? hint;
  final VoidCallback? onTap;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      hint: hint,
      button: true,
      enabled: isEnabled,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: child,
      ),
    );
  }
}

/// Extension to easily check contrast on Color objects.
extension ColorAccessibilityExtension on Color {
  /// Check if this color has sufficient contrast against another color.
  bool hasContrastWith(
    Color background, {
    bool isLargeText = false,
  }) {
    return AccessibilityUtils.meetsContrastStandard(
      this,
      background,
      isLargeText: isLargeText,
    );
  }

  /// Get the contrast ratio with another color.
  double contrastRatioWith(Color background) {
    return AccessibilityUtils.calculateContrastRatio(this, background);
  }

  /// Returns an adjusted version of this color that meets contrast standards.
  Color withEnsuredContrast(
    Color background, {
    double minRatio = 4.5,
  }) {
    return AccessibilityUtils.ensureContrast(
      this,
      background,
      minRatio: minRatio,
    );
  }
}

/// Mixin for widgets that need accessibility support.
///
/// Provides common accessibility-related properties and methods.
mixin AccessibilityMixin<T extends StatefulWidget> on State<T> {
  /// Whether accessibility features should be enabled.
  bool get accessibilityEnabled => true;

  /// Announce a message to screen readers.
  void announceForAccessibility(String message) {
    // ignore: deprecated_member_use
    SemanticsService.announce(message, TextDirection.ltr);
  }
}
