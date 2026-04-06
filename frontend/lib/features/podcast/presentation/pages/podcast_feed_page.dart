import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:personal_ai_assistant/core/constants/breakpoints.dart';
import 'package:personal_ai_assistant/core/constants/scroll_constants.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/utils/text_processing_cache.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/core/widgets/top_floating_notice.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_state_models.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/navigation/podcast_navigation.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/podcast_feed_episode_card.dart';
import 'package:personal_ai_assistant/shared/widgets/skeleton_widgets.dart';

class PodcastFeedPage extends ConsumerStatefulWidget {
  const PodcastFeedPage({super.key});

  @override
  ConsumerState<PodcastFeedPage> createState() => _PodcastFeedPageState();
}

class _PodcastFeedPageState extends ConsumerState<PodcastFeedPage> {
  final Set<int> _addingEpisodeIds = <int>{};
  final ScrollController _scrollController = ScrollController();
  bool _awaitingInitialFeed = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(podcastFeedProvider.notifier).loadInitialFeed().whenComplete(() {
        if (!mounted) {
          return;
        }
        setState(() {
          _awaitingInitialFeed = false;
        });
      });
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (!position.hasPixels || !position.hasContentDimensions) {
      return;
    }
    final remaining = position.maxScrollExtent - position.pixels;
    if (remaining > ScrollConstants.loadMoreThreshold) {
      return;
    }

    final feedState = ref.read(podcastFeedProvider);
    if (feedState.isLoadingMore || !feedState.hasMore) {
      return;
    }
    ref.read(podcastFeedProvider.notifier).loadMoreFeed();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final feedState = ref.watch(podcastFeedProvider);
    return ContentShell(
      title: l10n.podcast_feed_page_title,
      subtitle: '',
      roundedViewport: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDailyReportEntryTile(context, compact: false, heroStyle: true),
          const SizedBox(width: 8),
          HeaderCapsuleActionButton(
            tooltip: l10n.profile_subscriptions,
            onPressed: () {
              context.push('/profile/subscriptions');
            },
            icon: Icons.subscriptions_outlined,
            circular: true,
          ),
        ],
      ),
      child: _buildFeedContent(context, ref, feedState),
    );
  }

  Future<void> _addToQueue(PodcastEpisodeModel episode) async {
    if (_addingEpisodeIds.contains(episode.id)) {
      return;
    }
    setState(() {
      _addingEpisodeIds.add(episode.id);
    });

    try {
      await ref
          .read(podcastQueueControllerProvider.notifier)
          .addToQueue(episode.id);
      if (mounted) {
        final l10n = context.l10n;
        showTopFloatingNotice(
          context,
          message: l10n.added_to_queue,
          extraTopOffset: 64,
        );
      }
    } catch (error) {
      if (mounted) {
        final l10n = context.l10n;
        showTopFloatingNotice(
          context,
          message: l10n.failed_to_add_to_queue(error.toString()),
          isError: true,
          extraTopOffset: 64,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _addingEpisodeIds.remove(episode.id);
        });
      }
    }
  }

  Widget _buildDailyReportEntryTile(
    BuildContext context, {
    required bool compact,
    bool heroStyle = false,
  }) {
    final l10n = context.l10n;

    if (heroStyle) {
      return HeaderCapsuleActionButton(
        key: const Key('library_daily_report_entry_tile'),
        tooltip: l10n.podcast_daily_report_open,
        icon: Icons.summarize_outlined,
        label: Text(l10n.podcast_report_label),
        trailingIcon: Icons.chevron_right,
        onPressed: () =>
            PodcastNavigation.goToDailyReport(context, source: 'library'),
      );
    }

    final theme = Theme.of(context);
    final borderRadius = compact ? 12.0 : 16.0;

    return Semantics(
      button: true,
      label: l10n.podcast_daily_report_open,
      child: Tooltip(
        message: l10n.podcast_daily_report_open,
        child: Material(
          key: const Key('library_daily_report_entry_tile'),
          color: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(borderRadius),
            onTap: () =>
                PodcastNavigation.goToDailyReport(context, source: 'library'),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 12 : 16,
                vertical: compact ? 10 : 12,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.summarize_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.podcast_daily_report_title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.podcast_daily_report_entry_subtitle,
                          maxLines: compact ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyFeedWithEntry(
    BuildContext context, {
    required bool mobile,
  }) {
    final l10n = context.l10n;
    return RefreshIndicator(
      onRefresh: () async {
        await ref
            .read(podcastFeedProvider.notifier)
            .refreshFeed(fastReturn: true);
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 4),
        children: [
          const SizedBox(height: 36),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.rss_feed,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.podcast_no_episodes_found,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedContent(
    BuildContext context,
    WidgetRef localRef,
    PodcastFeedState feedState,
  ) {
    final l10n = context.l10n;
    final showInitialLoading =
        _awaitingInitialFeed &&
        feedState.episodes.isEmpty &&
        feedState.error == null;

    if (showInitialLoading ||
        (feedState.isLoading && feedState.episodes.isEmpty)) {
      // Show skeleton cards matching the eventual layout
      return LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final isMobile = screenWidth < Breakpoints.medium;
          if (isMobile) {
            return const SkeletonCardList(compact: true);
          }
          final crossAxisCount = screenWidth < 900 ? 2 : (screenWidth < 1200 ? 3 : 4);
          return SkeletonCardGrid(
            crossAxisCount: crossAxisCount,
            itemCount: crossAxisCount * 2,
          );
        },
      );
    }

    if (feedState.error != null && feedState.episodes.isEmpty) {
      return AppEmptyState(
        icon: Icons.error_outline,
        title: l10n.podcast_failed_to_load_feed,
        subtitle: feedState.error,
        action: FilledButton(
          onPressed: () {
            localRef.read(podcastFeedProvider.notifier).loadInitialFeed();
          },
          child: Text(l10n.podcast_retry),
        ),
      );
    }

    // Use LayoutBuilder to switch between mobile and desktop layouts.
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isMobile = screenWidth < Breakpoints.medium;

        if (feedState.episodes.isEmpty) {
          return _buildEmptyFeedWithEntry(context, mobile: isMobile);
        }

        return RefreshIndicator(
          onRefresh: () => localRef
              .read(podcastFeedProvider.notifier)
              .refreshFeed(fastReturn: true),
          child: _buildFeedScrollable(
            context,
            feedState: feedState,
            screenWidth: screenWidth,
          ),
        );
      },
    );
  }

  Widget _buildFeedScrollable(
    BuildContext context, {
    required PodcastFeedState feedState,
    required double screenWidth,
  }) {
    final isMobile = screenWidth < Breakpoints.medium;
    final itemCount = feedState.episodes.length + (feedState.hasMore ? 1 : 0);

    if (isMobile) {
      return ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 4),
        cacheExtent: ScrollConstants.largeListCacheExtent,
        itemCount: itemCount,
        itemBuilder: (context, index) =>
            _buildFeedListItem(context, feedState, index, compact: true),
      );
    }

    final crossAxisCount = screenWidth < 900 ? 2 : (screenWidth < 1200 ? 3 : 4);
    const spacing = 6.0;
    final availableWidth = screenWidth - (crossAxisCount - 1) * spacing;
    final cardWidth = availableWidth / crossAxisCount;
    const desktopCardHeight = 172.0;
    final childAspectRatio = cardWidth / desktopCardHeight;

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 4),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) =>
          _buildFeedListItem(context, feedState, index, compact: false),
    );
  }

  Widget _buildFeedListItem(
    BuildContext context,
    PodcastFeedState feedState,
    int index, {
    required bool compact,
  }) {
    if (index >= feedState.episodes.length) {
      if (!feedState.isLoadingMore) {
        return const SizedBox.shrink();
      }
      final loader = CircularProgressIndicator(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );
      if (compact) {
        return Center(
          child: Padding(padding: const EdgeInsets.all(8), child: loader),
        );
      }
      return Center(child: loader);
    }

    final episode = feedState.episodes[index];
    return compact
        ? _buildMobileCard(context, episode)
        : _buildDesktopCard(context, episode);
  }

  /// Build mobile feed card.
  Widget _buildMobileCard(BuildContext context, PodcastEpisodeModel episode) {
    final displayDescription = _getFeedCardDescription(episode.description);
    final isAddingToQueue = _addingEpisodeIds.contains(episode.id);

    void playAndOpenDetail() {
      ref.read(audioPlayerProvider.notifier).playManagedEpisode(episode);
      PodcastNavigation.goToEpisodeDetail(
        context,
        episodeId: episode.id,
        subscriptionId: episode.subscriptionId,
        episodeTitle: episode.title,
      );
    }

    return PodcastFeedEpisodeCard(
      episode: episode,
      compact: true,
      isAddingToQueue: isAddingToQueue,
      displayDescription: displayDescription,
      onOpenDetail: () {
        PodcastNavigation.goToEpisodeDetail(
          context,
          episodeId: episode.id,
          subscriptionId: episode.subscriptionId,
          episodeTitle: episode.title,
        );
      },
      onPlayAndOpenDetail: playAndOpenDetail,
      onAddToQueue: () {
        _addToQueue(episode);
      },
    );
  }

  /// Build desktop feed card.
  Widget _buildDesktopCard(BuildContext context, PodcastEpisodeModel episode) {
    final displayDescription = _getFeedCardDescription(episode.description);
    final isAddingToQueue = _addingEpisodeIds.contains(episode.id);

    void playAndOpenDetail() {
      ref.read(audioPlayerProvider.notifier).playManagedEpisode(episode);
      PodcastNavigation.goToEpisodeDetail(
        context,
        episodeId: episode.id,
        subscriptionId: episode.subscriptionId,
        episodeTitle: episode.title,
      );
    }

    return PodcastFeedEpisodeCard(
      episode: episode,
      compact: false,
      isAddingToQueue: isAddingToQueue,
      displayDescription: displayDescription,
      onOpenDetail: () {
        PodcastNavigation.goToEpisodeDetail(
          context,
          episodeId: episode.id,
          subscriptionId: episode.subscriptionId,
          episodeTitle: episode.title,
        );
      },
      onPlayAndOpenDetail: playAndOpenDetail,
      onAddToQueue: () {
        _addToQueue(episode);
      },
    );
  }
}

String _getFeedCardDescription(String? description) {
  return TextProcessingCache.getCachedDescription(description);
}
