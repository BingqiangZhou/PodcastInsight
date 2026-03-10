import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/storage/local_storage_service.dart';
import 'package:personal_ai_assistant/core/widgets/custom_adaptive_navigation.dart';
import 'package:personal_ai_assistant/features/auth/domain/models/user.dart';
import 'package:personal_ai_assistant/features/auth/presentation/providers/auth_provider.dart';
import 'package:personal_ai_assistant/features/home/presentation/pages/home_page.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/audio_player_state_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_discover_chart_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_search_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_state_models.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/profile_stats_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/services/apple_podcast_rss_service.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/pages/podcast_feed_page.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_discover_provider.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/profile/presentation/pages/profile_page.dart';

void main() {
  group('HomePage player navigation behavior', () {
    testWidgets('enters home and triggers restore once', (tester) async {
      final audioNotifier = TestAudioPlayerNotifier(const AudioPlayerState());
      final feedNotifier = TestPodcastFeedNotifier();

      await _pumpHomePage(
        tester,
        audioNotifier: audioNotifier,
        feedNotifier: feedNotifier,
        initialTab: 0,
      );

      expect(audioNotifier.restoreCallCount, 1);
    });

    testWidgets('enters home and prefetches library feed once', (tester) async {
      final audioNotifier = TestAudioPlayerNotifier(const AudioPlayerState());
      final feedNotifier = TestPodcastFeedNotifier();

      await _pumpHomePage(
        tester,
        audioNotifier: audioNotifier,
        feedNotifier: feedNotifier,
        initialTab: 0,
      );

      expect(feedNotifier.backgroundLoadCallCount, 1);
    });

    testWidgets('does not prefetch library repeatedly in same home lifecycle', (
      tester,
    ) async {
      final audioNotifier = TestAudioPlayerNotifier(const AudioPlayerState());
      final feedNotifier = TestPodcastFeedNotifier();

      await _pumpHomePage(
        tester,
        audioNotifier: audioNotifier,
        feedNotifier: feedNotifier,
        initialTab: 0,
      );

      await tester.tap(find.byIcon(Icons.library_books_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.travel_explore_outlined));
      await tester.pumpAndSettle();

      expect(feedNotifier.backgroundLoadCallCount, 1);
    });

    testWidgets('switching tabs does not re-trigger feed first load', (
      tester,
    ) async {
      final audioNotifier = TestAudioPlayerNotifier(const AudioPlayerState());
      final feedNotifier = TestPodcastFeedNotifier();

      await _pumpHomePage(
        tester,
        audioNotifier: audioNotifier,
        feedNotifier: feedNotifier,
        initialTab: 0,
      );

      await tester.tap(find.byIcon(Icons.library_books_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.travel_explore_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.library_books_outlined));
      await tester.pumpAndSettle();

      expect(feedNotifier.foregroundLoadCallCount, 1);
      expect(feedNotifier.loadInitialFeedCallCount, 2);
    });

    testWidgets('profile tab shows mini player when current episode exists', (
      tester,
    ) async {
      final audioNotifier = TestAudioPlayerNotifier(
        AudioPlayerState(currentEpisode: _testEpisode(), isExpanded: false),
      );

      await _pumpHomePage(tester, audioNotifier: audioNotifier, initialTab: 2);

      expect(find.byType(ProfilePage), findsOneWidget);
      expect(
        find.byKey(const Key('podcast_bottom_player_mini')),
        findsOneWidget,
      );
      expect(audioNotifier.state.isExpanded, isFalse);
    });

    testWidgets('profile tab mini player expands on tap', (tester) async {
      final audioNotifier = TestAudioPlayerNotifier(
        AudioPlayerState(currentEpisode: _testEpisode(), isExpanded: false),
      );

      await _pumpHomePage(tester, audioNotifier: audioNotifier, initialTab: 2);

      await tester.tap(
        find.byKey(const Key('podcast_bottom_player_mini_info')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ProfilePage), findsOneWidget);
      expect(audioNotifier.state.isExpanded, isTrue);
      expect(
        find.byKey(const Key('podcast_bottom_player_expanded')),
        findsOneWidget,
      );
    });

    testWidgets('profile tab barrier tap collapses expanded player', (
      tester,
    ) async {
      final audioNotifier = TestAudioPlayerNotifier(
        AudioPlayerState(currentEpisode: _testEpisode(), isExpanded: true),
      );

      await _pumpHomePage(tester, audioNotifier: audioNotifier, initialTab: 2);

      expect(
        find.byKey(const Key('podcast_bottom_player_expanded')),
        findsOneWidget,
      );

      await tester.tapAt(const Offset(195, 120));
      await tester.pumpAndSettle();

      expect(audioNotifier.state.isExpanded, isFalse);
      expect(
        find.byKey(const Key('podcast_bottom_player_mini')),
        findsOneWidget,
      );
    });

    testWidgets(
      'profile viewport stays above mini player and remains scrollable',
      (tester) async {
        final audioNotifier = TestAudioPlayerNotifier(
          AudioPlayerState(currentEpisode: _testEpisode(), isExpanded: false),
        );

        await _pumpHomePage(
          tester,
          audioNotifier: audioNotifier,
          initialTab: 2,
        );

        final profileScrollView = find.descendant(
          of: find.byType(ProfilePage),
          matching: find.byType(SingleChildScrollView),
        );
        final profileScrollable = find.descendant(
          of: find.byType(ProfilePage),
          matching: find.byType(Scrollable),
        );

        expect(profileScrollView, findsOneWidget);
        expect(profileScrollable, findsWidgets);

        final profileRect = tester.getRect(profileScrollView);
        final miniPlayerRect = tester.getRect(
          find.byKey(const Key('podcast_bottom_player_mini_wrapper')),
        );
        expect(profileRect.bottom, lessThanOrEqualTo(miniPlayerRect.top + 0.1));

        final before = tester
            .state<ScrollableState>(profileScrollable.first)
            .position
            .pixels;

        await tester.drag(profileScrollView, const Offset(0, -300));
        await tester.pumpAndSettle();

        final after = tester
            .state<ScrollableState>(profileScrollable.first)
            .position
            .pixels;
        expect(after, greaterThan(before));
      },
    );

    testWidgets(
      'podcast tab still supports barrier tap to collapse expanded player',
      (tester) async {
        final audioNotifier = TestAudioPlayerNotifier(
          AudioPlayerState(currentEpisode: _testEpisode(), isExpanded: true),
        );

        await _pumpHomePage(
          tester,
          audioNotifier: audioNotifier,
          initialTab: 1,
        );

        expect(
          find.byKey(const Key('podcast_bottom_player_expanded')),
          findsOneWidget,
        );

        await tester.tapAt(const Offset(195, 120));
        await tester.pumpAndSettle();

        expect(audioNotifier.state.isExpanded, isFalse);
        expect(
          find.byKey(const Key('podcast_bottom_player_mini')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'position updates do not break mini player interaction on home',
      (tester) async {
        final audioNotifier = TestAudioPlayerNotifier(
          AudioPlayerState(
            currentEpisode: _testEpisode(),
            isExpanded: false,
            duration: 180000,
          ),
        );

        await _pumpHomePage(
          tester,
          audioNotifier: audioNotifier,
          initialTab: 0,
        );

        for (var i = 1; i <= 5; i++) {
          audioNotifier.updatePositionForTest(i * 1000);
          await tester.pump(const Duration(milliseconds: 16));
        }

        expect(
          find.byKey(const Key('podcast_bottom_player_mini')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'discover list viewport stays above mini player when current episode exists',
      (tester) async {
        final audioNotifier = TestAudioPlayerNotifier(
          AudioPlayerState(currentEpisode: _testEpisode(), isExpanded: false),
        );

        await _pumpHomePage(
          tester,
          audioNotifier: audioNotifier,
          initialTab: 0,
        );

        final discoverListFinder = find.byKey(
          const Key('podcast_discover_list'),
        );
        final miniPlayerFinder = find.byKey(
          const Key('podcast_bottom_player_mini_wrapper'),
        );

        expect(discoverListFinder, findsOneWidget);
        expect(miniPlayerFinder, findsOneWidget);

        final discoverRect = tester.getRect(discoverListFinder);
        final miniPlayerRect = tester.getRect(miniPlayerFinder);
        expect(
          discoverRect.bottom,
          lessThanOrEqualTo(miniPlayerRect.top + 0.1),
        );
      },
    );

    testWidgets(
      'feed list viewport stays above mini player when current episode exists',
      (tester) async {
        final audioNotifier = TestAudioPlayerNotifier(
          AudioPlayerState(currentEpisode: _testEpisode(), isExpanded: false),
        );
        final feedNotifier = TestPodcastFeedNotifier(
          PodcastFeedState(
            episodes: [_testEpisode()],
            hasMore: false,
            total: 1,
          ),
        );

        await _pumpHomePage(
          tester,
          audioNotifier: audioNotifier,
          feedNotifier: feedNotifier,
          initialTab: 1,
        );

        final feedListFinder = find.descendant(
          of: find.byType(PodcastFeedPage),
          matching: find.byType(ListView),
        );
        final miniPlayerFinder = find.byKey(
          const Key('podcast_bottom_player_mini_wrapper'),
        );

        expect(feedListFinder, findsOneWidget);
        expect(miniPlayerFinder, findsOneWidget);

        final feedRect = tester.getRect(feedListFinder);
        final miniPlayerRect = tester.getRect(miniPlayerFinder);
        expect(feedRect.bottom, lessThanOrEqualTo(miniPlayerRect.top + 0.1));
      },
    );

    testWidgets(
      'light theme keeps backdrop behind mini player and bottom dock',
      (tester) async {
        final audioNotifier = TestAudioPlayerNotifier(
          AudioPlayerState(currentEpisode: _testEpisode(), isExpanded: false),
        );

        await _pumpHomePage(
          tester,
          audioNotifier: audioNotifier,
          initialTab: 2,
        );

        final backdropFinder = find.byKey(
          const Key('custom_adaptive_navigation_bottom_backdrop'),
        );
        final miniPlayerFinder = find.byKey(
          const Key('podcast_bottom_player_mini_wrapper'),
        );
        final navFinder = find.byType(NavigationBar);

        expect(backdropFinder, findsOneWidget);
        expect(miniPlayerFinder, findsOneWidget);
        expect(navFinder, findsOneWidget);

        final backdropRect = tester.getRect(backdropFinder);
        final miniPlayerRect = tester.getRect(miniPlayerFinder);
        final navRect = tester.getRect(navFinder);

        expect(miniPlayerRect.bottom, lessThanOrEqualTo(navRect.top + 1));
        expect(backdropRect.top, lessThan(miniPlayerRect.top));
        expect(backdropRect.bottom, greaterThanOrEqualTo(navRect.bottom));

        final mobileStack = tester
            .widgetList<Stack>(find.byType(Stack))
            .firstWhere(
              (stack) => stack.children.any(
                (child) =>
                    child is Positioned &&
                    child.child.key ==
                        const Key('custom_adaptive_navigation_bottom_backdrop'),
              ),
            );
        expect(
          mobileStack.children.first,
          isA<Positioned>().having(
            (positioned) => positioned.child.key,
            'child key',
            const Key('custom_adaptive_navigation_bottom_backdrop'),
          ),
        );
        expect(find.byType(CustomAdaptiveNavigation), findsOneWidget);
      },
    );
  });
}

Future<void> _pumpHomePage(
  WidgetTester tester, {
  required TestAudioPlayerNotifier audioNotifier,
  TestPodcastFeedNotifier? feedNotifier,
  required int initialTab,
}) async {
  tester.view.physicalSize = const Size(390, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final effectiveFeedNotifier = feedNotifier ?? TestPodcastFeedNotifier();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(
          _MockLocalStorageService(),
        ),
        authProvider.overrideWith(TestAuthNotifier.new),
        audioPlayerProvider.overrideWith(() => audioNotifier),
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
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomePage(initialTab: initialTab),
      ),
    ),
  );

  await tester.pumpAndSettle();
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
  int setExpandedCalls = 0;
  int restoreCallCount = 0;

  @override
  AudioPlayerState build() {
    return _initialState;
  }

  @override
  void setExpanded(bool expanded) {
    setExpandedCalls += 1;
    state = state.copyWith(isExpanded: expanded);
  }

  @override
  Future<void> restoreLastPlayedEpisodeIfNeeded() async {
    restoreCallCount += 1;
  }

  void updatePositionForTest(int position) {
    state = state.copyWith(position: position);
  }
}

class TestPodcastFeedNotifier extends PodcastFeedNotifier {
  TestPodcastFeedNotifier([this._initialState = const PodcastFeedState()]);

  final PodcastFeedState _initialState;
  int loadInitialFeedCallCount = 0;
  int backgroundLoadCallCount = 0;
  int foregroundLoadCallCount = 0;

  @override
  PodcastFeedState build() {
    return _initialState;
  }

  @override
  Future<void> loadInitialFeed({
    bool forceRefresh = false,
    bool background = false,
  }) async {
    loadInitialFeedCallCount += 1;
    if (background) {
      backgroundLoadCallCount += 1;
      return;
    }
    foregroundLoadCallCount += 1;
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

PodcastEpisodeModel _testEpisode() {
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
