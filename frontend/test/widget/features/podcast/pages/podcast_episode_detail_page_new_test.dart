import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
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
  group('PodcastEpisodeDetailPage wide layout tests', () {
    testWidgets('renders wide primary content without side rail', (
      tester,
    ) async {
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      await tester.pumpWidget(_createWidget(episode: _episode()));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('podcast_episode_detail_primary_content')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('podcast_episode_detail_side_rail')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('podcast_episode_detail_summary_section')),
        findsNothing,
      );
    });

    testWidgets('opens chat drawer from secondary action', (tester) async {
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1280, 900));

      await tester.pumpWidget(_createWidget(episode: _episode()));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('podcast_episode_detail_chat_button')),
      );
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

        await tester.pumpWidget(_createWidget(episode: _episode()));
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

Widget _createWidget({required PodcastEpisodeDetailResponse? episode}) {
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

PodcastEpisodeDetailResponse _episode() {
  final now = DateTime(2026, 3, 11, 9, 30);
  return PodcastEpisodeDetailResponse(
    id: 1,
    subscriptionId: 1,
    title: 'Test Episode',
    description:
        '<h2>Opening</h2><p>Description</p><h2>Deep Dive</h2><p>More content</p>',
    audioUrl: 'https://example.com/audio.mp3',
    itemLink: 'https://example.com/source',
    audioDuration: 180,
    publishedAt: now,
    aiSummary: 'summary',
    transcriptContent: 'Transcript content',
    status: 'published',
    metadata: const {'podcast_title': 'Test Podcast'},
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
