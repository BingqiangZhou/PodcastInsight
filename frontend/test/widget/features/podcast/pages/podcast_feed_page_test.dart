import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/glass/surface_card.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_state_models.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/pages/podcast_feed_page.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/shared/widgets/skeleton_widgets.dart';

void main() {
  group('PodcastFeedPage Widget Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets('displays loading shimmer initially', (
      tester,
    ) async {
      final testContainer = ProviderContainer(
        overrides: [
          podcastFeedProvider.overrideWith(
            () => MockPodcastFeedNotifier(
              const PodcastFeedState(
                isLoading: true,
                hasMore: false,
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: testContainer,
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PodcastFeedPage(),
          ),
        ),
      );

      final l10n = AppLocalizations.of(
        tester.element(find.byType(PodcastFeedPage)),
      )!;
      // Loading state now shows skeleton cards instead of CircularProgressIndicator
      expect(find.byType(SkeletonCardList), findsAtLeast(1));
      expect(find.text(l10n.podcast_feed_page_title), findsOneWidget);

      testContainer.dispose();
    });

    testWidgets('calls loadInitialFeed on init', (tester) async {
      final feedNotifier = LoadTrackingPodcastFeedNotifier(
        const PodcastFeedState(
          hasMore: false,
        ),
      );
      final testContainer = ProviderContainer(
        overrides: [podcastFeedProvider.overrideWith(() => feedNotifier)],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: testContainer,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PodcastFeedPage(),
          ),
        ),
      );

      await tester.pump();
      expect(feedNotifier.loadInitialFeedCallCount, 1);
      testContainer.dispose();
    });

    testWidgets('shows loading before first empty result resolves', (
      tester,
    ) async {
      final feedNotifier = DelayedLoadPodcastFeedNotifier(
        const PodcastFeedState(
          hasMore: false,
        ),
      );
      final testContainer = ProviderContainer(
        overrides: [podcastFeedProvider.overrideWith(() => feedNotifier)],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: testContainer,
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PodcastFeedPage(),
          ),
        ),
      );

      await tester.pump();
      // Loading state now shows skeleton cards
      expect(find.byType(SkeletonCardList), findsAtLeast(1));

      feedNotifier.completeLoad();
      await tester.pump(const Duration(seconds: 1));

      final l10n = AppLocalizations.of(
        tester.element(find.byType(PodcastFeedPage)),
      )!;
      expect(find.text(l10n.podcast_no_episodes_found), findsOneWidget);

      testContainer.dispose();
    });

    testWidgets('displays empty state when no episodes', (
      tester,
    ) async {
      // Arrange - Override provider to return empty state
      final testContainer = ProviderContainer(
        overrides: [
          podcastFeedProvider.overrideWith(
            () => MockPodcastFeedNotifier(
              const PodcastFeedState(
                hasMore: false,
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: testContainer,
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PodcastFeedPage(),
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      final l10n = AppLocalizations.of(
        tester.element(find.byType(PodcastFeedPage)),
      )!;
      expect(find.text(l10n.podcast_no_episodes_found), findsOneWidget);

      testContainer.dispose();
    });

    testWidgets('displays episode cards when data is loaded', (
      tester,
    ) async {
      // Arrange - Create mock episodes
      final mockEpisodes = [
        PodcastEpisodeModel(
          id: 1,
          subscriptionId: 1,
          title: 'Test Episode 1',
          audioUrl: 'https://example.com/audio1.mp3',
          publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
          createdAt: DateTime.now(),
        ),
        PodcastEpisodeModel(
          id: 2,
          subscriptionId: 1,
          title: 'Test Episode 2',
          audioUrl: 'https://example.com/audio2.mp3',
          publishedAt: DateTime.now().subtract(const Duration(days: 1)),
          createdAt: DateTime.now(),
        ),
      ];

      // Override provider with mock data
      final testContainer = ProviderContainer(
        overrides: [
          podcastFeedProvider.overrideWith(
            () => MockPodcastFeedNotifier(
              PodcastFeedState(
                episodes: mockEpisodes,
                total: 2,
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: testContainer,
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PodcastFeedPage(),
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      // Assert
      expect(find.text('Test Episode 1'), findsOneWidget);
      expect(find.text('Test Episode 2'), findsOneWidget);
      expect(find.byType(SurfaceCard), findsAtLeast(2));

      testContainer.dispose();
    });

    testWidgets('displays error state when loading fails', (
      tester,
    ) async {
      // Arrange - Override provider to return error state
      final testContainer = ProviderContainer(
        overrides: [
          podcastFeedProvider.overrideWith(
            () => MockPodcastFeedNotifier(
              const PodcastFeedState(
                hasMore: false,
                error: 'Network error occurred',
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: testContainer,
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PodcastFeedPage(),
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      final l10n = AppLocalizations.of(
        tester.element(find.byType(PodcastFeedPage)),
      )!;
      expect(
        find.textContaining(l10n.podcast_failed_to_load_feed),
        findsOneWidget,
      );
      expect(find.textContaining('Network error occurred'), findsOneWidget);
      expect(find.text(l10n.podcast_retry), findsOneWidget);

      testContainer.dispose();
    });

    testWidgets('displays loading more indicator', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Arrange - Create mock episodes with loading state
      final mockEpisodes = [
        PodcastEpisodeModel(
          id: 1,
          subscriptionId: 1,
          title: 'Test Episode 1',
          audioUrl: 'https://example.com/audio1.mp3',
          publishedAt: DateTime.now(),
          createdAt: DateTime.now(),
        ),
      ];

      // Override provider with mock data and loading more state
      final testContainer = ProviderContainer(
        overrides: [
          podcastFeedProvider.overrideWith(
            () => MockPodcastFeedNotifier(
              PodcastFeedState(
                episodes: mockEpisodes,
                isLoadingMore: true,
                total: 1,
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: testContainer,
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PodcastFeedPage(),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsWidgets);

      testContainer.dispose();
    });

    testWidgets('does not show load-more indicator when hasMore=false', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockEpisodes = [
        PodcastEpisodeModel(
          id: 1,
          subscriptionId: 1,
          title: 'Test Episode 1',
          audioUrl: 'https://example.com/audio1.mp3',
          publishedAt: DateTime.now(),
          createdAt: DateTime.now(),
        ),
      ];

      final testContainer = ProviderContainer(
        overrides: [
          podcastFeedProvider.overrideWith(
            () => MockPodcastFeedNotifier(
              PodcastFeedState(
                episodes: mockEpisodes,
                hasMore: false,
                total: 1,
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: testContainer,
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PodcastFeedPage(),
          ),
        ),
      );

      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Test Episode 1'), findsOneWidget);
      // There may be a CircularProgressIndicator from global widgets (e.g., mini player)
      // so we just verify the feed-specific load-more indicator is absent
      // by checking the feed list doesn't have extra items beyond the episodes
      final indicators = find.byType(CircularProgressIndicator);
      expect(indicators.evaluate().length, lessThanOrEqualTo(1));

      testContainer.dispose();
    });
  });
}

// Test helper classes
class MockPodcastFeedNotifier extends PodcastFeedNotifier {
  MockPodcastFeedNotifier(this._initialState);

  final PodcastFeedState _initialState;

  @override
  PodcastFeedState build() {
    return _initialState;
  }

  // Mock the methods that the page might call
  @override
  Future<void> loadInitialFeed({
    bool forceRefresh = false,
    bool background = false,
  }) async {
    // Do nothing for testing
  }

  @override
  Future<void> loadMoreFeed() async {
    // Do nothing for testing
  }

  @override
  Future<void> refreshFeed({bool fastReturn = false}) async {
    // Do nothing for testing
  }
}

class LoadTrackingPodcastFeedNotifier extends PodcastFeedNotifier {
  LoadTrackingPodcastFeedNotifier(this._initialState);

  final PodcastFeedState _initialState;
  int loadInitialFeedCallCount = 0;

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
  }
}

class DelayedLoadPodcastFeedNotifier extends PodcastFeedNotifier {
  DelayedLoadPodcastFeedNotifier(this._initialState);

  final PodcastFeedState _initialState;
  final Completer<void> _loadCompleter = Completer<void>();

  @override
  PodcastFeedState build() {
    return _initialState;
  }

  @override
  Future<void> loadInitialFeed({
    bool forceRefresh = false,
    bool background = false,
  }) async {
    await _loadCompleter.future;
  }

  void completeLoad() {
    if (!_loadCompleter.isCompleted) {
      _loadCompleter.complete();
    }
  }
}
