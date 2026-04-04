import 'package:flutter/material.dart';

/// Liquid Glass Tier System
/// Defines blur intensity levels for different component types.
enum LiquidGlassTier {
  /// Strong blur for dialogs, bottom sheets, modals
  heavy(25),

  /// Medium blur for navigation bars, side rails, app bars
  medium(18),

  /// Light blur for cards, surface panels
  light(12),

  /// Minimal blur for chips, tooltips, badges, buttons
  subtle(6);

  final double sigma;
  const LiquidGlassTier(this.sigma);
}

/// Liquid Glass Style Configuration
/// Contains all visual parameters for the glass effect based on theme brightness.
@immutable
class LiquidGlassStyle {
  const LiquidGlassStyle({
    required this.sigma,
    required this.fill,
    required this.borderTop,
    required this.borderBottom,
    required this.innerGlow,
    required this.shadow,
    required this.noiseOpacity,
    required this.saturationBoost,
  });

  /// Blur sigma value (Gaussian blur radius)
  final double sigma;

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

  /// Noise texture opacity (0.0-1.0)
  final double noiseOpacity;

  /// Saturation boost multiplier (1.0 = no boost, >1.0 = increased vibrancy)
  final double saturationBoost;

  /// Create style for a given tier and brightness
  factory LiquidGlassStyle.forTier(LiquidGlassTier tier, Brightness brightness) {
    return brightness == Brightness.dark
        ? _darkStyleForTier(tier)
        : _lightStyleForTier(tier);
  }

  /// Dark mode style parameters
  static LiquidGlassStyle _darkStyleForTier(LiquidGlassTier tier) {
    return LiquidGlassStyle(
      sigma: tier.sigma,
      fill: const Color(0x0DFFFFFF), // white 5%
      borderTop: const Color(0x66FFFFFF), // white 40%
      borderBottom: const Color(0x1AFFFFFF), // white 10%
      innerGlow: const Color(0x14FFFFFF), // white 8%
      shadow: const Color(0x40000000), // black 25%
      noiseOpacity: 0.025,
      saturationBoost: 1.8,
    );
  }

  /// Light mode style parameters
  static LiquidGlassStyle _lightStyleForTier(LiquidGlassTier tier) {
    return LiquidGlassStyle(
      sigma: tier.sigma,
      fill: const Color(0x73FFFFFF), // white 45%
      borderTop: const Color(0x99FFFFFF), // white 60%
      borderBottom: const Color(0x4DFFFFFF), // white 30%
      innerGlow: const Color(0x1EFFFFFF), // white 12%
      shadow: const Color(0x14000000), // black 8%
      noiseOpacity: 0.02,
      saturationBoost: 1.3,
    );
  }

  /// Copy with for creating modified styles
  LiquidGlassStyle copyWith({
    double? sigma,
    Color? fill,
    Color? borderTop,
    Color? borderBottom,
    Color? innerGlow,
    Color? shadow,
    double? noiseOpacity,
    double? saturationBoost,
  }) {
    return LiquidGlassStyle(
      sigma: sigma ?? this.sigma,
      fill: fill ?? this.fill,
      borderTop: borderTop ?? this.borderTop,
      borderBottom: borderBottom ?? this.borderBottom,
      innerGlow: innerGlow ?? this.innerGlow,
      shadow: shadow ?? this.shadow,
      noiseOpacity: noiseOpacity ?? this.noiseOpacity,
      saturationBoost: saturationBoost ?? this.saturationBoost,
    );
  }

  /// Hover style - increased border light and blur
  LiquidGlassStyle withHover() {
    final currentAlpha = borderTop.a;
    final newAlpha = (currentAlpha * 1.5).clamp(0.0, 1.0);
    return copyWith(
      sigma: sigma + 2,
      borderTop: borderTop.withValues(alpha: newAlpha),
    );
  }

  /// Press style - further increased blur
  LiquidGlassStyle withPress() {
    return copyWith(
      sigma: sigma + 4,
    );
  }
}
