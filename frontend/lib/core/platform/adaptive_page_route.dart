import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Creates a platform-adaptive page transition.
///
/// Uses `defaultTargetPlatform` instead of `Theme.of(context).platform`
/// because this function is called during route construction where no
/// [BuildContext] is available. This matches GoRouter's own pattern.
Page<T> adaptivePageTransition<T>({
  required Widget child,
  required ValueKey<String> pageKey,
  bool fullscreenDialog = false,
}) {
  if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
    return CupertinoPage<T>(
      key: pageKey,
      child: child,
      fullscreenDialog: fullscreenDialog,
    );
  }

  return MaterialPage<T>(
    key: pageKey,
    child: child,
    fullscreenDialog: fullscreenDialog,
  );
}
