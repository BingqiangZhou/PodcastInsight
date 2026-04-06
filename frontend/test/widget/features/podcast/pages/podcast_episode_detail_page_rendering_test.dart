import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/pages/podcast_episode_detail_page.dart';
import '../../../../helpers/podcast_episode_detail_helper.dart';

void main() {
  // =========================================================================
  // From podcast_episode_detail_page_basic_test.dart
  // =========================================================================
  group('PodcastEpisodeDetailPage basic smoke tests', () {
    testWidgets('renders hero and three primary tabs on mobile', (
      tester,
    ) async {
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(
        createEpisodeDetailWidget(episode: createTestEpisode()),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final context = tester.element(find.byType(PodcastEpisodeDetailPage));
      final l10n = AppLocalizations.of(context)!;

      expect(find.text('Test Episode'), findsOneWidget);
      expect(
        find.byKey(const Key('podcast_episode_detail_primary_tabs')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('episode_detail_mobile_tab_0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('episode_detail_mobile_tab_1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('episode_detail_mobile_tab_2')),
        findsOneWidget,
      );
      expect(find.text(l10n.podcast_tab_shownotes), findsWidgets);
      expect(find.text(l10n.podcast_tab_transcript), findsOneWidget);
      expect(find.text(l10n.podcast_tab_summary), findsOneWidget);
      expect(find.text(l10n.podcast_tab_chat), findsOneWidget);
      expect(
        find.byKey(const Key('podcast_episode_detail_owned_player')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('podcast_episode_detail_summary_section')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('podcast_episode_detail_chat_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('podcast_episode_detail_mobile_hero_actions')),
        findsOneWidget,
      );
      expect(
        tester
            .getSize(
              find.byKey(
                const Key('podcast_episode_detail_mobile_hero_artwork'),
              ),
            )
            .width,
        lessThanOrEqualTo(56),
      );
      expect(
        tester
            .getSize(
              find.byKey(const Key('podcast_episode_detail_mobile_hero_body')),
            )
            .height,
        lessThanOrEqualTo(140),
      );
    });

    testWidgets(
      'keeps shownotes transcript summary and chat visible at 360px',
      (tester) async {
        addTearDown(() async => tester.binding.setSurfaceSize(null));
        await tester.binding.setSurfaceSize(const Size(360, 844));

        await tester.pumpWidget(
          createEpisodeDetailWidget(episode: createTestEpisode()),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        final context = tester.element(find.byType(PodcastEpisodeDetailPage));
        final l10n = AppLocalizations.of(context)!;

        final shownotesFinder = find.text(l10n.podcast_tab_shownotes);
        final transcriptFinder = find.text(l10n.podcast_tab_transcript);
        final summaryFinder = find.text(l10n.podcast_tab_summary);
        final chatFinder = find.text(l10n.podcast_tab_chat);

        expect(shownotesFinder, findsWidgets);
        expect(transcriptFinder, findsOneWidget);
        expect(summaryFinder, findsOneWidget);
        expect(chatFinder, findsOneWidget);

        final viewportWidth = tester.view.physicalSize.width;
        expect(
          tester.getRect(transcriptFinder).right,
          lessThanOrEqualTo(viewportWidth),
        );
        expect(
          tester.getRect(summaryFinder).right,
          lessThanOrEqualTo(viewportWidth),
        );
        expect(
          tester.getRect(chatFinder).right,
          lessThanOrEqualTo(viewportWidth),
        );
      },
    );

    testWidgets('switches between transcript and summary tabs', (tester) async {
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(
        createEpisodeDetailWidget(episode: createTestEpisode()),
      );
      await tester.pumpAndSettle();

      final transcriptTabFinder = find.byKey(
        const Key('episode_detail_mobile_tab_1'),
      );
      await tester.ensureVisible(transcriptTabFinder);
      await tester.tap(transcriptTabFinder);
      await tester.pumpAndSettle();

      // Default view is now highlights - switch to full transcript view
      final fullTextButton = find.textContaining('Full Text');
      if (fullTextButton.evaluate().isNotEmpty) {
        await tester.tap(fullTextButton);
        await tester.pumpAndSettle();
      }

      expect(find.textContaining('Transcript content'), findsOneWidget);

      final summaryTabFinder = find.byKey(
        const Key('episode_detail_mobile_tab_2'),
      );
      await tester.ensureVisible(summaryTabFinder);
      await tester.tap(summaryTabFinder);
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(PodcastEpisodeDetailPage));
      final l10n = AppLocalizations.of(context)!;

      expect(
        find.byKey(const Key('podcast_episode_detail_summary_section')),
        findsOneWidget,
      );
      expect(find.text('Generated summary'), findsOneWidget);
      expect(find.text(l10n.podcast_share_all_content), findsOneWidget);
    });

    testWidgets('hides mobile header after scrolling content', (tester) async {
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(
        createEpisodeDetailWidget(
          episode: createTestEpisode(
            description: List.filled(
              24,
              '<h2>Opening</h2><p>Description with enough body text to scroll the shownotes area.</p>',
            ).join(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(SingleChildScrollView).last,
        const Offset(0, -420),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('podcast_episode_detail_mobile_hero_body')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('podcast_episode_detail_primary_tabs')),
        findsOneWidget,
      );
    });

    testWidgets('uses inline source link and icon-only play action on mobile', (
      tester,
    ) async {
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(
        createEpisodeDetailWidget(episode: createTestEpisode()),
      );
      await tester.pumpAndSettle();

      final sourceButton = find.byKey(
        const Key('podcast_episode_detail_source_button'),
      );
      final playButton = find.byKey(
        const Key('podcast_episode_detail_play_button'),
      );
      final playWidget = tester.widget<HeaderCapsuleActionButton>(playButton);
      final sourceRect = tester.getRect(sourceButton);
      final actionsRect = tester.getRect(
        find.byKey(const Key('podcast_episode_detail_mobile_hero_actions')),
      );

      expect(sourceButton, findsOneWidget);
      expect(find.text('Source'), findsOneWidget);
      expect(sourceRect.right, lessThan(actionsRect.left));
      expect(playWidget.density, HeaderCapsuleActionButtonDensity.iconOnly);
      expect(tester.getSize(playButton).height, lessThanOrEqualTo(40));
    });

    testWidgets('uses icon-only play action on ultra narrow mobile', (
      tester,
    ) async {
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(350, 844));

      await tester.pumpWidget(
        createEpisodeDetailWidget(episode: createTestEpisode()),
      );
      await tester.pumpAndSettle();

      final playButton = find.byKey(
        const Key('podcast_episode_detail_play_button'),
      );
      final playWidget = tester.widget<HeaderCapsuleActionButton>(playButton);

      expect(playButton, findsOneWidget);
      expect(playWidget.density, HeaderCapsuleActionButtonDensity.iconOnly);
      expect(tester.getSize(playButton).width, lessThanOrEqualTo(40));
      expect(tester.getSize(playButton).height, lessThanOrEqualTo(40));
    });

    testWidgets('shows localized not-found state', (tester) async {
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(createEpisodeDetailWidget(episode: null));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(PodcastEpisodeDetailPage));
      final l10n = AppLocalizations.of(context)!;

      expect(find.text(l10n.podcast_error_loading), findsOneWidget);
      expect(find.text(l10n.podcast_episode_not_found), findsOneWidget);
      expect(find.text(l10n.podcast_go_back), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('renders bare loading state without GlassPanel', (
      tester,
    ) async {
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      final completer = Completer<PodcastEpisodeModel?>();
      await tester.pumpWidget(
        createEpisodeDetailWidget(
          episodeLoader: () => completer.future,
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('podcast_episode_detail_loading_content')),
        findsOneWidget,
      );
      expect(find.byType(SurfacePanel), findsNothing);

      completer.complete(createTestEpisode());
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });
  });

  // =========================================================================
  // From podcast_episode_detail_page_new_test.dart
  // =========================================================================
  group('PodcastEpisodeDetailPage wide layout tests', () {
    testWidgets('renders wide primary content without side rail', (
      tester,
    ) async {
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      await tester.pumpWidget(
        createEpisodeDetailWidget(
          episode: createTestEpisode(
            description:
                '<h2>Opening</h2><p>Description</p><h2>Deep Dive</h2><p>More content</p>',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('podcast_episode_detail_primary_content')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('podcast_episode_detail_side_rail')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('podcast_episode_detail_summary_section')),
        findsNothing,
      );
    });

    testWidgets('opens chat drawer from secondary action', (tester) async {
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      await tester.pumpWidget(
        createEpisodeDetailWidget(
          episode: createTestEpisode(
            description:
                '<h2>Opening</h2><p>Description</p><h2>Deep Dive</h2><p>More content</p>',
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('podcast_episode_detail_chat_button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('podcast_episode_detail_chat_drawer')),
        findsOneWidget,
      );
    });

    testWidgets(
      'wide header compresses artwork and keeps metadata chips inline',
      (tester) async {
        addTearDown(() async => tester.binding.setSurfaceSize(null));
        await tester.binding.setSurfaceSize(const Size(1280, 900));

        await tester.pumpWidget(
          createEpisodeDetailWidget(
            episode: createTestEpisode(
              description:
                  '<h2>Opening</h2><p>Description</p><h2>Deep Dive</h2><p>More content</p>',
            ),
          ),
        );
        await tester.pumpAndSettle();

        final sourceButton = find.byKey(
          const Key('podcast_episode_detail_source_button'),
        );

        expect(
          find.byKey(const Key('podcast_episode_detail_podcast_title_chip')),
          findsOneWidget,
        );
        expect(find.textContaining('Test Podcast'), findsOneWidget);
        expect(find.textContaining('2026-03-11'), findsOneWidget);
        expect(find.textContaining('03:00'), findsOneWidget);
        expect(sourceButton, findsOneWidget);
        expect(
          tester.widget<Material>(sourceButton).color,
          isNot(Colors.transparent),
        );
        expect(tester.getSize(sourceButton).height, lessThanOrEqualTo(32));
        expect(
          tester
              .getSize(
                find.byKey(
                  const Key('podcast_episode_detail_wide_hero_artwork'),
                ),
              )
              .width,
          lessThanOrEqualTo(76),
        );
        expect(
          tester
              .getSize(
                find.byKey(
                  const Key('podcast_episode_detail_wide_hero_content'),
                ),
              )
              .height,
          lessThanOrEqualTo(76),
        );
      },
    );
  });
}
