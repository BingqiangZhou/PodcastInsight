import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/utils/debounce.dart' as utils;
import 'package:personal_ai_assistant/features/podcast/data/models/itunes_episode_lookup_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_search_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/services/itunes_search_service.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/country_selector_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'podcast_search_provider.g.dart';

enum PodcastSearchMode { podcasts, episodes }

final podcastSearchDebounceDurationProvider = Provider<Duration>((ref) {
  return const Duration(milliseconds: 400);
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

@riverpod
class PodcastSearchNotifier extends _$PodcastSearchNotifier {
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
