import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/providers/route_provider.dart';
import 'package:personal_ai_assistant/core/router/app_router.dart';
import 'package:personal_ai_assistant/core/storage/local_storage_service.dart';
import 'package:personal_ai_assistant/features/auth/domain/models/user.dart';
import 'package:personal_ai_assistant/features/auth/presentation/providers/auth_provider.dart';
import 'package:personal_ai_assistant/features/home/presentation/pages/home_page.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/audio_player_state_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/pages/podcast_list_page.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_discover_chart_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_search_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_state_models.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/profile_stats_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/services/apple_podcast_rss_service.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/constants/podcast_ui_constants.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/pages/podcast_feed_page.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_discover_provider.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/profile/presentation/pages/profile_page.dart';

void main() {
  group('HomePage player navigation behavior', () {
    testWidgets('entering home restores playback once and prefetches once', (
      tester,
    ) async {
      final audioNotifier = TestAudioPlayerNotifier(const AudioPlayerState());
      final feedNotifier = TestPodcastFeedNotifier();

      await _pumpHomeShellWidget(
        tester,
        audioNotifier: audioNotifier,
        feedNotifier: feedNotifier,
        initialTab: 0,
        route: '/home',
      );

      expect(audioNotifier.restoreCallCount, 1);
      expect(feedNotifier.backgroundLoadCallCount, 1);
    });

    testWidgets('home defaults to library tab when initialTab is omitted', (
      tester,
    ) async {
      await _pumpHomeShellWidget(
        tester,
        audioNotifier: TestAudioPlayerNotifier(const AudioPlayerState()),
        route: '/home',
      );

      expect(find.byType(PodcastFeedPage), findsOneWidget);
      expect(
        find.byKey(const Key('library_daily_report_entry_tile')),
        findsOneWidget,
      );
      expect(find.byType(ProfilePage), findsNothing);
    });

    testWidgets('profile tab shows dock and can expand/collapse player', (
      tester,
    ) async {
      final audioNotifier = TestAudioPlayerNotifier(
        AudioPlayerState(currentEpisode: _episode()),
      );
      final uiNotifier = TestPodcastPlayerUiNotifier();

      await _pumpHomeShellWidget(
        tester,
        audioNotifier: audioNotifier,
        initialTab: 2,
        route: '/profile',
        uiNotifier: uiNotifier,
      );

      expect(find.byType(ProfilePage), findsOneWidget);
      expect(
        find.byKey(const Key('podcast_bottom_player_mini')),
        findsOneWidget,
      );

      uiNotifier.expand();
      await tester.pumpAndSettle();
      expect(uiNotifier.state.isExpanded, isTrue);
      expect(
        find.byKey(const Key('podcast_bottom_player_expanded')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('podcast_bottom_player_collapse')));
      await tester.pumpAndSettle();
      expect(uiNotifier.state.isExpanded, isFalse);
    });

    testWidgets('desktop home shell still renders the dock', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpHomeShellWidget(
        tester,
        audioNotifier: TestAudioPlayerNotifier(
          AudioPlayerState(currentEpisode: _episode()),
        ),
        initialTab: 2,
        route: '/profile',
      );

      expect(
        find.byKey(const Key('podcast_bottom_player_mini')),
        findsOneWidget,
      );
    });

    testWidgets(
      'mobile home shell mini player touches navigation dock and keeps dock bottom inset',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await _pumpHomeShellWidget(
          tester,
          audioNotifier: TestAudioPlayerNotifier(
            AudioPlayerState(currentEpisode: _episode()),
          ),
          initialTab: 2,
          route: '/profile',
        );

        final miniPlayerRect = tester.getRect(
          find.byKey(const Key('podcast_bottom_player_mini')),
        );
        final navDockRect = tester.getRect(
          find.byKey(const Key('custom_adaptive_navigation_mobile_dock')),
        );

        expect(miniPlayerRect.bottom, closeTo(navDockRect.top, 2.1));
        expect(
          navDockRect.bottom,
          closeTo(844 - kPodcastGlobalPlayerMobileViewportPadding, 0.1),
        );
      },
    );

    testWidgets('returning from covered route collapses expanded player', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final uiNotifier = TestPodcastPlayerUiNotifier(
        const PodcastPlayerUiState(
          presentation: PodcastPlayerPresentation.expanded,
        ),
      );

      final router = await _pumpHomePageRouterFlow(
        tester,
        audioNotifier: TestAudioPlayerNotifier(
          AudioPlayerState(currentEpisode: _episode(), duration: 180000),
        ),
        uiNotifier: uiNotifier,
      );

      await tester.tap(
        find.byKey(const Key('podcast_bottom_player_expanded_title')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Episode Detail Route'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();

      expect(uiNotifier.state.isExpanded, isFalse);
      expect(
        find.byKey(const Key('podcast_bottom_player_mini')),
        findsOneWidget,
      );
    });
  });
}

Future<void> _pumpHomeShellWidget(
  WidgetTester tester, {
  required TestAudioPlayerNotifier audioNotifier,
  TestPodcastFeedNotifier? feedNotifier,
  TestPodcastPlayerUiNotifier? uiNotifier,
  int? initialTab,
  required String route,
}) async {
  final effectiveFeedNotifier = feedNotifier ?? TestPodcastFeedNotifier();
  final tab = initialTab ?? 1;
  final initialLocation = _tabRoute(tab);

  final router = GoRouter(
    navigatorKey: appNavigatorKey,
    initialLocation: initialLocation,
    observers: [appRouteObserver],
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShellWidget(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/discover',
                builder: (context, state) => const PodcastListPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/feed',
                builder: (context, state) => const PodcastFeedPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(
          _MockLocalStorageService(),
        ),
        authProvider.overrideWith(TestAuthNotifier.new),
        currentRouteProvider.overrideWith(
          () => TestCurrentRouteNotifier(route),
        ),
        audioPlayerProvider.overrideWith(() => audioNotifier),
        podcastPlayerUiProvider.overrideWith(
          () => uiNotifier ?? TestPodcastPlayerUiNotifier(),
        ),
        podcastFeedProvider.overrideWith(() => effectiveFeedNotifier),
        podcastSubscriptionProvider.overrideWith(
          TestPodcastSubscriptionNotifier.new,
        ),
        applePodcastRssServiceProvider.overrideWithValue(
          _FakeApplePodcastRssService(),
        ),
        profileStatsProvider.overrideWith(
          () => _FixedProfileStatsNotifier(
            const ProfileStatsModel(
              totalSubscriptions: 2,
              totalEpisodes: 8,
              summariesGenerated: 3,
              pendingSummaries: 1,
              playedEpisodes: 4,
            ),
          ),
        ),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
        builder: (context, child) => Stack(
          fit: StackFit.expand,
          children: [
            child ?? const SizedBox.shrink(),
            _RouteSyncBridge(router: router),
          ],
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

String _tabRoute(int tab) {
  switch (tab) {
    case 0:
      return '/discover';
    case 1:
      return '/feed';
    case 2:
      return '/profile';
    default:
      return '/feed';
  }
}

Future<GoRouter> _pumpHomePageRouterFlow(
  WidgetTester tester, {
  required TestAudioPlayerNotifier audioNotifier,
  required TestPodcastPlayerUiNotifier uiNotifier,
}) async {
  final feedNotifier = TestPodcastFeedNotifier();
  final router = GoRouter(
    navigatorKey: appNavigatorKey,
    initialLocation: '/profile',
    observers: [appRouteObserver],
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShellWidget(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/discover',
                builder: (context, state) => const PodcastListPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/feed',
                builder: (context, state) => const PodcastFeedPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/podcast/episodes/:subscriptionId/:episodeId',
        name: 'episodeDetail',
        builder: (context, state) => const _EpisodeDetailRoutePage(),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(
          _MockLocalStorageService(),
        ),
        authProvider.overrideWith(TestAuthNotifier.new),
        audioPlayerProvider.overrideWith(() => audioNotifier),
        podcastPlayerUiProvider.overrideWith(() => uiNotifier),
        podcastFeedProvider.overrideWith(() => feedNotifier),
        podcastSubscriptionProvider.overrideWith(
          TestPodcastSubscriptionNotifier.new,
        ),
        applePodcastRssServiceProvider.overrideWithValue(
          _FakeApplePodcastRssService(),
        ),
        profileStatsProvider.overrideWith(
          () => _FixedProfileStatsNotifier(
            const ProfileStatsModel(
              totalSubscriptions: 2,
              totalEpisodes: 8,
              summariesGenerated: 3,
              pendingSummaries: 1,
              playedEpisodes: 4,
            ),
          ),
        ),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
        builder: (context, child) => Stack(
          fit: StackFit.expand,
          children: [
            child ?? const SizedBox.shrink(),
            _RouteSyncBridge(router: router),
          ],
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
  return router;
}

class TestAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return AuthState(
      isAuthenticated: true,
      user: User(
        id: '1',
        email: 'tester@example.com',
        username: 'tester',
        fullName: 'Test User',
        isVerified: true,
        isActive: true,
      ),
    );
  }
}

class _RouteSyncBridge extends ConsumerStatefulWidget {
  const _RouteSyncBridge({required this.router});

  final GoRouter router;

  @override
  ConsumerState<_RouteSyncBridge> createState() => _RouteSyncBridgeState();
}

class _RouteSyncBridgeState extends ConsumerState<_RouteSyncBridge> {
  late final VoidCallback _listener = _syncRoute;

  @override
  void initState() {
    super.initState();
    widget.router.routerDelegate.addListener(_listener);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncRoute());
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_listener);
    super.dispose();
  }

  void _syncRoute() {
    if (!mounted) {
      return;
    }
    ref
        .read(currentRouteProvider.notifier)
        .setRoute(
          widget.router.routerDelegate.currentConfiguration.uri.toString(),
        );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _EpisodeDetailRoutePage extends StatelessWidget {
  const _EpisodeDetailRoutePage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Episode Detail Route')));
  }
}

class _FixedProfileStatsNotifier extends ProfileStatsNotifier {
  _FixedProfileStatsNotifier(this._value);

  final ProfileStatsModel? _value;

  @override
  FutureOr<ProfileStatsModel?> build() => _value;

  @override
  Future<ProfileStatsModel?> load({bool forceRefresh = false}) async {
    state = AsyncValue.data(_value);
    return _value;
  }
}

class TestAudioPlayerNotifier extends AudioPlayerNotifier {
  TestAudioPlayerNotifier(this._initialState);

  final AudioPlayerState _initialState;
  int restoreCallCount = 0;

  @override
  AudioPlayerState build() => _initialState;

  @override
  Future<void> restoreLastPlayedEpisodeIfNeeded() async {
    restoreCallCount += 1;
  }
}

class TestPodcastPlayerUiNotifier extends PodcastPlayerUiNotifier {
  TestPodcastPlayerUiNotifier([
    this._initialState = const PodcastPlayerUiState(),
  ]);

  final PodcastPlayerUiState _initialState;

  @override
  PodcastPlayerUiState build() => _initialState;
}

class TestPodcastFeedNotifier extends PodcastFeedNotifier {
  TestPodcastFeedNotifier([this._initialState = const PodcastFeedState()]);

  final PodcastFeedState _initialState;
  int backgroundLoadCallCount = 0;

  @override
  PodcastFeedState build() => _initialState;

  @override
  Future<void> loadInitialFeed({
    bool forceRefresh = false,
    bool background = false,
  }) async {
    if (background) {
      backgroundLoadCallCount += 1;
    }
  }

  @override
  Future<void> refreshFeed({bool fastReturn = false}) async {}

  @override
  Future<void> loadMoreFeed() async {}
}

class TestPodcastSubscriptionNotifier extends PodcastSubscriptionNotifier {
  @override
  PodcastSubscriptionState build() => const PodcastSubscriptionState();

  @override
  Future<void> loadSubscriptions({
    int page = 1,
    int size = 10,
    int? categoryId,
    String? status,
    bool forceRefresh = false,
  }) async {}
}

class _FakeApplePodcastRssService extends ApplePodcastRssService {
  _FakeApplePodcastRssService() : super();

  @override
  Future<ApplePodcastChartResponse> fetchTopShows({
    required PodcastCountry country,
    int limit = 25,
    ApplePodcastRssFormat format = ApplePodcastRssFormat.json,
  }) async {
    return _response('podcasts', country.code);
  }

  @override
  Future<ApplePodcastChartResponse> fetchTopEpisodes({
    required PodcastCountry country,
    int limit = 25,
    ApplePodcastRssFormat format = ApplePodcastRssFormat.json,
  }) async {
    return _response('podcast-episodes', country.code);
  }

  ApplePodcastChartResponse _response(String kind, String country) {
    final item = ApplePodcastChartEntry.fromJson({
      'artistName': 'Artist',
      'id': '1001',
      'name': 'Chart Item',
      'kind': kind,
      'artworkUrl100': 'https://example.com/cover.png',
      'genres': [
        {'name': 'Technology'},
      ],
      'url': 'https://podcasts.apple.com/$country/podcast/id1001',
    });
    return ApplePodcastChartResponse(
      feed: ApplePodcastChartFeed(
        title: kind,
        country: country,
        updated: '2026-02-14T00:00:00Z',
        results: <ApplePodcastChartEntry>[item],
      ),
    );
  }
}

PodcastEpisodeModel _episode() {
  final now = DateTime.now();
  return PodcastEpisodeModel(
    id: 11,
    subscriptionId: 22,
    title: 'Test Episode',
    description: 'Test Description',
    audioUrl: 'https://example.com/test.mp3',
    publishedAt: now,
    createdAt: now,
  );
}

class TestCurrentRouteNotifier extends CurrentRouteNotifier {
  TestCurrentRouteNotifier(this._route);

  final String _route;

  @override
  String build() => _route;
}

class _MockLocalStorageService implements LocalStorageService {
  final Map<String, dynamic> _storage = {};

  @override
  Future<void> save<T>(String key, T value) async => _storage[key] = value;

  @override
  Future<T?> get<T>(String key) async => _storage[key] as T?;

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

  @override
  Future<void> saveString(String key, String value) async =>
      _storage[key] = value;

  @override
  Future<String?> getString(String key) async => _storage[key] as String?;

  @override
  Future<void> remove(String key) async => _storage.remove(key);

  @override
  Future<void> clear() async => _storage.clear();

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
      (_storage[key] as List<dynamic>?)?.cast<String>();
}
