import 'package:flutter/material.dart';

/// Custom page transition types for the app.
enum AppPageTransitionType {
  fade,
  slideRight,
  slideLeft,
  slideUp,
  slideDown,
  scale,
  fadeSlide,
}

/// A custom page route that provides smooth, consistent transitions.
class AppPageRoute<T> extends PageRouteBuilder<T> {
  AppPageRoute({
    required this.page,
    this.transitionType = AppPageTransitionType.fadeSlide,
    super.transitionDuration = const Duration(milliseconds: 350), // 极简风格：稍长，更流畅
    super.reverseTransitionDuration = const Duration(milliseconds: 280),
    super.settings,
    super.maintainState = true,
    super.fullscreenDialog = false,
    super.opaque = true,
    super.barrierDismissible = false,
    super.barrierColor,
    super.barrierLabel,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
        );

  final Widget page;
  final AppPageTransitionType transitionType;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Skip animation if the platform doesn't support it
    if (settings.arguments is Map &&
        (settings.arguments as Map).containsKey('disableTransitions') &&
        (settings.arguments as Map)['disableTransitions'] == true) {
      return child;
    }

    return _buildTransition(animation, secondaryAnimation, child);
  }

  Widget _buildTransition(
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // 极简风格：使用更自然的缓动曲线
    final curve = CurveTween(curve: Curves.easeOutExpo);
    final curvedAnimation = animation.drive(curve);

    switch (transitionType) {
      case AppPageTransitionType.fade:
        return FadeTransition(
          opacity: curvedAnimation,
          child: child,
        );

      case AppPageTransitionType.slideRight:
        return SlideTransition(
          position: curvedAnimation.drive(
            Tween<Offset>(
              begin: const Offset(-1.0, 0.0),
              end: Offset.zero,
            ),
          ),
          child: child,
        );

      case AppPageTransitionType.slideLeft:
        return SlideTransition(
          position: curvedAnimation.drive(
            Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ),
          ),
          child: child,
        );

      case AppPageTransitionType.slideUp:
        return SlideTransition(
          position: curvedAnimation.drive(
            Tween<Offset>(
              begin: const Offset(0.0, 1.0),
              end: Offset.zero,
            ),
          ),
          child: child,
        );

      case AppPageTransitionType.slideDown:
        return SlideTransition(
          position: curvedAnimation.drive(
            Tween<Offset>(
              begin: const Offset(0.0, -1.0),
              end: Offset.zero,
            ),
          ),
          child: child,
        );

      case AppPageTransitionType.scale:
        return ScaleTransition(
          scale: curvedAnimation.drive(
            Tween<double>(begin: 0.92, end: 1.0),
          ),
          child: FadeTransition(
            opacity: curvedAnimation,
            child: child,
          ),
        );

      case AppPageTransitionType.fadeSlide:
        return SlideTransition(
          position: curvedAnimation.drive(
            Tween<Offset>(
              begin: const Offset(0.03, 0.0),
              end: Offset.zero,
            ),
          ),
          child: FadeTransition(
            opacity: curvedAnimation,
            child: child,
          ),
        );
    }
  }
}

/// Predefined transition configurations for common use cases.
class AppTransitions {
  AppTransitions._();

  /// Standard forward navigation (push).
  static AppPageTransitionType get forward => AppPageTransitionType.fadeSlide;

  /// Modal/bottom sheet style (push from bottom).
  static AppPageTransitionType get modal => AppPageTransitionType.slideUp;

  /// Dialog style (scale + fade).
  static AppPageTransitionType get dialog => AppPageTransitionType.scale;

  /// Simple fade (for subtle transitions).
  static AppPageTransitionType get subtle => AppPageTransitionType.fade;

  /// Quick transition for tabs/sections.
  static AppPageTransitionType get quick => AppPageTransitionType.fade;
}

/// Animated page route that supports hero-style animations with custom transitions.
class AnimatedPageRoute<T> extends PageRouteBuilder<T> {
  AnimatedPageRoute({
    required Widget Function(BuildContext) builder,
    AppPageTransitionType transitionType = AppPageTransitionType.fadeSlide,
    Duration duration = const Duration(milliseconds: 350), // 极简风格：稍长，更流畅
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionDuration: duration,
          reverseTransitionDuration: Duration(milliseconds: duration.inMilliseconds ~/ 2),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // 极简风格：使用更自然的缓动曲线
            final curve = CurveTween(curve: Curves.easeOutExpo);
            final curvedAnimation = animation.drive(curve);

            switch (transitionType) {
              case AppPageTransitionType.fade:
                return FadeTransition(
                  opacity: curvedAnimation,
                  child: child,
                );

              case AppPageTransitionType.fadeSlide:
                return SlideTransition(
                  position: curvedAnimation.drive(
                    Tween<Offset>(
                      begin: const Offset(0.02, 0.0),
                      end: Offset.zero,
                    ),
                  ),
                  child: FadeTransition(
                    opacity: curvedAnimation,
                    child: child,
                  ),
                );

              case AppPageTransitionType.scale:
                return ScaleTransition(
                  scale: curvedAnimation.drive(
                    Tween<double>(begin: 0.95, end: 1.0),
                  ),
                  child: FadeTransition(
                    opacity: curvedAnimation,
                    child: child,
                  ),
                );

              case AppPageTransitionType.slideUp:
                return SlideTransition(
                  position: curvedAnimation.drive(
                    Tween<Offset>(
                      begin: const Offset(0.0, 0.05),
                      end: Offset.zero,
                    ),
                  ),
                  child: FadeTransition(
                    opacity: curvedAnimation,
                    child: child,
                  ),
                );

              default:
                return FadeTransition(
                  opacity: curvedAnimation,
                  child: child,
                );
            }
          },
        );
}
