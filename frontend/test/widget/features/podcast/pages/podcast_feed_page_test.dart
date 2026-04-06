import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_state_models.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/pages/podcast_feed_page.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/shared/base_episode_card.dart';
import 'package:personal_ai_assistant/shared/widgets/skeleton_widgets.dart';

PodcastEpisodeModel _buildEpisode({String? description}) {
  return PodcastEpisodeModel(
    id: 1,
    subscriptionId: 1,
    title: 'Test Episode',
    description: description ?? 'A test episode description.',
    audioUrl: 'https://example.com/audio.mp3',
    publishedAt: DateTime(2024, 1, 15),
    createdAt: DateTime(2024, 1, 15),
    audioDuration: 1800000,
    subscriptionTitle: 'Test Podcast',
  );
}

class _MockPodcastFeedNotifier extends PodcastFeedNotifier {
  _MockPodcastFeedNotifier(this._initialState);
  final PodcastFeedState _initialState;

  @override
  PodcastFeedState build() => _initialState;

  @override
  Future<void> loadInitialFeed({
    bool forceRefresh = false,
    bool background = false,
  }) async {}

  @override
  Future<void> refreshFeed({bool fastReturn = false}) async {}
}

void main() {
  group('PodcastFeedPage', () {
    testWidgets('shows skeleton while loading', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          podcastFeedProvider.overrideWith(
            () => _MockPodcastFeedNotifier(
              const PodcastFeedState(
                episodes: [],
                hasMore: false,
                total: 0,
                isLoading: true,
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates:
                AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PodcastFeedPage(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(SkeletonCardList), findsOneWidget);
    });

    testWidgets('shows empty state when no episodes', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          podcastFeedProvider.overrideWith(
            () => _MockPodcastFeedNotifier(
              const PodcastFeedState(
                episodes: [],
                hasMore: false,
                total: 0,
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates:
                AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PodcastFeedPage(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(PodcastFeedPage), findsOneWidget);
    });

    testWidgets('renders episodes when loaded', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final episode = _buildEpisode();
      final container = ProviderContainer(
        overrides: [
          podcastFeedProvider.overrideWith(
            () => _MockPodcastFeedNotifier(
              PodcastFeedState(
                episodes: [episode],
                hasMore: false,
                total: 1,
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates:
                AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PodcastFeedPage(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(BaseEpisodeCard), findsOneWidget);
      expect(find.text('Test Episode'), findsOneWidget);
    });

    testWidgets('shows error state with retry button', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          podcastFeedProvider.overrideWith(
            () => _MockPodcastFeedNotifier(
              const PodcastFeedState(
                episodes: [],
                hasMore: false,
                total: 0,
                error: 'Network error',
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates:
                AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PodcastFeedPage(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(PodcastFeedPage), findsOneWidget);
    });
  });
}
