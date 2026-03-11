import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/providers/route_provider.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/audio_player_state_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_conversation_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_playback_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_queue_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_transcription_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/pages/podcast_episode_detail_page.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/conversation_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/summary_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/transcription_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/global_podcast_player_host.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/podcast_bottom_player_widget.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/shownotes_display_widget.dart';

void main() {
  group('PodcastEpisodeDetailPage player behavior', () {
    testWidgets('shows bottom player and auto-collapses on upward scroll', (
      tester,
    ) async {
      final notifier = TestAudioPlayerNotifier(
        AudioPlayerState(
          currentEpisode: _episode(),
          duration: 180000,
          isExpanded: true,
          isPlaying: true,
        ),
      );

      await tester.pumpWidget(_createWidget(notifier));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('podcast_bottom_player_expanded')),
        findsOneWidget,
      );

      final context = tester.element(find.byType(PageView).first);
      final metrics = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 400,
        pixels: 20,
        viewportDimension: 400,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 1.0,
      );
      ScrollUpdateNotification(
        metrics: metrics,
        context: context,
        scrollDelta: 12.0,
      ).dispatch(context);

      await tester.pumpAndSettle();

      expect(notifier.state.isExpanded, isFalse);
      expect(
        find.byKey(const Key('podcast_bottom_player_expanded')),
        findsNothing,
      );
    });

    testWidgets('does not auto-expand on downward scroll', (tester) async {
      final notifier = TestAudioPlayerNotifier(
        AudioPlayerState(
          currentEpisode: _episode(),
          duration: 180000,
          isExpanded: false,
          isPlaying: true,
        ),
      );

      await tester.pumpWidget(_createWidget(notifier));
      await tester.pumpAndSettle();
      notifier.setExpanded(false);
      await tester.pump();

      final context = tester.element(find.byType(PageView).first);
      final metrics = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 400,
        pixels: 100,
        viewportDimension: 400,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 1.0,
      );
      ScrollUpdateNotification(
        metrics: metrics,
        context: context,
        scrollDelta: -12.0,
      ).dispatch(context);

      await tester.pumpAndSettle();

      expect(notifier.state.isExpanded, isFalse);
      expect(
        find.byKey(const Key('podcast_bottom_player_expanded')),
        findsNothing,
      );
    });

    testWidgets(
      'shows collapsed actions at left-bottom on wide screen after header collapse',
      (tester) async {
        addTearDown(() async {
          await tester.binding.setSurfaceSize(null);
        });
        await tester.binding.setSurfaceSize(const Size(1200, 900));

        final notifier = TestAudioPlayerNotifier(
          AudioPlayerState(
            currentEpisode: _episode(),
            duration: 180000,
            isExpanded: true,
            isPlaying: true,
          ),
        );

        await tester.pumpWidget(_createWidget(notifier));
        await tester.pumpAndSettle();

        final collapsedActions = find.byKey(
          const Key('podcast_episode_detail_collapsed_actions'),
        );
        expect(collapsedActions, findsNothing);

        final context = tester.element(find.byType(ShownotesDisplayWidget));
        final metrics = FixedScrollMetrics(
          minScrollExtent: 0,
          maxScrollExtent: 1200,
          pixels: 60,
          viewportDimension: 800,
          axisDirection: AxisDirection.down,
          devicePixelRatio: 1.0,
        );
        ScrollUpdateNotification(
          metrics: metrics,
          context: context,
          scrollDelta: 12.0,
        ).dispatch(context);

        await tester.pumpAndSettle();

        expect(collapsedActions, findsOneWidget);

        final topLeft = tester.getTopLeft(collapsedActions);
        final bottomLeft = tester.getBottomLeft(collapsedActions);
        expect(topLeft.dx, lessThan(200));
        expect(bottomLeft.dy, greaterThan(700));

        expect(
          find.descendant(
            of: collapsedActions,
            matching: find.byKey(
              const Key('podcast_episode_detail_play_button'),
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: collapsedActions,
            matching: find.byIcon(Icons.arrow_back),
          ),
          findsOneWidget,
        );

        final backIconPosition = tester.getTopLeft(
          find.descendant(
            of: collapsedActions,
            matching: find.byIcon(Icons.arrow_back),
          ),
        );
        final playButtonPosition = tester.getTopLeft(
          find.descendant(
            of: collapsedActions,
            matching: find.byKey(
              const Key('podcast_episode_detail_play_button'),
            ),
          ),
        );
        expect(backIconPosition.dx, lessThan(playButtonPosition.dx));
      },
    );

    testWidgets('does not show collapsed actions on narrow layout', (
      tester,
    ) async {
      final notifier = TestAudioPlayerNotifier(
        AudioPlayerState(
          currentEpisode: _episode(),
          duration: 180000,
          isExpanded: true,
          isPlaying: true,
        ),
      );

      await tester.pumpWidget(_createWidget(notifier));
      await tester.pumpAndSettle();

      final collapsedActions = find.byKey(
        const Key('podcast_episode_detail_collapsed_actions'),
      );
      expect(collapsedActions, findsNothing);

      final context = tester.element(find.byType(PageView).first);
      final metrics = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 1200,
        pixels: 100,
        viewportDimension: 600,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 1.0,
      );
      ScrollUpdateNotification(
        metrics: metrics,
        context: context,
        scrollDelta: 12.0,
      ).dispatch(context);

      await tester.pumpAndSettle();
      expect(collapsedActions, findsNothing);
    });

    testWidgets(
      'hides bottom player on mobile when switching to chat tab without changing playback state',
      (tester) async {
        addTearDown(() async {
          await tester.binding.setSurfaceSize(null);
        });
        await tester.binding.setSurfaceSize(const Size(390, 844));

        final notifier = TestAudioPlayerNotifier(
          AudioPlayerState(
            currentEpisode: _episode(),
            duration: 180000,
            isExpanded: true,
            isPlaying: true,
          ),
        );

        await tester.pumpWidget(_createWidget(notifier));
        await tester.pumpAndSettle();

        expect(find.byType(PodcastBottomPlayerWidget), findsOneWidget);
        expect(
          find.byKey(const Key('podcast_bottom_player_expanded')),
          findsOneWidget,
        );

        await _setMobilePage(tester, 3);
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(PodcastBottomPlayerWidget), findsNothing);
        expect(
          find.byKey(const Key('podcast_bottom_player_expanded')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('podcast_bottom_player_mini')),
          findsNothing,
        );
        expect(notifier.state.isPlaying, isTrue);
        expect(notifier.playEpisodeCalls, 0);
        expect(notifier.resumeCalls, 0);
      },
    );

    testWidgets('restores bottom player on mobile when leaving chat tab', (
      tester,
    ) async {
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });
      await tester.binding.setSurfaceSize(const Size(390, 844));

      final notifier = TestAudioPlayerNotifier(
        AudioPlayerState(
          currentEpisode: _episode(),
          duration: 180000,
          isExpanded: true,
          isPlaying: true,
        ),
      );

      await tester.pumpWidget(_createWidget(notifier));
      await tester.pumpAndSettle();

      await _setMobilePage(tester, 3);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(PodcastBottomPlayerWidget), findsNothing);

      await _setMobilePage(tester, 0);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(PodcastBottomPlayerWidget), findsOneWidget);
      expect(
        find.byKey(const Key('podcast_bottom_player_expanded')),
        findsOneWidget,
      );
    });

    testWidgets(
      'keeps bottom player visible on mobile shownotes tab when header is expanded',
      (tester) async {
        addTearDown(() async {
          await tester.binding.setSurfaceSize(null);
        });
        await tester.binding.setSurfaceSize(const Size(390, 844));

        final notifier = TestAudioPlayerNotifier(
          AudioPlayerState(
            currentEpisode: _episode(),
            duration: 180000,
            isExpanded: false,
            isPlaying: true,
          ),
        );

        await tester.pumpWidget(_createWidget(notifier));
        await tester.pumpAndSettle();
        notifier.setExpanded(false);
        await tester.pumpAndSettle();

        expect(find.byType(ShownotesDisplayWidget), findsOneWidget);
        expect(find.byType(PodcastBottomPlayerWidget), findsOneWidget);
        expect(
          find.byKey(const Key('podcast_bottom_player_mini')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'hides bottom player on mobile shownotes tab after header collapse',
      (tester) async {
        addTearDown(() async {
          await tester.binding.setSurfaceSize(null);
        });
        await tester.binding.setSurfaceSize(const Size(390, 844));

        final notifier = TestAudioPlayerNotifier(
          AudioPlayerState(
            currentEpisode: _episode(),
            duration: 180000,
            isExpanded: false,
            isPlaying: true,
          ),
        );

        await tester.pumpWidget(_createWidget(notifier));
        await tester.pumpAndSettle();
        notifier.setExpanded(false);
        await tester.pumpAndSettle();

        _dispatchVerticalScrollUpdate(
          tester,
          context: tester.element(find.byType(PageView).first),
          pixels: 120,
        );
        await tester.pumpAndSettle();

        expect(find.byType(PodcastBottomPlayerWidget), findsNothing);
      },
    );

    testWidgets(
      'restores bottom player after leaving hidden shownotes reading state',
      (tester) async {
        addTearDown(() async {
          await tester.binding.setSurfaceSize(null);
        });
        await tester.binding.setSurfaceSize(const Size(390, 844));

        final notifier = TestAudioPlayerNotifier(
          AudioPlayerState(
            currentEpisode: _episode(),
            duration: 180000,
            isExpanded: false,
            isPlaying: true,
          ),
        );

        await tester.pumpWidget(_createWidget(notifier));
        await tester.pumpAndSettle();
        notifier.setExpanded(false);
        await tester.pumpAndSettle();

        _dispatchVerticalScrollUpdate(
          tester,
          context: tester.element(find.byType(PageView).first),
          pixels: 120,
        );
        await tester.pumpAndSettle();
        expect(find.byType(PodcastBottomPlayerWidget), findsNothing);

        await _setMobilePage(tester, 1);
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(PodcastBottomPlayerWidget), findsOneWidget);
        expect(
          find.byKey(const Key('podcast_bottom_player_mini')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'keeps bottom player visible on mobile transcript tab when header is expanded',
      (tester) async {
        addTearDown(() async {
          await tester.binding.setSurfaceSize(null);
        });
        await tester.binding.setSurfaceSize(const Size(390, 844));

        final notifier = TestAudioPlayerNotifier(
          AudioPlayerState(
            currentEpisode: _episode(),
            duration: 180000,
            isExpanded: false,
            isPlaying: true,
          ),
        );

        await tester.pumpWidget(_createWidget(notifier));
        await tester.pumpAndSettle();
        notifier.setExpanded(false);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('podcast_bottom_player_mini')),
          findsOneWidget,
        );

        await _setMobilePage(tester, 1);
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(PodcastBottomPlayerWidget), findsOneWidget);
        expect(
          find.byKey(const Key('podcast_bottom_player_mini')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'keeps bottom player visible on mobile summary tab when header is expanded',
      (tester) async {
        addTearDown(() async {
          await tester.binding.setSurfaceSize(null);
        });
        await tester.binding.setSurfaceSize(const Size(390, 844));

        final notifier = TestAudioPlayerNotifier(
          AudioPlayerState(
            currentEpisode: _episode(),
            duration: 180000,
            isExpanded: false,
            isPlaying: true,
          ),
        );

        await tester.pumpWidget(_createWidget(notifier));
        await tester.pumpAndSettle();
        notifier.setExpanded(false);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('podcast_bottom_player_mini')),
          findsOneWidget,
        );

        await _setMobilePage(tester, 2);
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(PodcastBottomPlayerWidget), findsOneWidget);
        expect(
          find.byKey(const Key('podcast_bottom_player_mini')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'keeps bottom player visible on mobile transcript and summary tabs when expanded',
      (tester) async {
        addTearDown(() async {
          await tester.binding.setSurfaceSize(null);
        });
        await tester.binding.setSurfaceSize(const Size(390, 844));

        final notifier = TestAudioPlayerNotifier(
          AudioPlayerState(
            currentEpisode: _episode(),
            duration: 180000,
            isExpanded: true,
            isPlaying: true,
          ),
        );

        await tester.pumpWidget(_createWidget(notifier));
        await tester.pumpAndSettle();

        await _setMobilePage(tester, 1);
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(PodcastBottomPlayerWidget), findsOneWidget);
        expect(
          find.byKey(const Key('podcast_bottom_player_expanded')),
          findsOneWidget,
        );

        await _setMobilePage(tester, 2);
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(PodcastBottomPlayerWidget), findsOneWidget);
        expect(
          find.byKey(const Key('podcast_bottom_player_expanded')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'hides bottom player on wide layout when collapsed in shownotes tab after header collapse',
      (tester) async {
        addTearDown(() async {
          await tester.binding.setSurfaceSize(null);
        });
        await tester.binding.setSurfaceSize(const Size(1200, 900));

        final notifier = TestAudioPlayerNotifier(
          AudioPlayerState(
            currentEpisode: _episode(),
            duration: 180000,
            isExpanded: false,
            isPlaying: true,
          ),
        );

        await tester.pumpWidget(_createWidget(notifier));
        await tester.pumpAndSettle();
        notifier.setExpanded(false);
        await tester.pumpAndSettle();

        _dispatchVerticalScrollUpdate(
          tester,
          context: tester.element(find.byType(ShownotesDisplayWidget)),
          pixels: 120,
        );
        await tester.pumpAndSettle();

        expect(find.byType(PageView), findsNothing);
        expect(find.byType(PodcastBottomPlayerWidget), findsNothing);
      },
    );

    testWidgets(
      'hides bottom player on wide layout when collapsed in transcript and summary tabs after header collapse',
      (tester) async {
        addTearDown(() async {
          await tester.binding.setSurfaceSize(null);
        });
        await tester.binding.setSurfaceSize(const Size(390, 844));

        final notifier = TestAudioPlayerNotifier(
          AudioPlayerState(
            currentEpisode: _episode(),
            duration: 180000,
            isExpanded: false,
            isPlaying: true,
          ),
        );

        await tester.pumpWidget(_createWidget(notifier));
        await tester.pumpAndSettle();
        notifier.setExpanded(false);
        await tester.pumpAndSettle();

        await _setMobilePage(tester, 1);
        await tester.pump(const Duration(milliseconds: 300));
        final transcriptPageContext = tester.element(
          find.byType(PageView).first,
        );
        final transcriptMetrics = FixedScrollMetrics(
          minScrollExtent: 0,
          maxScrollExtent: 400,
          pixels: 120,
          viewportDimension: 500,
          axisDirection: AxisDirection.down,
          devicePixelRatio: 1.0,
        );
        ScrollUpdateNotification(
          metrics: transcriptMetrics,
          context: transcriptPageContext,
          scrollDelta: 12.0,
        ).dispatch(transcriptPageContext);
        await tester.pumpAndSettle();
        await tester.binding.setSurfaceSize(const Size(1200, 900));
        await tester.pumpAndSettle();

        expect(find.byType(PageView), findsNothing);
        expect(find.byType(PodcastBottomPlayerWidget), findsNothing);

        await tester.binding.setSurfaceSize(const Size(390, 844));
        await tester.pumpAndSettle();
        await _setMobilePage(tester, 2);
        await tester.pump(const Duration(milliseconds: 300));
        final summaryPageContext = tester.element(find.byType(PageView).first);
        final summaryMetrics = FixedScrollMetrics(
          minScrollExtent: 0,
          maxScrollExtent: 400,
          pixels: 120,
          viewportDimension: 500,
          axisDirection: AxisDirection.down,
          devicePixelRatio: 1.0,
        );
        ScrollUpdateNotification(
          metrics: summaryMetrics,
          context: summaryPageContext,
          scrollDelta: 12.0,
        ).dispatch(summaryPageContext);
        await tester.pumpAndSettle();
        await tester.binding.setSurfaceSize(const Size(1200, 900));
        await tester.pumpAndSettle();

        expect(find.byType(PageView), findsNothing);
        expect(find.byType(PodcastBottomPlayerWidget), findsNothing);
      },
    );

    testWidgets('mobile renders player from global host without local spacer', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final notifier = TestAudioPlayerNotifier(
        AudioPlayerState(
          currentEpisode: _episode(),
          duration: 180000,
          isExpanded: true,
          isPlaying: true,
        ),
      );

      await tester.pumpWidget(_createWidget(notifier));
      await tester.pumpAndSettle();

      final playerFinder = find.byType(PodcastBottomPlayerWidget);
      expect(playerFinder, findsOneWidget);
      expect(
        find.byKey(const Key('podcast_episode_detail_mobile_bottom_spacer')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('global_podcast_player_host')),
        findsOneWidget,
      );
    });

    testWidgets('scroll-to-top button is above mini player when visible', (
      tester,
    ) async {
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });
      await tester.binding.setSurfaceSize(const Size(390, 844));

      final notifier = TestAudioPlayerNotifier(
        AudioPlayerState(
          currentEpisode: _episode(),
          duration: 180000,
          isExpanded: false,
          isPlaying: true,
        ),
      );

      await tester.pumpWidget(_createWidget(notifier));
      await tester.pumpAndSettle();

      final pageContext = tester.element(find.byType(PageView).first);
      final metrics = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 400,
        pixels: 20,
        viewportDimension: 500,
        axisDirection: AxisDirection.down,
        devicePixelRatio: 1.0,
      );
      ScrollUpdateNotification(
        metrics: metrics,
        context: pageContext,
        scrollDelta: 12.0,
      ).dispatch(pageContext);
      await tester.pumpAndSettle();

      final scrollToTopFinder = find.byKey(
        const Key('podcast_episode_detail_scroll_to_top_button'),
      );
      final miniPlayerFinder = find.byKey(
        const Key('podcast_bottom_player_mini'),
      );
      expect(scrollToTopFinder, findsOneWidget);
      expect(miniPlayerFinder, findsOneWidget);

      final scrollButtonBottom = tester.getBottomLeft(scrollToTopFinder).dy;
      final miniPlayerTop = tester.getTopLeft(miniPlayerFinder).dy;
      expect(scrollButtonBottom, lessThan(miniPlayerTop));
    });

    testWidgets('mobile collapsed player no longer uses a local spacer', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final notifier = TestAudioPlayerNotifier(
        AudioPlayerState(
          currentEpisode: _episode(),
          duration: 180000,
          isExpanded: false,
          isPlaying: true,
        ),
      );

      await tester.pumpWidget(_createWidget(notifier));
      await tester.pumpAndSettle();
      notifier.setExpanded(false);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('podcast_episode_detail_mobile_bottom_spacer')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('podcast_bottom_player_mini')),
        findsOneWidget,
      );
    });

    testWidgets('hides bottom player on wide screen after switching to chat', (
      tester,
    ) async {
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      final notifier = TestAudioPlayerNotifier(
        AudioPlayerState(
          currentEpisode: _episode(),
          duration: 180000,
          isExpanded: true,
          isPlaying: true,
        ),
      );

      await tester.pumpWidget(_createWidget(notifier));
      await tester.pumpAndSettle();

      expect(find.byType(PageView), findsNothing);
      expect(find.byType(PodcastBottomPlayerWidget), findsOneWidget);

      notifier.setExpanded(false);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(GestureDetector, 'Chat').last);
      await tester.pumpAndSettle();

      expect(find.byType(PodcastBottomPlayerWidget), findsNothing);
    });

    testWidgets('desktop player stays globally anchored near viewport bottom', (
      tester,
    ) async {
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      final notifier = TestAudioPlayerNotifier(
        AudioPlayerState(
          currentEpisode: _episode(),
          duration: 180000,
          isExpanded: true,
          isPlaying: true,
        ),
      );

      await tester.pumpWidget(_createWidget(notifier));
      await tester.pumpAndSettle();

      final hostFinder = find.byKey(const Key('global_podcast_player'));
      expect(hostFinder, findsOneWidget);

      final playerRect = tester.getRect(hostFinder);
      expect(playerRect.left, closeTo(0, 0.5));
      expect(playerRect.right, closeTo(1200, 0.5));
      expect(playerRect.bottom, closeTo(888, 0.5));
    });

    testWidgets(
      'keeps bottom player visible on wide transcript and summary tabs when expanded',
      (tester) async {
        addTearDown(() async {
          await tester.binding.setSurfaceSize(null);
        });
        await tester.binding.setSurfaceSize(const Size(1200, 900));

        final notifier = TestAudioPlayerNotifier(
          AudioPlayerState(
            currentEpisode: _episode(),
            duration: 180000,
            isExpanded: true,
            isPlaying: true,
          ),
        );

        await tester.pumpWidget(_createWidget(notifier));
        await tester.pumpAndSettle();

        notifier.setExpanded(false);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Transcript').first);
        await tester.pump(const Duration(milliseconds: 400));
        notifier.setExpanded(true);
        await tester.pumpAndSettle();
        expect(find.byType(PodcastBottomPlayerWidget), findsOneWidget);

        notifier.setExpanded(false);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Summary').first);
        await tester.pump(const Duration(milliseconds: 400));
        notifier.setExpanded(true);
        await tester.pumpAndSettle();
        expect(find.byType(PodcastBottomPlayerWidget), findsOneWidget);
      },
    );

    testWidgets('add-to-queue shows loading and ignores repeated taps', (
      tester,
    ) async {
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });
      await tester.binding.setSurfaceSize(const Size(1200, 900));

      final notifier = TestAudioPlayerNotifier(
        AudioPlayerState(
          currentEpisode: _episode(),
          duration: 180000,
          isExpanded: true,
          isPlaying: true,
        ),
      );
      final queueController = _ControlledQueueController();

      await tester.pumpWidget(
        _createWidget(notifier, queueController: queueController),
      );
      await tester.pumpAndSettle();

      notifier.setExpanded(false);
      await tester.pumpAndSettle();

      final addButtonFinder = find.byKey(
        const Key('podcast_episode_detail_add_to_queue'),
      );
      expect(addButtonFinder, findsOneWidget);
      expect(
        find.descendant(
          of: addButtonFinder,
          matching: find.byIcon(Icons.playlist_add),
        ),
        findsOneWidget,
      );

      await tester.tap(addButtonFinder);
      await tester.pump();
      expect(queueController.addToQueueCallCount, 1);
      expect(
        find.descendant(
          of: addButtonFinder,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      await tester.tap(addButtonFinder);
      await tester.pump();
      expect(queueController.addToQueueCallCount, 1);

      queueController.completeAddToQueue();
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: addButtonFinder,
          matching: find.byIcon(Icons.playlist_add),
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('same episode paused tap should call resume only', (
      tester,
    ) async {
      final notifier = TestAudioPlayerNotifier(
        AudioPlayerState(
          currentEpisode: _episode(),
          duration: 180000,
          isPlaying: false,
        ),
      );

      await tester.pumpWidget(_createWidget(notifier));
      await tester.pumpAndSettle();

      final playButton = find.byKey(
        const Key('podcast_episode_detail_play_button'),
      );
      expect(playButton, findsOneWidget);

      await tester.tap(playButton);
      await tester.pump();

      expect(notifier.resumeCalls, 1);
      expect(notifier.playEpisodeCalls, 0);
    });

    testWidgets('same episode playing tap should no-op', (tester) async {
      final notifier = TestAudioPlayerNotifier(
        AudioPlayerState(
          currentEpisode: _episode(),
          duration: 180000,
          isPlaying: true,
        ),
      );

      await tester.pumpWidget(_createWidget(notifier));
      await tester.pumpAndSettle();

      final playButton = find.byKey(
        const Key('podcast_episode_detail_play_button'),
      );
      expect(playButton, findsOneWidget);

      await tester.tap(playButton);
      await tester.pump();

      expect(notifier.resumeCalls, 0);
      expect(notifier.playEpisodeCalls, 0);
    });

    testWidgets('different episode tap should call playEpisode', (
      tester,
    ) async {
      final notifier = TestAudioPlayerNotifier(
        AudioPlayerState(
          currentEpisode: _otherEpisode(),
          duration: 180000,
          isPlaying: false,
        ),
      );

      await tester.pumpWidget(_createWidget(notifier));
      await tester.pumpAndSettle();

      final playButton = find.byKey(
        const Key('podcast_episode_detail_play_button'),
      );
      expect(playButton, findsOneWidget);

      await tester.tap(playButton);
      await tester.pump();

      expect(notifier.playEpisodeCalls, 1);
      expect(notifier.resumeCalls, 0);
    });
  });
}

Widget _createWidget(
  TestAudioPlayerNotifier notifier, {
  PodcastQueueController? queueController,
}) {
  final effectiveQueueController =
      queueController ?? _ControlledQueueController();
  if (queueController == null &&
      effectiveQueueController is _ControlledQueueController) {
    effectiveQueueController.completeAddToQueue();
  }

  return ProviderScope(
    overrides: [
      audioPlayerProvider.overrideWith(() => notifier),
      currentRouteProvider.overrideWith(_TestCurrentRouteNotifier.new),
      podcastQueueControllerProvider.overrideWith(
        () => effectiveQueueController,
      ),
      episodeDetailProvider.overrideWith(
        (ref, episodeId) async => _episodeDetail(),
      ),
      getTranscriptionProvider(
        1,
      ).overrideWith(() => MockTranscriptionNotifier(1)),
      getConversationProvider(
        1,
      ).overrideWith(() => _ConversationWithoutMessagesNotifier()),
      getSessionListProvider(1).overrideWith(() => _EmptySessionListNotifier()),
      getCurrentSessionIdProvider(
        1,
      ).overrideWith(() => _NullSessionIdNotifier()),
      availableModelsProvider.overrideWith((ref) async => <SummaryModelInfo>[]),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => Overlay(
        initialEntries: [
          OverlayEntry(builder: (_) => child ?? const SizedBox.shrink()),
          OverlayEntry(builder: (_) => const GlobalPodcastPlayerHost()),
        ],
      ),
      home: const PodcastEpisodeDetailPage(episodeId: 1),
    ),
  );
}

PodcastEpisodeModel _episode() {
  final now = DateTime.now();
  return PodcastEpisodeModel(
    id: 1,
    subscriptionId: 1,
    title: 'Detail Episode',
    description: 'A long long description to support detail content rendering.',
    audioUrl: 'https://example.com/audio.mp3',
    publishedAt: now,
    createdAt: now,
    audioDuration: 180,
  );
}

PodcastEpisodeModel _otherEpisode() {
  final now = DateTime.now();
  return PodcastEpisodeModel(
    id: 2,
    subscriptionId: 1,
    title: 'Another Episode',
    description: 'Another episode for mismatch scenario.',
    audioUrl: 'https://example.com/audio-2.mp3',
    publishedAt: now,
    createdAt: now,
    audioDuration: 200,
  );
}

PodcastEpisodeDetailResponse _episodeDetail() {
  final now = DateTime.now();
  return PodcastEpisodeDetailResponse(
    id: 1,
    subscriptionId: 1,
    title: 'Detail Episode',
    description: List.filled(80, 'This is shownotes content').join(' '),
    audioUrl: 'https://example.com/audio.mp3',
    audioDuration: 180,
    publishedAt: now,
    aiSummary: 'summary',
    transcriptContent: 'transcript',
    status: 'published',
    createdAt: now,
    updatedAt: now,
    subscription: null,
    relatedEpisodes: const [],
  );
}

class TestAudioPlayerNotifier extends AudioPlayerNotifier {
  TestAudioPlayerNotifier(this._initialState);

  final AudioPlayerState _initialState;
  int playEpisodeCalls = 0;
  int resumeCalls = 0;

  @override
  AudioPlayerState build() {
    return _initialState;
  }

  @override
  void setExpanded(bool expanded) {
    state = state.copyWith(isExpanded: expanded);
  }

  @override
  Future<void> pause() async {
    state = state.copyWith(isPlaying: false);
  }

  @override
  Future<void> resume() async {
    resumeCalls++;
    state = state.copyWith(isPlaying: true);
  }

  @override
  Future<void> playEpisode(
    PodcastEpisodeModel episode, {
    PlaySource source = PlaySource.direct,
    int? queueEpisodeId,
  }) async {
    playEpisodeCalls++;
    state = state.copyWith(
      currentEpisode: episode,
      isPlaying: true,
      isLoading: false,
      error: null,
    );
  }

  @override
  Future<void> playManagedEpisode(PodcastEpisodeModel episode) async {
    await playEpisode(episode);
  }

  @override
  Future<void> seekTo(int position) async {
    state = state.copyWith(position: position);
  }

  @override
  Future<void> setPlaybackRate(
    double rate, {
    bool applyToSubscription = false,
  }) async {
    state = state.copyWith(playbackRate: rate);
  }

  @override
  Future<void> stop() async {
    state = state.copyWith(clearCurrentEpisode: true);
  }
}

class _TestCurrentRouteNotifier extends CurrentRouteNotifier {
  @override
  String build() {
    return '/podcast/episodes/1/1';
  }
}

class MockTranscriptionNotifier extends TranscriptionNotifier {
  MockTranscriptionNotifier(super.episodeId);

  @override
  Future<PodcastTranscriptionResponse?> build() async {
    return null;
  }

  @override
  Future<void> checkOrStartTranscription() async {}

  @override
  Future<void> startTranscription() async {}

  @override
  Future<void> loadTranscription() async {}
}

class _ConversationWithoutMessagesNotifier extends ConversationNotifier {
  _ConversationWithoutMessagesNotifier() : super(1);

  @override
  ConversationState build() {
    return const ConversationState(messages: []);
  }
}

class _EmptySessionListNotifier extends SessionListNotifier {
  _EmptySessionListNotifier() : super(1);

  @override
  Future<List<ConversationSession>> build() async => [];
}

class _NullSessionIdNotifier extends SessionIdNotifier {
  @override
  int? build() => null;
}

class _ControlledQueueController extends PodcastQueueController {
  final Completer<void> _addToQueueCompleter = Completer<void>();
  int addToQueueCallCount = 0;

  @override
  Future<PodcastQueueModel> build() async {
    return PodcastQueueModel.empty();
  }

  @override
  Future<PodcastQueueModel> addToQueue(int episodeId) async {
    addToQueueCallCount += 1;
    await _addToQueueCompleter.future;
    return PodcastQueueModel(
      currentEpisodeId: episodeId,
      revision: addToQueueCallCount,
      items: [
        PodcastQueueItemModel(
          episodeId: episodeId,
          position: 0,
          title: 'Episode $episodeId',
          podcastId: 1,
          audioUrl: 'https://example.com/$episodeId.mp3',
        ),
      ],
    );
  }

  @override
  Future<PodcastQueueModel> activateEpisode(int episodeId) async {
    return addToQueue(episodeId);
  }

  void completeAddToQueue() {
    if (!_addToQueueCompleter.isCompleted) {
      _addToQueueCompleter.complete();
    }
  }
}

Future<void> _setMobilePage(WidgetTester tester, int pageIndex) async {
  final pageViewFinder = find.byType(PageView);
  expect(pageViewFinder, findsOneWidget);
  final pageView = tester.widget<PageView>(pageViewFinder);
  pageView.onPageChanged?.call(pageIndex);
  await tester.pump();
}

void _dispatchVerticalScrollUpdate(
  WidgetTester tester, {
  required Element context,
  required double pixels,
  double maxScrollExtent = 400,
  double viewportDimension = 500,
  double scrollDelta = 12,
}) {
  final metrics = FixedScrollMetrics(
    minScrollExtent: 0,
    maxScrollExtent: maxScrollExtent,
    pixels: pixels,
    viewportDimension: viewportDimension,
    axisDirection: AxisDirection.down,
    devicePixelRatio: 1.0,
  );
  ScrollUpdateNotification(
    metrics: metrics,
    context: context,
    scrollDelta: scrollDelta,
  ).dispatch(context);
}
