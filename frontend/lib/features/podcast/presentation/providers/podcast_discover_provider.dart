import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/cache_constants.dart';
import '../../data/models/podcast_discover_chart_model.dart';
import '../../data/models/podcast_search_model.dart';
import '../../data/services/apple_podcast_rss_service.dart';
import 'country_selector_provider.dart';

enum PodcastDiscoverTab { podcasts, episodes }

class PodcastDiscoverPaginationState {
  final int loadedCount;
  final bool isLoadingMore;
  final bool hasMore;

  const PodcastDiscoverPaginationState({
    this.loadedCount = 0,
    this.isLoadingMore = false,
    this.hasMore = false,
  });

  PodcastDiscoverPaginationState copyWith({
    int? loadedCount,
    bool? isLoadingMore,
    bool? hasMore,
  }) {
    return PodcastDiscoverPaginationState(
      loadedCount: loadedCount ?? this.loadedCount,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class PodcastDiscoverState {
  final PodcastCountry country;
  final bool isLoading;
  final bool isRefreshing;
  final String? error;
  final PodcastDiscoverTab selectedTab;
  final String selectedCategory;
  final List<PodcastDiscoverItem> topShows;
  final List<PodcastDiscoverItem> topEpisodes;
  final PodcastDiscoverPaginationState showsPagination;
  final PodcastDiscoverPaginationState episodesPagination;
  final DateTime? lastRefreshTime;

  const PodcastDiscoverState({
    required this.country,
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
    this.selectedTab = PodcastDiscoverTab.episodes,
    this.selectedCategory = allCategoryValue,
    this.topShows = const [],
    this.topEpisodes = const [],
    this.showsPagination = const PodcastDiscoverPaginationState(),
    this.episodesPagination = const PodcastDiscoverPaginationState(),
    this.lastRefreshTime,
  });

  static const String allCategoryValue = '__all__';

  PodcastDiscoverState copyWith({
    PodcastCountry? country,
    bool? isLoading,
    bool? isRefreshing,
    String? error,
    bool clearError = false,
    PodcastDiscoverTab? selectedTab,
    String? selectedCategory,
    List<PodcastDiscoverItem>? topShows,
    List<PodcastDiscoverItem>? topEpisodes,
    PodcastDiscoverPaginationState? showsPagination,
    PodcastDiscoverPaginationState? episodesPagination,
    DateTime? lastRefreshTime,
  }) {
    return PodcastDiscoverState(
      country: country ?? this.country,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: clearError ? null : (error ?? this.error),
      selectedTab: selectedTab ?? this.selectedTab,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      topShows: topShows ?? this.topShows,
      topEpisodes: topEpisodes ?? this.topEpisodes,
      showsPagination: showsPagination ?? this.showsPagination,
      episodesPagination: episodesPagination ?? this.episodesPagination,
      lastRefreshTime: lastRefreshTime ?? this.lastRefreshTime,
    );
  }

  bool isDataFresh({
    Duration cacheDuration = CacheConstants.discoverCacheDuration,
  }) {
    if (lastRefreshTime == null) return false;
    return DateTime.now().difference(lastRefreshTime!) < cacheDuration;
  }

  List<PodcastDiscoverItem> get activeItems =>
      selectedTab == PodcastDiscoverTab.podcasts ? topShows : topEpisodes;

  PodcastDiscoverPaginationState get currentPagination =>
      selectedTab == PodcastDiscoverTab.podcasts
      ? showsPagination
      : episodesPagination;

  bool get isCurrentTabLoadingMore => currentPagination.isLoadingMore;

  bool get currentTabHasMore => currentPagination.hasMore;

  int get currentTabLoadedCount => currentPagination.loadedCount;

  List<String> get categories {
    final counts = <String, int>{};
    for (final item in activeItems) {
      for (final genre in item.genres) {
        final trimmed = genre.trim();
        if (trimmed.isEmpty) continue;
        counts[trimmed] = (counts[trimmed] ?? 0) + 1;
      }
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) {
        final countCompare = b.value.compareTo(a.value);
        if (countCompare != 0) return countCompare;
        return a.key.toLowerCase().compareTo(b.key.toLowerCase());
      });
    return sorted.map((entry) => entry.key).toList();
  }

  List<PodcastDiscoverItem> get filteredActiveItems {
    if (selectedCategory == allCategoryValue) {
      return activeItems;
    }
    return activeItems
        .where((item) => item.hasGenre(selectedCategory))
        .toList();
  }

  List<PodcastDiscoverItem> get visibleItems => filteredActiveItems;
}

final applePodcastRssServiceProvider = Provider<ApplePodcastRssService>((ref) {
  return ApplePodcastRssService.ref(ref);
});

final podcastDiscoverProvider =
    NotifierProvider<PodcastDiscoverNotifier, PodcastDiscoverState>(
      PodcastDiscoverNotifier.new,
    );

class PodcastDiscoverNotifier extends Notifier<PodcastDiscoverState> {
  late final ApplePodcastRssService _rssService;
  Future<void>? _inFlightLoad;
  PodcastCountry? _inFlightLoadCountry;
  Future<void>? _inFlightShowsLoadMore;
  Future<void>? _inFlightEpisodesLoadMore;
  int _activeRequestId = 0;

  @override
  PodcastDiscoverState build() {
    _rssService = ref.read(applePodcastRssServiceProvider);
    final selectedCountry = ref.read(countrySelectorProvider).selectedCountry;

    ref.listen<CountrySelectorState>(countrySelectorProvider, (previous, next) {
      final previousCountry = previous?.selectedCountry;
      if (previousCountry != next.selectedCountry) {
        unawaited(onCountryChanged(next.selectedCountry));
      }
    });

    return PodcastDiscoverState(country: selectedCountry);
  }

  Future<void> loadInitialData() async {
    if (_hasAnyData && state.isDataFresh()) {
      return;
    }
    await _loadCharts(country: state.country, isRefresh: false);
  }

  Future<void> refresh() async {
    await _loadCharts(
      country: state.country,
      isRefresh: true,
      forceRefresh: true,
    );
  }

  Future<void> onCountryChanged(PodcastCountry country) async {
    if (country == state.country && _hasAnyData && state.isDataFresh()) {
      return;
    }
    state = state.copyWith(
      country: country,
      selectedCategory: PodcastDiscoverState.allCategoryValue,
      topShows: const [],
      topEpisodes: const [],
      showsPagination: const PodcastDiscoverPaginationState(),
      episodesPagination: const PodcastDiscoverPaginationState(),
      clearError: true,
    );
    await _loadCharts(country: country, isRefresh: false, forceRefresh: true);
  }

  void setTab(PodcastDiscoverTab tab) {
    if (tab == state.selectedTab) return;
    state = state.copyWith(
      selectedTab: tab,
      selectedCategory: PodcastDiscoverState.allCategoryValue,
      clearError: true,
    );
  }

  void selectCategory(String category) {
    final normalized = category.trim();
    if (normalized.isEmpty) {
      return;
    }
    state = state.copyWith(selectedCategory: normalized);
  }

  Future<void> loadMoreCurrentTab() async {
    if (state.isLoading || state.isRefreshing || state.activeItems.isEmpty) {
      return;
    }

    await _loadMoreTab(state.selectedTab);
  }

  void clearRuntimeCache() {
    final rssService = ref.read(applePodcastRssServiceProvider);
    final selectedCountry = ref.read(countrySelectorProvider).selectedCountry;
    rssService.clearCache();
    _activeRequestId += 1;
    _inFlightLoad = null;
    _inFlightLoadCountry = null;
    _inFlightShowsLoadMore = null;
    _inFlightEpisodesLoadMore = null;
    state = PodcastDiscoverState(country: selectedCountry);
  }

  Future<void> _loadCharts({
    required PodcastCountry country,
    required bool isRefresh,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        country == state.country &&
        _hasAnyData &&
        state.isDataFresh()) {
      return;
    }

    final existingLoad = _inFlightLoad;
    if (existingLoad != null &&
        !forceRefresh &&
        _inFlightLoadCountry == country) {
      return existingLoad;
    }

    final requestId = ++_activeRequestId;
    final selectedTab = state.selectedTab;
    _inFlightShowsLoadMore = null;
    _inFlightEpisodesLoadMore = null;
    _inFlightLoadCountry = country;

    state = state.copyWith(
      country: country,
      isLoading: !isRefresh,
      isRefreshing: isRefresh,
      selectedCategory: PodcastDiscoverState.allCategoryValue,
      clearError: true,
    );

    final loadFuture = () async {
      try {
        final showsFuture = _rssService.fetchTopShows(
          country: country,
          limit: CacheConstants.discoverInitialFetchLimit,
          format: ApplePodcastRssFormat.json,
        );
        final episodesFuture = _rssService.fetchTopEpisodes(
          country: country,
          limit: CacheConstants.discoverInitialFetchLimit,
          format: ApplePodcastRssFormat.json,
        );

        List<PodcastDiscoverItem>? shows;
        List<PodcastDiscoverItem>? episodes;

        if (selectedTab == PodcastDiscoverTab.podcasts) {
          final showsResponse = await showsFuture;
          shows = _mapChartItems(
            showsResponse,
            defaultKind: PodcastDiscoverKind.podcasts,
          );
          if (_isRequestActive(requestId)) {
            state = state.copyWith(
              isLoading: false,
              isRefreshing: false,
              topShows: shows,
              showsPagination: _paginationStateFor(
                requestedLimit: CacheConstants.discoverInitialFetchLimit,
                loadedCount: shows.length,
              ),
              selectedCategory: PodcastDiscoverState.allCategoryValue,
              clearError: true,
            );
          }
          final episodesResponse = await episodesFuture;
          episodes = _mapChartItems(
            episodesResponse,
            defaultKind: PodcastDiscoverKind.podcastEpisodes,
          );
        } else {
          final episodesResponse = await episodesFuture;
          episodes = _mapChartItems(
            episodesResponse,
            defaultKind: PodcastDiscoverKind.podcastEpisodes,
          );
          if (_isRequestActive(requestId)) {
            state = state.copyWith(
              isLoading: false,
              isRefreshing: false,
              topEpisodes: episodes,
              episodesPagination: _paginationStateFor(
                requestedLimit: CacheConstants.discoverInitialFetchLimit,
                loadedCount: episodes.length,
              ),
              selectedCategory: PodcastDiscoverState.allCategoryValue,
              clearError: true,
            );
          }
          final showsResponse = await showsFuture;
          shows = _mapChartItems(
            showsResponse,
            defaultKind: PodcastDiscoverKind.podcasts,
          );
        }

        if (!_isRequestActive(requestId)) {
          return;
        }

        state = state.copyWith(
          country: country,
          isLoading: false,
          isRefreshing: false,
          topShows: shows,
          topEpisodes: episodes,
          showsPagination: _paginationStateFor(
            requestedLimit: CacheConstants.discoverInitialFetchLimit,
            loadedCount: shows.length,
          ),
          episodesPagination: _paginationStateFor(
            requestedLimit: CacheConstants.discoverInitialFetchLimit,
            loadedCount: episodes.length,
          ),
          selectedCategory: PodcastDiscoverState.allCategoryValue,
          clearError: true,
          lastRefreshTime: DateTime.now(),
        );
      } catch (error) {
        if (!_isRequestActive(requestId)) {
          return;
        }
        state = state.copyWith(
          isLoading: false,
          isRefreshing: false,
          error: error.toString(),
        );
      }
    }();

    _inFlightLoad = loadFuture;
    try {
      await loadFuture;
    } finally {
      if (identical(_inFlightLoad, loadFuture)) {
        _inFlightLoad = null;
        _inFlightLoadCountry = null;
      }
    }
  }

  Future<void> _loadMoreTab(PodcastDiscoverTab tab) async {
    final inFlight = tab == PodcastDiscoverTab.podcasts
        ? _inFlightShowsLoadMore
        : _inFlightEpisodesLoadMore;
    if (inFlight != null) {
      return inFlight;
    }

    final pagination = tab == PodcastDiscoverTab.podcasts
        ? state.showsPagination
        : state.episodesPagination;
    if (pagination.isLoadingMore || !pagination.hasMore) {
      return;
    }

    final nextLimit = _nextHydrationTarget(pagination.loadedCount);
    if (nextLimit == null) {
      return;
    }

    final previousPagination = pagination;
    final requestId = _activeRequestId;
    final country = state.country;

    state = _copyWithTabPagination(
      state,
      tab,
      pagination.copyWith(isLoadingMore: true),
      clearError: true,
    );

    final loadMoreFuture = () async {
      try {
        if (tab == PodcastDiscoverTab.podcasts) {
          final response = await _rssService.fetchTopShows(
            country: country,
            limit: nextLimit,
            format: ApplePodcastRssFormat.json,
          );
          if (!_isRequestActive(requestId) || state.country != country) {
            return;
          }

          final items = _mapChartItems(
            response,
            defaultKind: PodcastDiscoverKind.podcasts,
          );
          state = _copyWithTabItems(
            state,
            tab,
            items,
            _paginationStateFor(
              requestedLimit: nextLimit,
              loadedCount: items.length,
            ),
            clearError: true,
          );
          return;
        }

        final response = await _rssService.fetchTopEpisodes(
          country: country,
          limit: nextLimit,
          format: ApplePodcastRssFormat.json,
        );
        if (!_isRequestActive(requestId) || state.country != country) {
          return;
        }

        final items = _mapChartItems(
          response,
          defaultKind: PodcastDiscoverKind.podcastEpisodes,
        );
        state = _copyWithTabItems(
          state,
          tab,
          items,
          _paginationStateFor(
            requestedLimit: nextLimit,
            loadedCount: items.length,
          ),
          clearError: true,
        );
      } catch (error) {
        if (!_isRequestActive(requestId) || state.country != country) {
          return;
        }

        state = _copyWithTabPagination(
          state,
          tab,
          previousPagination.copyWith(isLoadingMore: false),
          error: error.toString(),
        );
      }
    }();

    if (tab == PodcastDiscoverTab.podcasts) {
      _inFlightShowsLoadMore = loadMoreFuture;
    } else {
      _inFlightEpisodesLoadMore = loadMoreFuture;
    }

    try {
      await loadMoreFuture;
    } finally {
      if (tab == PodcastDiscoverTab.podcasts) {
        if (identical(_inFlightShowsLoadMore, loadMoreFuture)) {
          _inFlightShowsLoadMore = null;
        }
      } else if (identical(_inFlightEpisodesLoadMore, loadMoreFuture)) {
        _inFlightEpisodesLoadMore = null;
      }
    }
  }

  bool get _hasAnyData =>
      state.topShows.isNotEmpty || state.topEpisodes.isNotEmpty;

  bool _isRequestActive(int requestId) =>
      ref.mounted && requestId == _activeRequestId;

  PodcastDiscoverState _copyWithTabPagination(
    PodcastDiscoverState currentState,
    PodcastDiscoverTab tab,
    PodcastDiscoverPaginationState pagination, {
    String? error,
    bool clearError = false,
  }) {
    return currentState.copyWith(
      showsPagination: tab == PodcastDiscoverTab.podcasts ? pagination : null,
      episodesPagination: tab == PodcastDiscoverTab.episodes
          ? pagination
          : null,
      error: error,
      clearError: clearError,
    );
  }

  PodcastDiscoverState _copyWithTabItems(
    PodcastDiscoverState currentState,
    PodcastDiscoverTab tab,
    List<PodcastDiscoverItem> items,
    PodcastDiscoverPaginationState pagination, {
    bool clearError = false,
  }) {
    return currentState.copyWith(
      topShows: tab == PodcastDiscoverTab.podcasts ? items : null,
      topEpisodes: tab == PodcastDiscoverTab.episodes ? items : null,
      showsPagination: tab == PodcastDiscoverTab.podcasts ? pagination : null,
      episodesPagination: tab == PodcastDiscoverTab.episodes
          ? pagination
          : null,
      clearError: clearError,
    );
  }

  PodcastDiscoverPaginationState _paginationStateFor({
    required int requestedLimit,
    required int loadedCount,
  }) {
    final hasMore =
        requestedLimit < CacheConstants.discoverTopChartMaxLimit &&
        loadedCount >= requestedLimit;
    return PodcastDiscoverPaginationState(
      loadedCount: loadedCount,
      isLoadingMore: false,
      hasMore: hasMore,
    );
  }

  int? _nextHydrationTarget(int currentCount) {
    if (currentCount >= CacheConstants.discoverTopChartMaxLimit) {
      return null;
    }

    final normalized = currentCount < CacheConstants.discoverInitialFetchLimit
        ? CacheConstants.discoverInitialFetchLimit
        : currentCount;
    final nextLimit = normalized + CacheConstants.discoverHydrationStep;
    return nextLimit > CacheConstants.discoverTopChartMaxLimit
        ? CacheConstants.discoverTopChartMaxLimit
        : nextLimit;
  }

  List<PodcastDiscoverItem> _mapChartItems(
    ApplePodcastChartResponse response, {
    required PodcastDiscoverKind defaultKind,
  }) {
    return response.feed.results
        .map(
          (entry) => PodcastDiscoverItem.fromChartEntry(
            entry,
            defaultKind: defaultKind,
          ),
        )
        .toList();
  }
}
