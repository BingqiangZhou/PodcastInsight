import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// ============================================================
/// Arctic Garden Design System - 极光视觉效果
///
/// 模拟北极光的视觉效果，用于背景装饰
/// ============================================================

/// AuroraGlow - 极光光晕效果
///
/// 一个柔和的径向渐变组件，放置在页面角落或特定位置，
/// 模拟北极光的视觉效果。
///
/// Example:
/// ```dart
/// Stack(
///   children: [
///     AuroraGlow(
///       color: Color(0xFF38BDF8).withOpacity(0.15),
///       size: 300,
///       position: AuroraGlowPosition.topLeft,
///     ),
///     YourContent(),
///   ],
/// )
/// ```
class AuroraGlow extends StatelessWidget {
  const AuroraGlow({
    super.key,
    required this.color,
    this.size = 200,
    this.position = AuroraGlowPosition.topLeft,
    this.offset = Offset.zero,
    this.opacity = 1.0,
    this.blur = 80,
  });

  /// The primary color of the glow
  final Color color;

  /// Size of the glow effect
  final double size;

  /// Position of the glow
  final AuroraGlowPosition position;

  /// Additional offset from the position
  final Offset offset;

  /// Opacity multiplier for the color
  final double opacity;

  /// Blur amount for the glow effect
  final double blur;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: position == AuroraGlowPosition.topLeft ||
              position == AuroraGlowPosition.topRight
          ? -size / 3 + offset.dy
          : null,
      bottom: position == AuroraGlowPosition.bottomLeft ||
              position == AuroraGlowPosition.bottomRight
          ? -size / 3 - offset.dy
          : null,
      left: position == AuroraGlowPosition.topLeft ||
              position == AuroraGlowPosition.bottomLeft
          ? -size / 3 + offset.dx
          : null,
      right: position == AuroraGlowPosition.topRight ||
              position == AuroraGlowPosition.bottomRight
          ? -size / 3 - offset.dx
          : null,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                color.withValues(alpha: color.a * opacity * 0.6),
                color.withValues(alpha: color.a * opacity * 0.3),
                color.withValues(alpha: 0),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: Container(),
          ),
        ),
      ),
    );
  }
}

/// Position options for AuroraGlow
enum AuroraGlowPosition {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

/// AuroraWave - 极光波浪动画
///
/// 一个水平移动的极光波浪效果，适合用于页面顶部或底部装饰
class AuroraWave extends StatefulWidget {
  const AuroraWave({
    super.key,
    this.colors = const [
      Color(0xFF0EA5E9),
      Color(0xFF06B6D4),
      Color(0xFF10B981),
    ],
    this.height = 120,
    this.speed = const Duration(seconds: 8),
    this.opacity = 0.15,
  });

  /// Colors for the aurora gradient
  final List<Color> colors;

  /// Height of the wave
  final double height;

  /// Duration for one complete animation cycle
  final Duration speed;

  /// Opacity of the wave
  final double opacity;

  @override
  State<AuroraWave> createState() => _AuroraWaveState();
}

class _AuroraWaveState extends State<AuroraWave>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.speed,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ClipRect(
          child: SizedBox(
            height: widget.height,
            child: Stack(
              children: [
                for (int i = 0; i < widget.colors.length; i++)
                  Positioned(
                    left: -100 +
                        (_controller.value * 200) +
                        (i * 100.0 * math.sin(_controller.value * math.pi)),
                    top: math.sin(_controller.value * math.pi * 2 + i) * 20,
                    child: Container(
                      width: 300,
                      height: widget.height,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(150),
                        gradient: RadialGradient(
                          colors: [
                            widget.colors[i].withValues(alpha: widget.opacity),
                            widget.colors[i].withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// AuroraBackdrop - 极光背景组件
///
/// 完整的极光背景效果，包含多个光晕和波浪
class AuroraBackdrop extends StatelessWidget {
  const AuroraBackdrop({
    super.key,
    this.showWave = false,
    this.showGlows = true,
    this.paddingTop = 0,
  });

  final bool showWave;
  final bool showGlows;
  final double paddingTop;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<MindriverThemeExtension>();

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background gradient
        DecoratedBox(
          decoration: BoxDecoration(gradient: tokens?.shellGradient),
        ),

        // Aurora glows
        if (showGlows) ...[
          // Primary aurora glow
          AuroraGlow(
            color: const Color(0xFF38BDF8),
            size: 280,
            position: AuroraGlowPosition.topLeft,
            offset: Offset(0, paddingTop - 60),
            opacity: 0.12,
          ),
          // Secondary aurora glow
          AuroraGlow(
            color: const Color(0xFF22D3EE),
            size: 220,
            position: AuroraGlowPosition.topRight,
            offset: const Offset(-40, 60),
            opacity: 0.08,
          ),
          // Accent aurora glow
          AuroraGlow(
            color: const Color(0xFF34D399),
            size: 200,
            position: AuroraGlowPosition.bottomLeft,
            offset: const Offset(60, -40),
            opacity: 0.06,
          ),
        ],

        // Wave effect
        if (showWave)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AuroraWave(
              colors: [
                const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                const Color(0xFF06B6D4).withValues(alpha: 0.08),
                const Color(0xFF10B981).withValues(alpha: 0.06),
              ],
              height: 100,
              speed: const Duration(seconds: 10),
            ),
          ),
      ],
    );
  }
}
