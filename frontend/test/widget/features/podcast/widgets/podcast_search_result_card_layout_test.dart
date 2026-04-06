import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/glass/surface_card.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_search_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/constants/podcast_ui_constants.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/podcast_search_result_card.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/shared/base_episode_card.dart';

void main() {
  group('PodcastSearchResultCard layout', () {
    testWidgets('uses subscription-style shell and keeps search metadata', (
      tester,
    ) async {
      const result = PodcastSearchResult(
        collectionName: 'Daily Pod',
        artistName: 'Jane Host',
        feedUrl: 'https://example.com/feed.xml',
        primaryGenreName: 'Technology',
        trackCount: 42,
      );

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: PodcastSearchResultCard(result: result)),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the card uses BaseEpisodeCard (which internally uses SurfaceCard)
      expect(find.byType(BaseEpisodeCard), findsOneWidget);
      expect(find.byType(SurfaceCard), findsWidgets);

      // Verify text content
      expect(find.text('Daily Pod'), findsOneWidget);
      expect(find.text('Jane Host'), findsOneWidget);
      expect(find.text('Technology'), findsOneWidget);
      expect(find.textContaining('42'), findsOneWidget);

      // Verify subscribe button icon
      expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);

      // Verify genre and episodes metadata icons
      expect(find.byIcon(Icons.category), findsOneWidget);
      expect(find.byIcon(Icons.podcasts), findsOneWidget);
    });
  });
}
