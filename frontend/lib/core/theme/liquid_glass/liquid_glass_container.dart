import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:personal_ai_assistant/core/theme/liquid_glass/liquid_glass_animations.dart';
import 'package:personal_ai_assistant/core/theme/liquid_glass/liquid_glass_style.dart';

/// Liquid Glass Container
///
/// A 4-layer rendering widget that creates Apple-style Liquid Glass effects:
/// 1. Optical Layer: BackdropFilter with blur and saturation boost
/// 2. Material Layer: Gradient border, fill, inner glow, outer shadow
/// 3. Dynamic Layer: Animated light flow gradient sweep
/// 4. Content Layer: Child widget
///
/// Example:
/// ```dart
/// LiquidGlassContainer(
///   tier: LiquidGlassTier.medium,
///   borderRadius: 16,
///   padding: const EdgeInsets.all(16),
///   child: Text('Glass content'),
/// )
/// ```
class LiquidGlassContainer extends StatefulWidget {
  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.tier = LiquidGlassTier.medium,
    this.borderRadius,
    this.padding,
    this.animate = true,
    this.interactive = true,
    this.tint,
  });

  /// The content to display inside the glass container
  final Widget child;

  /// The blur intensity tier
  final LiquidGlassTier tier;

  /// Border radius (defaults to 16)
  final double? borderRadius;

  /// Internal padding for the child
  final EdgeInsetsGeometry? padding;

  /// Enable light flow animation (default: true)
  final bool animate;

  /// Enable hover/press interactions (default: true)
  final bool interactive;

  /// Optional tint color overlay (for selected states)
  final Color? tint;

  @override
  State<LiquidGlassContainer> createState() => _LiquidGlassContainerState();
}

class _LiquidGlassContainerState extends State<LiquidGlassContainer>
    with TickerProviderStateMixin {
  late final LiquidGlassAnimationController _animationController;
  bool _isHovered = false;
  bool _isPressed = false;

  // Cache the style for the current theme
  late LiquidGlassStyle _style;

  // Pre-generated noise texture (created once)
  ui.Image? _noiseImage;

  @override
  void initState() {
    super.initState();
    _animationController = LiquidGlassAnimationController.create(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Update style when theme changes (safe to access Theme.of here)
    _style = LiquidGlassStyle.forTier(
      widget.tier,
      Theme.of(context).brightness,
    );
  }

  @override
  void didUpdateWidget(LiquidGlassContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update style if tier changed
    if (oldWidget.tier != widget.tier) {
      _style = LiquidGlassStyle.forTier(
        widget.tier,
        Theme.of(context).brightness,
      );
    }
    // Handle animation state changes
    if (oldWidget.animate != widget.animate) {
      if (widget.animate) {
        _animationController.startLightFlow();
        if (!_animationController.hasPlayedEntryAnimation) {
          _animationController.playEntryAnimation();
        }
      } else {
        _animationController.stopLightFlow();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = widget.borderRadius ?? 16.0;
    final effectivePadding = widget.padding;

    return MouseRegion(
      onEnter: widget.interactive ? (_) => _handleHoverEnter() : null,
      onExit: widget.interactive ? (_) => _handleHoverExit() : null,
      child: GestureDetector(
        onTapDown: widget.interactive ? _handlePressDown : null,
        onTapUp: widget.interactive ? _handlePressUp : null,
        onTapCancel: widget.interactive ? _handlePressCancel : null,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _animationController.lightFlow,
            _animationController.entry,
            if (_isHovered) _animationController.hover,
            if (_isPressed) _animationController.press,
          ]),
          builder: (context, child) {
            return _buildGlassContainer(borderRadius, effectivePadding, child!);
          },
          child: widget.child,
        ),
      ),
    );
  }

  Widget _buildGlassContainer(
    double borderRadius,
    EdgeInsetsGeometry? padding,
    Widget child,
  ) {
    final entryValue = _animationController.entry.value;
    final currentBlur = LiquidGlassAnimations.entryBlur(entryValue, _style.sigma);
    final currentBorderOpacity = LiquidGlassAnimations.entryBorderOpacity(
      entryValue,
      1.0,
    );

    // Apply hover/press modifiers
    final effectiveStyle = _getEffectiveStyle();

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: RepaintBoundary(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: currentBlur,
            sigmaY: currentBlur,
          ),
          child: _buildMaterialLayer(
            borderRadius,
            padding,
            effectiveStyle,
            currentBorderOpacity,
            child,
          ),
        ),
      ),
    );
  }

  Widget _buildMaterialLayer(
    double borderRadius,
    EdgeInsetsGeometry? padding,
    LiquidGlassStyle style,
    double borderOpacity,
    Widget child,
  ) {
    return Container(
      decoration: BoxDecoration(
        // Gradient border (Fresnel edge light effect)
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            style.borderTop.withValues(alpha: borderOpacity),
            style.borderBottom.withValues(alpha: borderOpacity * 0.25),
          ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Container(
        margin: const EdgeInsets.all(1), // Border width
        decoration: BoxDecoration(
          // Semi-transparent fill
          color: style.fill,
          borderRadius: BorderRadius.circular(borderRadius - 1),
          // Inner glow (simulated via border)
          border: Border.all(
            color: style.innerGlow,
            width: 1,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            // Outer shadow
            borderRadius: BorderRadius.circular(borderRadius - 1),
            boxShadow: [
              BoxShadow(
                color: style.shadow,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius - 1),
            child: Stack(
              children: [
                // Noise texture overlay
                if (_noiseImage != null)
                  Positioned.fill(
                    child: Opacity(
                      opacity: style.noiseOpacity,
                      child: CustomPaint(
                        painter: _NoisePainter(_noiseImage!),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                // Light flow animation
                if (widget.animate)
                  Positioned.fill(
                    child: _buildLightFlowOverlay(style),
                  ),
                // Tint overlay (for selected states)
                if (widget.tint != null)
                  Positioned.fill(
                    child: Container(color: widget.tint),
                  ),
                // Content layer
                Padding(
                  padding: padding ?? EdgeInsets.zero,
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLightFlowOverlay(LiquidGlassStyle style) {
    final lightFlowValue = _animationController.lightFlow.value;
    final angle = LiquidGlassAnimations.lightFlowAngle(lightFlowValue);

    // Calculate max opacity based on theme
    final maxOpacity = Theme.of(context).brightness == Brightness.dark ? 0.06 : 0.04;
    final opacity = LiquidGlassAnimations.lightFlowOpacity(lightFlowValue, maxOpacity);

    return Transform.rotate(
      angle: angle,
      child: Opacity(
        opacity: opacity,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.transparent,
                Colors.white,
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ),
    );
  }

  LiquidGlassStyle _getEffectiveStyle() {
    var style = _style;

    if (_isPressed) {
      style = style.withPress();
    } else if (_isHovered) {
      style = style.withHover();
    }

    return style;
  }

  void _handleHoverEnter() {
    if (_isHovered) return;
    setState(() {
      _isHovered = true;
    });
    _animationController.hoverIn();
  }

  void _handleHoverExit() {
    if (!_isHovered) return;
    setState(() {
      _isHovered = false;
    });
    _animationController.hoverOut();
  }

  void _handlePressDown(_) {
    if (_isPressed) return;
    setState(() {
      _isPressed = true;
    });
    _animationController.pressDown();
  }

  void _handlePressUp(_) {
    if (!_isPressed) return;
    setState(() {
      _isPressed = false;
    });
    _animationController.pressUp();
  }

  void _handlePressCancel() {
    if (!_isPressed) return;
    setState(() {
      _isPressed = false;
    });
    _animationController.pressUp();
  }
}

/// Noise texture painter
/// Draws a subtle grain texture over the glass surface
@immutable
class _NoisePainter extends CustomPainter {
  const _NoisePainter(this.image);

  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..filterQuality = FilterQuality.low;

    // Tile the noise image across the surface
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(image, src, dst, paint);
  }

  @override
  bool shouldRepaint(covariant _NoisePainter oldDelegate) => false;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _NoisePainter && other.image == image;

  @override
  int get hashCode => image.hashCode;
}
