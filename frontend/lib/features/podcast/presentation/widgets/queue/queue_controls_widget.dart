import 'package:flutter/material.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';

import 'package:personal_ai_assistant/core/constants/app_radius.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_queue_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';

class QueueHeader extends StatelessWidget {
  const QueueHeader({
    super.key,
    required this.title,
    required this.itemCount,
    required this.queueOperation,
    required this.queueSyncing,
    required this.onRefresh,
  });

  final String title;
  final int? itemCount;
  final QueueOperationState queueOperation;
  final bool queueSyncing;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final statusLabel = queueStatusLabel(
      l10n,
      queueOperation: queueOperation,
      queueSyncing: queueSyncing,
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(context.spacing.md, context.spacing.smMd, context.spacing.smMd, context.spacing.smMd),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: context.spacing.xs, bottom: context.spacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      if (itemCount != null)
                        QueueInfoChip(
                          icon: Icons.queue_music_rounded,
                          label:
                              '${itemCount ?? 0} ${l10n.queue_in_queue}',
                        ),
                      if (itemCount != null && statusLabel != null)
                        SizedBox(width: context.spacing.sm),
                      if (statusLabel != null)
                        Flexible(
                          child: QueueInfoChip(
                            icon: Icons.sync_rounded,
                            label: statusLabel,
                            emphasized: true,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l10n.refresh,
                  onPressed: onRefresh,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.refresh),
                ),
                IconButton(
                  tooltip: l10n.close,
                  onPressed: () => Navigator.of(context).pop(),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class QueueInfoChip extends StatelessWidget {
  const QueueInfoChip({
    super.key,
    required this.icon,
    required this.label,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: context.spacing.sm, vertical: context.spacing.sm),
      decoration: BoxDecoration(
        color: emphasized
            ? theme.colorScheme.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: AppRadius.pillRadius,
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: theme.colorScheme.onSurfaceVariant),
          SizedBox(width: context.spacing.xs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Returns a human-readable status label for the current queue operation, or
/// `null` when the queue is idle and not syncing.
String? queueStatusLabel(
  AppLocalizations l10n, {
  required QueueOperationState queueOperation,
  required bool queueSyncing,
}) {
  switch (queueOperation.kind) {
    case QueueOperationKind.initialLoading:
      return l10n.loading;
    case QueueOperationKind.refreshing:
      return l10n.refreshing;
    case QueueOperationKind.reordering:
      return l10n.queue_saving_order;
    case QueueOperationKind.removing:
    case QueueOperationKind.activating:
      return l10n.queue_updating;
    case QueueOperationKind.idle:
      if (queueSyncing) {
        return l10n.queue_syncing;
      }
      return null;
  }
}
