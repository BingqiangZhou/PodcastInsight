import 'package:flutter/foundation.dart';

/// Utility class for detecting device performance capabilities.
///
/// Used to conditionally enable/disable performance-intensive effects
/// like blur filters and complex animations on lower-end devices.
class DevicePerformance {
  DevicePerformance._();

  /// Performance tier levels
  static PerformanceTier _tier = PerformanceTier.unknown;

  /// Whether blur effects should be enabled.
  static bool get enableBlurEffects => _tier != PerformanceTier.low;

  /// Whether complex animations should be enabled.
  static bool get enableComplexAnimations =>
      _tier == PerformanceTier.high || _tier == PerformanceTier.medium;

  /// Whether glassmorphism effects should be enabled.
  static bool get enableGlassmorphism => _tier != PerformanceTier.low;

  /// Whether decorative orbs should be rendered.
  /// Only primary orb on low-end devices.
  static bool get enableDecorativeOrbs => _tier != PerformanceTier.low;

  /// Get the current performance tier.
  static PerformanceTier get tier => _tier;

  /// Initialize performance detection.
  ///
  /// This should be called once at app startup.
  static Future<void> initialize() async {
    if (_tier != PerformanceTier.unknown) {
      return;
    }

    // Detect based on platform
    if (kIsWeb) {
      // Web may have varying performance
      _tier = PerformanceTier.medium;
      return;
    }

    if (kDebugMode) {
      // Debug mode may be slower, use medium tier
      _tier = PerformanceTier.medium;
      return;
    }

    // For mobile/desktop, we use heuristics
    // In production, you would use more sophisticated detection
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      // Mobile devices - default to medium, could be refined with device info
      _tier = PerformanceTier.medium;
    } else {
      // Desktop platforms - assume high performance
      _tier = PerformanceTier.high;
    }
  }

  /// Manually set the performance tier.
  ///
  /// Use this for testing or if you have custom device detection.
  static void setTier(PerformanceTier tier) {
    _tier = tier;
  }

  /// Check if the device is likely a low-end device.
  ///
  /// This is a heuristic based on platform and debug mode.
  static bool get isLowEndDevice => _tier == PerformanceTier.low;
}

/// Performance tier levels for device capabilities.
enum PerformanceTier {
  /// Performance tier not yet detected.
  unknown,

  /// Low-end device (older mobile devices, low memory)
  low,

  /// Medium-end device (most modern mobile devices)
  medium,

  /// High-end device (desktop, tablets, flagship phones)
  high,
}
