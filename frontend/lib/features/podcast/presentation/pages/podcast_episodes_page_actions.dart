part of 'podcast_episodes_page.dart';

extension _PodcastEpisodesPageActions on _PodcastEpisodesPageState {
  void _setupInfiniteScrollListener() {
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
    _applyViewState(() {
      _addingEpisodeIds.add(episode.id);
    });

    try {
      await ref.read(podcastQueueControllerProvider.notifier).addToQueue(episode.id);
      if (!mounted) return;
      final l10n = context.l10n;
      showTopFloatingNotice(
        context,
        message: l10n.added_to_queue,
        extraTopOffset: 72,
      );
    } catch (error) {
      if (!mounted) return;
      final l10n = context.l10n;
      showTopFloatingNotice(
        context,
        message: l10n.failed_to_add_to_queue(error.toString()),
        isError: true,
        extraTopOffset: 72,
      );
    } finally {
      if (mounted) {
        _applyViewState(() {
          _addingEpisodeIds.remove(episode.id);
        });
      }
    }
  }

  Future<void> _reparseSubscription() async {
    if (_isReparsing) return; // Ignore repeated taps while reparsing.

    _applyViewState(() {
      _isReparsing = true;
    });

    final l10n = context.l10n;

    try {
      if (mounted) {
        showTopFloatingNotice(
          context,
          message: l10n.podcast_reparsing,
          extraTopOffset: 72,
        );
      }

      await ref.read(podcastSubscriptionProvider.notifier).reparseSubscription(
            widget.subscriptionId,
            true,
          );

      await _refreshEpisodes();

      if (mounted) {
        showTopFloatingNotice(
          context,
          message: l10n.podcast_reparse_completed,
          extraTopOffset: 72,
        );
      }
    } catch (error) {
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
        _applyViewState(() {
          _isReparsing = false;
        });
      }
    }
  }

  Future<void> _playAndOpenEpisodeDetail(PodcastEpisodeModel episode) async {
    await ref.read(audioPlayerProvider.notifier).playManagedEpisode(episode);
    if (!mounted) return;
    context.push('/podcast/episode/detail/${episode.id}');
  }
}
