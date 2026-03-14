import 'package:flutter/material.dart';

import '../constants/breakpoints.dart';

class ResponsiveDialogHelper {
  const ResponsiveDialogHelper._();

  static double maxWidth(
    BuildContext context, {
    double desktopMaxWidth = 560,
    double mobileHorizontalMargin = 16,
  }) {
    if (!context.isMobile) {
      return desktopMaxWidth;
    }
    final horizontalInset = mobileHorizontalMargin * 2;
    return context.screenWidth - horizontalInset;
  }

  static EdgeInsets insetPadding({double all = 16}) => EdgeInsets.all(all);

  static Color iconColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  static ButtonStyle actionButtonStyle(BuildContext context) =>
      TextButton.styleFrom(foregroundColor: iconColor(context));

  static ButtonStyle segmentedButtonStyle(BuildContext context) =>
      SegmentedButton.styleFrom(selectedForegroundColor: iconColor(context));
}
