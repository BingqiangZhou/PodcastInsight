import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

CustomTransitionPage<T> adaptivePageTransition<T>({
  required Widget child,
  required ValueKey<String> pageKey,
  bool fullscreenDialog = false,
}) {
  return CustomTransitionPage<T>(
    key: pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final platform = Theme.of(context).platform;
      final isIOS = platform == TargetPlatform.iOS;

      if (isIOS) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.linearToEaseOut,
          reverseCurve: Curves.easeInToLinear,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: child,
        );
      }

      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      );
      return FadeTransition(
        opacity: curvedAnimation,
        child: child,
      );
    },
  );
}
