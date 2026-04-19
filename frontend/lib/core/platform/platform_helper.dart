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

  static bool isDesktop(BuildContext context) {
    if (kIsWeb) return false;
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.macOS ||
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux;
  }

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
