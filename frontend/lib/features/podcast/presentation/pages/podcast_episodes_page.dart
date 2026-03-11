import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/top_floating_notice.dart';
import '../../data/models/podcast_episode_model.dart';
import '../../data/models/podcast_state_models.dart';
import '../../data/models/podcast_subscription_model.dart';
import '../navigation/podcast_navigation.dart';
import '../providers/podcast_providers.dart';
import '../widgets/simplified_episode_card.dart';
import '../widgets/podcast_image_widget.dart';
import '../../../../core/utils/app_logger.dart' as logger;

class PodcastEpisodesPage extends ConsumerStatefulWidget {
  final int subscriptionId;
  final String? podcastTitle;
  final PodcastSubscriptionModel? subscription;

  const PodcastEpisodesPage({
    super.key,
    required this.subscriptionId,
    this.podcastTitle,
    this.subscription,
  });

  /// Factory for navigation from args
  factory PodcastEpisodesPage.fromArgs(PodcastEpisodesPageArgs args) {
    return PodcastEpisodesPage(
      subscriptionId: args.subscriptionId,
      podcastTitle: args.podcastTitle,
      subscription: args.subscription,
    );
  }

  /// Factory for direct navigation with subscription object
  factory PodcastEpisodesPage.withSubscription(
    PodcastSubscriptionModel subscription,
  ) {
    return PodcastEpisodesPage(
      subscriptionId: subscription.id,
      podcastTitle: subscription.title,
      subscription: subscription,
    );
  }

  @override
  ConsumerState<PodcastEpisodesPage> createState() =>
      _PodcastEpisodesPageState();
}

class _PodcastEpisodesPageState extends ConsumerState<PodcastEpisodesPage> {
  final ScrollController _scrollController = ScrollController();
  final Set<int> _addingEpisodeIds = <int>{};
  String _selectedFilter = 'all';
  bool _showOnlyWithSummary = false;
  bool _isReparsing = false; // Guard to avoid duplicate reparse requests.
  static const double _desktopEpisodeCardHeight = 160.0;

  String? get _statusFilter => _selectedFilter == 'played'
      ? 'played'
      : _selectedFilter == 'unplayed'
      ? 'unplayed'
      : null;

  bool? get _hasSummaryFilter => _showOnlyWithSummary ? true : null;

  @override
  void initState() {
    super.initState();
    // Load initial episodes
    _loadEpisodesForSubscription();

    // Setup scroll listener for infinite scroll
    _scrollController.addListener(() {
      const preloadThresholdPx = 240.0;
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (!position.hasPixels || !position.hasContentDimensions) return;
      final remaining = position.maxScrollExtent - position.pixels;
      if (remaining > preloadThresholdPx) return;

      final episodesState = ref.read(podcastEpisodesProvider);
      if (episodesState.isLoadingMore || !episodesState.hasMore) return;

      ref
          .read(podcastEpisodesProvider.notifier)
          .loadMoreEpisodesForSubscription(
            subscriptionId: widget.subscriptionId,
            status: _statusFilter,
            hasSummary: _hasSummaryFilter,
          );
    });
  }

  @override
  void didUpdateWidget(PodcastEpisodesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check if subscriptionId has changed
    if (oldWidget.subscriptionId != widget.subscriptionId) {
      logger.AppLogger.debug(
        '[Episodes] ===== didUpdateWidget: Subscription ID changed =====',
      );
      logger.AppLogger.debug(
        '[Episodes] Old Subscription ID: ${oldWidget.subscriptionId}',
      );
      logger.AppLogger.debug(
        '[Episodes] New Subscription ID: ${widget.subscriptionId}',
      );
      logger.AppLogger.debug(
        '[Episodes] Reloading episodes for new subscription',
      );

      // Reset filters
      _selectedFilter = 'all';
      _showOnlyWithSummary = false;

      // Reload episodes for the new subscription
      _loadEpisodesForSubscription(forceRefresh: true);

      logger.AppLogger.debug('[Episodes] ===== didUpdateWidget complete =====');
    }
  }

  Future<void> _loadEpisodesForSubscription({bool forceRefresh = false}) async {
    logger.AppLogger.debug(
      '[Episodes] Loading episodes for subscription: ${widget.subscriptionId}',
    );
    await ref
        .read(podcastEpisodesProvider.notifier)
        .loadEpisodesForSubscription(
          subscriptionId: widget.subscriptionId,
          status: _statusFilter,
          hasSummary: _hasSummaryFilter,
          forceRefresh: forceRefresh,
        );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshEpisodes() async {
    await ref
        .read(podcastEpisodesProvider.notifier)
        .refreshEpisodesForSubscription(
          subscriptionId: widget.subscriptionId,
          status: _statusFilter,
          hasSummary: _hasSummaryFilter,
        );
  }

  // Add episode to queue and show feedback.
  Future<void> _handleAddToQueue(PodcastEpisodeModel episode) async {
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
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      showTopFloatingNotice(
        context,
        message: l10n.added_to_queue,
        extraTopOffset: 72,
      );
    } catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      showTopFloatingNotice(
        context,
        message: l10n.failed_to_add_to_queue(error.toString()),
        isError: true,
        extraTopOffset: 72,
      );
    } finally {
      if (mounted) {
        setState(() {
          _addingEpisodeIds.remove(episode.id);
        });
      }
    }
  }

  Future<void> _reparseSubscription() async {
    if (_isReparsing) return; // Ignore repeated taps while reparsing.

    setState(() {
      _isReparsing = true;
    });

    final l10n = AppLocalizations.of(context)!;

    try {
      // Show loading notice.
      if (mounted) {
        showTopFloatingNotice(
          context,
          message: l10n.podcast_reparsing,
          extraTopOffset: 72,
        );
      }

      // Trigger reparse on backend.
      await ref
          .read(podcastSubscriptionProvider.notifier)
          .reparseSubscription(
            widget.subscriptionId,
            true, // forceAll: full reparse
          );

      // Refresh list after reparse.
      await _refreshEpisodes();

      // Show success notice.
      if (mounted) {
        showTopFloatingNotice(
          context,
          message: l10n.podcast_reparse_completed,
          extraTopOffset: 72,
        );
      }
    } catch (error) {
      // Show error notice.
      if (mounted) {
        showTopFloatingNotice(
          context,
          message: '${l10n.podcast_reparse_failed} $error',
          isError: true,
          extraTopOffset: 72,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isReparsing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hostLayout = ref.watch(podcastPlayerHostLayoutProvider);
    final playerBottomInset = hostLayout.visible
        ? resolvePodcastPlayerTotalReservedSpace(context, hostLayout)
        : 0.0;

    // Debug helper for first episode image fields.
    // if (episodesState.episodes.isNotEmpty) {
    //   final firstEpisode = episodesState.episodes.first;
    //   logger.AppLogger.debug('[Episodes] First episode image debug:');
    //   logger.AppLogger.debug('  Episode ID: ${firstEpisode.id}');
    //   logger.AppLogger.debug('  Episode Title: ${firstEpisode.title}');
    //   logger.AppLogger.debug('  Image URL: ${firstEpisode.imageUrl}');
    //   logger.AppLogger.debug('  Subscription Image URL: ${firstEpisode.subscriptionImageUrl}');
    //   logger.AppLogger.debug('  Has episode image: ${firstEpisode.imageUrl != null}');
    //   logger.AppLogger.debug('  Has subscription image: ${firstEpisode.subscriptionImageUrl != null}');
    // }

    return Scaffold(
      body: AnimatedPadding(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: playerBottomInset),
        child: Column(
          children: [
            // Custom Header with top padding to align with Feed page
            Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
              ),
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 8),
                    // Icon
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Consumer(
                          builder: (context, localRef, child) {
                            final sub = widget.subscription;
                            final fallbackSubscriptionImageUrl = localRef.watch(
                              podcastEpisodesProvider.select(
                                (state) => state.episodes.isNotEmpty
                                    ? state.episodes.first.subscriptionImageUrl
                                    : null,
                              ),
                            );

                            if (sub?.imageUrl != null) {
                              return PodcastImageWidget(
                                imageUrl: sub!.imageUrl,
                                width: 40,
                                height: 40,
                                iconSize: 24,
                                iconColor: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                              );
                            }

                            if (fallbackSubscriptionImageUrl != null) {
                              return PodcastImageWidget(
                                imageUrl: fallbackSubscriptionImageUrl,
                                width: 40,
                                height: 40,
                                iconSize: 24,
                                iconColor: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                              );
                            }

                            return Icon(
                              Icons.podcasts,
                              size: 24,
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.podcastTitle ?? l10n.podcast_episodes,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Reparse action.
                    IconButton(
                      icon: _isReparsing
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            )
                          : const Icon(Icons.refresh),
                      onPressed: _isReparsing ? null : _reparseSubscription,
                      tooltip: l10n.podcast_reparse_tooltip,
                    ),
                    // Mobile shows filter button; desktop shows inline chips.
                    if (MediaQuery.of(context).size.width < 700) ...[
                      IconButton(
                        icon: const Icon(Icons.filter_list),
                        onPressed: _showFilterDialog,
                        tooltip: l10n.filter,
                      ),
                      _buildMoreMenu(),
                    ] else ...[
                      _buildFilterChips(),
                      const SizedBox(width: 8),
                      _buildMoreMenu(),
                    ],
                  ],
                ),
              ),
            ),

            Expanded(
              child: Consumer(
                builder: (context, localRef, child) {
                  final episodesState = localRef.watch(podcastEpisodesProvider);
                  return episodesState.isLoading &&
                          episodesState.episodes.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : episodesState.error != null
                      ? _buildErrorState(episodesState.error!)
                      : episodesState.episodes.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _refreshEpisodes,
                          child: _buildEpisodesScrollable(episodesState),
                        );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEpisodesScrollable(PodcastEpisodesState episodesState) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final itemCount =
            episodesState.episodes.length +
            (episodesState.isLoadingMore ? 1 : 0);

        if (screenWidth < 600) {
          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            itemCount: itemCount,
            itemBuilder: (context, index) {
              if (index == episodesState.episodes.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final episode = episodesState.episodes[index];
              return _buildEpisodeCard(episode);
            },
          );
        }

        final crossAxisCount = screenWidth < 900
            ? 2
            : (screenWidth < 1200 ? 3 : 4);
        return GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: _desktopEpisodeCardHeight,
          ),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            if (index == episodesState.episodes.length) {
              return const Center(child: CircularProgressIndicator());
            }
            final episode = episodesState.episodes[index];
            return _buildEpisodeCard(episode);
          },
        );
      },
    );
  }

  Widget _buildEpisodeCard(PodcastEpisodeModel episode) {
    return SimplifiedEpisodeCard(
      episode: episode,
      isAddingToQueue: _addingEpisodeIds.contains(episode.id),
      onTap: () => context.push('/podcast/episode/detail/${episode.id}'),
      onPlay: () => _playAndOpenEpisodeDetail(episode),
      onAddToQueue: () => _handleAddToQueue(episode),
    );
  }

  Future<void> _playAndOpenEpisodeDetail(PodcastEpisodeModel episode) async {
    await ref.read(audioPlayerProvider.notifier).playManagedEpisode(episode);
    if (!mounted) return;
    context.push('/podcast/episode/detail/${episode.id}');
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.headphones_outlined,
            size: 80,
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _showOnlyWithSummary
                ? l10n.podcast_no_episodes_with_summary
                : l10n.podcast_no_episodes,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _showOnlyWithSummary
                ? l10n.podcast_try_adjusting_filters
                : l10n.podcast_no_episodes_yet,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FilterChip(
          label: Text(l10n.podcast_filter_all),
          selected: _selectedFilter == 'all',
          onSelected: (selected) {
            setState(() {
              _selectedFilter = 'all';
            });
            _refreshEpisodes();
          },
        ),
        const SizedBox(width: 8),
        FilterChip(
          label: Text(l10n.podcast_filter_unplayed),
          selected: _selectedFilter == 'unplayed',
          onSelected: (selected) {
            setState(() {
              _selectedFilter = 'unplayed';
            });
            _refreshEpisodes();
          },
        ),
        const SizedBox(width: 8),
        FilterChip(
          label: Text(l10n.podcast_filter_played),
          selected: _selectedFilter == 'played',
          onSelected: (selected) {
            setState(() {
              _selectedFilter = 'played';
            });
            _refreshEpisodes();
          },
        ),
        const SizedBox(width: 8),
        FilterChip(
          label: Text(l10n.podcast_filter_with_summary),
          selected: _showOnlyWithSummary,
          onSelected: (selected) {
            setState(() {
              _showOnlyWithSummary = selected;
            });
            _refreshEpisodes();
          },
          avatar: _showOnlyWithSummary
              ? const Icon(Icons.summarize, size: 16)
              : null,
        ),
      ],
    );
  }

  Widget _buildMoreMenu() {
    final l10n = AppLocalizations.of(context)!;
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert,
        color: Theme.of(context).colorScheme.secondary,
      ),
      onSelected: (value) {
        // TODO: Implement
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'mark_all_played',
          child: Text(l10n.podcast_mark_all_played),
        ),
        PopupMenuItem(
          value: 'mark_all_unplayed',
          child: Text(l10n.podcast_mark_all_unplayed),
        ),
      ],
    );
  }

  Widget _buildErrorState(Object error) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.podcast_failed_load_episodes,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _refreshEpisodes,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.retry),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.podcast_filter_episodes),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.podcast_playback_status),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'all',
                    label: Text(l10n.podcast_all_episodes),
                  ),
                  ButtonSegment(
                    value: 'unplayed',
                    label: Text(l10n.podcast_unplayed_only),
                  ),
                  ButtonSegment(
                    value: 'played',
                    label: Text(l10n.podcast_played_only),
                  ),
                ],
                selected: {_selectedFilter},
                onSelectionChanged: (Set<String> selection) {
                  setDialogState(() {
                    _selectedFilter = selection.first;
                  });
                },
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: Text(l10n.podcast_only_with_summary),
                value: _showOnlyWithSummary,
                onChanged: (value) {
                  setDialogState(() {
                    _showOnlyWithSummary = value!;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {});
                _refreshEpisodes();
              },
              child: Text(l10n.podcast_apply),
            ),
          ],
        ),
      ),
    );
  }
}
