import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

/// Adaptive haptic feedback that provides platform-aware vibration.
///
/// iOS uses native HapticFeedback API.
/// Android uses light vibration or skips haptic (Android vibration requires permissions).
class AdaptiveHaptic {
  AdaptiveHaptic._();

  /// Light impact feedback for subtle interactions.
  ///
  /// Use for: tab switching, list item taps, slider movements.
  static void lightImpact(BuildContext context) {
    if (!Platform.isIOS) return;
    try {
      HapticFeedback.lightImpact();
    } catch (_) {
      // Silently ignore haptic errors
    }
  }

  /// Medium impact feedback for confirmations.
  ///
  /// Use for: like/favorite actions, download completion, successful operations.
  static void mediumImpact(BuildContext context) {
    if (!Platform.isIOS) return;
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {
      // Silently ignore haptic errors
    }
  }

  /// Heavy impact feedback for important actions.
  ///
  /// Use for: delete actions, major confirmations.
  static void heavyImpact(BuildContext context) {
    if (!Platform.isIOS) return;
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {
      // Silently ignore haptic errors
    }
  }

  /// Selection click feedback for precise interactions.
  ///
  /// Use for: slider tick marks, picker selections.
  static void selectionClick(BuildContext context) {
    if (!Platform.isIOS) return;
    try {
      HapticFeedback.selectionClick();
    } catch (_) {
      // Silently ignore haptic errors
    }
  }

  /// Notification success feedback.
  ///
  /// Use for: login success, subscription confirmations.
  static void notificationSuccess(BuildContext context) {
    if (!Platform.isIOS) return;
    // Fallback to medium impact for success notifications
    mediumImpact(context);
  }
}
