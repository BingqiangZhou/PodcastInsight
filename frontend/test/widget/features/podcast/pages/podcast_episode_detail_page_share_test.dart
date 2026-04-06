import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
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

void main() {
  testWidgets('summary tab shows share-all when summary exists', (
    tester,
  ) async {
    addTearDown(() async => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      _createWidget(hasSummary: true, episodeSummary: null),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(PodcastEpisodeDetailPage));
    final l10n = AppLocalizations.of(context)!;

    final summaryTabFinder = find.byKey(
      const Key('episode_detail_mobile_tab_2'),
    );
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
      _createWidget(hasSummary: false, episodeSummary: null),
    );
    await tester.pumpAndSettle();

    final summaryTabFinder = find.byKey(
      const Key('episode_detail_mobile_tab_2'),
    );
    await tester.ensureVisible(summaryTabFinder);
    await tester.tap(summaryTabFinder);
    await tester.pumpAndSettle();

    expect(find.text('Generated summary'), findsNothing);
  });
}

Widget _createWidget({
  required bool hasSummary,
  required String? episodeSummary,
}) {
  return ProviderScope(
    overrides: [
      audioPlayerProvider.overrideWith(_MockAudioPlayerNotifier.new),
      episodeDetailProvider.overrideWith(
        (ref, episodeId) async => _episodeDetail(episodeSummary),
      ),
      summaryProvider(1).overrideWith(
        () => hasSummary
            ? _SummaryWithContentNotifier()
            : _SummaryEmptyNotifier(),
      ),
      transcriptionProvider(
        1,
      ).overrideWith(() => _NoopTranscriptionNotifier(1)),
      conversationProvider(
        1,
      ).overrideWith(_ConversationWithoutMessagesNotifier.new),
      sessionListProvider(1).overrideWith(_EmptySessionListNotifier.new),
      currentSessionIdProvider(
        1,
      ).overrideWith(_NullSessionIdNotifier.new),
      availableModelsProvider.overrideWith((ref) async => <SummaryModelInfo>[]),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('en'),
      home: PodcastEpisodeDetailPage(episodeId: 1),
    ),
  );
}

PodcastEpisodeModel _episodeDetail(String? summary) {
  final now = DateTime.now();
  return PodcastEpisodeModel(
    id: 1,
    subscriptionId: 1,
    title: 'Test Episode',
    description: 'Description',
    audioUrl: 'https://example.com/audio.mp3',
    audioDuration: 180,
    publishedAt: now,
    aiSummary: summary,
    createdAt: now,
    updatedAt: now,
    relatedEpisodes: const [],
  );
}

class _MockAudioPlayerNotifier extends AudioPlayerNotifier {
  @override
  AudioPlayerState build() {
    return const AudioPlayerState();
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
  SummaryState build() {
    return const SummaryState(summary: 'Generated summary');
  }
}

class _SummaryEmptyNotifier extends SummaryNotifier {
  _SummaryEmptyNotifier() : super(1);

  @override
  SummaryState build() {
    return const SummaryState();
  }
}

class _ConversationWithoutMessagesNotifier extends ConversationNotifier {
  _ConversationWithoutMessagesNotifier() : super(1);

  @override
  ConversationState build() {
    return const ConversationState();
  }
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
