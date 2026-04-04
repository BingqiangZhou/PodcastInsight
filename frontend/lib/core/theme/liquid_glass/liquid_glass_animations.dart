import 'package:flutter/material.dart';

/// Liquid Glass Animation Controllers
/// Manages all glass-related animations including light flow, hover, press, and entry effects.
class LiquidGlassAnimationController {
  /// Create animation controllers with the given TickerProvider
  factory LiquidGlassAnimationController.create(TickerProvider vsync) {
    return LiquidGlassAnimationController._(vsync);
  }

  LiquidGlassAnimationController._(this._vsync) {
    _initializeControllers();
  }

  final TickerProvider _vsync;

  late final AnimationController _lightFlowController;
  late final AnimationController _hoverController;
  late final AnimationController _pressController;
  late final AnimationController _entryController;

  bool _entryAnimationPlayed = false;

  void _initializeControllers() {
    // Light flow: 3s cycle, continuous rotation
    _lightFlowController = AnimationController(
      vsync: _vsync,
      duration: const Duration(milliseconds: 3000),
    );

    // Hover: 200ms ease out for border light boost
    _hoverController = AnimationController(
      vsync: _vsync,
      duration: const Duration(milliseconds: 200),
    );

    // Press: 150ms ease in for scale down and blur boost
    _pressController = AnimationController(
      vsync: _vsync,
      duration: const Duration(milliseconds: 150),
    );

    // Entry: 400ms fade in for blur and border light
    _entryController = AnimationController(
      vsync: _vsync,
      duration: const Duration(milliseconds: 400),
    );
  }

  /// Get the light flow animation (0.0 to 1.0, repeating)
  /// Use this to drive gradient angle rotation
  Animation<double> get lightFlow => _lightFlowController;

  /// Get the hover animation (0.0 to 1.0)
  /// Drives border light intensity and blur delta
  Animation<double> get hover => _hoverController;

  /// Get the press animation (0.0 to 1.0)
  /// Drives scale and blur boost
  Animation<double> get press => _pressController;

  /// Get the entry animation (0.0 to 1.0)
  /// Drives blur fade in and border light fade in
  Animation<double> get entry => _entryController;

  /// Start the continuous light flow animation
  void startLightFlow() {
    _lightFlowController.repeat();
  }

  /// Stop the light flow animation
  void stopLightFlow() {
    _lightFlowController.stop();
  }

  /// Trigger hover effect (forward animation)
  void hoverIn() {
    _hoverController.forward();
  }

  /// End hover effect (reverse animation)
  void hoverOut() {
    _hoverController.reverse();
  }

  /// Trigger press effect (forward animation)
  void pressDown() {
    _pressController.forward();
  }

  /// End press effect (reverse animation)
  void pressUp() {
    _pressController.reverse();
  }

  /// Play entry animation once (call on first build)
  void playEntryAnimation() {
    if (!_entryAnimationPlayed) {
      _entryAnimationPlayed = true;
      _entryController.forward();
    }
  }

  /// Check if entry animation has been played
  bool get hasPlayedEntryAnimation => _entryAnimationPlayed;

  /// Reset entry animation flag (for testing or rebuild scenarios)
  void resetEntryAnimation() {
    _entryAnimationPlayed = false;
    _entryController.reset();
  }

  /// Dispose all controllers
  void dispose() {
    _lightFlowController.dispose();
    _hoverController.dispose();
    _pressController.dispose();
    _entryController.dispose();
  }
}

/// Curved animation helpers for glass effects
class LiquidGlassCurves {
  /// Light flow curve: smooth ease in-out for continuous rotation
  static const Curve lightFlow = Curves.easeInOut;

  /// Hover curve: quick ease out for responsive feel
  static const Curve hover = Curves.easeOut;

  /// Press curve: sharp ease in for tactile response
  static const Curve press = Curves.easeIn;

  /// Entry curve: gentle ease out for smooth appearance
  static const Curve entry = Curves.easeOut;

  /// Entry curve for border light (slightly slower for fade-in effect)
  static const Curve entryBorder = Curves.easeOutCubic;
}

/// Animation value helpers for interpolated effects
class LiquidGlassAnimations {
  /// Create curved animation for light flow
  static Animation<double> lightFlow(Animation<double> parent) {
    return CurvedAnimation(
      parent: parent,
      curve: LiquidGlassCurves.lightFlow,
    );
  }

  /// Create curved animation for hover
  static Animation<double> hover(Animation<double> parent) {
    return CurvedAnimation(
      parent: parent,
      curve: LiquidGlassCurves.hover,
    );
  }

  /// Create curved animation for press
  static Animation<double> press(Animation<double> parent) {
    return CurvedAnimation(
      parent: parent,
      curve: LiquidGlassCurves.press,
    );
  }

  /// Create curved animation for entry
  static Animation<double> entry(Animation<double> parent) {
    return CurvedAnimation(
      parent: parent,
      curve: LiquidGlassCurves.entry,
    );
  }

  /// Interpolate blur sigma during entry animation
  /// [targetSigma] is the final blur value
  static double entryBlur(double animationValue, double targetSigma) {
    return targetSigma * animationValue;
  }

  /// Interpolate border opacity during entry animation
  /// [targetOpacity] is the final opacity (0.0-1.0)
  static double entryBorderOpacity(double animationValue, double targetOpacity) {
    return targetOpacity * animationValue;
  }

  /// Interpolate scale during press animation
  /// Scales from 1.0 to 0.98
  static double pressScale(double animationValue) {
    return 1.0 - (0.02 * animationValue);
  }

  /// Interpolate border light during hover animation
  /// Boosts from base opacity to 1.5x base opacity
  static double hoverBorderLight(double animationValue, double baseOpacity) {
    return baseOpacity * (1.0 + (0.5 * animationValue));
  }

  /// Calculate light flow angle (0 to 2pi)
  static double lightFlowAngle(double animationValue) {
    return animationValue * 2 * 3.14159;
  }

  /// Interpolate light flow opacity (3-6% for dark, 2-4% for light)
  static double lightFlowOpacity(double animationValue, double maxOpacity) {
    // Create a subtle pulse effect using sine wave
    final pulse = (1 + (animationValue * 2 - 1) * 0.3); // 0.7 to 1.3
    return maxOpacity * pulse;
  }
}
