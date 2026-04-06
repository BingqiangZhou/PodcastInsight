import 'package:flutter/material.dart';

/// Glass Background Theme
///
/// Defines the color palette for gradient orbs based on context:
/// - podcast: indigo + violet + blue
/// - home: blue + cyan + indigo
/// - neutral: gray + slate + cool
enum GlassBackgroundTheme {
  podcast,
  home,
  neutral,
}

/// Glass Background
///
/// Background with neutral base color and 4 static gradient orbs
/// providing subtle atmospheric depth.
/// Includes RepaintBoundary for performance and respects disableAnimations.
class GlassBackground extends StatelessWidget {
  const GlassBackground({
    required this.child,
    this.theme = GlassBackgroundTheme.podcast,
    this.enableAnimation = false,
    super.key,
  });

  final Widget child;
  final GlassBackgroundTheme theme;
  final bool enableAnimation;

  // Orb configuration
  static const int _orbCount = 4;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0f0f1a) : const Color(0xFFF8F9FA),
        ),
        child: Stack(
          children: [
            // Gradient orbs (only when animations are enabled)
            if (!disableAnimations) ..._buildOrbs(isDark),
            // Content
            child,
          ],
        ),
      ),
    );
  }

  /// Build static gradient orbs at fixed positions
  List<Widget> _buildOrbs(bool isDark) {
    final colors = _getThemeColors(isDark);
    final opacity = isDark ? 0.06 : 0.15;

    return List.generate(_orbCount, (index) {
      return Positioned(
        left: 100.0 * index,
        top: 100.0 * index,
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                colors[index % colors.length].withValues(alpha: opacity),
                colors[index % colors.length].withValues(alpha: 0),
              ],
            ),
          ),
        ),
      );
    });
  }

  /// Get theme colors for gradient orbs
  List<Color> _getThemeColors(bool isDark) {
    if (isDark) {
      // Deep, desaturated colors that blend into #0f0f1a background
      return const [
        Color(0xFF1a1040), // deep indigo
        Color(0xFF0f2030), // deep teal
        Color(0xFF201020), // deep purple
      ];
    }

    switch (theme) {
      case GlassBackgroundTheme.podcast:
        // Pale pastel indigo + violet + blue
        return const [
          Color(0xFFE0E0F0), // pale indigo
          Color(0xFFE8D8F8), // pale violet
          Color(0xFFD8E4F8), // pale blue
        ];
      case GlassBackgroundTheme.home:
        // Pale pastel blue + cyan + indigo
        return const [
          Color(0xFFD8E4F8), // pale blue
          Color(0xFFD0F0F4), // pale cyan
          Color(0xFFE0E0F0), // pale indigo
        ];
      case GlassBackgroundTheme.neutral:
        // Pale pastel gray + slate + cool
        return const [
          Color(0xFFE0E0E4), // pale gray
          Color(0xFFD8DCE0), // pale slate
          Color(0xFFE4E4E8), // pale cool
        ];
    }
  }
}
