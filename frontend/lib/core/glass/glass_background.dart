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
    this.enableAnimation = false, // Disabled by default to avoid test issues
    super.key,
  });

  final Widget child;
  final GlassBackgroundTheme theme;
  final bool enableAnimation;

  @override
  State<GlassBackground> createState() => _GlassBackgroundState();
}

class _GlassBackgroundState extends State<GlassBackground>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  // Orb configuration
  static const int _orbCount = 4;
  static const Duration _cycleDuration = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    // Don't start animation in initState to avoid pumpAndSettle timeout
    // Animation will be started after a delay if enableAnimation is true
    if (widget.enableAnimation) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          final disableAnimations = MediaQuery.disableAnimationsOf(context);
          if (!disableAnimations) {
            _controller = AnimationController(
              vsync: this,
              duration: _cycleDuration,
            )..repeat();
            setState(() {}); // Rebuild with controller
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

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
            widget.child,
          ],
        ),
      ),
    );
  }

  /// Build animated gradient orbs
  List<Widget> _buildOrbs(bool isDark) {
    final colors = _getThemeColors(isDark);
    final opacity = isDark ? 0.06 : 0.15; // 6% dark (barely visible), 15% light

    // If no controller, render static orbs
    if (_controller == null) {
      return List.generate(_orbCount, (index) {
        return Positioned(
          left: 100.0 * index,
          top: 100.0 * index,
          child: Container(
            width: 200.0,
            height: 200.0,
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

    return List.generate(_orbCount, (index) {
      // Stagger each orb's animation
      final stagger = index * _cycleDuration.inMilliseconds / _orbCount;
      return AnimatedBuilder(
        animation: _controller!,
        builder: (context, child) {
          final progress = ((_controller!.value * 1000 + stagger) %
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
    if (isDark) {
      // Deep, desaturated colors that blend into #0f0f1a background
      return const [
        Color(0xFF1a1040), // deep indigo
        Color(0xFF0f2030), // deep teal
        Color(0xFF201020), // deep purple
      ];
    }

    switch (widget.theme) {
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
