import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/storage/local_storage_service.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_discover_chart_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_search_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_state_models.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_subscription_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/services/apple_podcast_rss_service.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/pages/podcast_list_page.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_discover_provider.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_search_provider.dart'
    as search;
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/country_selector_dropdown.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/podcast_image_widget.dart';

void main() {
  group('PodcastListPage discover header', () {
    testWidgets('renders discover structure and sections', (tester) async {
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(
            _MockLocalStorageService(),
          ),
          podcastSubscriptionProvider.overrideWith(
            () => _TestPodcastSubscriptionNotifier(
              PodcastSubscriptionState(
                subscriptions: [_subscription()],
                hasMore: false,
                total: 1,
              ),
            ),
          ),
          applePodcastRssServiceProvider.overrideWithValue(
            _FakeApplePodcastRssService(),
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
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PodcastListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Discover'), findsOneWidget);
      expect(find.text('Start with a search'), findsNothing);
      expect(find.text('Refine query'), findsNothing);
      expect(find.text('Update query or switch modes.'), findsNothing);
      expect(
        find.byKey(const Key('podcast_discover_country_button')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('podcast_discover_country_button')),
          matching: find.text('CN'),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('podcast_discover_country_button')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CountrySelectorDropdown), findsOneWidget);
      Navigator.of(tester.element(find.byType(CountrySelectorDropdown))).pop();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('podcast_discover_search_bar')),
        findsOneWidget,
      );
      expect(find.byType(HeroHeader), findsOneWidget);
      expect(
        find.byKey(const Key('podcast_discover_search_input')),
        findsOneWidget,
      );
      expect(find.text('Find a show or browse charts.'), findsNothing);
      final searchInputWidget = tester.widget<TextField>(
        find.byKey(const Key('podcast_discover_search_input')),
      );
      final decoration = searchInputWidget.decoration;
      expect(decoration, isNotNull);
      expect(decoration!.border, InputBorder.none);
      expect(decoration.enabledBorder, InputBorder.none);
      expect(decoration.focusedBorder, InputBorder.none);
      expect(decoration.disabledBorder, InputBorder.none);
      expect(decoration.errorBorder, InputBorder.none);
      expect(decoration.focusedErrorBorder, InputBorder.none);
      expect(
        find.byKey(const Key('podcast_discover_tab_selector')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('podcast_discover_tab_podcasts')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('podcast_discover_tab_episodes')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('podcast_discover_top_charts')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('podcast_discover_category_chips')),
        findsOneWidget,
      );
      final chipsTop = tester
          .getTopLeft(find.byKey(const Key('podcast_discover_category_chips')))
          .dy;
      final topChartsTop = tester
          .getTopLeft(find.byKey(const Key('podcast_discover_top_charts')))
          .dy;
      expect(chipsTop, greaterThan(topChartsTop));
      expect(find.byKey(const Key('podcast_discover_see_all')), findsNothing);
      expect(
        find.byKey(const Key('podcast_discover_category_chip_all')),
        findsOneWidget,
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(PodcastListPage)),
      )!;
      expect(find.text(l10n.podcast_discover_browse_by_category), findsNothing);

      expect(find.byKey(const Key('podcast_list_header_title')), findsNothing);
      expect(
        find.byKey(const Key('podcast_list_discover_title')),
        findsNothing,
      );
    });

    testWidgets('search clear button follows controller text changes', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(
            _MockLocalStorageService(),
          ),
          podcastSubscriptionProvider.overrideWith(
            () => _TestPodcastSubscriptionNotifier(
              PodcastSubscriptionState(
                subscriptions: [_subscription()],
                hasMore: false,
                total: 1,
              ),
            ),
          ),
          applePodcastRssServiceProvider.overrideWithValue(
            _FakeApplePodcastRssService(),
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
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PodcastListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final searchInput = find.byKey(
        const Key('podcast_discover_search_input'),
      );
      final clearButton = find.descendant(
        of: find.byKey(const Key('podcast_discover_search_bar')),
        matching: find.byIcon(Icons.clear),
      );

      expect(clearButton, findsNothing);

      await tester.enterText(searchInput, 'flutter');
      await tester.pump();

      expect(clearButton, findsOneWidget);

      await tester.tap(clearButton);
      await tester.pump();

      final textField = tester.widget<TextField>(searchInput);
      expect(textField.controller?.text, isEmpty);
      expect(clearButton, findsNothing);
    });

    testWidgets('uses dense layout when subscription total is at least 20', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(
            _MockLocalStorageService(),
          ),
          podcastSubscriptionProvider.overrideWith(
            () => _TestPodcastSubscriptionNotifier(
              PodcastSubscriptionState(
                subscriptions: [_subscription()],
                hasMore: true,
                total: 25,
              ),
            ),
          ),
          applePodcastRssServiceProvider.overrideWithValue(
            _FakeApplePodcastRssService(),
          ),
          search.podcastSearchProvider.overrideWithValue(
            const search.PodcastSearchState(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PodcastListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rowFinder = find.byKey(
        const Key('podcast_discover_chart_row_1000'),
      );
      expect(rowFinder, findsOneWidget);

      final imageWidget = tester.widget<PodcastImageWidget>(
        find
            .descendant(
              of: rowFinder,
              matching: find.byType(PodcastImageWidget),
            )
            .first,
      );
      expect(imageWidget.width, 56.0);
    });
  });
}

class _TestPodcastSearchNotifier extends search.PodcastSearchNotifier {
  _TestPodcastSearchNotifier(this._initialState);

  final search.PodcastSearchState _initialState;

  @override
  search.PodcastSearchState build() => _initialState;

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
    state = search.PodcastSearchState(searchMode: state.searchMode);
  }
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
      8,
      (index) => ApplePodcastChartEntry.fromJson({
        'artistName': 'Artist $index',
        'id': '${1000 + index}',
        'name': 'Chart Item $index',
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
  _TestPodcastSubscriptionNotifier(this._initialState);

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

PodcastSubscriptionModel _subscription() {
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
