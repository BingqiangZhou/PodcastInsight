import 'dart:math' as math;

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
/// Dynamic background with neutral base color and 4 drifting gradient orbs.
/// Orbs move in gentle figure-8 patterns on 30s cycles with staggered offsets.
/// Includes RepaintBoundary for performance and respects disableAnimations.
class GlassBackground extends StatefulWidget {
  const GlassBackground({
    required this.child,
    this.theme = GlassBackgroundTheme.podcast,
    super.key,
  });

  final Widget child;
  final GlassBackgroundTheme theme;

  @override
  State<GlassBackground> createState() => _GlassBackgroundState();
}

class _GlassBackgroundState extends State<GlassBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Orb configuration
  static const int _orbCount = 4;
  static const Duration _cycleDuration = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _cycleDuration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF0F0F5),
        ),
        child: Stack(
          children: [
            // Gradient orbs (only when animations are enabled)
            if (!disableAnimations) ..._buildOrbs(isDark),
            // Content
            widget.child,
          ],
        ),
      ),
    );
  }

  /// Build animated gradient orbs
  List<Widget> _buildOrbs(bool isDark) {
    final colors = _getThemeColors(isDark);
    final opacity = isDark ? 0.10 : 0.06; // 8-12% dark, 5-8% light

    return List.generate(_orbCount, (index) {
      // Stagger each orb's animation
      final stagger = index * _cycleDuration.inMilliseconds / _orbCount;
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = ((_controller.value * 1000 + stagger) %
                  _cycleDuration.inMilliseconds) /
              _cycleDuration.inMilliseconds;

          final position = _calculateOrbPosition(progress, index);
          final size = _calculateOrbSize(progress, index);

          return Positioned(
            left: position.dx,
            top: position.dy,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeInOutSine,
              width: size,
              height: size,
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
        },
      );
    });
  }

  /// Calculate orb position using figure-8 pattern
  Offset _calculateOrbPosition(double progress, int index) {
    final size = MediaQuery.sizeOf(context);
    final baseX = size.width * 0.5;
    final baseY = size.height * 0.5;

    // Figure-8 parameters vary per orb
    final scaleA = 150.0 + index * 50.0; // Horizontal scale
    final scaleB = 100.0 + index * 30.0; // Vertical scale
    final phaseOffset = index * math.pi / 2;

    final t = progress * 2 * math.pi + phaseOffset;

    // Figure-8 (lemniscate) motion
    final x = baseX + scaleA * math.sin(t);
    final y = baseY + scaleB * math.sin(t) * math.cos(t);

    // Constrain to screen bounds with margin
    final margin = 50.0;
    final constrainedX = x.clamp(margin, size.width - margin);
    final constrainedY = y.clamp(margin, size.height - margin);

    return Offset(constrainedX - scaleA, constrainedY - scaleB);
  }

  /// Calculate orb size with gentle pulsing
  double _calculateOrbSize(double progress, int index) {
    final baseSize = 200.0 + index * 40.0;
    final pulse = math.sin(progress * 2 * math.pi + index) * 30.0;
    return baseSize + pulse;
  }

  /// Get theme colors for gradient orbs
  List<Color> _getThemeColors(bool isDark) {
    switch (widget.theme) {
      case GlassBackgroundTheme.podcast:
        // indigo + violet + blue
        return const [
          Color(0xFF6366F1), // indigo
          Color(0xFF8B5CF6), // violet
          Color(0xFF3B82F6), // blue
        ];
      case GlassBackgroundTheme.home:
        // blue + cyan + indigo
        return const [
          Color(0xFF3B82F6), // blue
          Color(0xFF06B6D4), // cyan
          Color(0xFF6366F1), // indigo
        ];
      case GlassBackgroundTheme.neutral:
        // gray + slate + cool
        return const [
          Color(0xFF6B7280), // gray
          Color(0xFF475569), // slate
          Color(0xFF9CA3AF), // cool
        ];
    }
  }
}
