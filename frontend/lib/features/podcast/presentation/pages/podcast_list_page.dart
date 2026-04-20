import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/constants/app_durations.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/constants/breakpoints.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/utils/debounce.dart';
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive.dart';
import 'package:personal_ai_assistant/core/widgets/adaptive_sheet_helper.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/core/widgets/linear_section_header.dart';
import 'package:personal_ai_assistant/core/widgets/top_floating_notice.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_discover_chart_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_search_provider.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/country_selector_dropdown.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/discover/discover_charts_list.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/pages/sections/discover_interaction_handler.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/pages/sections/search_mode_toggle.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/discover/discover_search_input.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/discover/discover_top_charts_section.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/search/podcast_search_results_list.dart';
import 'package:personal_ai_assistant/shared/widgets/skeleton_widgets.dart';

/// Podcast list/discover page with search and top charts.
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
      unawaited(_loadInitialData());
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

  Future<void> _loadInitialData() async {
    try {
      await ref.read(podcastSubscriptionProvider.notifier).loadSubscriptions();
      await ref.read(podcastDiscoverProvider.notifier).loadInitialData();
    } catch (error) {
      if (mounted) {
        showTopFloatingNotice(
          context,
          message: context.l10n.error,
          isError: true,
        );
      }
    }
  }

  void _handleDiscoverTabSelected(PodcastSearchMode mode) {
    ref.read(podcastSearchProvider.notifier).setSearchMode(mode);
    ref.read(podcastDiscoverProvider.notifier).setTab(
          mode == PodcastSearchMode.podcasts
              ? PodcastDiscoverTab.podcasts
              : PodcastDiscoverTab.episodes,
        );
    _resetDiscoverListScroll();
  }

  void _handleDiscoverCategorySelected(String category) {
    ref.read(podcastDiscoverProvider.notifier).selectCategory(category);
    _resetDiscoverListScroll();
  }

  void _onSearchChanged(String query) {
    if (query.trim().isEmpty) {
      _searchDebounce?.cancel();
      ref.read(podcastSearchProvider.notifier).clearSearch();
      return;
    }
    _searchDebounce?.cancel();
    _searchDebounce = DebounceTimer(
      AppDurations.debounceMedium,
      () {
        final notifier = ref.read(podcastSearchProvider.notifier);
        final mode = ref.read(podcastSearchProvider).searchMode;
        mode == PodcastSearchMode.episodes
            ? notifier.searchEpisodes(query)
            : notifier.searchPodcasts(query);
      },
    );
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(podcastSearchProvider.notifier).clearSearch();
    _searchFocusNode.requestFocus();
  }

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

  Future<void> _handleSubscribeFromChart(PodcastDiscoverItem item) async {
    final l10n = context.l10n;
    final country = ref.read(countrySelectorProvider).selectedCountry;
    final itunesId = item.itunesId;

    if (itunesId == null || _subscribingShowIds.contains(itunesId)) return;

    setState(() => _subscribingShowIds.add(itunesId));

    try {
      final searchService = ref.read(iTunesSearchServiceProvider);
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
      showTopFloatingNotice(
        context,
        message: l10n.podcast_subscribe_success(lookup?.collectionName ?? item.title),
      );
    } catch (error) {
      if (!mounted) return;
      showTopFloatingNotice(
        context,
        message: l10n.podcast_subscribe_failed(error.toString()),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _subscribingShowIds.remove(itunesId));
    }
  }

  Future<void> _openCountrySelector(BuildContext context) async {
    await showAdaptiveSheet<void>(
      context: context,
      desktopMaxWidth: 480,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.all(context.spacing.md),
            child: CountrySelectorDropdown(
              onCountryChanged: (country) {
                _resetDiscoverListScroll();
                ref.read(podcastDiscoverProvider.notifier).onCountryChanged(country);
                if (ref.read(podcastSearchProvider).currentQuery.isNotEmpty) {
                  ref.read(podcastSearchProvider.notifier).retrySearch();
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
    final searchState = ref.watch(podcastSearchProvider);
    final discoverState = ref.watch(podcastDiscoverProvider);
    const isDense = true;
    final hasSearched = searchState.hasSearched;
    final searchMode = searchState.searchMode;

    final content = hasSearched
        ? PodcastSearchResultsList(
            searchState: searchState,
            onEpisodeTap: (e) =>
                DiscoverInteractionHandler.handleEpisodeTap(ref, context, e),
            onEpisodePlay: (e) =>
                DiscoverInteractionHandler.handleEpisodePlay(ref, context, e),
            onPodcastSubscribe: (r) =>
                DiscoverInteractionHandler.subscribeFromSearch(ref, context, r),
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
          trailing: SearchModeToggle(
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
              SizedBox(height: useCompactShell ? context.spacing.smMd : context.spacing.md),
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
      return LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final isMobile = screenWidth < Breakpoints.medium;
          if (isMobile) {
            return const DiscoverChartSkeletonList(itemCount: 6, compact: true);
          }
          final crossAxisCount = screenWidth < 900
              ? 2
              : (screenWidth < 1200 ? 3 : 4);
          return DiscoverChartSkeletonGrid(
            crossAxisCount: crossAxisCount,
            itemCount: crossAxisCount * 2,
          );
        },
      );
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
        SizedBox(height: isDense ? context.spacing.sm : context.spacing.md),
        LinearSectionHeader.label(
          l10n.podcast_discover_browse_by_category,
          padding: EdgeInsets.symmetric(horizontal: context.spacing.xs, vertical: context.spacing.xs),
        ),
        SizedBox(height: isDense ? context.spacing.smMd : context.spacing.sm),
        Expanded(
          child: AdaptiveRefreshIndicator(
            onRefresh: () => ref.read(podcastDiscoverProvider.notifier).refresh(),
            child: DiscoverChartsList(
              state: discoverState,
              scrollController: _discoverListScrollController,
              onItemTap: (item) =>
                  DiscoverInteractionHandler.handleChartRowTap(ref, context, item),
              onItemSubscribe: _handleSubscribeFromChart,
              onItemPlay: (item) =>
                  DiscoverInteractionHandler.playEpisodeFromChartRow(ref, context, item),
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
    return AppEmptyState(
      icon: Icons.error_outline,
      title: error,
      action: FilledButton.icon(
        onPressed: () =>
            ref.read(podcastDiscoverProvider.notifier).loadInitialData(),
        icon: const Icon(Icons.refresh),
        label: Text(l10n.retry),
      ),
    );
  }
}
