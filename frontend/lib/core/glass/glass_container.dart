import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:personal_ai_assistant/core/glass/glass_tokens.dart';

/// Glass Container
///
/// A simple StatelessWidget that creates a glass effect using
/// backdrop blur, semi-transparent fill, and a subtle border.
///
/// Example:
/// ```dart
/// GlassContainer(
///   tier: GlassTier.standard,
///   borderRadius: 14,
///   padding: const EdgeInsets.all(16),
///   child: Text('Glass content'),
/// )
/// ```
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    this.child,
    this.tier = GlassTier.standard,
    this.borderRadius = 14,
    this.padding,
    this.tint,
  });

  /// The content to display inside the glass container
  final Widget? child;

  /// The blur intensity tier
  final GlassTier tier;

  /// Border radius (defaults to 14)
  final double borderRadius;

  /// Internal padding for the child
  final EdgeInsetsGeometry? padding;

  /// Optional tint color overlay (for selected/error states)
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final sigma = tier.sigma;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: Container(
          decoration: BoxDecoration(
            color: tier == GlassTier.overlay
                ? const Color(0x0AFFFFFF) // rgba 0.04
                : const Color(0x0FFFFFFF), // rgba 0.06
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: const Color(0x0FFFFFFF), // rgba 0.06
              width: 0.5,
            ),
          ),
          padding: padding,
          child: tint != null
              ? Stack(
                  children: [
                    if (child != null) child!,
                    Positioned.fill(
                      child: Container(color: tint),
                    ),
                  ],
                )
              : child,
        ),
      ),
    );
  }
}
