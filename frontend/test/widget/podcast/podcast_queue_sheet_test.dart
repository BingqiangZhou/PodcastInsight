import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/audio_player_state_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_queue_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/podcast_queue_sheet.dart';

const _queueSubtitleSeparator = ' • ';

void main() {
  group('PodcastQueueSheet', () {
    testWidgets('opening load shows bare loading content without state card', (
      tester,
    ) async {
      final controller = PendingPodcastQueueController();
      await tester.pumpWidget(_createWidget(controller));
      await tester.pump();

      expect(find.text('Loading queue'), findsOneWidget);
      expect(find.text('Fetching the latest playback order.'), findsOneWidget);
      expect(find.byKey(const Key('queue_loading_content')), findsOneWidget);
      expect(find.byKey(const Key('queue_state_card')), findsNothing);
    });

    testWidgets('empty queue keeps state card styling', (tester) async {
      final controller = TestPodcastQueueController(
        const PodcastQueueModel(currentEpisodeId: null, items: []),
      );
      await tester.pumpWidget(_createWidget(controller));
      await tester.pumpAndSettle();

      expect(find.text('Queue is empty'), findsOneWidget);
      expect(find.byKey(const Key('queue_state_card')), findsOneWidget);
      expect(find.byKey(const Key('queue_loading_content')), findsNothing);
    });

    testWidgets(
      'uses custom left drag handle and does not overlap delete icon',
      (tester) async {
        final controller = TestPodcastQueueController(_queue());
        await tester.pumpWidget(_createWidget(controller));
        await tester.pumpAndSettle();

        final list = tester.widget<ReorderableListView>(
          find.byType(ReorderableListView),
        );
        expect(list.buildDefaultDragHandles, isFalse);

        final dragRect = tester.getRect(
          find.byKey(const Key('queue_item_drag_1')),
        );
        final deleteRect = tester.getRect(
          find.byKey(const Key('queue_item_remove_1')),
        );
        expect(dragRect.overlaps(deleteRect), isFalse);
      },
    );

    testWidgets('shows fallback podcast icon when item has no image', (
      tester,
    ) async {
      final controller = TestPodcastQueueController(_queue(withImages: false));
      await tester.pumpWidget(_createWidget(controller));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('queue_item_cover_fallback_1')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.podcasts), findsWidgets);
    });

    testWidgets('prefers subscription image over episode image for cover', (
      tester,
    ) async {
      final controller = TestPodcastQueueController(_queue(withImages: true));
      await tester.pumpWidget(_createWidget(controller));
      await tester.pumpAndSettle();

      final imageFinder = find.descendant(
        of: find.byKey(const Key('queue_item_cover_1')),
        matching: find.byType(Image),
      );
      expect(imageFinder, findsOneWidget);

      final image = tester.widget<Image>(imageFinder);
      final provider = image.image;
      final innerProvider = provider is ResizeImage
          ? provider.imageProvider
          : provider;
      if (innerProvider is NetworkImage) {
        expect(innerProvider.url, 'https://example.com/subscription-1.jpg');
      } else if (innerProvider is CachedNetworkImageProvider) {
        expect(innerProvider.url, 'https://example.com/subscription-1.jpg');
      } else {
        fail('Unexpected ImageProvider type: ${innerProvider.runtimeType}');
      }
    });

    testWidgets('shows equalizer badge only on current queue item', (
      tester,
    ) async {
      final controller = TestPodcastQueueController(_queue());
      await tester.pumpWidget(_createWidget(controller));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('queue_item_playing_badge_1')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('queue_item_playing_badge_2')), findsNothing);
    });

    testWidgets('shows played and total duration for non-current queue items', (
      tester,
    ) async {
      final controller = TestPodcastQueueController(_queue());
      await tester.pumpWidget(_createWidget(controller));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Podcast B$_queueSubtitleSeparator'
          '02:05 / 40:00',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'current item uses realtime playback position from audio state',
      (tester) async {
        final controller = TestPodcastQueueController(_queue());
        final audioNotifier = TestAudioPlayerNotifier(
          AudioPlayerState(
            currentEpisode: _episode(id: 1),
            position: 65000,
            duration: 3600000,
          ),
        );

        await tester.pumpWidget(
          _createWidget(controller, audioNotifier: audioNotifier),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Podcast A$_queueSubtitleSeparator'
            '01:05 / 1:00:00',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'progress updates only change current item subtitle while others stay stable',
      (tester) async {
        final controller = TestPodcastQueueController(_queue());
        final audioNotifier = TestAudioPlayerNotifier(
          AudioPlayerState(
            currentEpisode: _episode(id: 1),
            position: 10000,
            duration: 3600000,
          ),
        );

        await tester.pumpWidget(
          _createWidget(controller, audioNotifier: audioNotifier),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Podcast A$_queueSubtitleSeparator'
            '00:10 / 1:00:00',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            'Podcast B$_queueSubtitleSeparator'
            '02:05 / 40:00',
          ),
          findsOneWidget,
        );
        audioNotifier.setPlaybackPosition(20000);
        await tester.pump();

        expect(
          find.text(
            'Podcast A$_queueSubtitleSeparator'
            '00:20 / 1:00:00',
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            'Podcast A$_queueSubtitleSeparator'
            '00:10 / 1:00:00',
          ),
          findsNothing,
        );
        expect(
          find.text(
            'Podcast B$_queueSubtitleSeparator'
            '02:05 / 40:00',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('tapping item and delete trigger expected controller methods', (
      tester,
    ) async {
      final controller = TestPodcastQueueController(_queue());
      await tester.pumpWidget(_createWidget(controller));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('queue_item_tile_1')));
      await tester.pumpAndSettle();
      expect(controller.playedEpisodeId, isNull);

      await tester.tap(find.byKey(const Key('queue_item_tile_2')));
      await tester.pumpAndSettle();
      expect(controller.playedEpisodeId, 2);

      await tester.tap(find.byKey(const Key('queue_item_remove_1')));
      await tester.pumpAndSettle();
      expect(controller.removedEpisodeId, 1);
    });

    testWidgets('reorder callback triggers reorderQueue with expected order', (
      tester,
    ) async {
      final controller = TestPodcastQueueController(_queue());
      await tester.pumpWidget(_createWidget(controller));
      await tester.pumpAndSettle();

      final list = tester.widget<ReorderableListView>(
        find.byType(ReorderableListView),
      );
      list.onReorder(0, 2);
      await tester.pumpAndSettle();

      expect(controller.reorderedEpisodeIds, <int>[2, 1, 3]);
    });
  });
}

Widget _createWidget(
  PodcastQueueController controller, {
  TestAudioPlayerNotifier? audioNotifier,
}) {
  return ProviderScope(
    overrides: [
      podcastQueueControllerProvider.overrideWith(() => controller),
      audioPlayerProvider.overrideWith(
        () =>
            audioNotifier ?? TestAudioPlayerNotifier(const AudioPlayerState()),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(
        body: SizedBox(width: 430, height: 760, child: PodcastQueueSheet()),
      ),
    ),
  );
}

PodcastQueueModel _queue({bool withImages = false}) {
  return PodcastQueueModel(
    currentEpisodeId: 1,
    items: [
      PodcastQueueItemModel(
        episodeId: 1,
        position: 0,
        playbackPosition: 10,
        title: 'Episode 1',
        podcastId: 10,
        audioUrl: 'https://example.com/1.mp3',
        duration: 3600,
        subscriptionTitle: 'Podcast A',
        imageUrl: withImages ? 'https://example.com/episode-1.jpg' : null,
        subscriptionImageUrl: withImages
            ? 'https://example.com/subscription-1.jpg'
            : null,
      ),
      const PodcastQueueItemModel(
        episodeId: 2,
        position: 1,
        playbackPosition: 125,
        title: 'Episode 2',
        podcastId: 11,
        audioUrl: 'https://example.com/2.mp3',
        duration: 2400,
        subscriptionTitle: 'Podcast B',
      ),
      const PodcastQueueItemModel(
        episodeId: 3,
        position: 2,
        playbackPosition: 90,
        title: 'Episode 3',
        podcastId: 12,
        audioUrl: 'https://example.com/3.mp3',
        duration: null,
        subscriptionTitle: 'Podcast C',
      ),
    ],
  );
}

class TestAudioPlayerNotifier extends AudioPlayerNotifier {
  TestAudioPlayerNotifier(this._initialState);

  final AudioPlayerState _initialState;

  @override
  AudioPlayerState build() {
    return _initialState;
  }

  void setPlaybackPosition(int positionMs) {
    state = state.copyWith(position: positionMs);
  }
}

class TestPodcastQueueController extends PodcastQueueController {
  TestPodcastQueueController(this.initialQueue);

  final PodcastQueueModel initialQueue;
  int? playedEpisodeId;
  int? removedEpisodeId;
  List<int>? reorderedEpisodeIds;

  @override
  Future<PodcastQueueModel> build() async {
    return initialQueue;
  }

  @override
  Future<PodcastQueueModel> loadQueue({bool forceRefresh = true}) async {
    state = AsyncValue.data(initialQueue);
    return initialQueue;
  }

  @override
  Future<PodcastQueueModel> removeFromQueue(int episodeId) async {
    removedEpisodeId = episodeId;
    return state.value ?? initialQueue;
  }

  @override
  Future<PodcastQueueModel> reorderQueue(List<int> episodeIds) async {
    reorderedEpisodeIds = List<int>.from(episodeIds);
    return state.value ?? initialQueue;
  }

  @override
  Future<PodcastQueueModel> playFromQueue(int episodeId) async {
    playedEpisodeId = episodeId;
    return state.value ?? initialQueue;
  }

  @override
  Future<PodcastQueueModel> activateEpisode(int episodeId) async {
    return state.value ?? initialQueue;
  }
}

class PendingPodcastQueueController extends PodcastQueueController {
  final Completer<PodcastQueueModel> _completer =
      Completer<PodcastQueueModel>();

  @override
  Future<PodcastQueueModel> build() => _completer.future;
}

PodcastEpisodeModel _episode({required int id}) {
  return PodcastEpisodeModel(
    id: id,
    subscriptionId: 10,
    title: 'Episode $id',
    audioUrl: 'https://example.com/$id.mp3',
    audioDuration: 3600,
    publishedAt: DateTime(2026, 2, 14),
    createdAt: DateTime(2026, 2, 14),
  );
}
