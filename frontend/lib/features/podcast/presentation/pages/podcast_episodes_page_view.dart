part of 'podcast_episodes_page.dart';

extension _PodcastEpisodesPageView on _PodcastEpisodesPageState {
  Widget _buildHeader(AppLocalizations l10n, String? fallbackImageUrl) {
    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8),
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
            _buildHeaderCover(fallbackImageUrl),
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
            IconButton(
              icon: _isReparsing
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    )
                  : const Icon(Icons.refresh),
              onPressed: _isReparsing ? null : _reparseSubscription,
              tooltip: l10n.podcast_reparse_tooltip,
            ),
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
    );
  }

  Widget _buildHeaderCover(String? fallbackImageUrl) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Builder(
          builder: (context) {
            final sub = widget.subscription;

            if (sub?.imageUrl != null) {
              return PodcastImageWidget(
                imageUrl: sub!.imageUrl,
                width: 40,
                height: 40,
                iconSize: 24,
                iconColor: Theme.of(context).colorScheme.onPrimaryContainer,
              );
            }

            if (fallbackImageUrl != null) {
              return PodcastImageWidget(
                imageUrl: fallbackImageUrl,
                width: 40,
                height: 40,
                iconSize: 24,
                iconColor: Theme.of(context).colorScheme.onPrimaryContainer,
              );
            }

            return Icon(
              Icons.podcasts,
              size: 24,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            );
          },
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
            cacheExtent: 1000, // Cache 1000 pixels for smoother scrolling
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
            mainAxisExtent: _PodcastEpisodesPageState._desktopEpisodeCardHeight,
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

  Widget _buildEmptyState() {
    final l10n = context.l10n;
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
    final l10n = context.l10n;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FilterChip(
          label: Text(l10n.podcast_filter_all),
          selected: _selectedFilter == 'all',
          onSelected: (selected) {
            _applyViewState(() {
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
            _applyViewState(() {
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
            _applyViewState(() {
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
            _applyViewState(() {
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
    final l10n = context.l10n;
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
    final l10n = context.l10n;
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
    final l10n = context.l10n;
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
                _applyViewState(() {});
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
