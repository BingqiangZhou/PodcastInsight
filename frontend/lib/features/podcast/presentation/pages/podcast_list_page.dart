import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/app_shells.dart';
import '../../../../core/widgets/adaptive_sheet_helper.dart';
import '../../../../core/widgets/top_floating_notice.dart';
import '../../data/models/podcast_discover_chart_model.dart';
import '../../data/models/itunes_episode_lookup_model.dart';
import '../../data/models/podcast_episode_model.dart';
import '../../data/models/podcast_search_model.dart';
import '../../data/utils/podcast_url_utils.dart';
import '../constants/podcast_ui_constants.dart';
import '../providers/country_selector_provider.dart';
import '../providers/podcast_discover_provider.dart';
import '../providers/podcast_providers.dart';
import '../providers/podcast_subscription_selectors.dart';
import '../providers/podcast_search_provider.dart' as search;
import '../widgets/country_selector_dropdown.dart';
import '../widgets/discover_episode_detail_sheet.dart';
import '../widgets/discover_show_episodes_sheet.dart';
import '../widgets/podcast_image_widget.dart';
import '../widgets/podcast_episode_search_result_card.dart';
import '../widgets/podcast_search_result_card.dart';

class PodcastListPage extends ConsumerStatefulWidget {
  const PodcastListPage({super.key});

  @override
  ConsumerState<PodcastListPage> createState() => _PodcastListPageState();
}

class _PodcastListPageState extends ConsumerState<PodcastListPage> {
  static const double _kDiscoverLoadMoreExtentThreshold = 320;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _discoverListScrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();
  final Set<int> _subscribingShowIds = <int>{};
  final Set<int> _subscribedShowIds = <int>{};

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
    _discoverListScrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _openCountrySelector(BuildContext context) async {
    await showAdaptiveSheet<void>(
      context: context,
      desktopMaxWidth: 480,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: CountrySelectorDropdown(
              onCountryChanged: (country) {
                _resetDiscoverListScroll();
                ref
                    .read(podcastDiscoverProvider.notifier)
                    .onCountryChanged(country);
                if (ref
                    .read(search.podcastSearchProvider)
                    .currentQuery
                    .isNotEmpty) {
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

  void _onSearchChanged(String query) {
    if (query.trim().isEmpty) {
      ref.read(search.podcastSearchProvider.notifier).clearSearch();
      return;
    }
    final notifier = ref.read(search.podcastSearchProvider.notifier);
    final mode = ref.read(search.podcastSearchProvider).searchMode;
    if (mode == search.PodcastSearchMode.episodes) {
      notifier.searchEpisodes(query);
      return;
    }
    notifier.searchPodcasts(query);
  }

  void _onDiscoverListScroll() {
    if (!_discoverListScrollController.hasClients) {
      return;
    }

    final position = _discoverListScrollController.position;
    if (position.extentAfter > _kDiscoverLoadMoreExtentThreshold) {
      return;
    }

    ref.read(podcastDiscoverProvider.notifier).loadMoreCurrentTab();
  }

  void _resetDiscoverListScroll() {
    if (!_discoverListScrollController.hasClients) {
      return;
    }

    _discoverListScrollController.jumpTo(0);
  }

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

  void _clearSearch() {
    _searchController.clear();
    ref.read(search.podcastSearchProvider.notifier).clearSearch();
    _searchFocusNode.requestFocus();
  }

  Future<void> _handleSubscribeFromSearch(PodcastSearchResult result) async {
    final l10n = AppLocalizations.of(context)!;
    if (result.feedUrl == null || result.collectionName == null) {
      showTopFloatingNotice(
        context,
        message: l10n.podcast_subscribe_failed('Invalid podcast data'),
        isError: true,
      );
      return;
    }

    try {
      await ref
          .read(podcastSubscriptionProvider.notifier)
          .addSubscription(feedUrl: result.feedUrl!);
      if (!mounted) return;
      showTopFloatingNotice(
        context,
        message: l10n.podcast_subscribe_success(result.collectionName!),
      );
    } catch (error) {
      if (!mounted) return;
      showTopFloatingNotice(
        context,
        message: l10n.podcast_subscribe_failed(error.toString()),
        isError: true,
      );
    }
  }

  Future<void> _handleSubscribeFromChart(PodcastDiscoverItem item) async {
    final l10n = AppLocalizations.of(context)!;
    final country = ref.read(countrySelectorProvider).selectedCountry;
    final itunesId = item.itunesId;

    if (itunesId == null) {
      showTopFloatingNotice(
        context,
        message: l10n.podcast_subscribe_failed('Invalid show id'),
        isError: true,
      );
      return;
    }
    if (_subscribingShowIds.contains(itunesId)) {
      return;
    }

    setState(() {
      _subscribingShowIds.add(itunesId);
    });

    try {
      final searchService = ref.read(search.iTunesSearchServiceProvider);
      final lookup = await searchService.lookupPodcast(
        itunesId: itunesId,
        country: country,
      );
      if (lookup?.feedUrl == null) {
        throw Exception('No RSS feed url for this show');
      }

      await ref
          .read(podcastSubscriptionProvider.notifier)
          .addSubscription(feedUrl: lookup!.feedUrl!);

      if (!mounted) return;
      setState(() {
        _subscribedShowIds.add(itunesId);
      });
      showTopFloatingNotice(
        context,
        message: l10n.podcast_subscribe_success(
          lookup.collectionName ?? item.title,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      showTopFloatingNotice(
        context,
        message: l10n.podcast_subscribe_failed(error.toString()),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _subscribingShowIds.remove(itunesId);
        });
      }
    }
  }

  void _showErrorNotice(String message) {
    if (!mounted) return;
    showTopFloatingNotice(context, message: message, isError: true);
  }

  Future<void> _handleChartRowTap(PodcastDiscoverItem item) async {
    if (item.isPodcastShow) {
      await _showPodcastEpisodeInfoSheet(item);
      return;
    }
    await _showEpisodeDetailSheet(item);
  }

  int? _resolveShowIdForPodcast(PodcastDiscoverItem item) {
    final searchService = ref.read(search.iTunesSearchServiceProvider);
    return item.itunesId ??
        searchService.extractShowIdFromApplePodcastUrl(item.url);
  }

  Future<_DiscoverEpisodeSelection?> _resolveDiscoverEpisodeSelection(
    PodcastDiscoverItem item,
  ) async {
    final l10n = AppLocalizations.of(context)!;
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
    } catch (_) {
      _showErrorNotice(l10n.podcast_failed_load_episodes);
      return null;
    }
  }

  Future<void> _showPodcastEpisodeInfoSheet(PodcastDiscoverItem item) async {
    final l10n = AppLocalizations.of(context)!;
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
      if (!mounted) return;
      if (lookup.episodes.isEmpty) {
        _showErrorNotice(l10n.podcast_no_episodes_found);
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
              onEpisodeSelected: (episode) async {
                Navigator.of(sheetContext).pop();
                await _showEpisodeDetailSheetFromSearch(episode);
              },
              onPlayEpisode: (episode) async {
                Navigator.of(sheetContext).pop();
                await _playDiscoverEpisode(
                  episode: episode,
                  showId: showId,
                );
              },
            ),
          );
        },
      );
    } catch (_) {
      _showErrorNotice(l10n.podcast_failed_load_episodes);
    }
  }

  Future<void> _showEpisodeDetailSheet(PodcastDiscoverItem item) async {
    final selection = await _resolveDiscoverEpisodeSelection(item);
    if (selection == null || !mounted) {
      return;
    }

    final episode = selection.episode;
    await showAdaptiveSheet<void>(
      context: context,
      builder: (sheetContext) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.9,
          ),
          child: DiscoverEpisodeDetailSheet(
            episode: episode,
            onPlay: () async {
              Navigator.of(sheetContext).pop();
              await _playDiscoverEpisode(
                episode: episode,
                showId: selection.showId,
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _playEpisodeFromChartRow(PodcastDiscoverItem item) async {
    final selection = await _resolveDiscoverEpisodeSelection(item);
    if (selection == null) {
      return;
    }
    await _playDiscoverEpisode(
      episode: selection.episode,
      showId: selection.showId,
    );
  }

  Future<void> _playDiscoverEpisode({
    required ITunesPodcastEpisodeResult episode,
    required int showId,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final audioUrl = episode.resolvedAudioUrl;
    if (audioUrl == null || audioUrl.isEmpty) {
      _showErrorNotice(l10n.podcast_player_no_audio);
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
      audioDuration: episode.trackTimeMillis == null
          ? null
          : (episode.trackTimeMillis! / 1000).round(),
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
    } catch (_) {
      _showErrorNotice(l10n.podcast_player_no_audio);
    }
  }

  Future<ITunesPodcastEpisodeResult?> _resolveEpisodeForSearchResult(
    ITunesPodcastEpisodeResult episode,
  ) async {
    final audioUrl = episode.resolvedAudioUrl;
    if (audioUrl != null && audioUrl.isNotEmpty) {
      return episode;
    }
    final country = ref.read(countrySelectorProvider).selectedCountry;
    final searchService = ref.read(search.iTunesSearchServiceProvider);
    try {
      return await searchService.findEpisodeInLookup(
        showId: episode.collectionId,
        episodeTrackId: episode.trackId,
        country: country,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _showEpisodeDetailSheetFromSearch(
    ITunesPodcastEpisodeResult episode,
  ) async {
    final resolved = await _resolveEpisodeForSearchResult(episode);
    if (!mounted) return;
    if (resolved == null) {
      final l10n = AppLocalizations.of(context)!;
      _showErrorNotice(l10n.podcast_failed_load_episodes);
      return;
    }
    await showAdaptiveSheet<void>(
      context: context,
      builder: (sheetContext) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.9,
          ),
          child: DiscoverEpisodeDetailSheet(
            episode: resolved,
            onPlay: () async {
              Navigator.of(sheetContext).pop();
              await _playDiscoverEpisode(
                episode: resolved,
                showId: resolved.collectionId,
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasSearched = ref.watch(
      search.podcastSearchProvider.select((state) => state.hasSearched),
    );
    final searchMode = ref.watch(
      search.podcastSearchProvider.select((state) => state.searchMode),
    );
    final selectedCountry = ref.watch(
      countrySelectorProvider.select((state) => state.selectedCountry),
    );
    const isDense = true;
    final content = hasSearched
        ? Consumer(
            builder: (context, localRef, _) {
              final searchState = localRef.watch(search.podcastSearchProvider);
              return _buildSearchResults(
                context,
                searchState,
                l10n,
                isDense: isDense,
              );
            },
          )
        : Consumer(
            builder: (context, localRef, _) {
              final discoverState = localRef.watch(podcastDiscoverProvider);
              return _buildDiscoverContent(
                context,
                discoverState,
                isDense: isDense,
              );
            },
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenHeight = MediaQuery.of(context).size.height;
        final screenWidth = MediaQuery.of(context).size.width;
        final useCompactShell =
            constraints.maxHeight < 540 || screenHeight < 720;
        final headerSpacing = screenWidth < 600 ? 20.0 : 12.0;

        return ContentShell(
          title: l10n.podcast_discover_title,
          subtitle: '',
          headerSpacing: headerSpacing,
          roundedViewport: true,
          badges: const [],
          trailing: HeaderCapsuleActionButton(
            key: const Key('podcast_discover_country_button'),
            tooltip: l10n.podcast_country_label,
            onPressed: () => _openCountrySelector(context),
            icon: Icons.flag_outlined,
            label: Text(selectedCountry.code.toUpperCase()),
            trailingIcon: Icons.keyboard_arrow_down_rounded,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassPanel(
                key: const Key('podcast_discover_search_panel'),
                padding: EdgeInsets.all(useCompactShell ? 10 : 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSearchModeSelector(
                      context,
                      searchMode,
                      isDense: isDense,
                    ),
                    SizedBox(height: useCompactShell ? 6 : 8),
                    _buildDiscoverSearchInput(
                      context,
                      l10n,
                      searchMode: searchMode,
                      isDense: isDense,
                    ),
                  ],
                ),
              ),
              SizedBox(height: useCompactShell ? 10 : 12),
              Expanded(
                child: Material(color: Colors.transparent, child: content),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDiscoverContent(
    BuildContext context,
    PodcastDiscoverState discoverState, {
    required bool isDense,
  }) {
    final l10n = AppLocalizations.of(context)!;

    if (discoverState.isLoading &&
        discoverState.topShows.isEmpty &&
        discoverState.topEpisodes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (discoverState.error != null &&
        discoverState.topShows.isEmpty &&
        discoverState.topEpisodes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 44),
            const SizedBox(height: 12),
            Text(discoverState.error!),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                ref.read(podcastDiscoverProvider.notifier).loadInitialData();
              },
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTopChartsSection(context, discoverState, isDense: isDense),
        SizedBox(height: isDense ? 10 : 14),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () =>
                ref.read(podcastDiscoverProvider.notifier).refresh(),
            child: _buildDiscoverChartsList(
              context,
              discoverState,
              isDense: isDense,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchModeSelector(
    BuildContext context,
    search.PodcastSearchMode searchMode, {
    required bool isDense,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Container(
      key: const Key('podcast_discover_tab_selector'),
      height: isDense ? 40 : 44,
      padding: EdgeInsets.all(isDense ? 3 : 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(kPodcastMiniCornerRadius),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabItem(
              context: context,
              key: const Key('podcast_discover_tab_episodes'),
              label: l10n.podcast_episodes,
              icon: Icons.headphones_outlined,
              selected: searchMode == search.PodcastSearchMode.episodes,
              isDense: isDense,
              onTap: () =>
                  _handleDiscoverTabSelected(search.PodcastSearchMode.episodes),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildTabItem(
              context: context,
              key: const Key('podcast_discover_tab_podcasts'),
              label: l10n.podcast_title,
              icon: Icons.podcasts,
              selected: searchMode == search.PodcastSearchMode.podcasts,
              isDense: isDense,
              onTap: () =>
                  _handleDiscoverTabSelected(search.PodcastSearchMode.podcasts),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoverSearchInput(
    BuildContext context,
    AppLocalizations l10n, {
    required search.PodcastSearchMode searchMode,
    required bool isDense,
  }) {
    final theme = Theme.of(context);
    final hintLabel = searchMode == search.PodcastSearchMode.episodes
        ? l10n.podcast_search_section_episodes
        : l10n.podcast_search_section_podcasts;
    final isZh = Localizations.localeOf(context).languageCode.startsWith('zh');
    final hintText = isZh
        ? '${l10n.search}$hintLabel...'
        : '${l10n.search} $hintLabel...';

    return Material(
      key: const Key('podcast_discover_search_bar'),
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kPodcastMiniCornerRadius),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: SizedBox(
        height: isDense ? 44 : 48,
        child: Row(
          children: [
            Padding(
              padding: EdgeInsets.only(left: isDense ? 10 : 12),
              child: Icon(
                Icons.search,
                size: isDense ? 18 : 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(width: isDense ? 6 : 8),
            Expanded(
              child: TextField(
                key: const Key('podcast_discover_search_input'),
                controller: _searchController,
                focusNode: _searchFocusNode,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  filled: false,
                  fillColor: Colors.transparent,
                  hintText: hintText,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  hintStyle: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                onChanged: (value) {
                  _onSearchChanged(value);
                },
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchController,
              builder: (context, value, _) {
                if (value.text.isNotEmpty) {
                  return IconButton(
                    onPressed: _clearSearch,
                    icon: Icon(
                      Icons.clear,
                      size: isDense ? 16 : 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  );
                }
                return SizedBox(width: isDense ? 6 : 8);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required BuildContext context,
    required Key key,
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    bool isDense = false,
  }) {
    final theme = Theme.of(context);
    final foregroundColor = selected
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurfaceVariant;
    final labelStyle =
        (isDense ? theme.textTheme.titleSmall : theme.textTheme.titleMedium)
            ?.copyWith(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: foregroundColor,
            );

    return AnimatedContainer(
      key: key,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected ? theme.colorScheme.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(kPodcastMiniCornerRadius),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(kPodcastMiniCornerRadius),
          onTap: onTap,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: isDense ? 16 : 18, color: foregroundColor),
                SizedBox(width: isDense ? 4 : 6),
                Text(label, style: labelStyle),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopChartsSection(
    BuildContext context,
    PodcastDiscoverState state, {
    required bool isDense,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold);
    final subtitleColor = Theme.of(context).colorScheme.onSurfaceVariant;
    final countryName = _countryDisplayName(state.country, l10n);

    return Column(
      key: const Key('podcast_discover_top_charts'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(l10n.podcast_discover_top_charts, style: titleStyle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    l10n.podcast_discover_trending_in(countryName),
                    key: const Key('podcast_discover_trending_label'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: subtitleColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: isDense ? 6 : 10),
        _buildCategorySection(context, state),
      ],
    );
  }

  Widget _buildDiscoverChartsList(
    BuildContext context,
    PodcastDiscoverState state, {
    required bool isDense,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final visibleItems = state.visibleItems;

    return ListView.builder(
      key: const Key('podcast_discover_list'),
      controller: _discoverListScrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: isDense ? 12 : 16),
      itemCount: switch ((
        visibleItems.isEmpty,
        state.isCurrentTabLoadingMore,
      )) {
        (true, _) => 1,
        (false, true) => visibleItems.length + 1,
        (false, false) => visibleItems.length,
      },
      itemBuilder: (context, index) {
        if (visibleItems.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text(l10n.podcast_discover_no_chart_data)),
          );
        }

        if (index >= visibleItems.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final item = visibleItems[index];
        return _buildChartRow(context, index + 1, item, isDense: isDense);
      },
    );
  }

  Widget _buildChartRow(
    BuildContext context,
    int rank,
    PodcastDiscoverItem item, {
    required bool isDense,
  }) {
    final theme = Theme.of(context);
    final showSubscribe = item.isPodcastShow;
    final itunesId = item.itunesId;
    final rankLabel = '$rank';
    final rankSlotWidth = isDense ? 44.0 : 48.0;
    final actionSlotWidth = rankSlotWidth;
    final isSubscribing =
        itunesId != null && _subscribingShowIds.contains(itunesId);
    final isSubscribed =
        itunesId != null && _subscribedShowIds.contains(itunesId);
    final rowOuterPadding = isDense ? 3.0 : 6.0;
    final rowInnerPadding = isDense ? 4.0 : 6.0;
    final imageSize = isDense ? 56.0 : 62.0;
    final titleStyle =
        (isDense ? theme.textTheme.titleSmall : theme.textTheme.titleMedium)
            ?.copyWith(fontWeight: FontWeight.w700);
    final subtitleStyle =
        (isDense ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium)
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Padding(
      key: Key('podcast_discover_chart_row_${item.itemId}'),
      padding: EdgeInsets.symmetric(vertical: rowOuterPadding),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _handleChartRowTap(item),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: rowInnerPadding),
          child: Row(
            children: [
              SizedBox(
                width: rankSlotWidth,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      key: Key(
                        'podcast_discover_chart_rank_text_${item.itemId}',
                      ),
                      rankLabel,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: isDense ? 4 : 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: PodcastImageWidget(
                  imageUrl: item.artworkUrl,
                  width: imageSize,
                  height: imageSize,
                  iconSize: 24,
                ),
              ),
              SizedBox(width: isDense ? 10 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: subtitleStyle,
                    ),
                  ],
                ),
              ),
              SizedBox(width: isDense ? 6 : 8),
              if (showSubscribe)
                SizedBox(
                  width: actionSlotWidth,
                  child: Center(
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: isSubscribing
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              key: Key(
                                'podcast_discover_subscribe_${item.itemId}',
                              ),
                              onPressed: isSubscribed
                                  ? null
                                  : () => _handleSubscribeFromChart(item),
                              style: IconButton.styleFrom(
                                minimumSize: const Size(36, 36),
                                maximumSize: const Size(36, 36),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ),
                              icon: Icon(
                                isSubscribed
                                    ? Icons.check_circle
                                    : Icons.add_circle_outline,
                              ),
                            ),
                    ),
                  ),
                ),
              if (!showSubscribe)
                SizedBox(
                  width: actionSlotWidth,
                  child: Center(
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: IconButton(
                        key: Key('podcast_discover_play_${item.itemId}'),
                        onPressed: () => _playEpisodeFromChartRow(item),
                        style: IconButton.styleFrom(
                          minimumSize: const Size(36, 36),
                          maximumSize: const Size(36, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          foregroundColor: theme.colorScheme.onSurfaceVariant,
                        ),
                        icon: const Icon(Icons.play_circle_outline, size: 24),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySection(
    BuildContext context,
    PodcastDiscoverState state,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final categories = state.categories;
    final theme = Theme.of(context);
    final selected = state.selectedCategory;

    final chipItems = <String>[
      PodcastDiscoverState.allCategoryValue,
      ...categories,
    ];
    final keyOccurrences = <String, int>{};

    return SingleChildScrollView(
      key: const Key('podcast_discover_category_chips'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          for (var index = 0; index < chipItems.length; index++) ...[
            () {
              final rawValue = chipItems[index];
              final baseKey = _normalizeCategoryKey(rawValue);
              final count = (keyOccurrences[baseKey] ?? 0) + 1;
              keyOccurrences[baseKey] = count;
              final uniqueKey = count == 1 ? baseKey : '${baseKey}_$count';

              return _buildCategoryChip(
                theme: theme,
                label: rawValue == PodcastDiscoverState.allCategoryValue
                    ? l10n.podcast_filter_all
                    : rawValue,
                selected: rawValue == PodcastDiscoverState.allCategoryValue
                    ? selected == PodcastDiscoverState.allCategoryValue
                    : selected.toLowerCase() == rawValue.toLowerCase(),
                onSelected: (_) => _handleDiscoverCategorySelected(rawValue),
                keyValue: uniqueKey,
              );
            }(),
            if (index != chipItems.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryChip({
    required ThemeData theme,
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
    required String keyValue,
  }) {
    final selectedBackgroundColor = theme.colorScheme.onSurfaceVariant;
    final selectedLabelColor = theme.colorScheme.surface;

    return ChoiceChip(
      key: Key(
        'podcast_discover_category_chip_${_normalizeCategoryKey(keyValue)}',
      ),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      visualDensity: const VisualDensity(horizontal: -1, vertical: -2),
      side: BorderSide(
        color: selected
            ? selectedBackgroundColor
            : theme.colorScheme.outlineVariant,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      labelStyle: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: selected
            ? selectedLabelColor
            : theme.colorScheme.onSurfaceVariant,
      ),
      selectedColor: selectedBackgroundColor,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    );
  }

  String _normalizeCategoryKey(String value) {
    final normalized = value.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '_',
    );
    final trimmed = normalized.replaceAll(RegExp(r'^_+|_+$'), '');
    return trimmed.isEmpty ? 'category' : trimmed;
  }

  Widget _buildSearchResults(
    BuildContext context,
    search.PodcastSearchState searchState,
    AppLocalizations l10n, {
    required bool isDense,
  }) {
    if (searchState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (searchState.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 44),
            const SizedBox(height: 12),
            Text(searchState.error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                ref.read(search.podcastSearchProvider.notifier).retrySearch();
              },
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          ],
        ),
      );
    }

    final resultsEmpty =
        searchState.searchMode == search.PodcastSearchMode.episodes
        ? searchState.episodeResults.isEmpty
        : searchState.podcastResults.isEmpty;
    if (resultsEmpty) {
      return Center(
        child: Text(
          l10n.podcast_search_no_results,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    if (searchState.searchMode == search.PodcastSearchMode.episodes) {
      return ListView.builder(
        key: const Key('podcast_discover_search_results'),
        itemCount: searchState.episodeResults.length,
        itemBuilder: (context, index) {
          final episode = searchState.episodeResults[index];
          return _buildEpisodeSearchResultItem(
            episode: episode,
            isDense: isDense,
            l10n: l10n,
          );
        },
      );
    }

    final normalizedSubscribedFeedUrls = ref.watch(
      subscribedNormalizedFeedUrlsProvider,
    );
    final normalizedSubscribingFeedUrls = ref.watch(
      subscribingNormalizedFeedUrlsProvider,
    );

    return ListView.builder(
      key: const Key('podcast_discover_search_results'),
      itemCount: searchState.podcastResults.length,
      itemBuilder: (context, index) {
        final result = searchState.podcastResults[index];
        return _buildPodcastSearchResultItem(
          result: result,
          isDense: isDense,
          searchCountry: searchState.searchCountry,
          normalizedSubscribedFeedUrls: normalizedSubscribedFeedUrls,
          normalizedSubscribingFeedUrls: normalizedSubscribingFeedUrls,
        );
      },
    );
  }

  Widget _buildEpisodeSearchResultItem({
    required ITunesPodcastEpisodeResult episode,
    required bool isDense,
    required AppLocalizations l10n,
  }) {
    return PodcastEpisodeSearchResultCard(
      episode: episode,
      dense: isDense,
      onTap: () => _showEpisodeDetailSheetFromSearch(episode),
      onPlay: () async {
        final resolved = await _resolveEpisodeForSearchResult(episode);
        if (!mounted) return;
        if (resolved == null) {
          _showErrorNotice(l10n.podcast_player_no_audio);
          return;
        }
        await _playDiscoverEpisode(
          episode: resolved,
          showId: resolved.collectionId,
        );
      },
      key: ValueKey('episode_search_${episode.trackId}'),
    );
  }

  Widget _buildPodcastSearchResultItem({
    required PodcastSearchResult result,
    required bool isDense,
    required PodcastCountry searchCountry,
    required Set<String> normalizedSubscribedFeedUrls,
    required Set<String> normalizedSubscribingFeedUrls,
  }) {
    final normalizedResultFeedUrl = result.feedUrl == null
        ? null
        : PodcastUrlUtils.normalizeFeedUrl(result.feedUrl!);
    final isSubscribed =
        normalizedResultFeedUrl != null &&
        normalizedSubscribedFeedUrls.contains(normalizedResultFeedUrl);
    final isSubscribing =
        normalizedResultFeedUrl != null &&
        normalizedSubscribingFeedUrls.contains(normalizedResultFeedUrl);

    return PodcastSearchResultCard(
      result: result,
      onSubscribe: _handleSubscribeFromSearch,
      isSubscribed: isSubscribed,
      isSubscribing: isSubscribing,
      searchCountry: searchCountry,
      dense: isDense,
      key: ValueKey('search_${result.feedUrl}'),
    );
  }

  String _countryDisplayName(PodcastCountry country, AppLocalizations l10n) {
    return switch (country.localizationKey) {
      'podcast_country_china' => l10n.podcast_country_china,
      'podcast_country_usa' => l10n.podcast_country_usa,
      'podcast_country_japan' => l10n.podcast_country_japan,
      'podcast_country_uk' => l10n.podcast_country_uk,
      'podcast_country_germany' => l10n.podcast_country_germany,
      'podcast_country_france' => l10n.podcast_country_france,
      'podcast_country_canada' => l10n.podcast_country_canada,
      'podcast_country_australia' => l10n.podcast_country_australia,
      'podcast_country_korea' => l10n.podcast_country_korea,
      'podcast_country_taiwan' => l10n.podcast_country_taiwan,
      'podcast_country_hong_kong' => l10n.podcast_country_hong_kong,
      'podcast_country_india' => l10n.podcast_country_india,
      'podcast_country_brazil' => l10n.podcast_country_brazil,
      'podcast_country_mexico' => l10n.podcast_country_mexico,
      'podcast_country_spain' => l10n.podcast_country_spain,
      'podcast_country_italy' => l10n.podcast_country_italy,
      _ => country.code.toUpperCase(),
    };
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
