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
  group('PodcastEpisodeDetailPage basic smoke tests', () {
    testWidgets('renders episode title and core tabs', (tester) async {
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(_createWidget(episode: _episode()));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(PodcastEpisodeDetailPage));
      final l10n = AppLocalizations.of(context)!;

      expect(find.text('Test Episode'), findsOneWidget);
      expect(find.text(l10n.podcast_tab_shownotes), findsWidgets);
      expect(find.text(l10n.podcast_tab_transcript), findsOneWidget);
      expect(find.text(l10n.podcast_filter_with_summary), findsOneWidget);
      expect(find.text(l10n.podcast_tab_chat), findsOneWidget);
    });

    testWidgets('switches tabs and shows transcript + summary content', (
      tester,
    ) async {
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(_createWidget(episode: _episode()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('episode_detail_mobile_tab_1')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Transcript content'), findsOneWidget);

      await tester.tap(find.byKey(const Key('episode_detail_mobile_tab_2')));
      await tester.pumpAndSettle();
      expect(find.text('Generated summary'), findsOneWidget);
    });

    testWidgets(
      'summary tab allows generation when transcript exists only on episode detail',
      (tester) async {
        addTearDown(() async => tester.binding.setSurfaceSize(null));
        await tester.binding.setSurfaceSize(const Size(390, 844));

        await tester.pumpWidget(
          _createWidget(
            episode: _episode(
              aiSummary: null,
              transcriptContent: 'Episode transcript from detail',
            ),
            createSummaryNotifier: () => _SummaryEmptyNotifier(),
            createTranscriptionNotifier: () => _EmptyTranscriptionNotifier(1),
          ),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(PodcastEpisodeDetailPage));
        final l10n = AppLocalizations.of(context)!;

        await tester.tap(find.byKey(const Key('episode_detail_mobile_tab_2')));
        await tester.pumpAndSettle();

        expect(find.text(l10n.podcast_summary_generate), findsOneWidget);
      },
    );

    testWidgets(
      'summary tab keeps summary visible when notifier also has an error',
      (tester) async {
        addTearDown(() async => tester.binding.setSurfaceSize(null));
        await tester.binding.setSurfaceSize(const Size(390, 844));

        await tester.pumpWidget(
          _createWidget(
            episode: _episode(aiSummary: null),
            createSummaryNotifier: () => _SummaryWithErrorNotifier(),
            createTranscriptionNotifier: () => _EmptyTranscriptionNotifier(1),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('episode_detail_mobile_tab_2')));
        await tester.pumpAndSettle();

        expect(find.text('Persisted summary'), findsOneWidget);
        expect(find.text('regeneration failed'), findsOneWidget);
      },
    );

    testWidgets('shows localized not-found state', (tester) async {
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(_createWidget(episode: null));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(PodcastEpisodeDetailPage));
      final l10n = AppLocalizations.of(context)!;

      expect(find.text(l10n.podcast_error_loading), findsOneWidget);
      expect(find.text(l10n.podcast_episode_not_found), findsOneWidget);
      expect(find.text(l10n.podcast_go_back), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });
}

Widget _createWidget({
  required PodcastEpisodeDetailResponse? episode,
  SummaryNotifier Function()? createSummaryNotifier,
  TranscriptionNotifier Function()? createTranscriptionNotifier,
}) {
  return ProviderScope(
    overrides: [
      audioPlayerProvider.overrideWith(_MockAudioPlayerNotifier.new),
      episodeDetailProvider.overrideWith((ref, episodeId) async => episode),
      getSummaryProvider(1).overrideWith(
        createSummaryNotifier ?? () => _SummaryWithContentNotifier(),
      ),
      getTranscriptionProvider(1).overrideWith(
        createTranscriptionNotifier ?? () => _NoopTranscriptionNotifier(1),
      ),
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

PodcastEpisodeDetailResponse _episode({
  String? aiSummary = 'summary',
  String? transcriptContent = 'Transcript content',
}) {
  final now = DateTime.now();
  return PodcastEpisodeDetailResponse(
    id: 1,
    subscriptionId: 1,
    title: 'Test Episode',
    description: 'Description',
    audioUrl: 'https://example.com/audio.mp3',
    itemLink: 'https://example.com/source',
    audioDuration: 180,
    publishedAt: now,
    aiSummary: aiSummary,
    transcriptContent: transcriptContent,
    status: 'published',
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

class _SummaryWithErrorNotifier extends SummaryNotifier {
  _SummaryWithErrorNotifier() : super(1);

  @override
  SummaryState build() {
    return const SummaryState(
      summary: 'Persisted summary',
      errorMessage: 'regeneration failed',
    );
  }
}

class _EmptyTranscriptionNotifier extends TranscriptionNotifier {
  _EmptyTranscriptionNotifier(super.episodeId);

  @override
  Future<PodcastTranscriptionResponse?> build() async => null;

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
