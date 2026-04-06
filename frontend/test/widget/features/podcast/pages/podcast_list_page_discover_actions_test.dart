import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_discover_provider.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_search_provider.dart'
    as search;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PodcastListPage discover actions', () {
    testWidgets('show subscribe button uses lookup and subscribes', (
      tester,
    ) async {
      final fakeLookupService = _FakeITunesSearchService();
      final fakeSubscriptionNotifier = _FakePodcastSubscriptionNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(
              _MockLocalStorageService(),
            ),
            applePodcastRssServiceProvider.overrideWithValue(
              _FakeApplePodcastRssService(),
            ),
            search.iTunesSearchServiceProvider.overrideWithValue(
              fakeLookupService,
            ),
            podcastSubscriptionProvider.overrideWith(
              () => fakeSubscriptionNotifier,
            ),
            search.podcastSearchProvider.overrideWith(
              () => _TestPodcastSearchNotifier(const search.PodcastSearchState()),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PodcastListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('podcast_discover_tab_podcasts')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('podcast_discover_subscribe_111')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));

      expect(fakeLookupService.lookupCalled, isTrue);
      expect(
        fakeSubscriptionNotifier.lastAddedFeedUrl,
        'https://example.com/feed.xml',
      );
    });

    testWidgets(
      'podcast row opens episodes info sheet and has no open button',
      (tester) async {
        final fakeLookupService = _FakeITunesSearchService();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              localStorageServiceProvider.overrideWithValue(
                _MockLocalStorageService(),
              ),
              applePodcastRssServiceProvider.overrideWithValue(
                _FakeApplePodcastRssService(),
              ),
              search.iTunesSearchServiceProvider.overrideWithValue(
                fakeLookupService,
              ),
              podcastSubscriptionProvider.overrideWith(
                _FakePodcastSubscriptionNotifier.new,
              ),
              search.podcastSearchProvider.overrideWith(
                () => _TestPodcastSearchNotifier(const search.PodcastSearchState()),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: PodcastListPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('podcast_discover_tab_podcasts')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('podcast_discover_open_111')),
          findsNothing,
        );
        await tester.tap(
          find.byKey(const Key('podcast_discover_chart_row_111')),
        );
        await tester.pumpAndSettle();

        expect(fakeLookupService.lookupEpisodesCalled, isTrue);
        expect(
          find.byKey(const Key('discover_show_episodes_sheet')),
          findsOneWidget,
        );
        expect(find.text('Show Episode Preview'), findsOneWidget);
      },
    );

    testWidgets('episodes support detail sheet and internal play button', (
      tester,
    ) async {
      final audioNotifier = _MockAudioPlayerNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(
              _MockLocalStorageService(),
            ),
            applePodcastRssServiceProvider.overrideWithValue(
              _FakeApplePodcastRssService(),
            ),
            search.iTunesSearchServiceProvider.overrideWithValue(
              _FakeITunesSearchService(),
            ),
            podcastSubscriptionProvider.overrideWith(
              _FakePodcastSubscriptionNotifier.new,
            ),
            audioPlayerProvider.overrideWith(() => audioNotifier),
            search.podcastSearchProvider.overrideWith(
              () => _TestPodcastSearchNotifier(const search.PodcastSearchState()),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PodcastListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('podcast_discover_open_222')), findsNothing);
      expect(
        find.byKey(const Key('podcast_discover_play_222')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('podcast_discover_chart_row_222')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('discover_episode_detail_sheet')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('discover_episode_detail_play_button')),
      );
      await tester.pumpAndSettle();

      final played = audioNotifier.lastPlayedEpisode;
      expect(played, isNotNull);
      expect(played!.id, 222);
      expect(played.metadata?['discover_preview'], isTrue);
    });
  });
}

class _TestPodcastSearchNotifier extends search.PodcastSearchNotifier {
  _TestPodcastSearchNotifier(this._initial);

  final search.PodcastSearchState _initial;

  @override
  search.PodcastSearchState build() => _initial;
}

class _FakeApplePodcastRssService extends ApplePodcastRssService {
  _FakeApplePodcastRssService() : super();

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

class _FakeITunesSearchService extends ITunesSearchService {
  _FakeITunesSearchService() : super();

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

class _MockAudioPlayerNotifier extends AudioPlayerNotifier {
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

class _FakePodcastSubscriptionNotifier extends PodcastSubscriptionNotifier {
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

class _MockLocalStorageService implements LocalStorageService {
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
