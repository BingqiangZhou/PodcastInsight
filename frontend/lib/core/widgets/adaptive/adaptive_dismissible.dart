import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/constants/app_text_styles.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
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
    if (PlatformHelper.isApple(context)) {
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
        dismissThresholds: const {
          DismissDirection.endToStart: 0.5,
          DismissDirection.startToEnd: 0.5,
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
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: AppSpacing.mdLg),
        child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onError),
      ),
      child: child,
    );
  }

  Widget _buildDeleteBackground(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.error,
      alignment: AlignmentDirectional.centerEnd,
      padding: const EdgeInsetsDirectional.only(end: AppSpacing.mdLg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.delete, color: scheme.onError),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            l10n.delete,
            style: AppTextStyles.metaSmall(scheme.onError),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryBackground(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final color = secondaryActionColor ?? scheme.primary;
    final label = secondaryActionLabel ?? l10n.more;
    final onActionColor = secondaryActionColor != null
        ? color.computeLuminance() > 0.5 ? Colors.black : Colors.white
        : scheme.onPrimary;
    return Container(
      color: color,
      alignment: AlignmentDirectional.centerStart,
      padding: const EdgeInsetsDirectional.only(start: AppSpacing.mdLg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.ellipsis, color: onActionColor),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            style: AppTextStyles.metaSmall(onActionColor),
          ),
        ],
      ),
    );
  }
}
