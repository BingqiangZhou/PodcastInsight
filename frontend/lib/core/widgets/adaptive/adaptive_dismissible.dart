import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:personal_ai_assistant/core/platform/platform_helper.dart';

/// Adaptive dismissible with platform-specific swipe actions.
///
/// iOS: Swipe actions with colored backgrounds (red delete, blue more).
/// Android: Material [Dismissible] with background.
class AdaptiveDismissible extends StatelessWidget {
  const AdaptiveDismissible({
    required this.key,
    required this.child,
    required this.onDelete,
    this.onSecondaryAction,
    this.secondaryActionLabel,
    this.secondaryActionColor,
    this.confirmDismiss,
  });

  @override
  final Key key;

  final Widget child;
  final VoidCallback onDelete;
  final VoidCallback? onSecondaryAction;
  final String? secondaryActionLabel;
  final Color? secondaryActionColor;
  final ConfirmDismissCallback? confirmDismiss;

  @override
  Widget build(BuildContext context) {
    if (PlatformHelper.isIOS(context)) {
      return Dismissible(
        key: key,
        confirmDismiss: confirmDismiss ??
            (direction) async {
              if (direction == DismissDirection.endToStart) {
                onDelete();
              } else if (direction == DismissDirection.startToEnd &&
                  onSecondaryAction != null) {
                onSecondaryAction!();
              }
              return false; // Don't actually dismiss, just trigger action
            },
        background: _buildSecondaryBackground(context),
        secondaryBackground: _buildDeleteBackground(context),
        child: child,
      );
    }

    return Dismissible(
      key: key,
      confirmDismiss: confirmDismiss,
      onDismissed: (_) => onDelete(),
      background: Container(
        color: Theme.of(context).colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onError),
      ),
      child: child,
    );
  }

  Widget _buildDeleteBackground(BuildContext context) {
    return Container(
      color: CupertinoColors.systemRed,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.delete, color: CupertinoColors.white),
          SizedBox(height: 2),
          Text(
            '删除',
            style: TextStyle(
              color: CupertinoColors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryBackground(BuildContext context) {
    final color = secondaryActionColor ?? CupertinoColors.activeBlue;
    final label = secondaryActionLabel ?? '更多';
    return Container(
      color: color,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.ellipsis, color: CupertinoColors.white),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: CupertinoColors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
