import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/constants/app_radius.dart';
import 'package:personal_ai_assistant/core/constants/scroll_constants.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/services/download_provider.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/utils/time_formatter.dart';
import 'package:personal_ai_assistant/core/widgets/top_floating_notice.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_queue_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/constants/podcast_ui_constants.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/podcast_image_widget.dart';

// ---------------------------------------------------------------------------
// QueueList — main reorderable list of queue items
// ---------------------------------------------------------------------------

class QueueList extends ConsumerStatefulWidget {
  const QueueList({super.key, required this.queue});

  final PodcastQueueModel queue;

  @override
  ConsumerState<QueueList> createState() => _QueueListState();
}

class _QueueListState extends ConsumerState<QueueList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scheduleScrollToCurrent(animate: false);
  }

  @override
  void didUpdateWidget(covariant QueueList oldWidget) {
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

    final targetOffset = math.max<double>(0, index * ScrollConstants.queueItemExtent - 96);
    final maxOffset = _scrollController.position.maxScrollExtent;
    final clampedOffset = math.min<double>(targetOffset, maxOffset);

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
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.smMd, AppSpacing.md, AppSpacing.mdLg),
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
                  borderRadius: BorderRadius.circular(appThemeOf(context).cardRadius),
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
          child: QueueListItem(
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

// ---------------------------------------------------------------------------
// QueueListItem — individual queue item row
// ---------------------------------------------------------------------------

class QueueListItem extends ConsumerWidget {
  const QueueListItem({
    super.key,
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
        borderRadius: BorderRadius.circular(appThemeOf(context).cardRadius),
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
            borderRadius: BorderRadius.circular(appThemeOf(context).cardRadius),
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
            padding: const EdgeInsets.fromLTRB(AppSpacing.smMd, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(appThemeOf(context).itemRadius),
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
                const SizedBox(width: AppSpacing.smMd),
                RepaintBoundary(
                  child: QueueItemCover(item: item, isCurrent: isCurrent, size: 42),
                ),
                const SizedBox(width: AppSpacing.smMd),
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
                      const SizedBox(height: AppSpacing.xs),
                      if (isCurrent) CurrentQueueSubtitle(item: item) else StaticQueueSubtitle(item: item),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                QueueItemDownloadIndicator(episodeId: item.episodeId),
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

// ---------------------------------------------------------------------------
// Subtitle widgets
// ---------------------------------------------------------------------------

class StaticQueueSubtitle extends StatelessWidget {
  const StaticQueueSubtitle({super.key, required this.item});

  final PodcastQueueItemModel item;

  @override
  Widget build(BuildContext context) {
    return Text(
      queueFormatSubtitle(
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

class CurrentQueueSubtitle extends ConsumerWidget {
  const CurrentQueueSubtitle({super.key, required this.item});

  final PodcastQueueItemModel item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(audioCurrentQueueProgressProvider);
    final playedSec = progress.currentEpisodeId == item.episodeId
        ? (progress.positionMs / 1000).round()
        : (item.playbackPosition ?? 0);
    return Text(
      queueFormatSubtitle(
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

// ---------------------------------------------------------------------------
// Cover, badge, and download indicator
// ---------------------------------------------------------------------------

class QueueItemCover extends StatelessWidget {
  const QueueItemCover({
    super.key,
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
                  child: EqualizerBadge(),
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

class EqualizerBadge extends StatelessWidget {
  const EqualizerBadge({super.key});

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
                      borderRadius: AppRadius.pillRadius,
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
class QueueItemDownloadIndicator extends ConsumerWidget {
  const QueueItemDownloadIndicator({super.key, required this.episodeId});

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
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared formatting helpers
// ---------------------------------------------------------------------------

String queueFormatSubtitle(
  PodcastQueueItemModel item, {
  required String separator,
  required int playedSec,
}) {
  final progressText = queueFormatProgress(
    playedSec: playedSec < 0 ? 0 : playedSec,
    durationSec: item.duration,
  );
  final title = item.subscriptionTitle;
  if (title == null || title.isEmpty) {
    return progressText;
  }
  return '$title$separator$progressText';
}

String queueFormatProgress({
  required int playedSec,
  required int? durationSec,
}) {
  if (durationSec == null || durationSec <= 0) {
    return '${queueFormatClock(playedSec)} / --:--';
  }

  final clampedPlayed = playedSec > durationSec ? durationSec : playedSec;
  return '${queueFormatClock(clampedPlayed)} / ${queueFormatClock(durationSec)}';
}

String queueFormatClock(int seconds) {
  return TimeFormatter.formatSecondsClock(seconds, padHours: false);
}
