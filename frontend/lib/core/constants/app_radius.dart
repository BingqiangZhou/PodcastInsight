import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Design tokens for border radius throughout the app.
///
/// These values align with [MindriverThemeExtension] and should be used
/// consistently instead of hardcoded values.
class AppRadius {
  AppRadius._();

  // Core radius values from MindriverThemeExtension
  static const double cardValue = 24.0;
  static const double panelValue = 28.0;
  static const double buttonValue = 20.0;

  // Additional common radius values
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double pill = 999.0;

  // Pre-built BorderRadius instances
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

  // RoundedRectangleBorder shapes
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
