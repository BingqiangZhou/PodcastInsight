import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;
import 'package:personal_ai_assistant/core/utils/debounce.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/core/widgets/adaptive_sheet_helper.dart';
import 'package:personal_ai_assistant/core/widgets/top_floating_notice.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_discover_chart_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/itunes_episode_lookup_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_search_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/country_selector_provider.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_discover_provider.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_search_provider.dart' as search;
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/country_selector_dropdown.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/discover/discover_search_input.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/discover/discover_top_charts_section.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/discover/discover_charts_list.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/discover_episode_detail_sheet.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/discover_show_episodes_sheet.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/search/podcast_search_results_list.dart';

/// Podcast list/discover page with search and top charts
class PodcastListPage extends ConsumerStatefulWidget {
  const PodcastListPage({super.key});

  @override
  ConsumerState<PodcastListPage> createState() => _PodcastListPageState();
}

class _PodcastListPageState extends ConsumerState<PodcastListPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _discoverListScrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();
  final Set<int> _subscribingShowIds = <int>{};
  final Set<int> _subscribedShowIds = <int>{};
  DebounceTimer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _discoverListScrollController.addListener(_onDiscoverListScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(podcastSubscriptionProvider.notifier).loadSubscriptions();
      ref.read(podcastDiscoverProvider.notifier).loadInitialData();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.dispose();
    _discoverListScrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // Tab and category selection
  void _handleDiscoverTabSelected(search.PodcastSearchMode mode) {
    ref.read(search.podcastSearchProvider.notifier).setSearchMode(mode);
    ref
        .read(podcastDiscoverProvider.notifier)
        .setTab(
          mode == search.PodcastSearchMode.podcasts
              ? PodcastDiscoverTab.podcasts
              : PodcastDiscoverTab.episodes,
        );
    _resetDiscoverListScroll();
  }

  void _handleDiscoverCategorySelected(String category) {
    ref.read(podcastDiscoverProvider.notifier).selectCategory(category);
    _resetDiscoverListScroll();
  }

  // Search handling
  void _onSearchChanged(String query) {
    if (query.trim().isEmpty) {
      _searchDebounce?.cancel();
      ref.read(search.podcastSearchProvider.notifier).clearSearch();
      return;
    }
    _searchDebounce?.cancel();
    _searchDebounce = DebounceTimer(
      const Duration(milliseconds: 400),
      () {
        final notifier = ref.read(search.podcastSearchProvider.notifier);
        final mode = ref.read(search.podcastSearchProvider).searchMode;
        mode == search.PodcastSearchMode.episodes
            ? notifier.searchEpisodes(query)
            : notifier.searchPodcasts(query);
      },
    );
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(search.podcastSearchProvider.notifier).clearSearch();
    _searchFocusNode.requestFocus();
  }

  // Scroll handling
  void _onDiscoverListScroll() {
    if (!_discoverListScrollController.hasClients) return;
    final position = _discoverListScrollController.position;
    if (position.extentAfter > 200) return;
    ref.read(podcastDiscoverProvider.notifier).loadMoreCurrentTab();
  }

  void _resetDiscoverListScroll() {
    if (!_discoverListScrollController.hasClients) return;
    _discoverListScrollController.jumpTo(0);
  }

  // Subscription handlers
  Future<void> _handleSubscribeFromSearch(PodcastSearchResult result) async {
    final l10n = context.l10n;
    final feedUrl = result.feedUrl;
    final collectionName = result.collectionName;
    if (feedUrl == null || collectionName == null) {
      _showErrorNotice(l10n.podcast_subscribe_failed('Invalid podcast data'));
      return;
    }

    try {
      await ref
          .read(podcastSubscriptionProvider.notifier)
          .addSubscription(feedUrl: feedUrl);
      if (!mounted) return;
      _showSuccessNotice(l10n.podcast_subscribe_success(collectionName));
    } catch (error) {
      if (!mounted) return;
      _showErrorNotice(l10n.podcast_subscribe_failed(error.toString()));
    }
  }

  Future<void> _handleSubscribeFromChart(PodcastDiscoverItem item) async {
    final l10n = context.l10n;
    final country = ref.read(countrySelectorProvider).selectedCountry;
    final itunesId = item.itunesId;

    if (itunesId == null || _subscribingShowIds.contains(itunesId)) return;

    setState(() => _subscribingShowIds.add(itunesId));

    try {
      final searchService = ref.read(search.iTunesSearchServiceProvider);
      final lookup = await searchService.lookupPodcast(
        itunesId: itunesId,
        country: country,
      );
      final feedUrl = lookup?.feedUrl;
      if (feedUrl == null) throw Exception('No RSS feed url');

      await ref
          .read(podcastSubscriptionProvider.notifier)
          .addSubscription(feedUrl: feedUrl);

      if (!mounted) return;
      setState(() => _subscribedShowIds.add(itunesId));
      _showSuccessNotice(
        l10n.podcast_subscribe_success(lookup?.collectionName ?? item.title),
      );
    } catch (error) {
      if (!mounted) return;
      _showErrorNotice(l10n.podcast_subscribe_failed(error.toString()));
    } finally {
      if (mounted) setState(() => _subscribingShowIds.remove(itunesId));
    }
  }

  // Episode/play handlers
  Future<void> _handleEpisodeTap(ITunesPodcastEpisodeResult episode) async {
    final resolved = await _resolveEpisodeForSearchResult(episode);
    if (!mounted || resolved == null) {
      if (mounted) _showErrorNotice(context.l10n.podcast_failed_load_episodes);
      return;
    }
    await _showEpisodeDetailSheetFromSearch(resolved);
  }

  Future<void> _handleEpisodePlay(ITunesPodcastEpisodeResult episode) async {
    final resolved = await _resolveEpisodeForSearchResult(episode);
    if (!mounted || resolved == null) {
      if (mounted) _showErrorNotice(context.l10n.podcast_player_no_audio);
      return;
    }
    await _playDiscoverEpisode(episode: resolved, showId: resolved.collectionId);
  }

  Future<void> _handleChartRowTap(PodcastDiscoverItem item) async {
    if (item.isPodcastShow) {
      await _showPodcastEpisodeInfoSheet(item);
    } else {
      await _showEpisodeDetailSheet(item);
    }
  }

  Future<void> _playEpisodeFromChartRow(PodcastDiscoverItem item) async {
    final selection = await _resolveDiscoverEpisodeSelection(item);
    if (selection != null) {
      await _playDiscoverEpisode(
        episode: selection.episode,
        showId: selection.showId,
      );
    }
  }

  // Sheet display helpers
  Future<void> _showPodcastEpisodeInfoSheet(PodcastDiscoverItem item) async {
    final l10n = context.l10n;
    final country = ref.read(countrySelectorProvider).selectedCountry;
    final showId = _resolveShowIdForPodcast(item);
    if (showId == null) {
      _showErrorNotice(l10n.podcast_failed_load_episodes);
      return;
    }

    try {
      final searchService = ref.read(search.iTunesSearchServiceProvider);
      final lookup = await searchService.lookupPodcastEpisodes(
        showId: showId,
        country: country,
      );
      if (!mounted || lookup.episodes.isEmpty) {
        if (mounted) _showErrorNotice(l10n.podcast_no_episodes_found);
        return;
      }

      await showAdaptiveSheet<void>(
        context: context,
        builder: (sheetContext) {
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.8,
            ),
            child: DiscoverShowEpisodesSheet(
              showId: showId,
              showTitle: lookup.collectionName ?? item.title,
              episodes: lookup.episodes,
              onEpisodeSelected: (episode) {
                Navigator.of(sheetContext).pop();
                _showEpisodeDetailSheetFromSearch(episode);
              },
              onPlayEpisode: (episode) {
                Navigator.of(sheetContext).pop();
                _playDiscoverEpisode(episode: episode, showId: showId);
              },
            ),
          );
        },
      );
    } catch (e) {
      logger.AppLogger.debug('[Discover] Failed to show podcast episodes: $e');
      _showErrorNotice(l10n.podcast_failed_load_episodes);
    }
  }

  Future<void> _showEpisodeDetailSheet(PodcastDiscoverItem item) async {
    final selection = await _resolveDiscoverEpisodeSelection(item);
    if (selection == null || !mounted) return;

    await showAdaptiveSheet<void>(
      context: context,
      builder: (sheetContext) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.9,
          ),
          child: DiscoverEpisodeDetailSheet(
            episode: selection.episode,
            onPlay: () {
              Navigator.of(sheetContext).pop();
              _playDiscoverEpisode(
                episode: selection.episode,
                showId: selection.showId,
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _showEpisodeDetailSheetFromSearch(
      ITunesPodcastEpisodeResult episode) async {
    await showAdaptiveSheet<void>(
      context: context,
      builder: (sheetContext) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.9,
          ),
          child: DiscoverEpisodeDetailSheet(
            episode: episode,
            onPlay: () {
              Navigator.of(sheetContext).pop();
              _playDiscoverEpisode(episode: episode, showId: episode.collectionId);
            },
          ),
        );
      },
    );
  }

  // Resolution helpers
  int? _resolveShowIdForPodcast(PodcastDiscoverItem item) {
    final searchService = ref.read(search.iTunesSearchServiceProvider);
    return item.itunesId ??
        searchService.extractShowIdFromApplePodcastUrl(item.url);
  }

  Future<_DiscoverEpisodeSelection?> _resolveDiscoverEpisodeSelection(
      PodcastDiscoverItem item) async {
    final l10n = context.l10n;
    final country = ref.read(countrySelectorProvider).selectedCountry;
    final searchService = ref.read(search.iTunesSearchServiceProvider);
    final showId = searchService.extractShowIdFromApplePodcastUrl(item.url);
    final episodeTrackId =
        searchService.extractEpisodeIdFromApplePodcastUrl(item.url) ??
        item.itunesId;

    if (showId == null || episodeTrackId == null) {
      _showErrorNotice(l10n.podcast_failed_load_episodes);
      return null;
    }

    try {
      final episode = await searchService.findEpisodeInLookup(
        showId: showId,
        episodeTrackId: episodeTrackId,
        country: country,
      );
      if (episode == null) {
        _showErrorNotice(l10n.podcast_failed_load_episodes);
        return null;
      }
      return _DiscoverEpisodeSelection(showId: showId, episode: episode);
    } catch (e) {
      logger.AppLogger.debug('[Discover] Failed to resolve episode selection: $e');
      _showErrorNotice(l10n.podcast_failed_load_episodes);
      return null;
    }
  }

  Future<ITunesPodcastEpisodeResult?> _resolveEpisodeForSearchResult(
      ITunesPodcastEpisodeResult episode) async {
    if (episode.resolvedAudioUrl?.isNotEmpty == true) return episode;
    final country = ref.read(countrySelectorProvider).selectedCountry;
    final searchService = ref.read(search.iTunesSearchServiceProvider);
    try {
      return await searchService.findEpisodeInLookup(
        showId: episode.collectionId,
        episodeTrackId: episode.trackId,
        country: country,
      );
    } catch (e) {
      logger.AppLogger.debug('[Search] Failed to resolve episode: $e');
      return null;
    }
  }

  Future<void> _playDiscoverEpisode({
    required ITunesPodcastEpisodeResult episode,
    required int showId,
  }) async {
    final audioUrl = episode.resolvedAudioUrl;
    if (audioUrl == null || audioUrl.isEmpty) {
      _showErrorNotice(context.l10n.podcast_player_no_audio);
      return;
    }

    final now = DateTime.now();
    final discoverEpisode = PodcastEpisodeModel(
      id: episode.trackId,
      subscriptionId: 0,
      title: episode.trackName,
      subscriptionTitle: episode.collectionName,
      description: episode.description ?? episode.shortDescription,
      audioUrl: audioUrl,
      audioDuration: switch (episode.trackTimeMillis) {
        null => null,
        final millis => (millis / 1000).round(),
      },
      publishedAt: episode.releaseDate ?? now,
      imageUrl: episode.artworkUrl600 ?? episode.artworkUrl100,
      itemLink: episode.trackViewUrl,
      metadata: {
        'discover_preview': true,
        'source': 'top_charts',
        'show_id': showId,
        'track_id': episode.trackId,
      },
      createdAt: now,
    );

    try {
      await ref.read(audioPlayerProvider.notifier).playEpisode(discoverEpisode);
    } catch (e) {
      logger.AppLogger.debug('[Discover] Failed to play episode: $e');
      _showErrorNotice(context.l10n.podcast_player_no_audio);
    }
  }

  void _showErrorNotice(String message) {
    if (!mounted) return;
    showTopFloatingNotice(context, message: message, isError: true);
  }

  void _showSuccessNotice(String message) {
    if (!mounted) return;
    showTopFloatingNotice(context, message: message);
  }

  Future<void> _openCountrySelector(BuildContext context) async {
    await showAdaptiveSheet<void>(
      context: context,
      desktopMaxWidth: 480,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: CountrySelectorDropdown(
              onCountryChanged: (country) {
                _resetDiscoverListScroll();
                ref.read(podcastDiscoverProvider.notifier).onCountryChanged(country);
                if (ref.read(search.podcastSearchProvider).currentQuery.isNotEmpty) {
                  ref.read(search.podcastSearchProvider.notifier).retrySearch();
                }
                Navigator.of(sheetContext).pop();
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final searchState = ref.watch(search.podcastSearchProvider);
    final discoverState = ref.watch(podcastDiscoverProvider);
    const isDense = true;
    final hasSearched = searchState.hasSearched;
    final searchMode = searchState.searchMode;

    final content = hasSearched
        ? PodcastSearchResultsList(
            searchState: searchState,
            onEpisodeTap: _handleEpisodeTap,
            onEpisodePlay: _handleEpisodePlay,
            onPodcastSubscribe: _handleSubscribeFromSearch,
            isDense: isDense,
          )
        : _buildDiscoverContent(context, discoverState, isDense);

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = MediaQuery.sizeOf(context).height;
        final screenWidth = MediaQuery.sizeOf(context).width;
        final useCompactShell =
            constraints.maxHeight < 540 || screenHeight < 720;
        final headerSpacing = screenWidth < 600 ? 20.0 : 12.0;

        return ContentShell(
          title: l10n.podcast_discover_title,
          subtitle: '',
          headerSpacing: headerSpacing,
          roundedViewport: true,
          badges: const [],
          trailing: _SearchModeToggle(
            searchMode: searchMode,
            isDense: isDense,
            onTabSelected: _handleDiscoverTabSelected,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DiscoverSearchInput(
                searchController: _searchController,
                searchFocusNode: _searchFocusNode,
                onSearchChanged: _onSearchChanged,
                onClearSearch: _clearSearch,
                onCountryTap: () => _openCountrySelector(context),
                searchMode: searchMode,
                isDense: isDense,
              ),
              SizedBox(height: useCompactShell ? 10 : 12),
              Expanded(child: Material(color: Colors.transparent, child: content)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDiscoverContent(
      BuildContext context, PodcastDiscoverState discoverState, bool isDense) {
    final l10n = context.l10n;

    if (discoverState.isLoading &&
        discoverState.topShows.isEmpty &&
        discoverState.topEpisodes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = discoverState.error;
    if (error != null &&
        discoverState.topShows.isEmpty &&
        discoverState.topEpisodes.isEmpty) {
      return _buildErrorView(context, l10n, error);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DiscoverTopChartsSection(
          state: discoverState,
          onCategorySelected: _handleDiscoverCategorySelected,
          isDense: isDense,
        ),
        SizedBox(height: isDense ? 10 : 14),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.read(podcastDiscoverProvider.notifier).refresh(),
            child: DiscoverChartsList(
              state: discoverState,
              scrollController: _discoverListScrollController,
              onItemTap: _handleChartRowTap,
              onItemSubscribe: _handleSubscribeFromChart,
              onItemPlay: _playEpisodeFromChartRow,
              subscribingShowIds: _subscribingShowIds,
              subscribedShowIds: _subscribedShowIds,
              isDense: isDense,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorView(BuildContext context, AppLocalizations l10n, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 44),
          const SizedBox(height: 12),
          Text(error),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () =>
                ref.read(podcastDiscoverProvider.notifier).loadInitialData(),
            icon: const Icon(Icons.refresh),
            label: Text(l10n.retry),
          ),
        ],
      ),
    );
  }
}

class _SearchModeToggle extends StatelessWidget {
  const _SearchModeToggle({
    required this.searchMode,
    required this.isDense,
    required this.onTabSelected,
  });

  final search.PodcastSearchMode searchMode;
  final bool isDense;
  final ValueChanged<search.PodcastSearchMode> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final toggleHeight = isDense ? 30.0 : 32.0;

    return Container(
      key: const Key('podcast_discover_tab_selector'),
      height: toggleHeight,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(toggleHeight / 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TabPill(
            key: const Key('podcast_discover_tab_episodes'),
            label: l10n.podcast_episodes,
            icon: Icons.headphones_outlined,
            selected: searchMode == search.PodcastSearchMode.episodes,
            isDense: isDense,
            height: toggleHeight - 4,
            onTap: () => onTabSelected(search.PodcastSearchMode.episodes),
          ),
          const SizedBox(width: 2),
          _TabPill(
            key: const Key('podcast_discover_tab_podcasts'),
            label: l10n.podcast_title,
            icon: Icons.podcasts,
            selected: searchMode == search.PodcastSearchMode.podcasts,
            isDense: isDense,
            height: toggleHeight - 4,
            onTap: () => onTabSelected(search.PodcastSearchMode.podcasts),
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.isDense,
    required this.height,
    required this.onTap,
  });

  final Key key;
  final String label;
  final IconData icon;
  final bool selected;
  final bool isDense;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foregroundColor = selected
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurfaceVariant;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      color: foregroundColor,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      height: height,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(height / 2),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13, color: foregroundColor),
                const SizedBox(width: 3),
                Text(label, style: labelStyle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscoverEpisodeSelection {
  const _DiscoverEpisodeSelection({
    required this.showId,
    required this.episode,
  });

  final int showId;
  final ITunesPodcastEpisodeResult episode;
}
