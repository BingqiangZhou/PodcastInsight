import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/storage/local_storage_service.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/audio_player_state_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/itunes_episode_lookup_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_discover_chart_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_search_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_state_models.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_subscription_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/services/apple_podcast_rss_service.dart';
import 'package:personal_ai_assistant/features/podcast/data/services/itunes_search_service.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/pages/podcast_list_page.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_search_provider.dart';

// ---------------------------------------------------------------------------
// Shared mocks
// ---------------------------------------------------------------------------

class MockLocalStorageService implements LocalStorageService {
  final Map<String, dynamic> _storage = {};

  @override
  Future<void> saveString(String key, String value) async =>
      _storage[key] = value;

  @override
  Future<String?> getString(String key) async => _storage[key] as String?;

  @override
  Future<void> saveBool(String key, bool value) async => _storage[key] = value;

  @override
  Future<bool?> getBool(String key) async => _storage[key] as bool?;

  @override
  Future<void> saveInt(String key, int value) async => _storage[key] = value;

  @override
  Future<int?> getInt(String key) async => _storage[key] as int?;

  @override
  Future<void> saveDouble(String key, double value) async =>
      _storage[key] = value;

  @override
  Future<double?> getDouble(String key) async => _storage[key] as double?;

  @override
  Future<void> saveStringList(String key, List<String> value) async =>
      _storage[key] = value;

  @override
  Future<List<String>?> getStringList(String key) async =>
      _storage[key] as List<String>?;

  @override
  Future<void> save<T>(String key, T value) async => _storage[key] = value;

  @override
  Future<T?> get<T>(String key) async => _storage[key] as T?;

  @override
  Future<void> remove(String key) async => _storage.remove(key);

  @override
  Future<void> clear() async => _storage.clear();

  @override
  Future<bool> containsKey(String key) async => _storage.containsKey(key);

  @override
  Future<void> cacheData(
    String key,
    dynamic data, {
    Duration? expiration,
  }) async {
    _storage[key] = data;
  }

  @override
  Future<T?> getCachedData<T>(String key) async => _storage[key] as T?;

  @override
  Future<void> clearExpiredCache() async {}

  @override
  Future<void> saveApiBaseUrl(String url) async =>
      _storage['api_base_url'] = url;

  @override
  Future<String?> getApiBaseUrl() async => _storage['api_base_url'] as String?;

  @override
  Future<void> saveServerBaseUrl(String url) async =>
      _storage['server_base_url'] = url;

  @override
  Future<String?> getServerBaseUrl() async =>
      _storage['server_base_url'] as String?;
}

/// Builds chart responses that respect the [limit] parameter passed to
/// [fetchTopShows] / [fetchTopEpisodes].
/// Uses [showsBaseId] for show IDs and [episodesBaseId] for episode IDs.
/// If [showsBaseId] == [episodesBaseId], both tabs produce the same ID range.
class FakeApplePodcastRssService extends ApplePodcastRssService {
  FakeApplePodcastRssService({
    this.showsBaseId = 1000,
    int? episodesBaseId,
  }) : episodesBaseId = episodesBaseId ?? showsBaseId;

  final int showsBaseId;
  final int episodesBaseId;

  @override
  Future<ApplePodcastChartResponse> fetchTopShows({
    required PodcastCountry country,
    int limit = 25,
    ApplePodcastRssFormat format = ApplePodcastRssFormat.json,
  }) async {
    return _buildResponse('podcasts', country.code, limit, showsBaseId);
  }

  @override
  Future<ApplePodcastChartResponse> fetchTopEpisodes({
    required PodcastCountry country,
    int limit = 25,
    ApplePodcastRssFormat format = ApplePodcastRssFormat.json,
  }) async {
    return _buildResponse(
        'podcast-episodes', country.code, limit, episodesBaseId);
  }

  ApplePodcastChartResponse _buildResponse(
      String kind, String country, int count, int base) {
    final items = List.generate(
      count,
      (index) => ApplePodcastChartEntry.fromJson({
        'artistName': 'Artist $index',
        'id': '${base + index}',
        'name': 'Chart Item $index',
        'kind': kind,
        'artworkUrl100': 'https://example.com/$index.png',
        'genres': [
          {'name': index.isEven ? 'Technology' : 'News'},
        ],
        'url': 'https://podcasts.apple.com/$country/podcast/id${base + index}',
      }),
    );
    return ApplePodcastChartResponse(
      feed: ApplePodcastChartFeed(
        title: kind,
        country: country,
        updated: '2026-02-14T00:00:00Z',
        results: items,
      ),
    );
  }
}

/// A [FakeApplePodcastRssService] that returns a single show (id 111) and a
/// single episode (id 222) — used by the discover-actions tests.
class SingleItemFakeApplePodcastRssService extends ApplePodcastRssService {
  SingleItemFakeApplePodcastRssService() : super();

  @override
  Future<ApplePodcastChartResponse> fetchTopShows({
    required PodcastCountry country,
    int limit = 25,
    ApplePodcastRssFormat format = ApplePodcastRssFormat.json,
  }) async {
    return ApplePodcastChartResponse(
      feed: ApplePodcastChartFeed(
        title: 'Top Shows',
        country: country.code,
        updated: '2026-02-14T00:00:00Z',
        results: [
          ApplePodcastChartEntry.fromJson({
            'artistName': 'Show Artist',
            'id': '111',
            'name': 'Show One',
            'kind': 'podcasts',
            'artworkUrl100': 'https://example.com/show.png',
            'genres': [
              {'name': 'Technology'},
            ],
            'url': 'https://podcasts.apple.com/us/podcast/show-one/id111',
          }),
        ],
      ),
    );
  }

  @override
  Future<ApplePodcastChartResponse> fetchTopEpisodes({
    required PodcastCountry country,
    int limit = 25,
    ApplePodcastRssFormat format = ApplePodcastRssFormat.json,
  }) async {
    return ApplePodcastChartResponse(
      feed: ApplePodcastChartFeed(
        title: 'Top Episodes',
        country: country.code,
        updated: '2026-02-14T00:00:00Z',
        results: [
          ApplePodcastChartEntry.fromJson({
            'artistName': 'Episode Artist',
            'id': '222',
            'name': 'Episode One',
            'kind': 'podcast-episodes',
            'artworkUrl100': 'https://example.com/ep.png',
            'genres': [
              {'name': 'News'},
            ],
            'url':
                'https://podcasts.apple.com/us/podcast/episode-one/id333?i=222',
          }),
        ],
      ),
    );
  }
}

/// Minimal subscription notifier with no data and no-op methods.
class EmptyPodcastSubscriptionNotifier extends PodcastSubscriptionNotifier {
  EmptyPodcastSubscriptionNotifier();

  @override
  PodcastSubscriptionState build() {
    return const PodcastSubscriptionState(hasMore: false);
  }

  @override
  Future<void> loadSubscriptions({
    int page = 1,
    int size = 10,
    int? categoryId,
    String? status,
    bool forceRefresh = false,
  }) async {}

  @override
  Future<void> loadMoreSubscriptions({int? categoryId, String? status}) async {}

  @override
  Future<void> refreshSubscriptions({int? categoryId, String? status}) async {}
}

/// Subscription notifier that accepts an initial state.
class TestPodcastSubscriptionNotifier extends PodcastSubscriptionNotifier {
  TestPodcastSubscriptionNotifier(this._initialState);

  final PodcastSubscriptionState _initialState;

  @override
  PodcastSubscriptionState build() => _initialState;

  @override
  Future<void> loadSubscriptions({
    int page = 1,
    int size = 10,
    int? categoryId,
    String? status,
    bool forceRefresh = false,
  }) async {}

  @override
  Future<void> loadMoreSubscriptions({int? categoryId, String? status}) async {}

  @override
  Future<void> refreshSubscriptions({int? categoryId, String? status}) async {}
}

/// Subscription notifier that records the last added feed URL.
class FakePodcastSubscriptionNotifier extends PodcastSubscriptionNotifier {
  String? lastAddedFeedUrl;

  @override
  PodcastSubscriptionState build() => const PodcastSubscriptionState(
        hasMore: false,
      );

  @override
  Future<void> loadSubscriptions({
    int page = 1,
    int size = 10,
    int? categoryId,
    String? status,
    bool forceRefresh = false,
  }) async {}

  @override
  Future<void> loadMoreSubscriptions({int? categoryId, String? status}) async {}

  @override
  Future<void> refreshSubscriptions({int? categoryId, String? status}) async {}

  @override
  Future<PodcastSubscriptionModel> addSubscription({
    required String feedUrl,
    List<int>? categoryIds,
  }) async {
    lastAddedFeedUrl = feedUrl;
    final now = DateTime.now();
    return PodcastSubscriptionModel(
      id: 1,
      userId: 1,
      title: 'Subscribed',
      sourceUrl: feedUrl,
      status: 'active',
      fetchInterval: 3600,
      createdAt: now,
    );
  }
}

/// Subscription notifier that delays then sets total=25.
class DelayedSubscriptionNotifier extends PodcastSubscriptionNotifier {
  @override
  PodcastSubscriptionState build() {
    return const PodcastSubscriptionState();
  }

  @override
  Future<void> loadSubscriptions({
    int page = 1,
    int size = 10,
    int? categoryId,
    String? status,
    bool forceRefresh = false,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    state = state.copyWith(total: 25);
  }

  @override
  Future<void> loadMoreSubscriptions({int? categoryId, String? status}) async {}

  @override
  Future<void> refreshSubscriptions({int? categoryId, String? status}) async {}
}

/// Search notifier that just returns its initial state.
class PassthroughPodcastSearchNotifier extends PodcastSearchNotifier {
  PassthroughPodcastSearchNotifier(this._initial);

  final PodcastSearchState _initial;

  @override
  PodcastSearchState build() => _initial;
}

/// Search notifier that overrides search/clear with real state mutations.
class InteractivePodcastSearchNotifier extends PodcastSearchNotifier {
  InteractivePodcastSearchNotifier(this._initialState);

  final PodcastSearchState _initialState;

  @override
  PodcastSearchState build() => _initialState;

  @override
  void searchPodcasts(String query) {
    state = state.copyWith(
      currentQuery: query,
      hasSearched: query.trim().isNotEmpty,
    );
  }

  @override
  void searchEpisodes(String query) {
    state = state.copyWith(
      currentQuery: query,
      hasSearched: query.trim().isNotEmpty,
    );
  }

  @override
  void clearSearch() {
    state = PodcastSearchState(searchMode: state.searchMode);
  }
}

/// Fake iTunes search service used by discover-actions tests.
class FakeITunesSearchService extends ITunesSearchService {
  FakeITunesSearchService() : super();

  bool lookupCalled = false;
  bool lookupEpisodesCalled = false;

  @override
  Future<PodcastSearchResult?> lookupPodcast({
    required int itunesId,
    PodcastCountry country = PodcastCountry.china,
  }) async {
    lookupCalled = true;
    return const PodcastSearchResult(
      collectionId: 111,
      collectionName: 'Show One',
      artistName: 'Show Artist',
      feedUrl: 'https://example.com/feed.xml',
    );
  }

  @override
  Future<ITunesPodcastLookupResult> lookupPodcastEpisodes({
    required int showId,
    PodcastCountry country = PodcastCountry.china,
    int limit = 50,
  }) async {
    lookupEpisodesCalled = true;

    if (showId == 111) {
      return ITunesPodcastLookupResult(
        showId: showId,
        collectionName: 'Show One',
        artistName: 'Show Artist',
        feedUrl: 'https://example.com/feed.xml',
        collectionViewUrl:
            'https://podcasts.apple.com/us/podcast/show-one/id111',
        episodes: [
          ITunesPodcastEpisodeResult(
            trackId: 1001,
            collectionId: 111,
            trackName: 'Show Episode Preview',
            collectionName: 'Show One',
            feedUrl: 'https://example.com/feed.xml',
            releaseDate: DateTime(2026, 2, 14),
            trackTimeMillis: 120000,
          ),
        ],
      );
    }

    return ITunesPodcastLookupResult(
      showId: showId,
      collectionName: 'Top Episode Show',
      artistName: 'Episode Artist',
      feedUrl: 'https://example.com/episode-feed.xml',
      collectionViewUrl:
          'https://podcasts.apple.com/us/podcast/top-episode/id333',
      episodes: [
        ITunesPodcastEpisodeResult(
          trackId: 222,
          collectionId: 333,
          trackName: 'Episode One',
          collectionName: 'Top Episode Show',
          feedUrl: 'https://example.com/episode-feed.xml',
          episodeUrl: 'https://example.com/episode-222.mp3',
          releaseDate: DateTime(2026, 2, 14),
          trackTimeMillis: 180000,
        ),
      ],
    );
  }
}

/// Mock audio player notifier that records the last played episode.
class MockAudioPlayerNotifier extends AudioPlayerNotifier {
  PodcastEpisodeModel? lastPlayedEpisode;

  @override
  AudioPlayerState build() {
    return const AudioPlayerState();
  }

  @override
  Future<void> playEpisode(
    PodcastEpisodeModel episode, {
    PlaySource source = PlaySource.direct,
    int? queueEpisodeId,
  }) async {
    lastPlayedEpisode = episode;
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

/// Creates a sample [PodcastSubscriptionModel].
PodcastSubscriptionModel createTestSubscription() {
  final now = DateTime.now();
  return PodcastSubscriptionModel(
    id: 1,
    userId: 1,
    title: 'Sample Podcast',
    description: 'Sample Description',
    sourceUrl: 'https://example.com/feed.xml',
    status: 'active',
    fetchInterval: 3600,
    episodeCount: 10,
    unplayedCount: 3,
    createdAt: now,
  );
}
