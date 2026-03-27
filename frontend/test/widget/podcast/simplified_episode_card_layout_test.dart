import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/simplified_episode_card.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/shared/base_episode_card.dart';

void main() {
  group('SimplifiedEpisodeCard layout', () {
    testWidgets(
      'mobile layout removes cover and subscription tag, keeps metadata and action icons',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final episode = _buildEpisode();

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SimplifiedEpisodeCard(
                  episode: episode,
                  onTap: () {},
                  onPlay: () {},
                  onAddToQueue: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify BaseEpisodeCard is rendered
        expect(find.byType(BaseEpisodeCard), findsOneWidget);
        expect(find.byType(Card), findsOneWidget);

        // Verify title is shown
        expect(find.text(episode.title), findsOneWidget);

        // Verify no subscription name or podcast icon (showImage: false, no subscription badge)
        expect(find.text('Sample Show'), findsNothing);
        expect(find.byIcon(Icons.podcasts), findsNothing);

        // Verify description is shown with 2-line max (dense/mobile mode)
        final descriptionFinder = find.text(
          'What is luck, really? Is it money, connections, or freedom? '
          'Why do some people burn out while others seem to move smoothly? '
          'This episode explores myths and reality around good fortune.',
        );
        expect(descriptionFinder, findsOneWidget);
        final descriptionText = tester.widget<Text>(descriptionFinder);
        expect(descriptionText.maxLines, 2);

        // Verify metadata icons are shown (date and duration)
        expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
        expect(find.byIcon(Icons.schedule), findsOneWidget);
        expect(find.text('2026-02-10'), findsOneWidget);
        expect(find.text(episode.formattedDuration), findsOneWidget);

        // Verify play button exists
        expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);

        // Verify add-to-queue button exists
        expect(find.byIcon(Icons.playlist_add), findsOneWidget);

        // Verify layout positions: play button is above add-to-queue button
        final playButtonFinder = find.byIcon(Icons.play_circle_outline);
        final addButtonFinder = find.byIcon(Icons.playlist_add);
        final playButtonRect = tester.getRect(playButtonFinder);
        final addButtonRect = tester.getRect(addButtonFinder);
        expect(playButtonRect.center.dy, lessThan(addButtonRect.center.dy));
      },
    );

    testWidgets(
      'desktop layout keeps same structure and uses 4-line description',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final episode = _buildEpisode();

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 360,
                    child: SimplifiedEpisodeCard(
                      episode: episode,
                      onTap: () {},
                      onPlay: () {},
                      onAddToQueue: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(BaseEpisodeCard), findsOneWidget);
        expect(find.byType(Card), findsOneWidget);

        // Verify no subscription name or podcast icon
        expect(find.text('Sample Show'), findsNothing);
        expect(find.byIcon(Icons.podcasts), findsNothing);

        // Verify description is shown with 4-line max (non-dense/desktop mode)
        final descriptionFinder = find.text(
          'What is luck, really? Is it money, connections, or freedom? '
          'Why do some people burn out while others seem to move smoothly? '
          'This episode explores myths and reality around good fortune.',
        );
        expect(descriptionFinder, findsOneWidget);
        final descriptionText = tester.widget<Text>(descriptionFinder);
        expect(descriptionText.maxLines, 4);

        // Verify metadata icons are shown
        expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
        expect(find.byIcon(Icons.schedule), findsOneWidget);

        // Verify play and queue buttons exist
        expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
        expect(find.byIcon(Icons.playlist_add), findsOneWidget);

        // Verify layout positions: play button is above add-to-queue button
        final playButtonFinder = find.byIcon(Icons.play_circle_outline);
        final addButtonFinder = find.byIcon(Icons.playlist_add);
        final playButtonRect = tester.getRect(playButtonFinder);
        final addButtonRect = tester.getRect(addButtonFinder);
        expect(playButtonRect.center.dy, lessThan(addButtonRect.center.dy));
      },
    );

    testWidgets(
      'title is rendered and card structure is correct',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final episode = _buildSingleLineTitleEpisode();

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 360,
                    child: SimplifiedEpisodeCard(
                      episode: episode,
                      onTap: () {},
                      onPlay: () {},
                      onAddToQueue: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify title is rendered
        final titleFinder = find.text(episode.title);
        expect(titleFinder, findsOneWidget);

        // Verify the card renders with BaseEpisodeCard
        expect(find.byType(BaseEpisodeCard), findsOneWidget);
        expect(find.byType(Card), findsOneWidget);
      },
    );

    testWidgets('add-to-queue button shows loading and becomes disabled', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final episode = _buildEpisode();
      var tapCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SimplifiedEpisodeCard(
                episode: episode,
                isAddingToQueue: true,
                onAddToQueue: () {
                  tapCount += 1;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // When isAddingToQueue is true, the add-to-queue IconButton should show
      // a CircularProgressIndicator instead of the playlist_add icon.
      // The button's onPressed should be null (disabled).
      expect(
        find.byType(CircularProgressIndicator),
        findsOneWidget,
      );

      // Try tapping the card area containing the add-to-queue button
      await tester.tap(find.byType(CircularProgressIndicator));
      await tester.pump();
      expect(tapCount, 0);
    });
  });
}

PodcastEpisodeModel _buildEpisode() {
  return PodcastEpisodeModel(
    id: 1,
    subscriptionId: 1,
    subscriptionTitle: 'Sample Show',
    title: 'S2E7 Why does luck look effortless?',
    description:
        'What is luck, really? Is it money, connections, or freedom? '
        'Why do some people burn out while others seem to move smoothly? '
        'This episode explores myths and reality around good fortune.',
    audioUrl: 'https://example.com/audio.mp3',
    audioDuration: 4143,
    publishedAt: DateTime(2026, 2, 10),
    createdAt: DateTime(2026, 2, 10),
  );
}

PodcastEpisodeModel _buildSingleLineTitleEpisode() {
  return PodcastEpisodeModel(
    id: 2,
    subscriptionId: 1,
    subscriptionTitle: 'Sample Show',
    title: 'Short Title',
    description:
        'Short description to keep layout deterministic for single-line title validation.',
    audioUrl: 'https://example.com/audio-short.mp3',
    audioDuration: 1800,
    publishedAt: DateTime(2026, 2, 11),
    createdAt: DateTime(2026, 2, 11),
  );
}
