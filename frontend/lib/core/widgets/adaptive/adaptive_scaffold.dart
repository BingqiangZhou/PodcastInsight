import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:personal_ai_assistant/core/platform/platform_helper.dart';

/// Adaptive scaffold: CupertinoPageScaffold on iOS, Scaffold on Android.
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({
    super.key,
    this.navigationBar,
    this.child,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
    this.bottomNavigationBar,
    this.floatingActionButton,
  });

  /// Navigation bar. On iOS, expects a [CupertinoNavigationBar].
  /// On other platforms, expects an [AppBar] (PreferredSizeWidget).
  final Widget? navigationBar;

  /// Page body content.
  final Widget? child;

  /// Background color. Defaults to system background on both platforms.
  final Color? backgroundColor;

  /// Whether to resize when the keyboard appears.
  final bool? resizeToAvoidBottomInset;

  /// Bottom navigation bar. Layered via Stack on iOS.
  final Widget? bottomNavigationBar;

  /// Floating action button. Layered via Stack on iOS.
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    if (PlatformHelper.isApple(context)) {
      final cupertinoNav = navigationBar is CupertinoNavigationBar
          ? navigationBar as CupertinoNavigationBar?
          : null;
      final needsStack = bottomNavigationBar != null || floatingActionButton != null;
      final body = child ?? const SizedBox.shrink();
      return CupertinoPageScaffold(
        navigationBar: cupertinoNav,
        child: needsStack
            ? Stack(
                children: [
                  body,
                  if (bottomNavigationBar != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: bottomNavigationBar!,
                    ),
                  if (floatingActionButton != null)
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: floatingActionButton!,
                    ),
                ],
              )
            : body,
        backgroundColor: backgroundColor,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset ?? true,
      );
    }

    final appBar = navigationBar is PreferredSizeWidget
        ? navigationBar as PreferredSizeWidget?
        : null;
    return Scaffold(
      appBar: appBar,
      body: child,
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset ?? true,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}
