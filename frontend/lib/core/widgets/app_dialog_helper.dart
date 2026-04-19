import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/platform/platform_helper.dart';

/// Show a dialog.
///
/// Example:
/// ```dart
/// showAppDialog(
///   context: context,
///   builder: (ctx) => AlertDialog(title: Text('Hello')),
/// );
/// ```
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool barrierDismissible = true,
  Color barrierColor = Colors.black54,
  double borderRadius = 28,
  bool useRootNavigator = false,
}) {
  if (PlatformHelper.isApple(context)) {
    return showCupertinoDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      useRootNavigator: useRootNavigator,
      builder: builder,
    );
  }
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: barrierColor,
    useRootNavigator: useRootNavigator,
    builder: (dialogCtx) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 560),
        decoration: BoxDecoration(
          color: Theme.of(dialogCtx).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: builder(dialogCtx),
      );
    },
  );
}

/// Show a simple confirmation dialog.
///
/// Returns `true` if confirmed, `false` if cancelled, `null` if dismissed.
///
/// Example:
/// ```dart
/// final confirmed = await showAppConfirmationDialog(
///   context: context,
///   title: 'Delete?',
///   message: 'This cannot be undone.',
///   isDestructive: true,
/// );
/// ```
Future<bool?> showAppConfirmationDialog({
  required BuildContext context,
  required String title,
  required String message,
  String? cancelText,
  String? confirmText,
  bool isDestructive = false,
  double borderRadius = 28,
}) {
  if (PlatformHelper.isApple(context)) {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (dialogCtx) => CupertinoAlertDialog(
        title: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(title),
        ),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(cancelText ?? 'Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: isDestructive,
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(confirmText ?? 'Confirm'),
          ),
        ],
      ),
    );
  }

  final theme = Theme.of(context);
  return showAppDialog<bool>(
    context: context,
    builder: (dialogCtx) {
      return Padding(
        padding: EdgeInsets.all(context.spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: theme.textTheme.headlineSmall,
            ),
            SizedBox(height: context.spacing.md),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: context.spacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(false),
                    child: Text(cancelText ?? 'Cancel'),
                  ),
                ),
                SizedBox(width: context.spacing.sm),
                Flexible(
                  child: TextButton(
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
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
