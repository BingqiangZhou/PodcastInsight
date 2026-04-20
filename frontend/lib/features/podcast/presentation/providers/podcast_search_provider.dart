import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/constants/app_durations.dart';
import 'package:personal_ai_assistant/core/constants/cache_constants.dart';
import 'package:personal_ai_assistant/core/storage/local_storage_service.dart';
import 'package:personal_ai_assistant/core/utils/debounce.dart' as utils;
import 'package:personal_ai_assistant/features/podcast/data/models/itunes_episode_lookup_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_discover_chart_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_search_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/services/apple_podcast_rss_service.dart';
import 'package:personal_ai_assistant/features/podcast/data/services/itunes_search_service.dart';

enum PodcastSearchMode { podcasts, episodes }

final podcastSearchDebounceDurationProvider = Provider<Duration>((ref) {
  return AppDurations.debounceMedium;
});

class PodcastSearchState extends Equatable {

  const PodcastSearchState({
    this.podcastResults = const [],
    this.episodeResults = const [],
    this.isLoading = false,
    this.hasSearched = false,
    this.error,
    this.currentQuery = '',
    this.searchCountry = PodcastCountry.china,
    this.searchMode = PodcastSearchMode.episodes,
  });
  final List<PodcastSearchResult> podcastResults;
  final List<ITunesPodcastEpisodeResult> episodeResults;
  final bool isLoading;
  final bool hasSearched;
  final String? error;
  final String currentQuery;
  final PodcastCountry searchCountry;
  final PodcastSearchMode searchMode;

  PodcastSearchState copyWith({
    List<PodcastSearchResult>? podcastResults,
    List<ITunesPodcastEpisodeResult>? episodeResults,
    bool? isLoading,
    bool? hasSearched,
    String? error,
    String? currentQuery,
    PodcastCountry? searchCountry,
    PodcastSearchMode? searchMode,
  }) {
    return PodcastSearchState(
      podcastResults: podcastResults ?? this.podcastResults,
      episodeResults: episodeResults ?? this.episodeResults,
      isLoading: isLoading ?? this.isLoading,
      hasSearched: hasSearched ?? this.hasSearched,
      error: error,
      currentQuery: currentQuery ?? this.currentQuery,
      searchCountry: searchCountry ?? this.searchCountry,
      searchMode: searchMode ?? this.searchMode,
    );
  }

  @override
  List<Object?> get props => [
        podcastResults,
        episodeResults,
        isLoading,
        hasSearched,
        error,
        currentQuery,
        searchCountry,
        searchMode,
      ];
}

final iTunesSearchServiceProvider = Provider<ITunesSearchService>((ref) {
  return ITunesSearchService();
});

final podcastSearchProvider =
    NotifierProvider<PodcastSearchNotifier, PodcastSearchState>(
      PodcastSearchNotifier.new,
    );

class PodcastSearchNotifier extends Notifier<PodcastSearchState> {
  utils.DebounceTimer? _debounce;
  Duration get _debounceDuration => ref.read(podcastSearchDebounceDurationProvider);
  int _activeSearchRequestId = 0;

  @override
  PodcastSearchState build() {
    ref.onDispose(() {
      _debounce?.cancel();
    });

    return const PodcastSearchState();
  }

  void searchPodcasts(String query) {
    _scheduleSearch(query, PodcastSearchMode.podcasts);
  }

  void searchEpisodes(String query) {
    _scheduleSearch(query, PodcastSearchMode.episodes);
  }

  void setSearchMode(PodcastSearchMode mode) {
    if (state.searchMode == mode) {
      return;
    }

    final hasQuery = state.currentQuery.trim().isNotEmpty;
    state = state.copyWith(
      searchMode: mode,
      isLoading: hasQuery,
      hasSearched: hasQuery,
      podcastResults: mode == PodcastSearchMode.podcasts
          ? state.podcastResults
          : const [],
      episodeResults: mode == PodcastSearchMode.episodes
          ? state.episodeResults
          : const [],
    );

    if (hasQuery) {
      _scheduleSearch(state.currentQuery, mode, bypassDebounce: true);
    }
  }

  void _scheduleSearch(
    String query,
    PodcastSearchMode mode, {
    bool bypassDebounce = false,
  }) {
    _debounce?.cancel();
    final normalizedQuery = query.trim();

    if (normalizedQuery.isEmpty) {
      _activeSearchRequestId += 1;
      state = PodcastSearchState(searchMode: mode);
      return;
    }

    state = state.copyWith(
      isLoading: true,
      hasSearched: true,
      currentQuery: normalizedQuery,
      searchMode: mode,
    );

    final requestId = ++_activeSearchRequestId;
    final delay = bypassDebounce ? Duration.zero : _debounceDuration;
    _debounce = utils.DebounceTimer(delay, () async {
      await _performSearch(normalizedQuery, mode, requestId: requestId);
    });
  }

  Future<void> _performSearch(
    String query,
    PodcastSearchMode mode, {
    required int requestId,
  }) async {
    final country = ref.read(countrySelectorProvider).selectedCountry;
    final searchService = ref.read(iTunesSearchServiceProvider);

    try {
      if (mode == PodcastSearchMode.podcasts) {
        final response = await searchService.searchPodcasts(
          term: query,
          country: country,
        );
        if (!_isRequestActive(requestId, query, mode)) {
          return;
        }
        state = state.copyWith(
          podcastResults: response.results,
          episodeResults: const [],
          isLoading: false,
          searchCountry: country,
          searchMode: mode,
        );
        return;
      }

      final episodes = await searchService.searchPodcastEpisodes(
        term: query,
        country: country,
      );
      if (!_isRequestActive(requestId, query, mode)) {
        return;
      }
      state = state.copyWith(
        podcastResults: const [],
        episodeResults: episodes,
        isLoading: false,
        searchCountry: country,
        searchMode: mode,
      );
    } catch (error) {
      if (!_isRequestActive(requestId, query, mode)) {
        return;
      }
      state = state.copyWith(
        podcastResults: const [],
        episodeResults: const [],
        isLoading: false,
        searchCountry: country,
        error: error.toString(),
        searchMode: mode,
      );
    }
  }

  bool _isRequestActive(
    int requestId,
    String query,
    PodcastSearchMode mode,
  ) {
    return requestId == _activeSearchRequestId &&
        state.currentQuery == query &&
        state.searchMode == mode;
  }

  void clearSearch() {
    _debounce?.cancel();
    _activeSearchRequestId += 1;
    state = PodcastSearchState(searchMode: state.searchMode);
  }

  Future<void> retrySearch() async {
    if (state.currentQuery.isEmpty) {
      return;
    }

    state = state.copyWith(isLoading: true);
    final requestId = ++_activeSearchRequestId;
    await _performSearch(
      state.currentQuery,
      state.searchMode,
      requestId: requestId,
    );
  }
}

// Country Selector

/// 国家选择状态
class CountrySelectorState {

  const CountrySelectorState({
    required this.selectedCountry,
    this.isLoading = false,
  });
  final PodcastCountry selectedCountry;
  final bool isLoading;

  CountrySelectorState copyWith({
    PodcastCountry? selectedCountry,
    bool? isLoading,
  }) {
    return CountrySelectorState(
      selectedCountry: selectedCountry ?? this.selectedCountry,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// 国家选择器 Notifier
final countrySelectorProvider =
    NotifierProvider<CountrySelectorNotifier, CountrySelectorState>(
      CountrySelectorNotifier.new,
    );

class CountrySelectorNotifier extends Notifier<CountrySelectorState> {
   @override
  CountrySelectorState build() {
    final localStorage = ref.read(localStorageServiceProvider);

    // Load saved country preference asynchronously
    _loadSavedCountry(localStorage);

    return CountrySelectorState(
      selectedCountry: _getDefaultCountry(),
    );
  }

  /// 获取默认国家
  PodcastCountry _getDefaultCountry() {
    return PodcastCountry.china;
  }

  /// 从本地存储加载保存的国家偏好
  Future<void> _loadSavedCountry(LocalStorageService localStorage) async {
    final savedCountryCode = await localStorage.getString('podcast_search_country');

    if (savedCountryCode != null) {
      final savedCountry = PodcastCountry.values.firstWhere(
        (country) => country.code == savedCountryCode,
        orElse: _getDefaultCountry,
      );

      if (state.selectedCountry != savedCountry) {
        state = CountrySelectorState(selectedCountry: savedCountry);
      }
    }
  }

  /// 选择国家
  Future<void> selectCountry(PodcastCountry country) async {
    final localStorage = ref.read(localStorageServiceProvider);

    state = CountrySelectorState(selectedCountry: country);

    // 保存到本地存储
    await localStorage.saveString('podcast_search_country', country.code);
  }

  /// 获取当前选中的国家
  PodcastCountry get selectedCountry => state.selectedCountry;
}

// Discover

enum PodcastDiscoverTab { podcasts, episodes }

class PodcastDiscoverPaginationState extends Equatable {

  const PodcastDiscoverPaginationState({
    this.loadedCount = 0,
    this.isLoadingMore = false,
    this.hasMore = false,
  });
  final int loadedCount;
  final bool isLoadingMore;
  final bool hasMore;

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

  @override
  List<Object?> get props => [loadedCount, isLoadingMore, hasMore];
}

class PodcastDiscoverState extends Equatable {

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
    final refreshTime = lastRefreshTime;
    if (refreshTime == null) return false;
    return DateTime.now().difference(refreshTime) < cacheDuration;
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

  @override
  List<Object?> get props => [
    country,
    isLoading,
    isRefreshing,
    error,
    selectedTab,
    selectedCategory,
    topShows,
    topEpisodes,
    showsPagination,
    episodesPagination,
    lastRefreshTime,
  ];
}

final applePodcastRssServiceProvider = Provider<ApplePodcastRssService>((ref) {
  return ApplePodcastRssService.ref();
});

final podcastDiscoverProvider =
    NotifierProvider<PodcastDiscoverNotifier, PodcastDiscoverState>(
      PodcastDiscoverNotifier.new,
    );

class PodcastDiscoverNotifier extends Notifier<PodcastDiscoverState> {
  ApplePodcastRssService get _rssService => ref.read(applePodcastRssServiceProvider);
  Future<void>? _inFlightLoad;
  PodcastCountry? _inFlightLoadCountry;
  Future<void>? _inFlightShowsLoadMore;
  Future<void>? _inFlightEpisodesLoadMore;
  int _activeRequestId = 0;

  @override
  PodcastDiscoverState build() {
    // Reset in-flight tracking on rebuild to avoid stale futures
    _inFlightLoad = null;
    _inFlightLoadCountry = null;
    _inFlightShowsLoadMore = null;
    _inFlightEpisodesLoadMore = null;

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
        );
        final episodesFuture = _rssService.fetchTopEpisodes(
          country: country,
        );

        // Parallel loading for better performance
        final (showsResponse, episodesResponse) = await (
          showsFuture,
          episodesFuture,
        ).wait;

        if (!_isRequestActive(requestId)) {
          return;
        }

        final shows = _mapChartItems(
          showsResponse,
          defaultKind: PodcastDiscoverKind.podcasts,
        );
        final episodes = _mapChartItems(
          episodesResponse,
          defaultKind: PodcastDiscoverKind.podcastEpisodes,
        );

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
