import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_ai_assistant/core/theme/app_theme.dart';
import 'package:personal_ai_assistant/core/constants/scroll_constants.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/utils/time_formatter.dart';
import 'package:personal_ai_assistant/core/widgets/adaptive_sheet_helper.dart';
import 'package:personal_ai_assistant/core/widgets/top_floating_notice.dart';
import 'package:personal_ai_assistant/shared/widgets/loading_widget.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_queue_model.dart';
import 'package:personal_ai_assistant/core/services/download_provider.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/constants/podcast_ui_constants.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/podcast_image_widget.dart';

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
    final l10n = AppLocalizations.of(context);
    final title = l10n?.queue_up_next ?? l10n?.podcast_player_list ?? 'Up Next';
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
        onRefresh: () => notifier.loadQueue(),
        body: _QueueLoadingState(
          title: l10n?.podcast_queue_loading_title ?? 'Loading',
          subtitle: l10n?.podcast_queue_loading_subtitle ?? 'Please wait...',
        ),
      );
    } else if (queue != null) {
      body = _QueuePanel(
        title: title,
        itemCount: queue.items.length,
        queueOperation: queueOperation,
        queueSyncing: queueSyncing,
        onRefresh: () => notifier.loadQueue(),
        body: queue.items.isEmpty
            ? _QueueStateList(
                icon: Icons.playlist_play,
                title: l10n?.queue_is_empty ?? 'Queue is empty',
                subtitle:
                    l10n?.pull_to_refresh ?? 'Pull to refresh for updates.',
              )
            : _QueueList(queue: queue),
      );
    } else {
      body = _QueuePanel(
        title: title,
        itemCount: null,
        queueOperation: queueOperation,
        queueSyncing: queueSyncing,
        onRefresh: () => notifier.loadQueue(),
        body: _QueueStateList(
          icon: Icons.error_outline,
          title: l10n?.error ?? 'Error',
          subtitle:
              l10n?.failed_to_load_queue(queueAsync.error.toString()) ??
              'Failed to load queue: ${queueAsync.error}',
          action: FilledButton.tonalIcon(
            onPressed: () => notifier.loadQueue(),
            icon: const Icon(Icons.refresh),
            label: Text(l10n?.retry ?? 'Retry'),
          ),
        ),
      );
    }

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * sheetHeightFactor,
      child: ClipRRect(
        key: const Key('podcast_queue_sheet_surface'),
        borderRadius: _sheetBorderRadius,
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(
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
          _QueueHeader(
            title: title,
            itemCount: itemCount,
            queueOperation: queueOperation,
            queueSyncing: queueSyncing,
            onRefresh: onRefresh,
          ),
          Expanded(
            child: RefreshIndicator(onRefresh: onRefresh, child: body),
          ),
        ],
      ),
    );
  }
}

class _QueueHeader extends StatelessWidget {
  const _QueueHeader({
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
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final statusLabel = _queueStatusLabel(
      l10n,
      queueOperation: queueOperation,
      queueSyncing: queueSyncing,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
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
            padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      if (itemCount != null)
                        _QueueInfoChip(
                          icon: Icons.queue_music_rounded,
                          label:
                              '${itemCount ?? 0} ${l10n?.queue_in_queue ?? 'in queue'}',
                        ),
                      if (itemCount != null && statusLabel != null)
                        const SizedBox(width: 6),
                      if (statusLabel != null)
                        Flexible(
                          child: _QueueInfoChip(
                            icon: Icons.sync_rounded,
                            label: statusLabel,
                            emphasized: true,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l10n?.refresh ?? 'Refresh',
                  onPressed: onRefresh,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.refresh),
                ),
                IconButton(
                  tooltip: l10n?.close ?? 'Close',
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

class _QueueInfoChip extends StatelessWidget {
  const _QueueInfoChip({
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: emphasized
            ? theme.colorScheme.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
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

class _QueueLoadingState extends StatelessWidget {
  const _QueueLoadingState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.08),
        Center(
          child: LoadingStatusContent(
            key: const Key('queue_loading_content'),
            title: title,
            subtitle: subtitle,
            spinnerSize: 40,
            spinnerStrokeWidth: 2.5,
          ),
        ),
      ],
    );
  }
}

class _QueueStateList extends StatelessWidget {
  const _QueueStateList({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.08),
        Container(
          key: const Key('queue_state_card'),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: 28,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (action != null) ...[const SizedBox(height: 18), action!],
            ],
          ),
        ),
      ],
    );
  }
}

class _QueueList extends ConsumerStatefulWidget {
  const _QueueList({required this.queue});

  final PodcastQueueModel queue;

  @override
  ConsumerState<_QueueList> createState() => _QueueListState();
}

class _QueueListState extends ConsumerState<_QueueList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scheduleScrollToCurrent(animate: false);
  }

  @override
  void didUpdateWidget(covariant _QueueList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.queue.currentEpisodeId != widget.queue.currentEpisodeId ||
        oldWidget.queue.items.length != widget.queue.items.length) {
      _scheduleScrollToCurrent();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleScrollToCurrent({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(Duration.zero);
      if (!mounted) {
        return;
      }
      await _scrollToCurrent(animate: animate);
    });
  }

  Future<void> _scrollToCurrent({bool animate = true}) async {
    final currentEpisodeId = widget.queue.currentEpisodeId;
    if (!_scrollController.hasClients || currentEpisodeId == null) {
      return;
    }

    final index = widget.queue.items.indexWhere(
      (item) => item.episodeId == currentEpisodeId,
    );
    if (index <= 0) {
      return;
    }

    final targetOffset = math.max(0.0, index * ScrollConstants.queueItemExtent - 96);
    final maxOffset = _scrollController.position.maxScrollExtent;
    final clampedOffset = math.min(targetOffset, maxOffset);

    if (animate) {
      await _scrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(clampedOffset);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(podcastQueueControllerProvider.notifier);
    final queueOperation = ref.watch(podcastQueueOperationProvider);
    final currentEpisodeId = widget.queue.currentEpisodeId;

    return ReorderableListView.builder(
      scrollController: _scrollController,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
      itemExtent: ScrollConstants.queueItemExtent,
      cacheExtent: ScrollConstants.defaultCacheExtent,
      buildDefaultDragHandles: false,
      physics: const AlwaysScrollableScrollPhysics(),
      proxyDecorator: (child, index, animation) {
        return RepaintBoundary(
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              final elevation = Tween<double>(
                begin: 0,
                end: 10,
              ).evaluate(animation);
              return Transform.scale(
                scale: 1.0 + (0.01 * animation.value),
                child: Material(
                  elevation: elevation,
                  color: Colors.transparent,
                  shadowColor: Theme.of(
                    context,
                  ).colorScheme.shadow.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                  child: child,
                ),
              );
            },
          ),
        );
      },
      itemCount: widget.queue.items.length,
      onReorder: (oldIndex, newIndex) async {
        var targetIndex = newIndex;
        if (oldIndex < newIndex) {
          targetIndex -= 1;
        }

        final ordered = [...widget.queue.items];
        final moved = ordered.removeAt(oldIndex);
        ordered.insert(targetIndex, moved);
        final orderedIds = ordered.map((item) => item.episodeId).toList();

        try {
          await notifier.reorderQueue(orderedIds);
        } catch (error) {
          if (!context.mounted) {
            return;
          }
          final l10n = AppLocalizations.of(context);
          showTopFloatingNotice(
            context,
            message:
                l10n?.failed_to_reorder_queue(error.toString()) ??
                'Failed to reorder queue: $error',
            isError: true,
          );
        }
      },
      itemBuilder: (context, index) {
        final item = widget.queue.items[index];
        final isCurrent = item.episodeId == currentEpisodeId;
        final isRemoving =
            queueOperation.kind == QueueOperationKind.removing &&
            queueOperation.episodeId == item.episodeId;
        return Padding(
          key: ValueKey(item.episodeId),
          padding: const EdgeInsets.only(bottom: 6),
          child: _QueueListItem(
            item: item,
            index: index,
            isCurrent: isCurrent,
            isRemoving: isRemoving,
            onTap: () async {
              if (isCurrent) {
                await _scrollToCurrent();
                return;
              }
              try {
                await notifier.playFromQueue(item.episodeId);
              } catch (error) {
                if (!context.mounted) {
                  return;
                }
                final l10n = AppLocalizations.of(context);
                showTopFloatingNotice(
                  context,
                  message:
                      l10n?.failed_to_play_item(error.toString()) ??
                      'Failed to play item: $error',
                  isError: true,
                );
              }
            },
            onRemove: isRemoving
                ? null
                : () async {
                    try {
                      await notifier.removeFromQueueAndResolvePlayback(
                        item.episodeId,
                      );
                    } catch (error) {
                      if (!context.mounted) {
                        return;
                      }
                      final l10n = AppLocalizations.of(context);
                      showTopFloatingNotice(
                        context,
                        message:
                            l10n?.failed_to_remove_item(error.toString()) ??
                            'Failed to remove item: $error',
                        isError: true,
                      );
                    }
                  },
          ),
        );
      },
    );
  }
}

class _QueueListItem extends ConsumerWidget {
  const _QueueListItem({
    required this.item,
    required this.index,
    required this.isCurrent,
    required this.isRemoving,
    required this.onTap,
    required this.onRemove,
  });

  final PodcastQueueItemModel item;
  final int index;
  final bool isCurrent;
  final bool isRemoving;
  final Future<void> Function() onTap;
  final Future<void> Function()? onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cardColors = isCurrent
        ? [
            theme.colorScheme.primaryContainer.withValues(alpha: 0.72),
            Colors.transparent,
          ]
        : [Colors.transparent, Colors.transparent];

    return Material(
      key: Key('queue_item_tile_${item.episodeId}'),
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: cardColors,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCurrent
                  ? theme.colorScheme.primary.withValues(alpha: 0.30)
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.30),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withValues(
                  alpha: isCurrent ? 0.07 : 0.03,
                ),
                blurRadius: isCurrent ? 10 : 6,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ReorderableDragStartListener(
                    key: Key('queue_item_drag_${item.episodeId}'),
                    index: index,
                    child: Icon(
                      Icons.drag_indicator,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                RepaintBoundary(
                  child: _QueueItemCover(item: item, isCurrent: isCurrent, size: 42),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      isCurrent
                          ? _CurrentQueueSubtitle(item: item)
                          : _StaticQueueSubtitle(item: item),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                _QueueItemDownloadIndicator(episodeId: item.episodeId),
                IconButton(
                  key: Key('queue_item_remove_${item.episodeId}'),
                  tooltip: AppLocalizations.of(context)?.delete ?? 'Delete',
                  constraints: const BoxConstraints.tightFor(
                    width: 36,
                    height: 36,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: onRemove,
                  icon: isRemoving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StaticQueueSubtitle extends StatelessWidget {
  const _StaticQueueSubtitle({required this.item});

  final PodcastQueueItemModel item;

  @override
  Widget build(BuildContext context) {
    return Text(
      _queueFormatSubtitle(
        item,
        separator:
            AppLocalizations.of(context)?.queue_subtitle_separator ?? ' • ',
        playedSec: item.playbackPosition ?? 0,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _CurrentQueueSubtitle extends ConsumerWidget {
  const _CurrentQueueSubtitle({required this.item});

  final PodcastQueueItemModel item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(audioCurrentQueueProgressProvider);
    final playedSec = progress.currentEpisodeId == item.episodeId
        ? (progress.positionMs / 1000).round()
        : (item.playbackPosition ?? 0);
    return Text(
      _queueFormatSubtitle(
        item,
        separator:
            AppLocalizations.of(context)?.queue_subtitle_separator ?? ' • ',
        playedSec: playedSec,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

String _queueFormatSubtitle(
  PodcastQueueItemModel item, {
  required String separator,
  required int playedSec,
}) {
  final progressText = _queueFormatProgress(
    playedSec: playedSec < 0 ? 0 : playedSec,
    durationSec: item.duration,
  );
  final title = item.subscriptionTitle;
  if (title == null || title.isEmpty) {
    return progressText;
  }
  return '$title$separator$progressText';
}

String _queueFormatProgress({
  required int playedSec,
  required int? durationSec,
}) {
  if (durationSec == null || durationSec <= 0) {
    return '${_queueFormatClock(playedSec)} / --:--';
  }

  final clampedPlayed = playedSec > durationSec ? durationSec : playedSec;
  return '${_queueFormatClock(clampedPlayed)} / ${_queueFormatClock(durationSec)}';
}

String _queueFormatClock(int seconds) {
  return TimeFormatter.formatSecondsClock(seconds, padHours: false);
}

String? _queueStatusLabel(
  AppLocalizations? l10n, {
  required QueueOperationState queueOperation,
  required bool queueSyncing,
}) {
  switch (queueOperation.kind) {
    case QueueOperationKind.initialLoading:
      return l10n?.loading ?? 'Loading...';
    case QueueOperationKind.refreshing:
      return l10n?.refreshing ?? 'Refreshing...';
    case QueueOperationKind.reordering:
      return l10n?.queue_saving_order ?? 'Saving order';
    case QueueOperationKind.removing:
    case QueueOperationKind.activating:
      return l10n?.queue_updating ?? 'Updating queue';
    case QueueOperationKind.idle:
      if (queueSyncing) {
        return l10n?.queue_syncing ?? 'Syncing queue';
      }
      return null;
  }
}

class _QueueItemCover extends StatelessWidget {
  const _QueueItemCover({
    required this.item,
    required this.isCurrent,
    required this.size,
  });

  final PodcastQueueItemModel item;
  final bool isCurrent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = item.subscriptionImageUrl ?? item.imageUrl;

    return SizedBox(
      key: Key('queue_item_cover_${item.episodeId}'),
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(kPodcastRowCardImageRadius),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? PodcastImageWidget(
                      imageUrl: imageUrl,
                      width: size,
                      height: size,
                      iconSize: size * 0.52,
                    )
                  : _fallback(theme),
            ),
          ),
          if (isCurrent)
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                key: Key('queue_item_playing_badge_${item.episodeId}'),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.surface,
                    width: 2,
                  ),
                ),
                child: const RepaintBoundary(
                  child: _EqualizerBadge(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fallback(ThemeData theme) {
    return Container(
      key: Key('queue_item_cover_fallback_${item.episodeId}'),
      color: Colors.transparent,
      alignment: Alignment.center,
      child: Icon(
        Icons.podcasts,
        color: theme.colorScheme.onSurfaceVariant,
        size: size * 0.52,
      ),
    );
  }
}

class _EqualizerBadge extends StatelessWidget {
  const _EqualizerBadge();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSecondary;
    const bars = <double>[5, 9, 6];
    return Center(
      child: SizedBox(
        width: 12,
        height: 10,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: bars
              .map(
                (height) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0.6),
                  child: Container(
                    width: 2.1,
                    height: height,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

/// Compact download status indicator for queue items.
class _QueueItemDownloadIndicator extends ConsumerWidget {
  const _QueueItemDownloadIndicator({required this.episodeId});

  final int episodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncTask = ref.watch(episodeDownloadStatusProvider(episodeId));

    return asyncTask.when(
      data: (task) {
        if (task == null) {
          // Not downloaded — show cloud icon to indicate streaming
          return Icon(
            Icons.cloud_outlined,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          );
        }

        return switch (task.status) {
          'pending' || 'downloading' => SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: theme.colorScheme.primary,
              ),
            ),
          'completed' => Icon(
              Icons.download_done,
              size: 14,
              color: theme.colorScheme.primary,
            ),
          'failed' => Icon(
              Icons.error_outline,
              size: 14,
              color: theme.colorScheme.error,
            ),
          _ => const SizedBox.shrink(),
        };
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
