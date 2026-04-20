import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/providers/route_provider.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/audio_player_state_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_conversation_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_playback_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_transcription_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/pages/podcast_episode_detail_page.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/conversation_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_playback_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/podcast_bottom_player_widget.dart';

// ---------------------------------------------------------------------------
// Mock Notifiers
// ---------------------------------------------------------------------------

class MockAudioPlayerNotifier extends AudioPlayerNotifier {
  MockAudioPlayerNotifier([this._initialState = const AudioPlayerState()]);

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

class NoopTranscriptionNotifier extends TranscriptionNotifier {
  NoopTranscriptionNotifier(super.episodeId);

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

class SummaryWithContentNotifier extends SummaryNotifier {
  SummaryWithContentNotifier() : super(1);

  @override
  SummaryState build() => const SummaryState(summary: 'Generated summary');
}

class SummaryEmptyNotifier extends SummaryNotifier {
  SummaryEmptyNotifier() : super(1);

  @override
  SummaryState build() => const SummaryState();
}

class ConversationWithoutMessagesNotifier extends ConversationNotifier {
  ConversationWithoutMessagesNotifier() : super(1);

  @override
  ConversationState build() => const ConversationState();
}

class EmptySessionListNotifier extends SessionListNotifier {
  EmptySessionListNotifier() : super(1);

  @override
  Future<List<ConversationSession>> build() async => [];
}

class NullSessionIdNotifier extends SessionIdNotifier {
  NullSessionIdNotifier() : super(1);

  @override
  int? build() => null;
}

class TestCurrentRouteNotifier extends CurrentRouteNotifier {
  TestCurrentRouteNotifier(this._route);

  final String _route;

  @override
  String build() => _route;
}

class TestPodcastPlayerUiNotifier extends PodcastPlayerUiNotifier {
  TestPodcastPlayerUiNotifier([
    this._initialState = const PodcastPlayerUiState(),
  ]);

  final PodcastPlayerUiState _initialState;

  @override
  PodcastPlayerUiState build() => _initialState;

  void expand() {
    state = state.copyWith(
      presentation: PodcastPlayerPresentation.expanded,
    );
  }
}

// ---------------------------------------------------------------------------
// Episode factory
// ---------------------------------------------------------------------------

PodcastEpisodeModel createTestEpisode({
  int id = 1,
  int subscriptionId = 1,
  String title = 'Test Episode',
  String description =
      '<h2>Opening</h2><p>Description with enough body text to scroll the shownotes area.</p>',
  String audioUrl = 'https://example.com/audio.mp3',
  String? itemLink = 'https://example.com/source',
  int audioDuration = 180,
  int? playbackPosition,
  String? aiSummary = 'summary',
  String transcriptContent = 'Transcript content',
  Map<String, dynamic>? metadata = const {'podcast_title': 'Test Podcast'},
  List<dynamic>? relatedEpisodes = const [],
}) {
  final now = DateTime(2026, 3, 11, 9, 30);
  return PodcastEpisodeModel(
    id: id,
    subscriptionId: subscriptionId,
    title: title,
    description: description,
    audioUrl: audioUrl,
    itemLink: itemLink,
    audioDuration: audioDuration,
    publishedAt: now,
    playbackPosition: playbackPosition,
    aiSummary: aiSummary,
    transcriptContent: transcriptContent,
    metadata: metadata,
    createdAt: now,
    updatedAt: now,
    relatedEpisodes: relatedEpisodes,
  );
}

// ---------------------------------------------------------------------------
// Widget builders
// ---------------------------------------------------------------------------

/// Creates the episode detail page wrapped in [ProviderScope] + [MaterialApp].
Widget createEpisodeDetailWidget({
  PodcastEpisodeModel? episode,
  Future<PodcastEpisodeModel?> Function()? episodeLoader,
  bool hasSummary = true,
}) {
  return ProviderScope(
    overrides: [
      audioPlayerProvider.overrideWith(MockAudioPlayerNotifier.new),
      episodeDetailProvider.overrideWith(
        (ref, episodeId) =>
            episodeLoader != null ? episodeLoader() : Future.value(episode),
      ),
      summaryProvider(1).overrideWith(
        () => hasSummary
            ? SummaryWithContentNotifier()
            : SummaryEmptyNotifier(),
      ),
      transcriptionProvider(1)
          .overrideWith(() => NoopTranscriptionNotifier(1)),
      conversationProvider(1)
          .overrideWith(ConversationWithoutMessagesNotifier.new),
      sessionListProvider(1).overrideWith(EmptySessionListNotifier.new),
      currentSessionIdProvider(1).overrideWith(NullSessionIdNotifier.new),
      availableModelsProvider
          .overrideWith((ref) async => <SummaryModelInfo>[]),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('en'),
      home: PodcastEpisodeDetailPage(episodeId: 1),
    ),
  );
}

/// Creates the episode detail page wrapped in [PodcastPlayerLayoutFrame] for
/// player-behavior tests.
Widget createEpisodeDetailWidgetWithPlayer({
  PodcastEpisodeModel? episode,
  AudioPlayerState? audioState,
  TestPodcastPlayerUiNotifier? uiNotifier,
  String route = '/podcast/episodes/1/1',
}) {
  final resolvedEpisode = episode ?? createTestEpisode(itemLink: null);
  return ProviderScope(
    overrides: [
      currentRouteProvider.overrideWith(
        () => TestCurrentRouteNotifier(route),
      ),
      audioPlayerProvider.overrideWith(
        () => MockAudioPlayerNotifier(
          audioState ??
              AudioPlayerState(
                currentEpisode: resolvedEpisode,
                duration: 180000,
                isPlaying: true,
              ),
        ),
      ),
      podcastPlayerUiProvider.overrideWith(
        () => uiNotifier ?? TestPodcastPlayerUiNotifier(),
      ),
      episodeDetailProvider.overrideWith(
        (ref, episodeId) async => resolvedEpisode,
      ),
      summaryProvider(1).overrideWith(SummaryWithContentNotifier.new),
      transcriptionProvider(1)
          .overrideWith(() => NoopTranscriptionNotifier(1)),
      conversationProvider(1)
          .overrideWith(ConversationWithoutMessagesNotifier.new),
      sessionListProvider(1).overrideWith(EmptySessionListNotifier.new),
      currentSessionIdProvider(1).overrideWith(NullSessionIdNotifier.new),
      availableModelsProvider
          .overrideWith((ref) async => <SummaryModelInfo>[]),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('en'),
      home: PodcastPlayerLayoutFrame(
        child: PodcastEpisodeDetailPage(episodeId: 1),
      ),
    ),
  );
}
