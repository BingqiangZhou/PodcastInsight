import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/providers/route_provider.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/audio_player_state_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_conversation_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_playback_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_transcription_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/pages/podcast_episode_detail_page.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/conversation_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/summary_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/transcription_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/global_podcast_player_host.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/podcast_bottom_player_widget.dart';

void main() {
  group('PodcastEpisodeDetailPage player behavior', () {
    testWidgets('keeps mini player visible while reading on mobile', (
      tester,
    ) async {
      addTearDown(() async => tester.binding.setSurfaceSize(null));
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

      expect(find.byType(PodcastBottomPlayerWidget), findsOneWidget);
      expect(
        find.byKey(const Key('podcast_bottom_player_mini')),
        findsOneWidget,
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

    testWidgets('auto-collapses expanded player on upward read scroll', (
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

      final pageContext = tester.element(find.byType(PageView));
      ScrollUpdateNotification(
        metrics: FixedScrollMetrics(
          minScrollExtent: 0,
          maxScrollExtent: 400,
          pixels: 20,
          viewportDimension: 400,
          axisDirection: AxisDirection.down,
          devicePixelRatio: 1,
        ),
        context: pageContext,
        scrollDelta: 12,
      ).dispatch(pageContext);
      await tester.pumpAndSettle();

      expect(notifier.state.isExpanded, isFalse);
      expect(
        find.byKey(const Key('podcast_bottom_player_expanded')),
        findsNothing,
      );
    });

    testWidgets('desktop global player aligns with new content shell', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
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

      final hostFinder = find.byKey(const Key('global_podcast_player'));
      final contentFinder = find.byKey(
        const Key('podcast_episode_detail_primary_content'),
      );
      expect(hostFinder, findsOneWidget);
      expect(contentFinder, findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(hostFinder),
        listen: false,
      );
      expect(container.read(currentRouteProvider), '/podcast/episodes/1/1');

      final playerRect = tester.getRect(hostFinder);
      final contentRect = tester.getRect(contentFinder);

      expect(playerRect.left, greaterThanOrEqualTo(16));
      expect(playerRect.left, lessThan(contentRect.left + 24));
      expect(playerRect.right, greaterThan(contentRect.left + 400));
    });

    testWidgets('scroll-to-top button stays above mini player', (tester) async {
      addTearDown(() async => tester.binding.setSurfaceSize(null));
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

      final pageContext = tester.element(find.byType(PageView));
      ScrollUpdateNotification(
        metrics: FixedScrollMetrics(
          minScrollExtent: 0,
          maxScrollExtent: 400,
          pixels: 20,
          viewportDimension: 500,
          axisDirection: AxisDirection.down,
          devicePixelRatio: 1,
        ),
        context: pageContext,
        scrollDelta: 12,
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
  });
}

Widget _createWidget(TestAudioPlayerNotifier notifier) {
  return ProviderScope(
    overrides: [
      currentRouteProvider.overrideWith(
        () => _TestCurrentRouteNotifier('/podcast/episodes/1/1'),
      ),
      audioPlayerProvider.overrideWith(() => notifier),
      episodeDetailProvider.overrideWith((ref, episodeId) async => _detail()),
      getSummaryProvider(1).overrideWith(() => _SummaryWithContentNotifier()),
      getTranscriptionProvider(
        1,
      ).overrideWith(() => _NoopTranscriptionNotifier(1)),
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
      locale: const Locale('en'),
      home: Stack(
        children: const [
          PodcastEpisodeDetailPage(episodeId: 1),
          GlobalPodcastPlayerHost(),
        ],
      ),
    ),
  );
}

PodcastEpisodeDetailResponse _detail() {
  final now = DateTime.now();
  return PodcastEpisodeDetailResponse(
    id: 1,
    subscriptionId: 1,
    title: 'Test Episode',
    description: '<h2>Opening</h2><p>Description</p>',
    audioUrl: 'https://example.com/audio.mp3',
    audioDuration: 180,
    publishedAt: now,
    aiSummary: 'summary',
    transcriptContent: 'Transcript content',
    status: 'published',
    createdAt: now,
    updatedAt: now,
    relatedEpisodes: const [],
  );
}

PodcastEpisodeModel _episode() => _detail().toEpisodeModel();

class TestAudioPlayerNotifier extends AudioPlayerNotifier {
  TestAudioPlayerNotifier(this._initialState);

  final AudioPlayerState _initialState;

  @override
  AudioPlayerState build() => _initialState;

  @override
  void setExpanded(bool expanded) {
    state = state.copyWith(isExpanded: expanded);
  }

  @override
  Future<void> playEpisode(
    PodcastEpisodeModel episode, {
    PlaySource source = PlaySource.direct,
    int? queueEpisodeId,
  }) async {}

  @override
  Future<void> playManagedEpisode(PodcastEpisodeModel episode) async {}
}

class _NoopTranscriptionNotifier extends TranscriptionNotifier {
  _NoopTranscriptionNotifier(super.episodeId);

  @override
  Future<PodcastTranscriptionResponse?> build() async {
    return PodcastTranscriptionResponse(
      id: 1,
      episodeId: episodeId,
      status: 'completed',
      transcriptContent: 'Transcript content',
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> checkOrStartTranscription() async {}

  @override
  Future<void> startTranscription() async {}

  @override
  Future<void> loadTranscription() async {}
}

class _SummaryWithContentNotifier extends SummaryNotifier {
  _SummaryWithContentNotifier() : super(1);

  @override
  SummaryState build() => const SummaryState(summary: 'Generated summary');
}

class _ConversationWithoutMessagesNotifier extends ConversationNotifier {
  _ConversationWithoutMessagesNotifier() : super(1);

  @override
  ConversationState build() => const ConversationState(messages: []);
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

class _TestCurrentRouteNotifier extends CurrentRouteNotifier {
  _TestCurrentRouteNotifier(this._route);

  final String _route;

  @override
  String build() => _route;
}
