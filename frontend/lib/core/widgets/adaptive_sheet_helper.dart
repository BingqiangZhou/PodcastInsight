import 'package:flutter/material.dart';

import 'package:personal_ai_assistant/core/glass/glass_container.dart';
import 'package:personal_ai_assistant/core/glass/glass_tokens.dart';
import 'package:personal_ai_assistant/core/router/app_router.dart';

/// On desktop/tablet (width >= 600), shows a centred [Dialog] within the
/// current navigator's content area.  On mobile shows a standard
/// [showModalBottomSheet].
///
/// Both variants wrap content in [GlassContainer] for a glass effect.
/// Returns the value produced by the builder (if any).
Future<T?> showAdaptiveSheet<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool isScrollControlled = true,
  bool showDragHandle = true,
  bool useSafeArea = true,
  double desktopMaxWidth = 560,
  double desktopMaxHeightFraction = 0.85,
}) {
  final fallbackContext = appNavigatorKey.currentContext;
  final resolvedContext = Navigator.maybeOf(context) != null
      ? context
      : fallbackContext;
  if (resolvedContext == null) {
    return Future<T?>.value();
  }

  final screenWidth = MediaQuery.of(resolvedContext).size.width;

  if (screenWidth >= 600) {
    // Desktop / tablet -> centred dialog with glass container.
    return showDialog<T>(
      context: resolvedContext,
      barrierColor: Colors.black54,
      builder: (dialogCtx) {
        final size = MediaQuery.of(dialogCtx).size;
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: desktopMaxWidth,
              maxHeight: size.height * desktopMaxHeightFraction,
            ),
            child: GlassContainer(
              tier: GlassTier.overlay,
              borderRadius: 28,
              padding: EdgeInsets.zero,
              child: builder(dialogCtx),
            ),
          ),
        );
      },
    );
  }

  // Mobile -> bottom sheet with glass container.
  return showModalBottomSheet<T>(
    context: resolvedContext,
    isScrollControlled: isScrollControlled,
    showDragHandle: showDragHandle,
    useSafeArea: useSafeArea,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetCtx) {
      return GlassContainer(
        tier: GlassTier.overlay,
        borderRadius: 28,
        padding: EdgeInsets.zero,
        child: builder(sheetCtx),
      );
    },
  );
}
