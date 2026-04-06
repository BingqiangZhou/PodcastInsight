import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/storage/local_storage_service.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
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
  group('PodcastListPage desktop discover layout', () {
    testWidgets('renders and allows switching to episodes tab', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
          search.podcastSearchProvider.overrideWith(
            () => _TestPodcastSearchNotifier(const search.PodcastSearchState()),
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

      expect(find.byKey(const Key('podcast_discover_list')), findsOneWidget);
      expect(
        find.byKey(const Key('podcast_discover_category_chips')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('podcast_discover_category_chip_all')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('podcast_discover_category_chip_technology')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('podcast_discover_chart_row_2000')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('podcast_discover_category_chip_technology')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('podcast_discover_chart_row_2000')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('podcast_discover_tab_podcasts')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('podcast_discover_chart_row_1000')),
        findsOneWidget,
      );
    });

    testWidgets(
      'uses menu icon color as selected category background in dark mode',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

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
            search.podcastSearchProvider.overrideWith(
              () =>
                  _TestPodcastSearchNotifier(const search.PodcastSearchState()),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: ThemeData.light(useMaterial3: true),
              darkTheme: ThemeData.dark(useMaterial3: true),
              themeMode: ThemeMode.dark,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const PodcastListPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final allChipFinder = find.byKey(
          const Key('podcast_discover_category_chip_all'),
        );
        expect(allChipFinder, findsOneWidget);
        final allChip = tester.widget<ChoiceChip>(allChipFinder);
        final context = tester.element(allChipFinder);
        final scheme = Theme.of(context).colorScheme;

        expect(allChip.selected, isTrue);
        expect(allChip.selectedColor, equals(scheme.primary));
      },
    );

    testWidgets(
      'uses menu icon color as selected category background in light mode',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

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
            search.podcastSearchProvider.overrideWith(
              () =>
                  _TestPodcastSearchNotifier(const search.PodcastSearchState()),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: ThemeData.light(useMaterial3: true),
              darkTheme: ThemeData.dark(useMaterial3: true),
              themeMode: ThemeMode.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const PodcastListPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final allChipFinder = find.byKey(
          const Key('podcast_discover_category_chip_all'),
        );
        expect(allChipFinder, findsOneWidget);
        final allChip = tester.widget<ChoiceChip>(allChipFinder);
        final context = tester.element(allChipFinder);
        final scheme = Theme.of(context).colorScheme;

        expect(allChip.selected, isTrue);
        expect(allChip.selectedColor, equals(scheme.primary));
      },
    );

    testWidgets(
      'uses desktop hero spacing and keeps trending label inset from the right edge',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

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
            search.podcastSearchProvider.overrideWith(
              () =>
                  _TestPodcastSearchNotifier(const search.PodcastSearchState()),
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

        final heroRect = tester.getRect(find.byType(HeroHeader));
        final searchBarRect = tester.getRect(
          find.byKey(const Key('podcast_discover_search_bar')),
        );
        final topChartsRect = tester.getRect(
          find.byKey(const Key('podcast_discover_top_charts')),
        );
        final trendingFinder = find.byKey(
          const Key('podcast_discover_trending_label'),
        );
        final trendingRect = tester.getRect(trendingFinder);
        final trendingText = tester.widget<Text>(trendingFinder);

        final heroSpacing = searchBarRect.top - heroRect.bottom;
        final trendingInset = topChartsRect.right - trendingRect.right;
        expect(heroSpacing, greaterThanOrEqualTo(8));
        expect(heroSpacing, lessThanOrEqualTo(16));
        expect(trendingInset, greaterThanOrEqualTo(8));
        expect(trendingInset, lessThanOrEqualTo(16));
        expect(trendingText.maxLines, 1);
        expect(trendingText.overflow, TextOverflow.ellipsis);
      },
    );
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
    return _buildResponse('podcasts', country.code, 1000);
  }

  @override
  Future<ApplePodcastChartResponse> fetchTopEpisodes({
    required PodcastCountry country,
    int limit = 25,
    ApplePodcastRssFormat format = ApplePodcastRssFormat.json,
  }) async {
    return _buildResponse('podcast-episodes', country.code, 2000);
  }

  ApplePodcastChartResponse _buildResponse(
    String kind,
    String country,
    int base,
  ) {
    final items = List.generate(
      8,
      (index) => ApplePodcastChartEntry.fromJson({
        'artistName': 'Artist $index',
        'id': '${base + index}',
        'name': 'Chart Item $index',
        'kind': kind,
        'artworkUrl100': 'https://example.com/$index.png',
        'genres': [
          {'name': 'Technology'},
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
