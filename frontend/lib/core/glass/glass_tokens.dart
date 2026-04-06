import 'package:flutter/material.dart';

/// Glass Tier System
///
/// Defines 2 tiers with specific blur sigma values:
/// - standard (20): Cards, navigation bars, toolbars, search bars, list items
/// - overlay (30): Full-screen overlays, modal dialogs, bottom sheets, sidebar
enum GlassTier {
  standard(20),
  overlay(30);

  final double sigma;
  const GlassTier(this.sigma);
}

/// Glass visual parameters for a specific tier and brightness.
///
/// Immutable class holding the visual parameters needed to render
/// the glass effect: fill color and blur sigma.
@immutable
class GlassTierParams {
  const GlassTierParams({
    required this.fill,
    required this.sigma,
  });

  /// Semi-transparent fill color
  final Color fill;

  /// Blur sigma value
  final double sigma;
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
    required this.standard,
    required this.overlay,
  });

  final Brightness brightness;
  final GlassTierParams standard;
  final GlassTierParams overlay;

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
      GlassTier.standard => standard,
      GlassTier.overlay => overlay,
    };
  }

  /// Convenience getter for standard-tier fill color
  Color get glassFill => standard.fill;
}

/// Dark mode glass tokens
///
/// White-tinted glass on pure #000000 background.
class _DarkGlassTokens extends GlassTokens {
  const _DarkGlassTokens()
      : super(
          brightness: Brightness.dark,
          standard: const GlassTierParams(
            fill: Color(0x0FFFFFFF), // white 6%
            sigma: 20,
          ),
          overlay: const GlassTierParams(
            fill: Color(0x1AFFFFFF), // white 10%
            sigma: 30,
          ),
        );
}

/// Light mode glass tokens
///
/// Black-tinted glass on #F2F2F7 background.
class _LightGlassTokens extends GlassTokens {
  const _LightGlassTokens()
      : super(
          brightness: Brightness.light,
          standard: const GlassTierParams(
            fill: Color(0x0D000000), // black 5%
            sigma: 20,
          ),
          overlay: const GlassTierParams(
            fill: Color(0x14000000), // black 8%
            sigma: 30,
          ),
        );
}
