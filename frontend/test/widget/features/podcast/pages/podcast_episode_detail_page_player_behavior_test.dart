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
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/podcast_bottom_player_widget.dart';

void main() {
  group('PodcastEpisodeDetailPage player behavior', () {
    testWidgets('keeps dock visible while reading on mobile', (tester) async {
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(_createWidget());
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

        await tester.pumpWidget(_createWidget(uiNotifier: uiNotifier));
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

      await tester.pumpWidget(
        _createWidget(
          audioState: const AudioPlayerState(),
          detail: _detail(playbackPosition: 245),
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

      final detail = _detail();
      await tester.pumpWidget(
        _createWidget(
          audioState: AudioPlayerState(
            currentEpisode: detail,
            duration: 180000,
            position: 60000,
            isPlaying: true,
          ),
          detail: detail,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Playing'), findsWidgets);
    });
  });
}

Widget _createWidget({
  TestPodcastPlayerUiNotifier? uiNotifier,
  AudioPlayerState? audioState,
  PodcastEpisodeModel? detail,
}) {
  final resolvedDetail = detail ?? _detail();
  return ProviderScope(
    overrides: [
      currentRouteProvider.overrideWith(
        () => _TestCurrentRouteNotifier('/podcast/episodes/1/1'),
      ),
      audioPlayerProvider.overrideWith(
        () => _TestAudioPlayerNotifier(
          audioState ??
              AudioPlayerState(
                currentEpisode: resolvedDetail,
                duration: 180000,
                isPlaying: true,
              ),
        ),
      ),
      podcastPlayerUiProvider.overrideWith(
        () => uiNotifier ?? TestPodcastPlayerUiNotifier(),
      ),
      episodeDetailProvider.overrideWith(
        (ref, episodeId) async => resolvedDetail,
      ),
      summaryProvider(1).overrideWith(() => _SummaryWithContentNotifier()),
      transcriptionProvider(
        1,
      ).overrideWith(() => _NoopTranscriptionNotifier(1)),
      conversationProvider(
        1,
      ).overrideWith(() => _ConversationWithoutMessagesNotifier()),
      sessionListProvider(1).overrideWith(() => _EmptySessionListNotifier()),
      currentSessionIdProvider(
        1,
      ).overrideWith(() => _NullSessionIdNotifier()),
      availableModelsProvider.overrideWith((ref) async => <SummaryModelInfo>[]),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: const PodcastPlayerLayoutFrame(
        child: PodcastEpisodeDetailPage(episodeId: 1),
      ),
    ),
  );
}

PodcastEpisodeModel _detail({int? playbackPosition}) {
  final now = DateTime.now();
  return PodcastEpisodeModel(
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
    playbackPosition: playbackPosition,
    createdAt: now,
    updatedAt: now,
    relatedEpisodes: const [],
  );
}

class _TestAudioPlayerNotifier extends AudioPlayerNotifier {
  _TestAudioPlayerNotifier(this._initialState);

  final AudioPlayerState _initialState;

  @override
  AudioPlayerState build() => _initialState;

  @override
  Future<void> playEpisode(
    PodcastEpisodeModel episode, {
    PlaySource source = PlaySource.direct,
    int? queueEpisodeId,
  }) async {}

  @override
  Future<void> playManagedEpisode(PodcastEpisodeModel episode) async {}
}

class TestPodcastPlayerUiNotifier extends PodcastPlayerUiNotifier {
  TestPodcastPlayerUiNotifier([
    this._initialState = const PodcastPlayerUiState(),
  ]);

  final PodcastPlayerUiState _initialState;

  @override
  PodcastPlayerUiState build() => _initialState;
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
  _NullSessionIdNotifier() : super(1);

  @override
  int? build() => null;
}

class _TestCurrentRouteNotifier extends CurrentRouteNotifier {
  _TestCurrentRouteNotifier(this._route);

  final String _route;

  @override
  String build() => _route;
}
