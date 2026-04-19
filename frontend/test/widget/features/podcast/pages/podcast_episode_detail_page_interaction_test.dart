import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive_segmented_control.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/audio_player_state_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/pages/podcast_episode_detail_page.dart';
import '../../../../helpers/podcast_episode_detail_helper.dart';

void main() {
  // =========================================================================
  // From podcast_episode_detail_page_player_behavior_test.dart
  // =========================================================================
  group('PodcastEpisodeDetailPage player behavior', () {
    testWidgets('keeps dock visible while reading on mobile', (tester) async {
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(createEpisodeDetailWidgetWithPlayer());
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('podcast_bottom_player_mini')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('podcast_episode_detail_owned_player')),
        findsNothing,
      );

      final pageContext = tester.element(find.byType(PageView));
      ScrollUpdateNotification(
        metrics: FixedScrollMetrics(
          minScrollExtent: 0,
          maxScrollExtent: 600,
          pixels: 160,
          viewportDimension: 500,
          axisDirection: AxisDirection.down,
          devicePixelRatio: 1,
        ),
        context: pageContext,
        scrollDelta: 12,
      ).dispatch(pageContext);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('podcast_bottom_player_mini')),
        findsOneWidget,
      );
    });

    testWidgets(
      'desktop route keeps mini player and opens unified sheet on tap',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final uiNotifier = TestPodcastPlayerUiNotifier();

        await tester.pumpWidget(
          createEpisodeDetailWidgetWithPlayer(uiNotifier: uiNotifier),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('podcast_bottom_player_mini')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('podcast_bottom_player_expanded')),
          findsNothing,
        );

        uiNotifier.expand();
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('podcast_player_mobile_sheet')),
          findsOneWidget,
        );
        expect(uiNotifier.state.isExpanded, isTrue);
      },
    );

    testWidgets('desktop header shows resume label for saved progress', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final detail = createTestEpisode(playbackPosition: 245);
      await tester.pumpWidget(
        createEpisodeDetailWidgetWithPlayer(
          episode: detail,
          audioState: const AudioPlayerState(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Resume'), findsWidgets);
    });

    testWidgets('desktop header shows playing label for active episode', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final detail = createTestEpisode();
      await tester.pumpWidget(
        createEpisodeDetailWidgetWithPlayer(
          episode: detail,
          audioState: AudioPlayerState(
            currentEpisode: detail,
            duration: 180000,
            position: 60000,
            isPlaying: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Playing'), findsWidgets);
    });
  });

  // =========================================================================
  // From podcast_episode_detail_page_share_test.dart
  // =========================================================================
  group('PodcastEpisodeDetailPage share behavior', () {
    testWidgets('summary tab shows share-all when summary exists', (
      tester,
    ) async {
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(
        createEpisodeDetailWidget(
          episode: createTestEpisode(description: 'Description'),
          hasSummary: true,
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(PodcastEpisodeDetailPage));
      final l10n = AppLocalizations.of(context)!;

      // Tab switching is now handled by AdaptiveSegmentedControl<int>,
      // which renders a Material SegmentedButton on non-iOS platforms.
      // Tap the "Summary" segment label to switch to tab index 2.
      final summaryTabFinder = find.text(l10n.podcast_tab_summary);
      await tester.ensureVisible(summaryTabFinder);
      await tester.tap(summaryTabFinder);
      await tester.pumpAndSettle();

      expect(find.text(l10n.podcast_share_all_content), findsOneWidget);
    });

    testWidgets('summary tab hides generated content when summary is empty', (
      tester,
    ) async {
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(
        createEpisodeDetailWidget(
          episode: createTestEpisode(description: 'Description'),
          hasSummary: false,
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(PodcastEpisodeDetailPage));
      final l10n = AppLocalizations.of(context)!;

      // Tap the "Summary" segment label to switch to tab index 2.
      final summaryTabFinder = find.text(l10n.podcast_tab_summary);
      await tester.ensureVisible(summaryTabFinder);
      await tester.tap(summaryTabFinder);
      await tester.pumpAndSettle();

      expect(find.text('Generated summary'), findsNothing);
    });
  });

  // =========================================================================
  // From podcast_episode_detail_page_tab_indicator_test.dart
  // =========================================================================
  group('PodcastEpisodeDetailPage mobile tab selection', () {
    testWidgets('AdaptiveSegmentedControl renders with shownotes selected', (
      tester,
    ) async {
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(
        createEpisodeDetailWidget(
          episode: createTestEpisode(description: '<p>Description</p>'),
        ),
      );
      await tester.pumpAndSettle();

      // AdaptiveSegmentedControl<int> is present
      expect(
        find.byType(AdaptiveSegmentedControl<int>),
        findsOneWidget,
      );

      // On non-iOS (test environment), a SegmentedButton is rendered.
      // The "Shownotes" tab (index 0) is selected by default.
      final context = tester.element(find.byType(PodcastEpisodeDetailPage));
      final l10n = AppLocalizations.of(context)!;

      // Verify all three tab labels are visible
      expect(find.text(l10n.podcast_tab_shownotes), findsWidgets);
      expect(find.text(l10n.podcast_tab_transcript), findsWidgets);
      expect(find.text(l10n.podcast_tab_summary), findsWidgets);
    });

    testWidgets('tap transcript tab updates selected segment', (
      tester,
    ) async {
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(
        createEpisodeDetailWidget(
          episode: createTestEpisode(description: '<p>Description</p>'),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(PodcastEpisodeDetailPage));
      final l10n = AppLocalizations.of(context)!;

      // Tap the "Transcript" segment label to switch to tab index 1
      final transcriptTabFinder = find.text(l10n.podcast_tab_transcript);
      await tester.ensureVisible(transcriptTabFinder);
      await tester.tap(transcriptTabFinder);
      await tester.pumpAndSettle();

      // Verify the page switched by checking the transcript content surface
      // appears (mobile layout uses PageView with surface keys)
      expect(
        find.byKey(
          const Key('podcast_episode_detail_mobile_content_surface_1'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tap summary tab updates selected segment', (tester) async {
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(
        createEpisodeDetailWidget(
          episode: createTestEpisode(description: '<p>Description</p>'),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(PodcastEpisodeDetailPage));
      final l10n = AppLocalizations.of(context)!;

      // Tap the "Summary" segment label to switch to tab index 2
      final summaryTabFinder = find.text(l10n.podcast_tab_summary);
      await tester.ensureVisible(summaryTabFinder);
      await tester.tap(summaryTabFinder);
      await tester.pumpAndSettle();

      // Verify the page switched by checking the summary content surface
      expect(
        find.byKey(
          const Key('podcast_episode_detail_mobile_content_surface_2'),
        ),
        findsOneWidget,
      );
    });
  });
}
