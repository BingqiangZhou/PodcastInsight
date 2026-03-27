import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/storage/local_storage_service.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_discover_chart_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_search_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/services/apple_podcast_rss_service.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_discover_provider.dart';

void main() {
  group('podcastDiscoverProvider', () {
    test('loads initial top shows and episodes', () async {
      final fakeService = _FakeApplePodcastRssService();
      final container = _createContainer(fakeService);
      addTearDown(container.dispose);

      await container.read(podcastDiscoverProvider.notifier).loadInitialData();
      final state = container.read(podcastDiscoverProvider);

      expect(state.topShows, hasLength(25));
      expect(state.topEpisodes, hasLength(25));
      expect(state.selectedTab, PodcastDiscoverTab.episodes);
      expect(state.selectedCategory, PodcastDiscoverState.allCategoryValue);
      expect(state.currentTabLoadedCount, 25);
      expect(state.currentTabHasMore, isTrue);
    });

    test('supports tab switching and category filtering', () async {
      final fakeService = _FakeApplePodcastRssService();
      final container = _createContainer(fakeService);
      addTearDown(container.dispose);

      await container.read(podcastDiscoverProvider.notifier).loadInitialData();
      final notifier = container.read(podcastDiscoverProvider.notifier);

      notifier.setTab(PodcastDiscoverTab.episodes);
      notifier.selectCategory('News');
      final state = container.read(podcastDiscoverProvider);

      expect(state.selectedTab, PodcastDiscoverTab.episodes);
      expect(state.selectedCategory, 'News');
      expect(
        state.filteredActiveItems.every((item) => item.hasGenre('News')),
        isTrue,
      );
    });

    test(
      'loads more current tab from top 25 to top 100 incrementally',
      () async {
        final fakeService = _FakeApplePodcastRssService();
        final container = _createContainer(fakeService);
        addTearDown(container.dispose);

        final notifier = container.read(podcastDiscoverProvider.notifier);
        await notifier.loadInitialData();

        expect(
          container.read(podcastDiscoverProvider).topEpisodes,
          hasLength(25),
        );

        await notifier.loadMoreCurrentTab();
        expect(
          container.read(podcastDiscoverProvider).topEpisodes,
          hasLength(50),
        );

        await notifier.loadMoreCurrentTab();
        expect(
          container.read(podcastDiscoverProvider).topEpisodes,
          hasLength(75),
        );

        await notifier.loadMoreCurrentTab();
        final state = container.read(podcastDiscoverProvider);
        expect(state.topEpisodes, hasLength(100));
        expect(state.currentTabHasMore, isFalse);
        expect(
          fakeService.episodeLimits,
          containsAllInOrder([25, 50, 75, 100]),
        );

        notifier.setTab(PodcastDiscoverTab.podcasts);
        expect(container.read(podcastDiscoverProvider).topShows, hasLength(25));

        await notifier.loadMoreCurrentTab();
        await notifier.loadMoreCurrentTab();
        await notifier.loadMoreCurrentTab();

        final podcastsState = container.read(podcastDiscoverProvider);
        expect(podcastsState.topShows, hasLength(100));
        expect(podcastsState.currentTabLoadedCount, 100);
        expect(fakeService.showsLimits, containsAllInOrder([25, 50, 75, 100]));
      },
    );

    test('reloads on country change', () async {
      final fakeService = _FakeApplePodcastRssService();
      final container = _createContainer(fakeService);
      addTearDown(container.dispose);

      await container.read(podcastDiscoverProvider.notifier).loadInitialData();
      final initialCalls = fakeService.showsCalls;

      await container
          .read(podcastDiscoverProvider.notifier)
          .onCountryChanged(PodcastCountry.japan);

      final state = container.read(podcastDiscoverProvider);
      expect(state.country, PodcastCountry.japan);
      expect(state.topShows, hasLength(25));
      expect(fakeService.showsCalls, greaterThan(initialCalls));
    });

    test('uses latest country when a load is already in flight', () async {
      final fakeService = _DelayedApplePodcastRssService();
      final container = _createContainer(fakeService);
      addTearDown(container.dispose);

      final notifier = container.read(podcastDiscoverProvider.notifier);
      final initialLoad = notifier.loadInitialData();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final changeLoad = notifier.onCountryChanged(PodcastCountry.usa);
      await Future.wait([initialLoad, changeLoad]);

      final state = container.read(podcastDiscoverProvider);
      expect(state.country, PodcastCountry.usa);
      expect(state.topShows.first.url, contains('/us/'));
      expect(state.topEpisodes.first.url, contains('/us/'));
    });

    test('skips repeated load when discover data is fresh', () async {
      final fakeService = _FakeApplePodcastRssService();
      final container = _createContainer(fakeService);
      addTearDown(container.dispose);

      await container.read(podcastDiscoverProvider.notifier).loadInitialData();
      final showsCallsAfterFirstLoad = fakeService.showsCalls;
      final episodesCallsAfterFirstLoad = fakeService.episodeCalls;

      await container.read(podcastDiscoverProvider.notifier).loadInitialData();

      expect(fakeService.showsCalls, showsCallsAfterFirstLoad);
      expect(fakeService.episodeCalls, episodesCallsAfterFirstLoad);
    });

    test('loads both shows and episodes in parallel', () async {
      final fakeService = _DelayedApplePodcastRssService();
      final container = _createContainer(fakeService);
      addTearDown(container.dispose);

      container
          .read(podcastDiscoverProvider.notifier)
          .setTab(PodcastDiscoverTab.episodes);

      // During loading, state should still be loading (no partial data)
      final future = container
          .read(podcastDiscoverProvider.notifier)
          .loadInitialData();

      await Future<void>.delayed(const Duration(milliseconds: 50));
      final midState = container.read(podcastDiscoverProvider);
      // Both are loaded atomically via parallel fetch, so during loading
      // the state has not yet been updated with results.
      expect(midState.isLoading, isTrue);

      await future;

      final finalState = container.read(podcastDiscoverProvider);
      expect(finalState.topEpisodes, isNotEmpty);
      expect(finalState.topShows, isNotEmpty);
      expect(finalState.isLoading, isFalse);
    });

    test('switching tabs does not auto-hydrate to top 100', () async {
      final fakeService = _FakeApplePodcastRssService();
      final container = _createContainer(fakeService);
      addTearDown(container.dispose);

      final notifier = container.read(podcastDiscoverProvider.notifier);
      await notifier.loadInitialData();

      notifier.setTab(PodcastDiscoverTab.podcasts);

      final state = container.read(podcastDiscoverProvider);
      expect(state.topShows, hasLength(25));
      expect(fakeService.showsLimits, equals([25]));
    });

    test(
      'suppresses concurrent load-more requests for the current tab',
      () async {
        final fakeService = _DelayedApplePodcastRssService();
        final container = _createContainer(fakeService);
        addTearDown(container.dispose);

        final notifier = container.read(podcastDiscoverProvider.notifier);
        await notifier.loadInitialData();

        await Future.wait([
          notifier.loadMoreCurrentTab(),
          notifier.loadMoreCurrentTab(),
        ]);

        final state = container.read(podcastDiscoverProvider);
        expect(state.topEpisodes, hasLength(50));
        expect(fakeService.episodeLimits, equals([25, 50]));
      },
    );

    test(
      'clearRuntimeCache clears discover state and triggers refetch',
      () async {
        final fakeService = _FakeApplePodcastRssService();
        final container = _createContainer(fakeService);
        addTearDown(container.dispose);

        await container
            .read(podcastDiscoverProvider.notifier)
            .loadInitialData();
        final callsBeforeClear = fakeService.showsCalls;

        container.read(podcastDiscoverProvider.notifier).clearRuntimeCache();
        final clearedState = container.read(podcastDiscoverProvider);
        expect(clearedState.topShows, isEmpty);
        expect(clearedState.topEpisodes, isEmpty);
        expect(fakeService.clearCacheCalls, 1);

        await container
            .read(podcastDiscoverProvider.notifier)
            .loadInitialData();
        expect(fakeService.showsCalls, greaterThan(callsBeforeClear));
      },
    );
  });
}

ProviderContainer _createContainer(ApplePodcastRssService service) {
  return ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(_MockLocalStorageService()),
      applePodcastRssServiceProvider.overrideWithValue(service),
    ],
  );
}

class _FakeApplePodcastRssService extends ApplePodcastRssService {
  _FakeApplePodcastRssService() : super();

  int showsCalls = 0;
  int episodeCalls = 0;
  int clearCacheCalls = 0;
  final List<int> showsLimits = [];
  final List<int> episodeLimits = [];

  @override
  Future<ApplePodcastChartResponse> fetchTopShows({
    required PodcastCountry country,
    int limit = 25,
    ApplePodcastRssFormat format = ApplePodcastRssFormat.json,
  }) async {
    showsCalls += 1;
    showsLimits.add(limit);
    return _responseFor(kind: 'podcasts', country: country.code, count: limit);
  }

  @override
  Future<ApplePodcastChartResponse> fetchTopEpisodes({
    required PodcastCountry country,
    int limit = 25,
    ApplePodcastRssFormat format = ApplePodcastRssFormat.json,
  }) async {
    episodeCalls += 1;
    episodeLimits.add(limit);
    return _responseFor(
      kind: 'podcast-episodes',
      country: country.code,
      count: limit,
    );
  }

  @override
  void clearCache() {
    clearCacheCalls += 1;
    super.clearCache();
  }

  ApplePodcastChartResponse _responseFor({
    required String kind,
    required String country,
    required int count,
  }) {
    final items = List.generate(
      count,
      (index) => ApplePodcastChartEntry.fromJson({
        'artistName': 'Artist $index',
        'id': '${1000 + index}',
        'name': 'Item $index',
        'kind': kind,
        'artworkUrl100': 'https://example.com/$index.png',
        'genres': [
          {'name': index.isEven ? 'Technology' : 'News'},
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

class _DelayedApplePodcastRssService extends _FakeApplePodcastRssService {
  @override
  Future<ApplePodcastChartResponse> fetchTopShows({
    required PodcastCountry country,
    int limit = 25,
    ApplePodcastRssFormat format = ApplePodcastRssFormat.json,
  }) async {
    showsCalls += 1;
    showsLimits.add(limit);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _responseFor(kind: 'podcasts', country: country.code, count: limit);
  }

  @override
  Future<ApplePodcastChartResponse> fetchTopEpisodes({
    required PodcastCountry country,
    int limit = 25,
    ApplePodcastRssFormat format = ApplePodcastRssFormat.json,
  }) async {
    episodeCalls += 1;
    episodeLimits.add(limit);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return _responseFor(
      kind: 'podcast-episodes',
      country: country.code,
      count: limit,
    );
  }
}

class _MockLocalStorageService implements LocalStorageService {
  final Map<String, dynamic> _storage = {};

  @override
  Future<void> clear() async => _storage.clear();

  @override
  Future<void> clearExpiredCache() async {}

  @override
  Future<bool> containsKey(String key) async => _storage.containsKey(key);

  @override
  Future<void> cacheData(String key, data, {Duration? expiration}) async {
    _storage[key] = data;
  }

  @override
  Future<T?> get<T>(String key) async => _storage[key] as T?;

  @override
  Future<String?> getApiBaseUrl() async => _storage['api_base_url'] as String?;

  @override
  Future<bool?> getBool(String key) async => _storage[key] as bool?;

  @override
  Future<T?> getCachedData<T>(String key) async => _storage[key] as T?;

  @override
  Future<double?> getDouble(String key) async => _storage[key] as double?;

  @override
  Future<int?> getInt(String key) async => _storage[key] as int?;

  @override
  Future<String?> getServerBaseUrl() async =>
      _storage['server_base_url'] as String?;

  @override
  Future<String?> getString(String key) async => _storage[key] as String?;

  @override
  Future<List<String>?> getStringList(String key) async =>
      _storage[key] as List<String>?;

  @override
  Future<void> remove(String key) async => _storage.remove(key);

  @override
  Future<void> save<T>(String key, T value) async => _storage[key] = value;

  @override
  Future<void> saveApiBaseUrl(String url) async =>
      _storage['api_base_url'] = url;

  @override
  Future<void> saveBool(String key, bool value) async => _storage[key] = value;

  @override
  Future<void> saveDouble(String key, double value) async =>
      _storage[key] = value;

  @override
  Future<void> saveInt(String key, int value) async => _storage[key] = value;

  @override
  Future<void> saveServerBaseUrl(String url) async =>
      _storage['server_base_url'] = url;

  @override
  Future<void> saveString(String key, String value) async =>
      _storage[key] = value;

  @override
  Future<void> saveStringList(String key, List<String> value) async =>
      _storage[key] = value;
}
