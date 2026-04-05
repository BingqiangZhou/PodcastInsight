import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:personal_ai_assistant/core/glass/glass_painter.dart';
import 'package:personal_ai_assistant/core/glass/glass_style.dart';
import 'package:personal_ai_assistant/core/glass/glass_tokens.dart';

/// Glass Container
///
/// A 5-layer rendering widget that creates Apple Liquid Glass effects:
/// 1. Optical Layer: BackdropFilter with blur and saturation boost
/// 2. Material Layer: Gradient border, fill, inner glow, outer shadow
/// 3. Specular Layer: Fresnel edge highlight + moving specular highlight
/// 4. Dynamic Layer: Noise texture + rotating light flow gradient sweep
/// 5. Content Layer: Child widget
///
/// Example:
/// ```dart
/// GlassContainer(
///   tier: GlassTier.medium,
///   borderRadius: 16,
///   padding: const EdgeInsets.all(16),
///   child: Text('Glass content'),
/// )
/// ```
class GlassContainer extends StatefulWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.tier = GlassTier.medium,
    this.borderRadius = 16,
    this.padding = const EdgeInsets.all(16),
    this.animate = true,
    this.interactive = false,
    this.tint,
  });

  /// The content to display inside the glass container
  final Widget child;

  /// The blur intensity tier
  final GlassTier tier;

  /// Border radius (defaults to 16)
  final double borderRadius;

  /// Internal padding for the child
  final EdgeInsetsGeometry padding;

  /// Enable light flow animation (default: true)
  final bool animate;

  /// Enable hover/press interactions (default: false)
  final bool interactive;

  /// Optional tint color overlay (for selected states)
  final Color? tint;

  @override
  State<GlassContainer> createState() => _GlassContainerState();
}

class _GlassContainerState extends State<GlassContainer>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _lightFlowController;
  late AnimationController _hoverController;
  late AnimationController _pressController;
  late AnimationController _entryController;

  // Hover/press state
  bool _isHovered = false;
  bool _isPressed = false;

  // Noise texture
  ui.Image? _noiseImage;

  // Current style
  late GlassStyle _style;

  // Disable animations flag
  bool _disableAnimations = false;

  @override
  void initState() {
    super.initState();

    // Light flow: 4s repeating
    _lightFlowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    // Hover: 200ms easeOut
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    // Press: 150ms easeIn
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    // Entry: 400ms easeOut, play once
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shouldDisable = MediaQuery.of(context).disableAnimations;
    if (shouldDisable != _disableAnimations) {
      _disableAnimations = shouldDisable;
      if (_disableAnimations) {
        _lightFlowController.stop();
      } else if (widget.animate) {
        _lightFlowController.repeat();
      }
    }

    // Resolve effective tier (degrade to light when animations disabled)
    final effectiveTier = _disableAnimations ? GlassTier.light : widget.tier;

    // Update style when theme changes
    _style = GlassStyle.forTier(
      effectiveTier,
      Theme.of(context).brightness,
    );

    // Generate noise texture once (skip if animations disabled)
    if (_noiseImage == null && !_disableAnimations) {
      _generateNoiseTexture();
    }
  }

  @override
  void didUpdateWidget(GlassContainer oldWidget) {
    super.didUpdateWidget(oldWidget);

    final effectiveTier = _disableAnimations ? GlassTier.light : widget.tier;

    // Update style if tier changed
    if (oldWidget.tier != widget.tier || _disableAnimations) {
      _style = GlassStyle.forTier(
        effectiveTier,
        Theme.of(context).brightness,
      );
    }

    // Handle animation state changes
    if (oldWidget.animate != widget.animate) {
      if (widget.animate && !_disableAnimations) {
        _lightFlowController.repeat();
      } else {
        _lightFlowController.stop();
      }
    }
  }

  @override
  void dispose() {
    _lightFlowController.dispose();
    _hoverController.dispose();
    _pressController.dispose();
    _entryController.dispose();
    _noiseImage?.dispose();
    super.dispose();
  }

  Future<void> _generateNoiseTexture() async {
    final image = await generateNoiseImage(seed: 42);
    if (mounted) {
      setState(() {
        _noiseImage = image;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(widget.borderRadius);

    final content = _buildGlassLayers(borderRadius);

    if (widget.interactive) {
      return MouseRegion(
        onEnter: (_) => _handleHoverEnter(),
        onExit: (_) => _handleHoverExit(),
        child: GestureDetector(
          onTapDown: _handlePressDown,
          onTapUp: _handlePressUp,
          onTapCancel: _handlePressCancel,
          child: AnimatedScale(
            scale: _isPressed ? 0.98 : 1.0,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
            child: content,
          ),
        ),
      );
    }

    return content;
  }

  Widget _buildGlassLayers(BorderRadius borderRadius) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _entryController,
            if (!_disableAnimations) _lightFlowController,
            if (_isHovered && !_disableAnimations) _hoverController,
            if (_isPressed && !_disableAnimations) _pressController,
          ]),
          builder: (context, child) {
            final entryValue = _entryController.value;
            final currentSigma = _style.sigma * entryValue;
            final currentBorderOpacity = entryValue;

            return _buildLayer1Optical(
              borderRadius,
              currentSigma,
              currentBorderOpacity,
              child,
            );
          },
          child: widget.child,
        ),
      ),
    );
  }

  /// Layer 1: Optical - BackdropFilter with blur and saturation
  Widget _buildLayer1Optical(
    BorderRadius borderRadius,
    double sigma,
    double borderOpacity,
    Widget? child,
  ) {
    return BackdropFilter(
      filter: ui.ImageFilter.blur(
        sigmaX: sigma,
        sigmaY: sigma,
      ),
      child: _buildLayer2Material(
        borderRadius,
        sigma,
        borderOpacity,
        child,
      ),
    );
  }

  /// Layer 2: Material - Border, fill, shadows
  Widget _buildLayer2Material(
    BorderRadius borderRadius,
    double sigma,
    double borderOpacity,
    Widget? child,
  ) {
    final effectiveStyle = _getEffectiveStyle();

    return Container(
      decoration: BoxDecoration(
        color: effectiveStyle.fill,
        borderRadius: borderRadius,
        border: Border.all(
          width: 1.5,
          color: Colors.white.withValues(alpha: borderOpacity * 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: effectiveStyle.shadow,
            blurRadius: sigma / 2,
            offset: Offset(0, sigma / 4),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius - 1.5),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              effectiveStyle.borderTop.withValues(alpha: borderOpacity),
              effectiveStyle.borderBottom.withValues(alpha: borderOpacity * 0.25),
            ],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius - 1.5),
          child: _buildLayer3Specular(
            borderRadius,
            borderOpacity,
            child,
          ),
        ),
      ),
    );
  }

  /// Layer 3: Specular - Fresnel and moving highlight
  Widget _buildLayer3Specular(
    BorderRadius borderRadius,
    double borderOpacity,
    Widget? child,
  ) {
    final effectiveStyle = _getEffectiveStyle();

    return Stack(
      fit: StackFit.passthrough,
      children: [
        // Fresnel painter
        Positioned.fill(
          child: CustomPaint(
            painter: FresnelPainter(
              borderRadius: borderRadius,
              borderTopColor: effectiveStyle.borderTop,
              borderBottomColor: effectiveStyle.borderBottom,
              opacity: borderOpacity,
            ),
          ),
        ),
        // Specular highlight
        if (!_disableAnimations)
          Positioned.fill(
            child: CustomPaint(
              painter: SpecularPainter(
                animationValue: _lightFlowController.value,
                opacity: 0.05,
              ),
            ),
          ),
        _buildLayer4Dynamic(child),
      ],
    );
  }

  /// Layer 4: Dynamic - Noise and light flow
  Widget _buildLayer4Dynamic(Widget? child) {
    final effectiveStyle = _getEffectiveStyle();

    return Stack(
      children: [
        // Noise texture
        if (_noiseImage != null)
          Positioned.fill(
            child: Opacity(
              opacity: _disableAnimations ? 0.0 : effectiveStyle.noiseOpacity,
              child: CustomPaint(
                painter: NoisePainter(
                  noiseImage: _noiseImage,
                  opacity: effectiveStyle.noiseOpacity,
                ),
              ),
            ),
          ),
        // Light flow gradient sweep
        if (widget.animate && !_disableAnimations)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _lightFlowController,
              builder: (context, _) {
                final angle = _lightFlowController.value * 2 * math.pi;
                final isDark = Theme.of(context).brightness == Brightness.dark;
                final maxOpacity = isDark ? 0.06 : 0.04;
                final opacity = math.sin(_lightFlowController.value * math.pi) * maxOpacity;

                return Transform.rotate(
                  angle: angle,
                  child: Opacity(
                    opacity: opacity.clamp(0.0, 1.0),
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
              },
            ),
          ),
        // Tint overlay
        if (widget.tint != null)
          Positioned.fill(child: Container(color: widget.tint)),
        // Content layer
        _buildLayer5Content(child),
      ],
    );
  }

  /// Layer 5: Content
  Widget _buildLayer5Content(Widget? child) {
    return Padding(
      padding: widget.padding,
      child: child,
    );
  }

  GlassStyle _getEffectiveStyle() {
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
    _hoverController.forward();
  }

  void _handleHoverExit() {
    if (!_isHovered) return;
    setState(() {
      _isHovered = false;
    });
    _hoverController.reverse();
  }

  void _handlePressDown(TapDownDetails details) {
    if (_isPressed) return;
    setState(() {
      _isPressed = true;
    });
    _pressController.forward();
  }

  void _handlePressUp(TapUpDetails details) {
    if (!_isPressed) return;
    setState(() {
      _isPressed = false;
    });
    _pressController.reverse();
  }

  void _handlePressCancel() {
    if (!_isPressed) return;
    setState(() {
      _isPressed = false;
    });
    _pressController.reverse();
  }
}
