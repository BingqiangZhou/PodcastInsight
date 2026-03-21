import 'dart:math' as math;

import 'package:flutter/material.dart';

/// ============================================================
/// Arctic Garden Design System - 有机纹理组件
///
/// 提供自然、有机的视觉纹理，增强设计的深度和质感
/// ============================================================

/// OrganicTexture - 有机噪点纹理
///
/// 一个微妙的噪点纹理层，放置在组件背景上增加质感
class OrganicTexture extends StatelessWidget {
  const OrganicTexture({
    super.key,
    this.opacity = 0.03,
    this.color,
    this.size = const Size(200, 200),
  });

  /// Opacity of the texture overlay
  final double opacity;

  /// Color of the texture (defaults to onSurface)
  final Color? color;

  /// Size of the texture pattern
  final Size size;

  @override
  Widget build(BuildContext context) {
    final textureColor = color ?? Theme.of(context).colorScheme.onSurface;

    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: CustomPaint(
          size: size,
          painter: _NoisePainter(color: textureColor),
        ),
      ),
    );
  }
}

class _NoisePainter extends CustomPainter {
  _NoisePainter({required this.color});

  final Color color;
  late final _random = math.Random(42); // Fixed seed for consistency

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;

    for (int i = 0; i < 200; i++) {
      final x = _random.nextDouble() * size.width;
      final y = _random.nextDouble() * size.height;
      final radius = _random.nextDouble() * 1.5;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_NoisePainter oldDelegate) => false;
}

/// WaveDivider - 波浪分隔线
///
/// 一个有机的波浪形分隔线，用于区域分隔
class WaveDivider extends StatelessWidget {
  const WaveDivider({
    super.key,
    this.height = 24,
    this.color,
    this.backgroundColor,
    this.amplitude = 8,
    this.waves = 3,
  });

  final double height;
  final Color? color;
  final Color? backgroundColor;
  final double amplitude;
  final int waves;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final waveColor = color ?? scheme.primary.withValues(alpha: 0.1);
    final bgColor = backgroundColor ?? Colors.transparent;

    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _WavePainter(
          waveColor: waveColor,
          backgroundColor: bgColor,
          amplitude: amplitude,
          waves: waves,
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.waveColor,
    required this.backgroundColor,
    required this.amplitude,
    required this.waves,
  });

  final Color waveColor;
  final Color backgroundColor;
  final double amplitude;
  final int waves;

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Wave path
    final wavePaint = Paint()
      ..color = waveColor
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);

    for (double x = 0; x <= size.width; x += 1) {
      final y = size.height / 2 +
          amplitude * math.sin((x / size.width) * waves * math.pi * 2);
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, wavePaint);
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) =>
      waveColor != oldDelegate.waveColor ||
      backgroundColor != oldDelegate.backgroundColor ||
      amplitude != oldDelegate.amplitude ||
      waves != oldDelegate.waves;
}

/// OrganicCard - 有机形状卡片
///
/// 一个带有不对称圆角的有机形状卡片
class OrganicCard extends StatelessWidget {
  const OrganicCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.backgroundColor,
    this.borderRadius,
    this.border,
    this.shadows,
    this.width,
    this.height,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final BoxBorder? border;
  final List<BoxShadow>? shadows;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final defaultRadius = borderRadius ??
        const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(24),
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(20),
        );

    return Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? scheme.surface,
        borderRadius: defaultRadius,
        border: border,
        boxShadow: shadows ??
            [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
      ),
      child: child,
    );
  }
}

/// RippleEffect - 水波纹效果
///
/// 点击时的水波纹扩散动画
class RippleEffect extends StatefulWidget {
  const RippleEffect({
    super.key,
    required this.child,
    this.color,
    this.duration = const Duration(milliseconds: 800),
  });

  final Widget child;
  final Color? color;
  final Duration duration;

  @override
  State<RippleEffect> createState() => _RippleEffectState();
}

class _RippleEffectState extends State<RippleEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void startRipple() {
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => startRipple(),
      child: Stack(
        children: [
          widget.child,
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return CustomPaint(
                painter: _RipplePainter(
                  progress: _animation.value,
                  color: widget.color ??
                      Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  _RipplePainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.sqrt(size.width * size.width + size.height * size.height) / 2;
    final radius = maxRadius * progress;

    final paint = Paint()
      ..color = color.withValues(alpha: color.a * (1 - progress))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_RipplePainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// FloatingOrb - 漂浮光球
///
/// 一个漂浮的发光球体，用于背景装饰
class FloatingOrb extends StatefulWidget {
  const FloatingOrb({
    super.key,
    required this.size,
    required this.color,
    this.duration = const Duration(seconds: 4),
    this.floatDistance = 20,
  });

  final double size;
  final Color color;
  final Duration duration;
  final double floatDistance;

  @override
  State<FloatingOrb> createState() => _FloatingOrbState();
}

class _FloatingOrbState extends State<FloatingOrb>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);
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
        return Transform.translate(
          offset: Offset(
            0,
            math.sin(_controller.value * math.pi) * widget.floatDistance,
          ),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  widget.color.withValues(alpha: 0.4),
                  widget.color.withValues(alpha: 0.1),
                  widget.color.withValues(alpha: 0),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        );
      },
    );
  }
}
