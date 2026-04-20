import 'package:flutter/material.dart';
import 'package:personal_ai_assistant/core/constants/app_text_styles.dart';

/// Named text style helpers for sizes not covered by standard TextTheme slots.
///
/// These are pure functions with no theme dependency.
class AppTextStyles {
  AppTextStyles._();

  /// Monospace style for code, timestamps, and data.
  static TextStyle monoStyle({
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w400,
    double height = 1.5,
    Color? color,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: 0,
      fontFamily: 'monospace',
      color: color,
    );
  }

  /// Transcript body text (fontSize: 15, height: 1.6).
  static TextStyle transcriptBody([Color? color]) => TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.6,
    letterSpacing: 0,
    color: color,
  );

  /// Caption text (fontSize: 13, height: 1.4).
  static TextStyle caption([Color? color]) => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: 0.1,
    color: color,
  );

  /// Compact metadata text (fontSize: 11, height: 1.3).
  static TextStyle metaSmall([Color? color]) => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0.1,
    color: color,
  );

  /// Navigation rail label (fontSize: 10, height: 1.0).
  static TextStyle navLabel(Color? color, {FontWeight weight = FontWeight.w500}) =>
    TextStyle(
      fontSize: 10,
      fontWeight: weight,
      height: 1,
      letterSpacing: 0.2,
      color: color,
    );
}
