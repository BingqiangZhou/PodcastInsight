import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/storage/local_storage_service.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/itunes_episode_lookup_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_discover_chart_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_search_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_state_models.dart';
import 'package:personal_ai_assistant/features/podcast/data/services/apple_podcast_rss_service.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/pages/podcast_list_page.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_discover_provider.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_search_provider.dart'
    as search;

void main() {
  group('PodcastListPage discover search mode selector', () {
    testWidgets('shows selector and renders podcast results in podcast mode',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(
            _MockLocalStorageService(),
          ),
          applePodcastRssServiceProvider.overrideWithValue(
            _FakeApplePodcastRssService(),
          ),
          podcastSubscriptionProvider.overrideWith(
            _TestPodcastSubscriptionNotifier.new,
          ),
          search.podcastSearchProvider.overrideWithValue(
            const search.PodcastSearchState(
              hasSearched: true,
              searchMode: search.PodcastSearchMode.podcasts,
              podcastResults: [
                PodcastSearchResult(
                  collectionId: 100,
                  collectionName: 'Test Podcast',
                  artistName: 'Tester',
                  feedUrl: 'https://example.com/feed.xml',
                  artworkUrl100: 'https://example.com/podcast.png',
                  trackCount: 10,
                  primaryGenreName: 'Tech',
                ),
              ],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PodcastListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('podcast_discover_search_results')), findsOneWidget);
      expect(
        find.byKey(const Key('podcast_discover_tab_selector')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('search_https://example.com/feed.xml')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('episode_search_200')), findsNothing);
    });

    testWidgets('shows selector and renders episode results in episode mode',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(
            _MockLocalStorageService(),
          ),
          applePodcastRssServiceProvider.overrideWithValue(
            _FakeApplePodcastRssService(),
          ),
          podcastSubscriptionProvider.overrideWith(
            _TestPodcastSubscriptionNotifier.new,
          ),
          search.podcastSearchProvider.overrideWithValue(
            search.PodcastSearchState(
              hasSearched: true,
              episodeResults: [
                ITunesPodcastEpisodeResult(
                  trackId: 200,
                  collectionId: 100,
                  trackName: 'Episode 1',
                  collectionName: 'Test Podcast',
                  feedUrl: 'https://example.com/feed.xml',
                  previewUrl: 'https://example.com/ep.mp3',
                  releaseDate: DateTime(2026, 2, 14),
                  trackTimeMillis: 1200000,
                  artworkUrl100: 'https://example.com/ep.png',
                ),
              ],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PodcastListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('podcast_discover_search_results')), findsOneWidget);
      expect(
        find.byKey(const Key('podcast_discover_tab_selector')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('episode_search_200')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('search_https://example.com/feed.xml')),
        findsNothing,
      );
    });
  });
}

class _FakeApplePodcastRssService extends ApplePodcastRssService {
  _FakeApplePodcastRssService() : super();

  @override
  Future<ApplePodcastChartResponse> fetchTopShows({
    required PodcastCountry country,
    int limit = 25,
    ApplePodcastRssFormat format = ApplePodcastRssFormat.json,
  }) async {
    return _buildResponse('podcasts', country.code);
  }

  @override
  Future<ApplePodcastChartResponse> fetchTopEpisodes({
    required PodcastCountry country,
    int limit = 25,
    ApplePodcastRssFormat format = ApplePodcastRssFormat.json,
  }) async {
    return _buildResponse('podcast-episodes', country.code);
  }

  ApplePodcastChartResponse _buildResponse(String kind, String country) {
    final items = List.generate(
      2,
      (index) => ApplePodcastChartEntry.fromJson({
        'artistName': 'Artist $index',
        'id': '${1000 + index}',
        'name': 'Chart Item $index',
        'kind': kind,
        'artworkUrl100': 'https://example.com/$index.png',
        'genres': [
          {'name': 'Technology'},
        ],
        'url': 'https://podcasts.apple.com/$country/podcast/id${1000 + index}',
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

class _MockLocalStorageService implements LocalStorageService {
  final Map<String, dynamic> _storage = {};

  @override
  Future<void> saveString(String key, String value) async => _storage[key] = value;

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
  Future<void> saveDouble(String key, double value) async => _storage[key] = value;

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
  Future<void> saveApiBaseUrl(String url) async => _storage['api_base_url'] = url;

  @override
  Future<String?> getApiBaseUrl() async => _storage['api_base_url'] as String?;

  @override
  Future<void> saveServerBaseUrl(String url) async =>
      _storage['server_base_url'] = url;

  @override
  Future<String?> getServerBaseUrl() async =>
      _storage['server_base_url'] as String?;
}

class _TestPodcastSubscriptionNotifier extends PodcastSubscriptionNotifier {
  @override
  PodcastSubscriptionState build() {
    return const PodcastSubscriptionState(
      hasMore: false,
    );
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
