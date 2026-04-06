import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_ai_assistant/core/glass/glass_container.dart';
import 'package:personal_ai_assistant/core/glass/glass_tokens.dart';
import 'package:personal_ai_assistant/core/providers/top_floating_notice_provider.dart';

const double _topFloatingNoticeGap = 0;

/// Show a floating notice at the top of the screen.
///
/// This function maintains backward compatibility while using the
/// topFloatingNoticeProvider for state management.
///
/// Example:
/// ```dart
/// showTopFloatingNotice(
///   context,
///   message: 'Operation completed successfully',
///   isError: false,
///   duration: const Duration(seconds: 3),
/// );
/// ```
void showTopFloatingNotice(
  BuildContext context, {
  required String message,
  bool isError = false,
  Duration duration = const Duration(seconds: 3),
  double extraTopOffset = 0,
}) {
  final container = ProviderScope.containerOf(context);
  final notifier = container.read(topFloatingNoticeProvider.notifier);

  _removeTopFloatingNotice(notifier);

  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) {
    return;
  }

  final theme = Theme.of(context);
  final topInset = MediaQuery.maybeOf(context)?.viewPadding.top ?? 0;
  final scaffold = Scaffold.maybeOf(context);
  final appBarHeight = scaffold?.widget.appBar?.preferredSize.height;
  final effectiveTopBarHeight =
      appBarHeight ?? (scaffold == null ? kToolbarHeight : 0);
  final foregroundColor = isError
      ? theme.colorScheme.onErrorContainer
      : theme.colorScheme.onSurface;
  final icon = isError ? Icons.error_outline : Icons.check_circle_outline;

  final entry = OverlayEntry(
    builder: (_) => Positioned(
      left: 16,
      right: 16,
      top:
          topInset +
          effectiveTopBarHeight +
          extraTopOffset +
          _topFloatingNoticeGap,
      child: IgnorePointer(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: GlassContainer(
              key: const Key('top_floating_notice'),
              tier: GlassTier.standard,
              borderRadius: 12,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              tint: isError ? theme.colorScheme.error.withValues(alpha: 0.08) : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: foregroundColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      key: const Key('top_floating_notice_message'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: foregroundColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  notifier.showNotice(entry: entry, duration: duration);
  overlay.insert(entry);
}

/// Internal function to remove the current floating notice
void _removeTopFloatingNotice(TopFloatingNoticeNotifier notifier) {
  notifier.hideNotice();
}
