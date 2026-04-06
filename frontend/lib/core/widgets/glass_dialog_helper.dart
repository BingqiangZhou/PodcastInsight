import 'package:flutter/material.dart';

import 'package:personal_ai_assistant/core/glass/glass_container.dart';
import 'package:personal_ai_assistant/core/glass/glass_tokens.dart';

/// Show a dialog wrapped in [GlassContainer] for a glass effect.
///
/// This is the glass counterpart to [showAdaptiveSheet] for dialog surfaces.
/// The builder's return value is automatically wrapped in a [GlassContainer].
///
/// Example:
/// ```dart
/// showGlassDialog(
///   context: context,
///   builder: (ctx) => AlertDialog(title: Text('Hello')),
/// );
/// ```
Future<T?> showGlassDialog<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool barrierDismissible = true,
  Color barrierColor = Colors.black54,
  GlassTier tier = GlassTier.overlay,
  double borderRadius = 28,
  bool useRootNavigator = false,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    useRootNavigator: useRootNavigator,
    builder: (dialogCtx) {
      return GlassContainer(
        tier: tier,
        borderRadius: borderRadius,
        padding: EdgeInsets.zero,
        child: builder(dialogCtx),
      );
    },
  );
}

/// Show a simple confirmation dialog with glass effect.
///
/// Returns `true` if confirmed, `false` if cancelled, `null` if dismissed.
///
/// Example:
/// ```dart
/// final confirmed = await showGlassConfirmationDialog(
///   context: context,
///   title: 'Delete?',
///   message: 'This cannot be undone.',
///   isDestructive: true,
/// );
/// ```
Future<bool?> showGlassConfirmationDialog({
  required BuildContext context,
  required String title,
  required String message,
  String? cancelText,
  String? confirmText,
  bool isDestructive = false,
  GlassTier tier = GlassTier.overlay,
  double borderRadius = 28,
}) {
  final theme = Theme.of(context);
  return showGlassDialog<bool>(
    context: context,
    tier: tier,
    borderRadius: borderRadius,
    builder: (dialogCtx) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(false),
                  child: Text(cancelText ?? 'Cancel'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(true),
                  style: isDestructive
                      ? TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                        )
                      : null,
                  child: Text(
                    confirmText ?? 'Confirm',
                    style: isDestructive
                        ? TextStyle(color: theme.colorScheme.error)
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
