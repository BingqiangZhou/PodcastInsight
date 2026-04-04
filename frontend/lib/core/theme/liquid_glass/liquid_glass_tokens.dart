import 'package:flutter/material.dart';

import 'package:personal_ai_assistant/core/theme/app_colors.dart';

/// Liquid Glass Theme Tokens
/// Provides access to glass effect parameters from the theme extension.
///
/// Usage:
/// ```dart
/// final tokens = LiquidGlassTokens.of(context);
/// final blur = tokens.glassBlurMedium; // 18.0
/// ```
@immutable
class LiquidGlassTokens {
  const LiquidGlassTokens({
    required this.glassBlurHeavy,
    required this.glassBlurMedium,
    required this.glassBlurLight,
    required this.glassBlurSubtle,
    required this.glassFill,
    required this.glassBorderTop,
    required this.glassBorderBottom,
    required this.glassInnerGlow,
    required this.glassShadow,
    required this.glassNoiseOpacity,
    required this.glassLightFlowDuration,
  });

  /// Heavy blur sigma (25.0) - for dialogs, bottom sheets, modals
  final double glassBlurHeavy;

  /// Medium blur sigma (18.0) - for navigation bars, side rails, app bars
  final double glassBlurMedium;

  /// Light blur sigma (12.0) - for cards, surface panels
  final double glassBlurLight;

  /// Subtle blur sigma (6.0) - for chips, tooltips, badges, buttons
  final double glassBlurSubtle;

  /// Semi-transparent fill color
  final Color glassFill;

  /// Top border gradient color (Fresnel edge light - bright)
  final Color glassBorderTop;

  /// Bottom border gradient color (Fresnel edge light - dim)
  final Color glassBorderBottom;

  /// Inner glow color (inset shadow)
  final Color glassInnerGlow;

  /// Outer shadow color
  final Color glassShadow;

  /// Noise texture opacity (0.02-0.03)
  final double glassNoiseOpacity;

  /// Light flow animation duration in milliseconds
  final int glassLightFlowDuration;

  /// Extract tokens from the current theme
  static LiquidGlassTokens of(BuildContext context) {
    final extension = Theme.of(context).extension<AppThemeExtension>();
    if (extension == null) {
      // Fallback to dark mode defaults
      return const LiquidGlassTokens.dark();
    }

    // Check if extension has glass tokens (will be added in app_colors.dart update)
    // For now, use fallback defaults
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? const LiquidGlassTokens.dark()
        : const LiquidGlassTokens.light();
  }

  /// Dark mode default tokens
  const factory LiquidGlassTokens.dark() = _DarkLiquidGlassTokens;

  /// Light mode default tokens
  const factory LiquidGlassTokens.light() = _LightLiquidGlassTokens;
}

/// Dark mode liquid glass tokens
class _DarkLiquidGlassTokens extends LiquidGlassTokens {
  const _DarkLiquidGlassTokens()
      : super(
          glassBlurHeavy: 25.0,
          glassBlurMedium: 18.0,
          glassBlurLight: 12.0,
          glassBlurSubtle: 6.0,
          glassFill: const Color(0x0DFFFFFF), // white 5%
          glassBorderTop: const Color(0x66FFFFFF), // white 40%
          glassBorderBottom: const Color(0x1AFFFFFF), // white 10%
          glassInnerGlow: const Color(0x14FFFFFF), // white 8%
          glassShadow: const Color(0x40000000), // black 25%
          glassNoiseOpacity: 0.025,
          glassLightFlowDuration: 3000,
        );
}

/// Light mode liquid glass tokens
class _LightLiquidGlassTokens extends LiquidGlassTokens {
  const _LightLiquidGlassTokens()
      : super(
          glassBlurHeavy: 25.0,
          glassBlurMedium: 18.0,
          glassBlurLight: 12.0,
          glassBlurSubtle: 6.0,
          glassFill: const Color(0x73FFFFFF), // white 45%
          glassBorderTop: const Color(0x99FFFFFF), // white 60%
          glassBorderBottom: const Color(0x4DFFFFFF), // white 30%
          glassInnerGlow: const Color(0x1EFFFFFF), // white 12%
          glassShadow: const Color(0x14000000), // black 8%
          glassNoiseOpacity: 0.02,
          glassLightFlowDuration: 3000,
        );
}

/// Extension on AppThemeExtension for glass token access
///
/// This will be integrated into app_colors.dart
/// Usage: `appThemeOf(context).glassBlurMedium`
extension LiquidGlassExtension on AppThemeExtension {
  /// Heavy blur sigma (25.0)
  double get glassBlurHeavy => 25.0;

  /// Medium blur sigma (18.0)
  double get glassBlurMedium => 18.0;

  /// Light blur sigma (12.0)
  double get glassBlurLight => 12.0;

  /// Subtle blur sigma (6.0)
  double get glassBlurSubtle => 6.0;

  /// Glass fill color (based on brightness)
  Color get glassFill {
    // This will be replaced by theme-based values in app_colors.dart
    return const Color(0x0DFFFFFF);
  }

  /// Glass border top color (Fresnel edge light - bright)
  Color get glassBorderTop {
    return const Color(0x66FFFFFF);
  }

  /// Glass border bottom color (Fresnel edge light - dim)
  Color get glassBorderBottom {
    return const Color(0x1AFFFFFF);
  }

  /// Glass inner glow color (inset shadow)
  Color get glassInnerGlow {
    return const Color(0x14FFFFFF);
  }

  /// Glass shadow color
  Color get glassShadow {
    return const Color(0x40000000);
  }

  /// Glass noise texture opacity
  double get glassNoiseOpacity => 0.025;

  /// Glass light flow animation duration in milliseconds
  int get glassLightFlowDuration => 3000;
}
