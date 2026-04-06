import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/features/podcast/core/utils/episode_description_helper.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/simplified_episode_card.dart';

void main() {
  group('SimplifiedEpisodeCard', () {
    testWidgets('displays plain shownotes regardless of AI summary',
        (tester) async {
      final episode = PodcastEpisodeModel(
        id: 1,
        subscriptionId: 1,
        title: 'Test Episode',
        description: '<p>Original shownotes content</p>',
        audioUrl: 'https://example.com/audio.mp3',
        publishedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SimplifiedEpisodeCard(episode: episode),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Should display description text, not AI summary
      expect(find.textContaining('shownotes'), findsOneWidget);
      expect(find.textContaining('Original'), findsOneWidget);
      // Should display plain shownotes (without HTML tags)
      expect(find.textContaining('<'), findsNothing);
      expect(find.textContaining('style='), findsNothing);
    });

    testWidgets('does not display description when null', (tester) async {
      final episode = PodcastEpisodeModel(
        id: 1,
        subscriptionId: 1,
        title: 'Test Episode',
        audioUrl: 'https://example.com/audio.mp3',
        publishedAt: DateTime.now(),
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SimplifiedEpisodeCard(episode: episode),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Card should still render (title + metadata only)
      expect(find.byType(SimplifiedEpisodeCard), findsOneWidget);
    });
  });
}
