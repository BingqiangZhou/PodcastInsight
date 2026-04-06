import 'package:flutter/material.dart';

import 'package:personal_ai_assistant/core/theme/app_colors.dart';

/// Card tier system for visual hierarchy.
///
/// Three tiers provide progressive elevation:
/// - **surface**: Lowest tier, minimal fill/border (lists, inline content)
/// - **card**: Default tier, medium fill/border (standard cards, panels)
/// - **elevated**: Highest tier, strong fill/border (prominent cards, dialogs)
enum CardTier {
  /// Lowest tier with minimal fill (rgba 0.04) and border (rgba 0.06)
  surface,

  /// Default tier with medium fill (rgba 0.06) and border (rgba 0.08)
  card,

  /// Highest tier with strong fill (rgba 0.08) and border (rgba 0.10)
  elevated,
}

/// Surface card variants for different visual hierarchy levels.
///
/// @deprecated Use CardTier instead. Kept for backward compatibility.
enum SurfaceCardVariant {
  /// Standard card with secondarySystemGroupedBackground.
  @Deprecated('Use CardTier.card instead')
  normal,

  /// Elevated card (same as normal, can add shadow later).
  @Deprecated('Use CardTier.elevated instead')
  elevated,

  /// Flat card with tertiarySystemGroupedBackground.
  @Deprecated('Use CardTier.surface instead')
  flat,
}

/// A content layer card widget using Arc+Linear theme tokens.
///
/// Provides a card surface with proper background colors and borders
/// following the Arc+Linear design system. The card automatically
/// adapts to light/dark mode and supports three tiers:
///
/// - **surface**: Uses `surfaceTierFill` + `surfaceTierBorder` (lowest elevation)
/// - **card**: Uses `cardTierFill` + `cardTierBorder` (default, medium elevation)
/// - **elevated**: Uses `elevatedTierFill` + `elevatedTierBorder` (highest elevation)
///
/// Example:
/// ```dart
/// SurfaceCard(
///   tier: CardTier.card,
///   padding: const EdgeInsets.all(16),
///   child: Text('Content'),
/// )
/// ```
class SurfaceCard extends StatelessWidget {
  /// Creates a surface card.
  const SurfaceCard({
    required this.child, super.key,
    this.padding,
    this.borderRadius = 16,
    this.tier = CardTier.card,
    this.variant,
    this.backgroundColor,
  });

  /// The content widget inside the card.
  final Widget child;

  /// Optional padding around the child.
  final EdgeInsetsGeometry? padding;

  /// The border radius of the card.
  final double borderRadius;

  /// The visual tier of the card.
  final CardTier tier;

  /// @deprecated Use [tier] instead.
  final SurfaceCardVariant? variant;

  /// Optional custom background color.
  /// When provided, this overrides the tier-based background color.
  final Color? backgroundColor;

  /// Convert legacy [variant] to equivalent [CardTier].
  CardTier _getEffectiveTier() {
    if (variant == null) return tier;
    return switch (variant!) {
      SurfaceCardVariant.normal => CardTier.card,
      SurfaceCardVariant.elevated => CardTier.elevated,
      SurfaceCardVariant.flat => CardTier.surface,
    };
  }

  @override
  Widget build(BuildContext context) {
    final extension = appThemeOf(context);
    final effectiveTier = _getEffectiveTier();

    // Resolve fill and border colors from tier
    final bg = backgroundColor ??
        switch (effectiveTier) {
          CardTier.surface => extension.surfaceTierFill,
          CardTier.card => extension.cardTierFill,
          CardTier.elevated => extension.elevatedTierFill,
        };

    final borderColor = switch (effectiveTier) {
      CardTier.surface => extension.surfaceTierBorder,
      CardTier.card => extension.cardTierBorder,
      CardTier.elevated => extension.elevatedTierBorder,
    };

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: padding != null
            ? Padding(padding: padding!, child: child)
            : child,
      ),
    );
  }
}
