import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/glass/surface_card.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/shared/base_episode_card.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/simplified_episode_card.dart';

/// Builds a test episode used across all layout tests.
PodcastEpisodeModel _buildEpisode() {
  return PodcastEpisodeModel(
    id: 42,
    subscriptionId: 1,
    subscriptionTitle: 'Sample Show',
    title: 'S2E7 Why does luck look effortless?',
    description:
        'What is luck, really? Is it money, connections, or freedom? '
        'This episode explores myths and reality around good fortune.',
    audioUrl: 'https://example.com/audio.mp3',
    audioDuration: 3600,
    publishedAt: DateTime(2025, 3, 15),
    createdAt: DateTime(2025, 3, 15),
  );
}

/// Wraps the [widgetUnderTest] in the standard test harness.
Widget _buildTestHarness(Widget widgetUnderTest) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: widgetUnderTest),
    ),
  );
}

void main() {
  group('SimplifiedEpisodeCard layout', () {
    testWidgets(
      'mobile layout (390x844): no cover image, no subscription tag, '
      'metadata icons present, play button, add-to-queue button',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final episode = _buildEpisode();
        await tester.pumpWidget(
          _buildTestHarness(
            SimplifiedEpisodeCard(
              episode: episode,
              onTap: () {},
              onPlay: () {},
              onAddToQueue: () {},
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));

        // BaseEpisodeCard and its SurfaceCard are rendered
        expect(find.byType(BaseEpisodeCard), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(BaseEpisodeCard),
            matching: find.byType(SurfaceCard),
          ),
          findsOneWidget,
        );

        // Title is shown
        expect(find.text('S2E7 Why does luck look effortless?'),
            findsOneWidget);

        // No subscription name rendered (SimplifiedEpisodeCard sets showImage: false
        // and does not pass subscriptionTitle as a subtitle)
        expect(find.text('Sample Show'), findsNothing);

        // Metadata icons (date and duration)
        expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
        expect(find.byIcon(Icons.schedule), findsOneWidget);

        // Play button
        expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);

        // Add-to-queue button
        expect(find.byIcon(Icons.playlist_add), findsOneWidget);

        // Layout: play button is vertically above add-to-queue button
        final playButtonIcon = find.byIcon(Icons.play_circle_outline);
        final addButtonIcon = find.byIcon(Icons.playlist_add);
        final playButtonRect = tester.getRect(playButtonIcon);
        final addButtonRect = tester.getRect(addButtonIcon);
        expect(
          playButtonRect.center.dy,
          lessThan(addButtonRect.center.dy),
        );
      },
    );

    testWidgets(
      'desktop layout (1200x900): same structure, 4-line description',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final episode = _buildEpisode();
        await tester.pumpWidget(
          _buildTestHarness(
            SimplifiedEpisodeCard(
              episode: episode,
              onTap: () {},
              onPlay: () {},
              onAddToQueue: () {},
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));

        // BaseEpisodeCard and its SurfaceCard are rendered
        expect(find.byType(BaseEpisodeCard), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(BaseEpisodeCard),
            matching: find.byType(SurfaceCard),
          ),
          findsOneWidget,
        );

        // No subscription name rendered
        expect(find.text('Sample Show'), findsNothing);

        // Description is displayed (the full plain text from HTML stripping)
        expect(find.textContaining('What is luck'), findsOneWidget);

        // Metadata icons (date and duration)
        expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
        expect(find.byIcon(Icons.schedule), findsOneWidget);

        // Play button
        expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);

        // Add-to-queue button
        expect(find.byIcon(Icons.playlist_add), findsOneWidget);

        // Layout: play button is vertically above add-to-queue button
        final playButtonIcon = find.byIcon(Icons.play_circle_outline);
        final addButtonIcon = find.byIcon(Icons.playlist_add);
        final playButtonRect = tester.getRect(playButtonIcon);
        final addButtonRect = tester.getRect(addButtonIcon);
        expect(
          playButtonRect.center.dy,
          lessThan(addButtonRect.center.dy),
        );
      },
    );

    testWidgets(
      'add-to-queue button shows CircularProgressIndicator when loading',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final episode = _buildEpisode();
        await tester.pumpWidget(
          _buildTestHarness(
            SimplifiedEpisodeCard(
              episode: episode,
              isAddingToQueue: true,
              onAddToQueue: () {},
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));

        // When isAddingToQueue is true, a CircularProgressIndicator replaces
        // the playlist_add icon. (The DownloadButton may also show a spinner
        // in its loading state, so we check for at least one.)
        expect(find.byType(CircularProgressIndicator), findsAtLeast(1));

        // The playlist_add icon should NOT be present (replaced by spinner)
        expect(find.byIcon(Icons.playlist_add), findsNothing);
      },
    );
  });
}
