import 'package:flutter/material.dart';

/// ============================================================
/// Stella Design System - Page Transitions
///
/// Simple, fast fade transitions for consistent navigation.
/// ============================================================

/// Page transition types for the Stella design system
enum StellaPageTransitionType {
  fade,
}

/// StellaPageRoute - Simple page route with fade transition
///
/// Provides fast, consistent 150ms fade transitions.
class StellaPageRoute<T> extends PageRouteBuilder<T> {
  StellaPageRoute({
    required this.page,
    this.transitionType = StellaPageTransitionType.fade,
    super.settings,
    super.maintainState = true,
    super.fullscreenDialog = false,
    super.opaque = true,
    super.barrierDismissible = false,
    super.barrierColor,
    super.barrierLabel,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 150),
          reverseTransitionDuration: const Duration(milliseconds: 150),
        );

  final Widget page;
  final StellaPageTransitionType transitionType;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Skip animation if explicitly disabled
    final args = settings.arguments;
    if (args is Map &&
        args.containsKey('disableTransitions') &&
        args['disableTransitions'] == true) {
      return child;
    }

    return _buildTransition(animation, child);
  }

  Widget _buildTransition(
    Animation<double> animation,
    Widget child,
  ) {
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOut,
    );

    switch (transitionType) {
      case StellaPageTransitionType.fade:
        return FadeTransition(
          opacity: curvedAnimation,
          child: child,
        );
    }
  }
}

/// StellaTransitions - Predefined transition configurations
class StellaTransitions {
  StellaTransitions._();

  /// Standard fade transition
  static StellaPageTransitionType get standard => StellaPageTransitionType.fade;

  /// Modal/bottom sheet style (same as standard for simplicity)
  static StellaPageTransitionType get modal => StellaPageTransitionType.fade;

  /// Dialog style (same as standard for simplicity)
  static StellaPageTransitionType get dialog => StellaPageTransitionType.fade;

  /// Subtle transition
  static StellaPageTransitionType get subtle => StellaPageTransitionType.fade;

  /// Quick transition for tabs/sections
  static StellaPageTransitionType get quick => StellaPageTransitionType.fade;
}
