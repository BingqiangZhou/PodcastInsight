import 'package:flutter/material.dart';

/// Cosmic atmospheric background for Stella pages.
///
/// Adds subtle depth through gradient backgrounds with radial accent overlays
/// for richer glass refraction:
/// - Dark: Deep indigo gradient + violet/indigo radial accents
/// - Light: Warm white gradient + amber/violet radial accents
///
/// Optionally renders faint radial glow points for star atmosphere.
class StellaBackground extends StatelessWidget {
  const StellaBackground({
    required this.child,
    this.enableGlow = false,
    super.key,
  });

  final Widget child;
  final bool enableGlow;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: isDark ? _darkGradient : _lightGradient,
      ),
      child: enableGlow ? _StarGlow(child: child) : child,
    );
  }

  static const _darkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF0C0A1A),
      Color(0xFF12102A),
      Color(0xFF16132B),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  static const _lightGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFAFAFA),
      Color(0xFFF8F7FF),
      Color(0xFFF5F3FF),
    ],
    stops: [0.0, 0.5, 1.0],
  );
}

/// Subtle radial glow overlay with enhanced accent gradients for glass refraction.
class _StarGlow extends StatelessWidget {
  const _StarGlow({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // Top-right indigo glow (dark mode stronger, light mode subtle)
        Positioned(
          top: -40,
          right: -20,
          child: Container(
            width: isDark ? 200 : 160,
            height: isDark ? 200 : 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF6366F1).withValues(alpha: isDark ? 0.08 : 0.03),
                  const Color(0xFF6366F1).withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
        // Bottom-left indigo glow
        Positioned(
          bottom: 40,
          left: -60,
          child: Container(
            width: isDark ? 280 : 200,
            height: isDark ? 280 : 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF6366F1).withValues(alpha: isDark ? 0.05 : 0.02),
                  const Color(0xFF6366F1).withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
        // Dark mode: violet radial accent behind content areas for refraction
        if (isDark)
          Positioned(
            top: 120,
            left: 80,
            child: Container(
              width: 320,
              height: 320,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x0D8B5CF6), // violet 5%
                    Color(0x008B5CF6),
                  ],
                ),
              ),
            ),
          ),
        // Light mode: warm amber accent for refraction
        if (!isDark)
          Positioned(
            bottom: 120,
            right: 60,
            child: Container(
              width: 200,
              height: 200,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(0x05F59E0B), // amber 2%
                    Color(0x00F59E0B),
                  ],
                ),
              ),
            ),
          ),
        // Content
        child,
      ],
    );
  }
}
