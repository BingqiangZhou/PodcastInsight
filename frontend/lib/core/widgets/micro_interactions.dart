import 'package:flutter/material.dart';

/// ============================================================
/// Arctic Garden Design System - 微交互系统
///
/// 动画原则：
/// - 有机缓动：模拟自然运动的曲线
/// - 柔和过渡：避免突兀的状态变化
/// - 适度反馈：提供清晰的交互反馈
/// ============================================================

/// Arctic Garden Animation Curves - 有机缓动曲线
class ArcticCurves {
  ArcticCurves._();

  /// 有机缓动 - 模拟自然运动
  static const Curve organic = Curves.easeOutQuart;

  /// 极光缓动 - 用于渐变和光效动画
  static const Curve aurora = Curves.easeInOutCubic;

  /// 弹性缓动 - 用于微交互
  static const Curve elastic = Curves.easeOutBack;

  /// 柔和缓动 - 用于状态变化
  static const Curve soft = Curves.easeOutCubic;

  /// 快速缓动 - 用于即时反馈
  static const Curve quick = Curves.easeOutExpo;
}

/// Arctic Garden Animation Durations - 动画时长
class ArcticDurations {
  ArcticDurations._();

  /// 快速 - 微交互（按钮点击、图标变化）
  static const Duration quick = Duration(milliseconds: 180);

  /// 标准 - 状态变化（展开/折叠、显示/隐藏）
  static const Duration standard = Duration(milliseconds: 350);

  /// 慢速 - 页面转场、大型动画
  static const Duration slow = Duration(milliseconds: 500);

  /// 极光 - 渐变和光效动画
  static const Duration aurora = Duration(milliseconds: 800);
}

/// TactileScale - 触觉缩放动画
///
/// 提供悬停和按下时的缩放反馈
class TactileScale extends StatefulWidget {
  const TactileScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.hoverScale = 1.02,
    this.pressScale = 0.98,
    this.duration = ArcticDurations.quick,
    this.curve = ArcticCurves.organic,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double hoverScale;
  final double pressScale;
  final Duration duration;
  final Curve curve;
  final bool enabled;

  @override
  State<TactileScale> createState() => _TactileScaleState();
}

class _TactileScaleState extends State<TactileScale> {
  bool _isHovered = false;
  bool _isPressed = false;

  double get _scale {
    if (!widget.enabled) return 1.0;
    if (_isPressed) return widget.pressScale;
    if (_isHovered) return widget.hoverScale;
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: widget.enabled ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: widget.enabled ? (_) => setState(() => _isPressed = false) : null,
        onTapCancel: widget.enabled ? () => setState(() => _isPressed = false) : null,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _scale,
          duration: widget.duration,
          curve: widget.curve,
          child: widget.child,
        ),
      ),
    );
  }
}

/// ShimmerLoading - 骨架屏加载效果
class ShimmerLoading extends StatefulWidget {
  const ShimmerLoading({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.duration = const Duration(milliseconds: 1800),
  });

  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration duration;

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: ArcticCurves.aurora),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final baseColor = widget.baseColor ?? scheme.surfaceContainerHighest;
    final highlightColor = widget.highlightColor ?? scheme.surface;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.0, 0.5, 1.0],
              transform: _SlidingGradientTransform(
                slidePercent: _animation.value,
              ),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform({required this.slidePercent});

  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0, 0);
  }
}

/// AnimatedIn - 入场动画
///
/// 淡入 + 滑动效果，用于列表项、卡片等
class AnimatedIn extends StatefulWidget {
  const AnimatedIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = ArcticDurations.standard,
    this.offset = const Offset(0, 24),
    this.curve = ArcticCurves.organic,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;
  final Curve curve;

  @override
  State<AnimatedIn> createState() => _AnimatedInState();
}

class _AnimatedInState extends State<AnimatedIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );

    _slideAnimation = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

/// StaggeredAnimatedList - 交错动画列表
class StaggeredAnimatedList extends StatelessWidget {
  const StaggeredAnimatedList({
    super.key,
    required this.children,
    this.itemDelay = const Duration(milliseconds: 60),
    this.itemDuration = ArcticDurations.standard,
    this.offset = const Offset(0, 20),
    this.curve = ArcticCurves.organic,
  });

  final List<Widget> children;
  final Duration itemDelay;
  final Duration itemDuration;
  final Offset offset;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < children.length; i++)
          AnimatedIn(
            delay: itemDelay * i,
            duration: itemDuration,
            offset: offset,
            curve: curve,
            child: children[i],
          ),
      ],
    );
  }
}

/// PulseIndicator - 脉冲指示器
class PulseIndicator extends StatefulWidget {
  const PulseIndicator({
    super.key,
    required this.child,
    this.color,
    this.duration = const Duration(milliseconds: 1800),
    this.minOpacity = 0.4,
    this.maxOpacity = 1.0,
    this.enabled = true,
  });

  final Widget child;
  final Color? color;
  final Duration duration;
  final double minOpacity;
  final double maxOpacity;
  final bool enabled;

  @override
  State<PulseIndicator> createState() => _PulseIndicatorState();
}

class _PulseIndicatorState extends State<PulseIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);
    _animation = Tween<double>(
      begin: widget.minOpacity,
      end: widget.maxOpacity,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: ArcticCurves.aurora,
    ));
  }

  @override
  void didUpdateWidget(PulseIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.enabled && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final scheme = Theme.of(context).colorScheme;
    final color = widget.color ?? scheme.primary;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: _animation.value * 0.5),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: widget.child,
        );
      },
    );
  }
}

/// SuccessAnimation - 成功动画
class SuccessAnimation extends StatefulWidget {
  const SuccessAnimation({
    super.key,
    this.size = 48,
    this.color,
    this.onComplete,
    this.duration = const Duration(milliseconds: 700),
  });

  final double size;
  final Color? color;
  final VoidCallback? onComplete;
  final Duration duration;

  @override
  State<SuccessAnimation> createState() => _SuccessAnimationState();
}

class _SuccessAnimationState extends State<SuccessAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: ArcticCurves.elastic),
      ),
    );

    _checkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: ArcticCurves.organic),
      ),
    );

    _controller.forward().then((_) => widget.onComplete?.call());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = widget.color ?? scheme.primary;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: SizedBox(
                width: widget.size * 0.5,
                height: widget.size * 0.5,
                child: CustomPaint(
                  painter: _CheckPainter(
                    progress: _checkAnimation.value,
                    color: color,
                    strokeWidth: 3,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    final width = size.width;
    final height = size.height;

    path.moveTo(0, height * 0.5);
    path.lineTo(width * 0.35, height * 0.85);
    path.lineTo(width, height * 0.15);

    final pathMetric = path.computeMetrics().first;
    final animatedPath = pathMetric.extractPath(
      0,
      pathMetric.length * progress,
    );

    canvas.drawPath(animatedPath, paint);
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// AnimationExtensions - 动画扩展
extension AnimationExtensions on Widget {
  /// 添加触觉反馈
  Widget withTactileFeedback({
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    double hoverScale = 1.02,
    double pressScale = 0.98,
    bool enabled = true,
  }) {
    return TactileScale(
      onTap: onTap,
      onLongPress: onLongPress,
      hoverScale: hoverScale,
      pressScale: pressScale,
      enabled: enabled,
      child: this,
    );
  }

  /// 添加入场动画
  Widget withEntranceAnimation({
    Duration delay = Duration.zero,
    Duration duration = ArcticDurations.standard,
    Offset offset = const Offset(0, 24),
    Curve curve = ArcticCurves.organic,
  }) {
    return AnimatedIn(
      delay: delay,
      duration: duration,
      offset: offset,
      curve: curve,
      child: this,
    );
  }
}
