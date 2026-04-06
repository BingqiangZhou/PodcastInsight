import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_ai_assistant/core/glass/surface_card.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_state_models.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/pages/podcast_feed_page.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/shared/base_episode_card.dart';

PodcastEpisodeModel _buildEpisode({String? description}) {
  return PodcastEpisodeModel(
    id: 1,
    subscriptionId: 1,
    title: 'S2E7 Why does luck look effortless?',
    description: description ??
        'What is luck, really? Is it money, connections, or freedom?'
            ' This episode explores myths and reality around good fortune.',
    audioUrl: 'https://example.com/audio.mp3',
    publishedAt: DateTime(2024, 1, 15),
    createdAt: DateTime(2024, 1, 15),
    subscriptionTitle: 'Sample Show',
    subscriptionImageUrl: 'https://example.com/cover.jpg',
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
  group('PodcastFeedPage card layout', () {
    testWidgets(
      'mobile card renders episode with BaseEpisodeCard',
      (tester) async {
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

        // Verify BaseEpisodeCard and SurfaceCard render
        expect(
          find.descendant(
            of: find.byType(BaseEpisodeCard),
            matching: find.byType(SurfaceCard),
          ),
          findsWidgets,
        );
        expect(find.byType(BaseEpisodeCard), findsOneWidget);
        expect(
          find.text('S2E7 Why does luck look effortless?'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'desktop layout renders feed page',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
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
      },
    );
  });
}
