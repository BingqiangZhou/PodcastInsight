import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive_segmented_control.dart';
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

      // The tab selector is now an AdaptiveSegmentedControl<int>
      expect(
        find.byType(AdaptiveSegmentedControl<int>),
        findsOneWidget,
      );

      // Verify tab labels are present in the SegmentedButton
      expect(find.text(l10n.podcast_tab_shownotes), findsWidgets);
      expect(find.text(l10n.podcast_tab_transcript), findsOneWidget);
      expect(find.text(l10n.podcast_tab_summary), findsOneWidget);

      // Chat is no longer a tab; it's in the AppBar as an IconButton
      expect(find.text(l10n.podcast_tab_chat), findsNothing);
      expect(find.byIcon(Icons.auto_awesome_outlined), findsOneWidget);

      // Summary section is not visible initially (tab 0 = shownotes)
      expect(
        find.byKey(const Key('podcast_episode_detail_summary_section')),
        findsNothing,
      );

      // Mobile hero artwork is 44px wide
      expect(
        tester
            .getSize(
              find.byKey(
                const Key('podcast_episode_detail_mobile_hero_artwork'),
              ),
            )
            .width,
        lessThanOrEqualTo(44),
      );
    });

    testWidgets(
      'keeps shownotes transcript and summary visible at 360px',
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

        // All three tab labels should be visible
        expect(shownotesFinder, findsWidgets);
        expect(transcriptFinder, findsOneWidget);
        expect(summaryFinder, findsOneWidget);

        // Ensure tab labels don't overflow viewport
        final viewportWidth = tester.view.physicalSize.width;
        expect(
          tester.getRect(transcriptFinder).right,
          lessThanOrEqualTo(viewportWidth),
        );
        expect(
          tester.getRect(summaryFinder).right,
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

      final context = tester.element(find.byType(PodcastEpisodeDetailPage));
      final l10n = AppLocalizations.of(context)!;

      // Tap the transcript tab using its text label in the SegmentedButton
      final transcriptTab = find.text(l10n.podcast_tab_transcript);
      await tester.tap(transcriptTab);
      await tester.pumpAndSettle();

      // Default view is now highlights - switch to full transcript view
      final fullTextButton = find.textContaining('Full Text');
      if (fullTextButton.evaluate().isNotEmpty) {
        await tester.tap(fullTextButton);
        await tester.pumpAndSettle();
      }

      expect(find.textContaining('Transcript content'), findsOneWidget);

      // Tap the summary tab using its text label
      final summaryTab = find.text(l10n.podcast_tab_summary);
      await tester.ensureVisible(summaryTab);
      await tester.tap(summaryTab);
      await tester.pumpAndSettle();

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

      // After scrolling, the header should be collapsed (not visible).
      // The header uses ValueKey('podcast_episode_detail_mobile_hero_false')
      // when collapsed, but is rendered via AnimatedSwitcher which may keep
      // the expanded key around. Instead, verify the expanded header is gone.
      expect(
        find.byKey(const ValueKey('podcast_episode_detail_mobile_hero_true')),
        findsNothing,
      );

      // The tab selector should still be present
      expect(
        find.byType(AdaptiveSegmentedControl<int>),
        findsOneWidget,
      );
    });

    testWidgets('uses inline action buttons on mobile header', (
      tester,
    ) async {
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(
        createEpisodeDetailWidget(episode: createTestEpisode()),
      );
      await tester.pumpAndSettle();

      // On mobile, the header uses inline icon buttons (queue, download, share)
      // and a source link icon button instead of a separate actions area.
      // The play button is accessed by tapping the artwork, not a separate button.
      expect(find.byIcon(Icons.playlist_add_rounded), findsOneWidget);
      expect(find.byIcon(Icons.download_outlined), findsOneWidget);
      expect(find.byIcon(Icons.adaptive.share), findsOneWidget);

      // Source link on mobile uses an icon-only button with tooltip
      final sourceTooltip = find.byTooltip('Source');
      expect(sourceTooltip, findsOneWidget);
      expect(tester.getSize(sourceTooltip).height, lessThanOrEqualTo(40));

      // Mobile hero metadata is present
      expect(
        find.byKey(
          const Key('podcast_episode_detail_mobile_hero_metadata'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders compact header on ultra narrow mobile', (
      tester,
    ) async {
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(350, 844));

      await tester.pumpWidget(
        createEpisodeDetailWidget(episode: createTestEpisode()),
      );
      await tester.pumpAndSettle();

      // On ultra-narrow mobile, header should still render with action buttons
      expect(find.byIcon(Icons.playlist_add_rounded), findsOneWidget);
      expect(find.byIcon(Icons.download_outlined), findsOneWidget);

      // Source link icon button is present
      final sourceTooltip = find.byTooltip('Source');
      expect(sourceTooltip, findsOneWidget);
      expect(tester.getSize(sourceTooltip).width, lessThanOrEqualTo(40));
      expect(tester.getSize(sourceTooltip).height, lessThanOrEqualTo(40));

      // Artwork is present and sized for mobile
      final artwork = find.byKey(
        const Key('podcast_episode_detail_mobile_hero_artwork'),
      );
      expect(artwork, findsOneWidget);
      expect(tester.getSize(artwork).width, lessThanOrEqualTo(44));
      expect(tester.getSize(artwork).height, lessThanOrEqualTo(44));
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
      // The wide layout no longer uses a side rail
      expect(
        find.byKey(const Key('podcast_episode_detail_side_rail')),
        findsNothing,
      );
      // Summary section is not visible initially (tab 0 = shownotes)
      expect(
        find.byKey(const Key('podcast_episode_detail_summary_section')),
        findsNothing,
      );
    });

    testWidgets('opens chat drawer from AppBar action', (tester) async {
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

      // Chat is now an IconButton in the AppBar with auto_awesome_outlined icon
      await tester.tap(find.byIcon(Icons.auto_awesome_outlined));
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
