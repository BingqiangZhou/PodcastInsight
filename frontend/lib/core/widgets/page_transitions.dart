import 'package:flutter/material.dart';

/// ============================================================
/// Arctic Garden Design System - 页面转场动画
///
/// 转场原则：
/// - 流畅自然：有机缓动曲线
/// - 方向感：清晰的导航方向
/// - 适度：不过于花哨，保持专业
/// ============================================================

/// Page transition types for the Arctic Garden design system
enum ArcticPageTransitionType {
  fade,
  slideRight,
  slideLeft,
  slideUp,
  slideDown,
  scale,
  fadeSlide,
  aurora,
}

/// ArcticPageRoute - 北极花园页面路由
///
/// 提供流畅、一致的页面转场效果
class ArcticPageRoute<T> extends PageRouteBuilder<T> {
  ArcticPageRoute({
    required this.page,
    this.transitionType = ArcticPageTransitionType.fadeSlide,
    super.transitionDuration = const Duration(milliseconds: 400),
    super.reverseTransitionDuration = const Duration(milliseconds: 320),
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
  final ArcticPageTransitionType transitionType;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Skip animation if explicitly disabled
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
    // Arctic Garden organic curve
    final curve = CurveTween(curve: Curves.easeOutQuart);
    final curvedAnimation = animation.drive(curve);

    switch (transitionType) {
      case ArcticPageTransitionType.fade:
        return FadeTransition(
          opacity: curvedAnimation,
          child: child,
        );

      case ArcticPageTransitionType.slideRight:
        return SlideTransition(
          position: curvedAnimation.drive(
            Tween<Offset>(
              begin: const Offset(-1.0, 0.0),
              end: Offset.zero,
            ),
          ),
          child: child,
        );

      case ArcticPageTransitionType.slideLeft:
        return SlideTransition(
          position: curvedAnimation.drive(
            Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ),
          ),
          child: child,
        );

      case ArcticPageTransitionType.slideUp:
        return SlideTransition(
          position: curvedAnimation.drive(
            Tween<Offset>(
              begin: const Offset(0.0, 1.0),
              end: Offset.zero,
            ),
          ),
          child: child,
        );

      case ArcticPageTransitionType.slideDown:
        return SlideTransition(
          position: curvedAnimation.drive(
            Tween<Offset>(
              begin: const Offset(0.0, -1.0),
              end: Offset.zero,
            ),
          ),
          child: child,
        );

      case ArcticPageTransitionType.scale:
        return ScaleTransition(
          scale: curvedAnimation.drive(
            Tween<double>(begin: 0.92, end: 1.0),
          ),
          child: FadeTransition(
            opacity: curvedAnimation,
            child: child,
          ),
        );

      case ArcticPageTransitionType.fadeSlide:
        return SlideTransition(
          position: curvedAnimation.drive(
            Tween<Offset>(
              begin: const Offset(0.04, 0.0),
              end: Offset.zero,
            ),
          ),
          child: FadeTransition(
            opacity: curvedAnimation,
            child: child,
          ),
        );

      case ArcticPageTransitionType.aurora:
        return _AuroraTransition(
          animation: animation,
          child: child,
        );
    }
  }
}

/// AuroraTransition - 极光效果转场
class _AuroraTransition extends StatelessWidget {
  const _AuroraTransition({
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final fadeAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutQuart,
    );

    final slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.03),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutQuart,
    ));

    final scaleAnimation = Tween<double>(begin: 0.98, end: 1.0).animate(
      CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutQuart,
      ),
    );

    return FadeTransition(
      opacity: fadeAnimation,
      child: SlideTransition(
        position: slideAnimation,
        child: ScaleTransition(
          scale: scaleAnimation,
          child: child,
        ),
      ),
    );
  }
}

/// ArcticTransitions - 预定义转场配置
class ArcticTransitions {
  ArcticTransitions._();

  /// Standard forward navigation (push)
  static ArcticPageTransitionType get forward => ArcticPageTransitionType.fadeSlide;

  /// Modal/bottom sheet style (push from bottom)
  static ArcticPageTransitionType get modal => ArcticPageTransitionType.slideUp;

  /// Dialog style (scale + fade)
  static ArcticPageTransitionType get dialog => ArcticPageTransitionType.scale;

  /// Simple fade (for subtle transitions)
  static ArcticPageTransitionType get subtle => ArcticPageTransitionType.fade;

  /// Quick transition for tabs/sections
  static ArcticPageTransitionType get quick => ArcticPageTransitionType.fade;

  /// Aurora effect for special pages
  static ArcticPageTransitionType get aurora => ArcticPageTransitionType.aurora;
}

/// AnimatedPageRoute - 带动画的页面路由
class AnimatedPageRoute<T> extends PageRouteBuilder<T> {
  AnimatedPageRoute({
    required Widget Function(BuildContext) builder,
    ArcticPageTransitionType transitionType = ArcticPageTransitionType.fadeSlide,
    Duration duration = const Duration(milliseconds: 400),
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionDuration: duration,
          reverseTransitionDuration: Duration(milliseconds: duration.inMilliseconds ~/ 2),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curve = CurveTween(curve: Curves.easeOutQuart);
            final curvedAnimation = animation.drive(curve);

            switch (transitionType) {
              case ArcticPageTransitionType.fade:
                return FadeTransition(
                  opacity: curvedAnimation,
                  child: child,
                );

              case ArcticPageTransitionType.fadeSlide:
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

              case ArcticPageTransitionType.scale:
                return ScaleTransition(
                  scale: curvedAnimation.drive(
                    Tween<double>(begin: 0.95, end: 1.0),
                  ),
                  child: FadeTransition(
                    opacity: curvedAnimation,
                    child: child,
                  ),
                );

              case ArcticPageTransitionType.slideUp:
                return SlideTransition(
                  position: curvedAnimation.drive(
                    Tween<Offset>(
                      begin: const Offset(0.0, 0.06),
                      end: Offset.zero,
                    ),
                  ),
                  child: FadeTransition(
                    opacity: curvedAnimation,
                    child: child,
                  ),
                );

              case ArcticPageTransitionType.aurora:
                return _AuroraTransition(
                  animation: animation,
                  child: child,
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

/// SharedAxisTransition - 共享轴转场
///
/// 用于具有空间关系的页面之间
class SharedAxisTransition extends StatelessWidget {
  const SharedAxisTransition({
    super.key,
    required this.animation,
    required this.child,
    this.type = SharedAxisTransitionType.horizontal,
  });

  final Animation<double> animation;
  final Widget child;
  final SharedAxisTransitionType type;

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutQuart,
    );

    Offset beginOffset;
    switch (type) {
      case SharedAxisTransitionType.horizontal:
        beginOffset = const Offset(0.08, 0.0);
        break;
      case SharedAxisTransitionType.vertical:
        beginOffset = const Offset(0.0, 0.08);
        break;
      case SharedAxisTransitionType.scaled:
        beginOffset = Offset.zero;
    }

    final fadeTransition = FadeTransition(
      opacity: curve,
      child: child,
    );

    if (type == SharedAxisTransitionType.scaled) {
      return ScaleTransition(
        scale: Tween<double>(begin: 0.9, end: 1.0).animate(curve),
        child: fadeTransition,
      );
    }

    return SlideTransition(
      position: Tween<Offset>(
        begin: beginOffset,
        end: Offset.zero,
      ).animate(curve),
      child: fadeTransition,
    );
  }
}

enum SharedAxisTransitionType {
  horizontal,
  vertical,
  scaled,
}

// Legacy compatibility - keep old names working
typedef AppPageRoute = ArcticPageRoute;
typedef AppPageTransitionType = ArcticPageTransitionType;
typedef AppTransitions = ArcticTransitions;
