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
  group('PodcastEpisodeDetailPage mobile tab indicator', () {
    testWidgets('initial state shows only indicator_0', (tester) async {
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(_createWidget());
      await tester.pumpAndSettle();

      expect(_indicatorColor(tester, 0), isNot(Colors.transparent));
      expect(_indicatorColor(tester, 1), Colors.transparent);
      expect(_indicatorColor(tester, 2), Colors.transparent);
    });

    testWidgets('tap transcript tab shows only indicator_1', (tester) async {
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(_createWidget());
      await tester.pumpAndSettle();

      final transcriptTabFinder = find.byKey(
        const Key('episode_detail_mobile_tab_1'),
      );
      await tester.ensureVisible(transcriptTabFinder);
      await tester.tap(transcriptTabFinder);
      await tester.pumpAndSettle();

      expect(_indicatorColor(tester, 0), Colors.transparent);
      expect(_indicatorColor(tester, 1), isNot(Colors.transparent));
      expect(_indicatorColor(tester, 2), Colors.transparent);
    });

    testWidgets('tap summary tab shows only indicator_2', (tester) async {
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(_createWidget());
      await tester.pumpAndSettle();

      final summaryTabFinder = find.byKey(
        const Key('episode_detail_mobile_tab_2'),
      );
      await tester.ensureVisible(summaryTabFinder);
      await tester.tap(summaryTabFinder);
      await tester.pumpAndSettle();

      expect(_indicatorColor(tester, 0), Colors.transparent);
      expect(_indicatorColor(tester, 1), Colors.transparent);
      expect(_indicatorColor(tester, 2), isNot(Colors.transparent));
    });
  });
}

Widget _createWidget() {
  final now = DateTime.now();
  final episode = PodcastEpisodeDetailResponse(
    id: 1,
    subscriptionId: 1,
    title: 'Test Episode',
    description: '<p>Description</p>',
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

  return ProviderScope(
    overrides: [
      audioPlayerProvider.overrideWith(_MockAudioPlayerNotifier.new),
      episodeDetailProvider.overrideWith((ref, episodeId) async => episode),
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
      home: const PodcastEpisodeDetailPage(episodeId: 1),
    ),
  );
}

Color _indicatorColor(WidgetTester tester, int index) {
  final indicator = tester.widget<Container>(
    find.byKey(Key('episode_detail_mobile_tab_indicator_$index')),
  );
  final decoration = indicator.decoration as BoxDecoration?;
  return decoration?.color ?? Colors.transparent;
}

class _MockAudioPlayerNotifier extends AudioPlayerNotifier {
  @override
  AudioPlayerState build() => const AudioPlayerState();

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
