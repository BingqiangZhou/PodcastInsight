import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_state_models.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/pages/podcast_feed_page.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';

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
  group('PodcastFeedPage daily report entry', () {
    testWidgets('shows daily report entry tile in header',
        (tester) async {
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

      // Verify daily report entry tile exists
      expect(
        find.byKey(const Key('library_daily_report_entry_tile')),
        findsOneWidget,
      );
    });

    testWidgets('daily report tile is present on desktop too',
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

      expect(
        find.byKey(const Key('library_daily_report_entry_tile')),
        findsOneWidget,
      );
    });
  });
}
