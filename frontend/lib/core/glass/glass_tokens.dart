import 'package:flutter/material.dart';

/// Glass Tier System
///
/// Defines 4 tiers with specific blur sigma values for different use cases:
/// - ultraHeavy (28): Full-screen overlay, modal dialogs, expanded player
/// - heavy (20): Bottom sheets, large panels, sidebar
/// - medium (14): Navigation bar, tab bar, toolbar, search bar, mini player
/// - light (8): Cards, list items, small panels, buttons, chips
enum GlassTier {
  ultraHeavy(28),
  heavy(20),
  medium(14),
  light(8);

  final double sigma;
  const GlassTier(this.sigma);
}

/// Glass visual parameters for a specific tier and brightness.
///
/// Immutable class holding all visual parameters needed to render
/// the glass effect: fill colors, border colors, shadow, saturation,
/// and noise opacity.
@immutable
class GlassTierParams {
  const GlassTierParams({
    required this.fill,
    required this.borderTop,
    required this.borderBottom,
    required this.innerGlow,
    required this.shadow,
    required this.saturationBoost,
    required this.noiseOpacity,
  });

  /// Semi-transparent fill color
  final Color fill;

  /// Top border gradient color (Fresnel edge light - bright)
  final Color borderTop;

  /// Bottom border gradient color (Fresnel edge light - dim)
  final Color borderBottom;

  /// Inner glow color (inset shadow)
  final Color innerGlow;

  /// Outer shadow color
  final Color shadow;

  /// Saturation boost factor for backdrop filter
  final double saturationBoost;

  /// Noise texture opacity
  final double noiseOpacity;
}

/// Glass Tokens
///
/// Immutable class holding all visual parameters per tier and brightness.
/// Provides static factory methods for dark/light modes and context-based
/// resolution.
@immutable
class GlassTokens {
  const GlassTokens({
    required this.brightness,
    required this.ultraHeavy,
    required this.heavy,
    required this.medium,
    required this.light,
  });

  final Brightness brightness;
  final GlassTierParams ultraHeavy;
  final GlassTierParams heavy;
  final GlassTierParams medium;
  final GlassTierParams light;

  /// Extract tokens from the current theme context
  static GlassTokens of(BuildContext context) {
    final themeBrightness = Theme.of(context).brightness;
    return themeBrightness == Brightness.dark
        ? const GlassTokens.dark()
        : const GlassTokens.light();
  }

  /// Dark mode tokens
  const factory GlassTokens.dark() = _DarkGlassTokens;

  /// Light mode tokens
  const factory GlassTokens.light() = _LightGlassTokens;

  /// Get params for a specific tier
  GlassTierParams paramsForTier(GlassTier tier) {
    return switch (tier) {
      GlassTier.ultraHeavy => ultraHeavy,
      GlassTier.heavy => heavy,
      GlassTier.medium => medium,
      GlassTier.light => light,
    };
  }

  /// Convenience getter for medium-tier fill color
  Color get glassFill => medium.fill;
}

/// Dark mode glass tokens
class _DarkGlassTokens extends GlassTokens {
  const _DarkGlassTokens()
      : super(
          brightness: Brightness.dark,
          ultraHeavy: const GlassTierParams(
            fill: Color(0x0AFFFFFF), // white 4%
            borderTop: Color(0x14FFFFFF), // white 8%
            borderBottom: Color(0x0AFFFFFF), // white 4%
            innerGlow: Color(0x08FFFFFF), // white 3%
            shadow: Color(0x80000000), // black 50%
            saturationBoost: 2.0,
            noiseOpacity: 0.06,
          ),
          heavy: const GlassTierParams(
            fill: Color(0x0DFFFFFF), // white 5%
            borderTop: Color(0x19FFFFFF), // white 10%
            borderBottom: Color(0x0DFFFFFF), // white 5%
            innerGlow: Color(0x0AFFFFFF), // white 4%
            shadow: Color(0x66000000), // black 40%
            saturationBoost: 1.8,
            noiseOpacity: 0.05,
          ),
          medium: const GlassTierParams(
            fill: Color(0x0FFFFFFF), // white 6%
            borderTop: Color(0x21FFFFFF), // white 13%
            borderBottom: Color(0x12FFFFFF), // white 7%
            innerGlow: Color(0x0DFFFFFF), // white 5%
            shadow: Color(0x4D000000), // black 30%
            saturationBoost: 1.5,
            noiseOpacity: 0.04,
          ),
          light: const GlassTierParams(
            fill: Color(0x12FFFFFF), // white 7%
            borderTop: Color(0x28FFFFFF), // white 16%
            borderBottom: Color(0x14FFFFFF), // white 8%
            innerGlow: Color(0x0FFFFFFF), // white 6%
            shadow: Color(0x33000000), // black 20%
            saturationBoost: 1.3,
            noiseOpacity: 0.03,
          ),
        );
}

/// Light mode glass tokens
///
/// Uses subtle dark tints for fill and borders (instead of white) to create
/// visible glass effects on light backgrounds. White fills on light backgrounds
/// are nearly invisible, so dark overlays provide better visual distinction.
class _LightGlassTokens extends GlassTokens {
  const _LightGlassTokens()
      : super(
          brightness: Brightness.light,
          ultraHeavy: const GlassTierParams(
            fill: Color(0x12000000), // black 7% — visible darkening
            borderTop: Color(0x1A000000), // black 10% — edge definition
            borderBottom: Color(0x0D000000), // black 5%
            innerGlow: Color(0x0AFFFFFF), // white 4% — subtle inner light
            shadow: Color(0x1A000000), // black 10% — stronger shadow
            saturationBoost: 1.08,
            noiseOpacity: 0.04,
          ),
          heavy: const GlassTierParams(
            fill: Color(0x0F000000), // black 6%
            borderTop: Color(0x16000000), // black 9%
            borderBottom: Color(0x0A000000), // black 4%
            innerGlow: Color(0x08FFFFFF), // white 3%
            shadow: Color(0x16000000), // black 9%
            saturationBoost: 1.06,
            noiseOpacity: 0.03,
          ),
          medium: const GlassTierParams(
            fill: Color(0x0D000000), // black 5%
            borderTop: Color(0x13000000), // black 7.5%
            borderBottom: Color(0x08000000), // black 3%
            innerGlow: Color(0x06FFFFFF), // white 2.5%
            shadow: Color(0x12000000), // black 7%
            saturationBoost: 1.05,
            noiseOpacity: 0.03,
          ),
          light: const GlassTierParams(
            fill: Color(0x0A000000), // black 4%
            borderTop: Color(0x10000000), // black 6%
            borderBottom: Color(0x06000000), // black 2.5%
            innerGlow: Color(0x05FFFFFF), // white 2%
            shadow: Color(0x0F000000), // black 6%
            saturationBoost: 1.03,
            noiseOpacity: 0.02,
          ),
        );
}
