import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:personal_ai_assistant/core/widgets/top_floating_notice.dart';

class PlatformHelper {
  PlatformHelper._();

  static bool isIOS(BuildContext context) {
    if (kIsWeb) return false;
    return Theme.of(context).platform == TargetPlatform.iOS;
  }

  static bool isAndroid(BuildContext context) {
    if (kIsWeb) return false;
    return Theme.of(context).platform == TargetPlatform.android;
  }

  /// Returns true on macOS, Windows, or Linux.
  ///
  /// **Note:** Always returns false on web due to the [kIsWeb] guard,
  /// even when the browser viewport is wide. Use [Breakpoints] for
  /// width-based layout decisions on web.
  static bool isDesktop(BuildContext context) {
    if (kIsWeb) return false;
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.macOS ||
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux;
  }

  /// Returns true on iOS or Android.
  ///
  /// **Note:** Always returns false on web due to the [kIsWeb] guard.
  /// Windows and Linux receive Material (non-Apple) styling but are
  /// not considered "mobile" — use [isDesktop] for those platforms.
  static bool isMobile(BuildContext context) {
    return isIOS(context) || isAndroid(context);
  }

  static bool isMacOS(BuildContext context) {
    if (kIsWeb) return false;
    return Theme.of(context).platform == TargetPlatform.macOS;
  }

  static bool isApple(BuildContext context) {
    return isIOS(context) || isMacOS(context);
  }

  static T platformValue<T>(BuildContext context, {
    required T material,
    required T cupertino,
    T? desktop,
  }) {
    if (isDesktop(context) && desktop != null) return desktop;
    if (isApple(context)) return cupertino;
    return material;
  }

  /// Show adaptive feedback message.
  /// iOS: TopFloatingNotice. Android/desktop: SnackBar.
  static void showAdaptiveFeedback(
    BuildContext context, {
    required String message,
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (isApple(context)) {
      showTopFloatingNotice(
        context,
        message: message,
        isError: isError,
        duration: duration,
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: duration,
      ),
    );
  }
}
