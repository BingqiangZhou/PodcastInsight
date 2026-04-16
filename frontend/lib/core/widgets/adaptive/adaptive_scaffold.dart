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

  /// Navigation bar. On iOS, pass a CupertinoNavigationBar or null.
  /// On Android, pass an AppBar or null.
  final Widget? navigationBar;

  /// Page body content.
  final Widget? child;

  /// Background color. Defaults to system background on both platforms.
  final Color? backgroundColor;

  /// Whether to resize when the keyboard appears.
  final bool? resizeToAvoidBottomInset;

  /// Bottom navigation bar (Android only meaningful, iOS can use it too).
  final Widget? bottomNavigationBar;

  /// Floating action button (Android-specific concept, ignored on iOS).
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    if (PlatformHelper.isIOS(context)) {
      return CupertinoPageScaffold(
        navigationBar: navigationBar as CupertinoNavigationBar?,
        child: child ?? const SizedBox.shrink(),
        backgroundColor: backgroundColor,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset ?? true,
      );
    }

    return Scaffold(
      appBar: navigationBar as PreferredSizeWidget?,
      body: child,
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset ?? true,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}
