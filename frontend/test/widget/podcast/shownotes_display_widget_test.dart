import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/shownotes_display_widget.dart';

void main() {
  group('ShownotesDisplayWidget Widget Tests', () {
    final testPublishedAt = DateTime(2024);
    final testCreatedAt = DateTime(2024);

    Future<void> pumpShownotes(
      WidgetTester tester,
      PodcastEpisodeModel episode,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ShownotesDisplayWidget(episode: episode)),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    PodcastEpisodeModel buildEpisode({
      String? description,
      String? aiSummary,
    }) {
      return PodcastEpisodeModel(
        id: 1,
        subscriptionId: 1,
        title: 'Test Episode',
        description: description,
        aiSummary: aiSummary,
        audioUrl: 'https://example.com/audio.mp3',
        publishedAt: testPublishedAt,
        createdAt: testCreatedAt,
      );
    }

    testWidgets('renders empty state when no description is provided', (
      tester,
    ) async {
      await pumpShownotes(tester, buildEpisode());
      final context = tester.element(find.byType(ShownotesDisplayWidget));
      final l10n = AppLocalizations.of(context)!;

      expect(find.text(l10n.podcast_no_shownotes), findsOneWidget);
      expect(find.byIcon(Icons.description_outlined), findsOneWidget);
      expect(find.byType(HtmlWidget), findsNothing);
    });

    testWidgets('renders empty state when description is empty', (
      tester,
    ) async {
      await pumpShownotes(tester, buildEpisode(description: ''));
      final context = tester.element(find.byType(ShownotesDisplayWidget));
      final l10n = AppLocalizations.of(context)!;

      expect(find.text(l10n.podcast_no_shownotes), findsOneWidget);
      expect(find.byType(HtmlWidget), findsNothing);
    });

    testWidgets('renders shownotes header and html widget for content', (
      tester,
    ) async {
      await pumpShownotes(
        tester,
        buildEpisode(description: '<p>Hello <strong>world</strong></p>'),
      );

      expect(find.text('Shownotes'), findsOneWidget);
      expect(find.byType(HtmlWidget), findsOneWidget);
    });

    testWidgets('shownotes header inherits titleLarge font family only', (
      tester,
    ) async {
      await pumpShownotes(
        tester,
        buildEpisode(description: 'This is a test shownotes content.'),
      );

      final titleFinder = find.text('Shownotes');
      final titleWidget = tester.widget<Text>(titleFinder);
      final titleStyle = titleWidget.style;
      final context = tester.element(titleFinder);
      final expectedStyle = Theme.of(context).textTheme.titleLarge;

      expect(titleStyle, isNotNull);
      expect(titleStyle!.fontFamily, expectedStyle?.fontFamily);
      expect(
        titleStyle.fontFamilyFallback,
        equals(expectedStyle?.fontFamilyFallback),
      );
      expect(titleStyle.fontSize, 22.0);
      expect(titleStyle.fontWeight, FontWeight.bold);
    });

    testWidgets('uses ai summary as fallback when description is empty', (
      tester,
    ) async {
      await pumpShownotes(
        tester,
        buildEpisode(aiSummary: 'AI Generated Summary'),
      );
      final context = tester.element(find.byType(ShownotesDisplayWidget));
      final l10n = AppLocalizations.of(context)!;

      expect(find.text('Shownotes'), findsOneWidget);
      expect(find.byType(HtmlWidget), findsOneWidget);
      expect(find.text(l10n.podcast_no_shownotes), findsNothing);
    });

    testWidgets('sanitizes dangerous script tags without crashing', (
      tester,
    ) async {
      await pumpShownotes(
        tester,
        buildEpisode(description: '<p>Safe</p><script>alert("XSS")</script>'),
      );

      expect(find.text('Shownotes'), findsOneWidget);
      expect(find.byType(HtmlWidget), findsOneWidget);
      expect(find.textContaining('alert'), findsNothing);
    });

    testWidgets('handles malformed html gracefully', (tester) async {
      await pumpShownotes(
        tester,
        buildEpisode(description: '<p>Unclosed paragraph<div>Nested</p>'),
      );

      expect(find.text('Shownotes'), findsOneWidget);
      expect(find.byType(HtmlWidget), findsOneWidget);
    });

    testWidgets('renders on mobile and desktop sizes', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      await pumpShownotes(tester, buildEpisode(description: '<p>Mobile</p>'));
      expect(find.text('Shownotes'), findsOneWidget);

      tester.view.physicalSize = const Size(1200, 800);
      await pumpShownotes(tester, buildEpisode(description: '<p>Desktop</p>'));
      expect(find.text('Shownotes'), findsOneWidget);
      expect(find.byType(HtmlWidget), findsOneWidget);
    });
  });
}
