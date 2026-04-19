import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive.dart';
import 'package:personal_ai_assistant/core/widgets/adaptive_sheet_helper.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_queue_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/queue/queue_controls_widget.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/queue/queue_empty_state_widget.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/queue/queue_list_widget.dart';

class PodcastQueueSheet extends ConsumerWidget {
  const PodcastQueueSheet({super.key});

  static const BorderRadius _sheetBorderRadius = BorderRadius.vertical(
    top: Radius.circular(28),
  );

  static Future<void>? _activeShowFuture;

  static Future<void> show(
    BuildContext context, {
    Future<void> Function()? beforeShow,
  }) {
    final existing = _activeShowFuture;
    if (existing != null) {
      return existing;
    }

    // Keep queue sheet opening idempotent even if multiple entry points race.
    late final Future<void> trackedFuture;
    trackedFuture =
        Future.sync(() async {
          if (beforeShow != null) {
            await beforeShow();
            if (!context.mounted) {
              return;
            }
          }
          await showAdaptiveSheet<void>(
            context: context,
            builder: (context) => const PodcastQueueSheet(),
          );
        }).whenComplete(() {
          if (identical(_activeShowFuture, trackedFuture)) {
            _activeShowFuture = null;
          }
        });

    _activeShowFuture = trackedFuture;
    return trackedFuture;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final title = l10n.queue_up_next;
    final queueAsync = ref.watch(podcastQueueControllerProvider);
    final queueOperation = ref.watch(podcastQueueOperationProvider);
    final queueSyncing = ref.watch(audioQueueSyncingProvider);
    final notifier = ref.read(podcastQueueControllerProvider.notifier);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final sheetHeightFactor = screenWidth >= 600 ? 0.80 : 0.82;
    final queue = queueAsync.asData?.value;
    final isOpeningLoad =
        queue == null &&
        (queueAsync.isLoading ||
            queueOperation.kind == QueueOperationKind.initialLoading ||
            queueOperation.kind == QueueOperationKind.refreshing);

    Widget body;
    if (isOpeningLoad) {
      body = _QueuePanel(
        title: title,
        itemCount: null,
        queueOperation: queueOperation,
        queueSyncing: queueSyncing,
        onRefresh: notifier.loadQueue,
        body: QueueLoadingState(
          title: l10n.podcast_queue_loading_title,
          subtitle: l10n.podcast_queue_loading_subtitle,
        ),
      );
    } else if (queue != null) {
      body = _QueuePanel(
        title: title,
        itemCount: queue.items.length,
        queueOperation: queueOperation,
        queueSyncing: queueSyncing,
        onRefresh: notifier.loadQueue,
        body: queue.items.isEmpty
            ? QueueEmptyStateList(
                icon: Icons.playlist_play,
                title: l10n.queue_is_empty,
                subtitle:
                    l10n.pull_to_refresh,
              )
            : QueueList(queue: queue),
      );
    } else {
      body = _QueuePanel(
        title: title,
        itemCount: null,
        queueOperation: queueOperation,
        queueSyncing: queueSyncing,
        onRefresh: notifier.loadQueue,
        body: QueueEmptyStateList(
          icon: Icons.error_outline,
          title: l10n.error,
          subtitle: l10n.failed_to_load_queue(queueAsync.error.toString()),
          action: FilledButton.tonalIcon(
            onPressed: notifier.loadQueue,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.retry),
          ),
        ),
      );
    }

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * sheetHeightFactor,
      child: ClipRRect(
        key: const Key('podcast_queue_sheet_surface'),
        borderRadius: _sheetBorderRadius,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.transparent,
              ],
            ),
          ),
          child: body,
        ),
      ),
    );
  }
}

class _QueuePanel extends StatelessWidget {
  const _QueuePanel({
    required this.title,
    required this.itemCount,
    required this.queueOperation,
    required this.queueSyncing,
    required this.onRefresh,
    required this.body,
  });

  final String title;
  final int? itemCount;
  final QueueOperationState queueOperation;
  final bool queueSyncing;
  final Future<void> Function() onRefresh;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          QueueHeader(
            title: title,
            itemCount: itemCount,
            queueOperation: queueOperation,
            queueSyncing: queueSyncing,
            onRefresh: onRefresh,
          ),
          Expanded(
            child: AdaptiveRefreshIndicator(onRefresh: onRefresh, child: body),
          ),
        ],
      ),
    );
  }
}
