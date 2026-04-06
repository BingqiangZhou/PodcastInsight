import 'package:flutter/material.dart';
import 'package:personal_ai_assistant/core/glass/glass_tokens.dart';

/// Text readability utility for glass surfaces.
///
/// Returns Apple label colors with alpha adjusted per glass tier.
/// Both tiers receive boosted alpha to maintain text readability
/// against semi-transparent backgrounds.
///
/// The alpha boosting follows Apple's approach for ensuring text
/// legibility on variable-transparency surfaces:
/// - **standard**: Base alpha + 0.15 (more transparent, needs more boost)
/// - **overlay**: Base alpha + 0.10 (less transparent, needs less boost)
///
/// Example:
/// ```dart
/// Text(
///   'Hello',
///   style: TextStyle(
///     color: GlassVibrancy.primaryText(context, tier: GlassTier.standard),
///   ),
/// )
/// ```
class GlassVibrancy {
  GlassVibrancy._();

  /// Primary text color for glass surfaces.
  ///
  /// Uses Apple's `.label` color with full opacity on all tiers.
  /// - Light mode: `#000000` (alpha 1.0)
  /// - Dark mode: `#FFFFFF` (alpha 1.0)
  static Color primaryText(BuildContext context, {required GlassTier tier}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
  }

  /// Secondary text color for glass surfaces.
  ///
  /// Uses Apple's `.secondaryLabel` color with alpha adjusted per tier.
  /// Base alpha is 0.6, boosted per tier:
  /// - overlay: 0.7 (base + 0.10)
  /// - standard: 0.75 (base + 0.15)
  ///
  /// Light mode: `#3C3C43` with adjusted alpha
  /// Dark mode: `#EBEBF5` with adjusted alpha
  static Color secondaryText(BuildContext context, {required GlassTier tier}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseAlpha = _boostedAlpha(0.6, tier);
    if (isDark) {
      return const Color(0xFFEBEBF5).withOpacity(baseAlpha);
    } else {
      return const Color(0xFF3C3C43).withOpacity(baseAlpha);
    }
  }

  /// Tertiary text color for glass surfaces.
  ///
  /// Uses Apple's `.tertiaryLabel` color with alpha adjusted per tier.
  /// Base alpha is 0.3, boosted per tier:
  /// - overlay: 0.4 (base + 0.10)
  /// - standard: 0.45 (base + 0.15)
  ///
  /// Light mode: `#3C3C43` with adjusted alpha
  /// Dark mode: `#EBEBF5` with adjusted alpha
  static Color tertiaryText(BuildContext context, {required GlassTier tier}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseAlpha = _boostedAlphaTertiary(0.3, tier);
    if (isDark) {
      return const Color(0xFFEBEBF5).withOpacity(baseAlpha);
    } else {
      return const Color(0xFF3C3C43).withOpacity(baseAlpha);
    }
  }

  /// Boost alpha for thinner glass tiers to maintain readability.
  ///
  /// Standard tier (more transparent) gets +0.15 boost.
  /// Overlay tier (more opaque) gets +0.10 boost.
  static double _boostedAlpha(double baseAlpha, GlassTier tier) {
    return switch (tier) {
      GlassTier.standard => (baseAlpha + 0.15).clamp(0.0, 1.0),
      GlassTier.overlay => (baseAlpha + 0.10).clamp(0.0, 1.0),
    };
  }

  /// Boost alpha for tertiary text.
  ///
  /// Standard tier (more transparent) gets +0.15 boost.
  /// Overlay tier (more opaque) gets +0.10 boost.
  static double _boostedAlphaTertiary(double baseAlpha, GlassTier tier) {
    return switch (tier) {
      GlassTier.standard => (baseAlpha + 0.15).clamp(0.0, 1.0),
      GlassTier.overlay => (baseAlpha + 0.10).clamp(0.0, 1.0),
    };
  }
}
