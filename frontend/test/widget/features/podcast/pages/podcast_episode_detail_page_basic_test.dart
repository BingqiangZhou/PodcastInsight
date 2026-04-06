import 'dart:async';

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
  group('PodcastEpisodeDetailPage basic smoke tests', () {
    testWidgets('renders hero and three primary tabs on mobile', (
      tester,
    ) async {
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(_createWidget(episode: _episode()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final context = tester.element(find.byType(PodcastEpisodeDetailPage));
      final l10n = AppLocalizations.of(context)!;

      expect(find.text('Test Episode'), findsOneWidget);
      expect(
        find.byKey(const Key('podcast_episode_detail_primary_tabs')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('episode_detail_mobile_tab_0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('episode_detail_mobile_tab_1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('episode_detail_mobile_tab_2')),
        findsOneWidget,
      );
      expect(find.text(l10n.podcast_tab_shownotes), findsWidgets);
      expect(find.text(l10n.podcast_tab_transcript), findsOneWidget);
      expect(find.text(l10n.podcast_tab_summary), findsOneWidget);
      expect(find.text(l10n.podcast_tab_chat), findsOneWidget);
      expect(
        find.byKey(const Key('podcast_episode_detail_owned_player')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('podcast_episode_detail_summary_section')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('podcast_episode_detail_chat_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('podcast_episode_detail_mobile_hero_actions')),
        findsOneWidget,
      );
      expect(
        tester
            .getSize(
              find.byKey(
                const Key('podcast_episode_detail_mobile_hero_artwork'),
              ),
            )
            .width,
        lessThanOrEqualTo(56),
      );
      expect(
        tester
            .getSize(
              find.byKey(const Key('podcast_episode_detail_mobile_hero_body')),
            )
            .height,
        lessThanOrEqualTo(140),
      );
    });

    testWidgets(
      'keeps shownotes transcript summary and chat visible at 360px',
      (tester) async {
        addTearDown(() async => tester.binding.setSurfaceSize(null));
        await tester.binding.setSurfaceSize(const Size(360, 844));

        await tester.pumpWidget(_createWidget(episode: _episode()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        final context = tester.element(find.byType(PodcastEpisodeDetailPage));
        final l10n = AppLocalizations.of(context)!;

        final shownotesFinder = find.text(l10n.podcast_tab_shownotes);
        final transcriptFinder = find.text(l10n.podcast_tab_transcript);
        final summaryFinder = find.text(l10n.podcast_tab_summary);
        final chatFinder = find.text(l10n.podcast_tab_chat);

        expect(shownotesFinder, findsWidgets);
        expect(transcriptFinder, findsOneWidget);
        expect(summaryFinder, findsOneWidget);
        expect(chatFinder, findsOneWidget);

        final viewportWidth = tester.view.physicalSize.width;
        expect(
          tester.getRect(transcriptFinder).right,
          lessThanOrEqualTo(viewportWidth),
        );
        expect(
          tester.getRect(summaryFinder).right,
          lessThanOrEqualTo(viewportWidth),
        );
        expect(
          tester.getRect(chatFinder).right,
          lessThanOrEqualTo(viewportWidth),
        );
      },
    );

    testWidgets('switches between transcript and summary tabs', (tester) async {
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(_createWidget(episode: _episode()));
      await tester.pumpAndSettle();

      final transcriptTabFinder = find.byKey(
        const Key('episode_detail_mobile_tab_1'),
      );
      await tester.ensureVisible(transcriptTabFinder);
      await tester.tap(transcriptTabFinder);
      await tester.pumpAndSettle();

      // Default view is now highlights - switch to full transcript view
      final fullTextButton = find.textContaining('Full Text');
      if (fullTextButton.evaluate().isNotEmpty) {
        await tester.tap(fullTextButton);
        await tester.pumpAndSettle();
      }

      expect(find.textContaining('Transcript content'), findsOneWidget);

      final summaryTabFinder = find.byKey(
        const Key('episode_detail_mobile_tab_2'),
      );
      await tester.ensureVisible(summaryTabFinder);
      await tester.tap(summaryTabFinder);
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(PodcastEpisodeDetailPage));
      final l10n = AppLocalizations.of(context)!;

      expect(
        find.byKey(const Key('podcast_episode_detail_summary_section')),
        findsOneWidget,
      );
      expect(find.text('Generated summary'), findsOneWidget);
      expect(find.text(l10n.podcast_share_all_content), findsOneWidget);
    });

    testWidgets('hides mobile header after scrolling content', (tester) async {
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(_createWidget(episode: _episode()));
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(SingleChildScrollView).last,
        const Offset(0, -420),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('podcast_episode_detail_mobile_hero_body')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('podcast_episode_detail_primary_tabs')),
        findsOneWidget,
      );
    });

    testWidgets('uses inline source link and icon-only play action on mobile', (
      tester,
    ) async {
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(_createWidget(episode: _episode()));
      await tester.pumpAndSettle();

      final sourceButton = find.byKey(
        const Key('podcast_episode_detail_source_button'),
      );
      final playButton = find.byKey(
        const Key('podcast_episode_detail_play_button'),
      );
      final playWidget = tester.widget<HeaderCapsuleActionButton>(playButton);
      final sourceRect = tester.getRect(sourceButton);
      final actionsRect = tester.getRect(
        find.byKey(const Key('podcast_episode_detail_mobile_hero_actions')),
      );

      expect(sourceButton, findsOneWidget);
      expect(find.text('Source'), findsOneWidget);
      expect(sourceRect.right, lessThan(actionsRect.left));
      expect(playWidget.density, HeaderCapsuleActionButtonDensity.iconOnly);
      expect(tester.getSize(playButton).height, lessThanOrEqualTo(40));
    });

    testWidgets('uses icon-only play action on ultra narrow mobile', (
      tester,
    ) async {
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(350, 844));

      await tester.pumpWidget(_createWidget(episode: _episode()));
      await tester.pumpAndSettle();

      final playButton = find.byKey(
        const Key('podcast_episode_detail_play_button'),
      );
      final playWidget = tester.widget<HeaderCapsuleActionButton>(playButton);

      expect(playButton, findsOneWidget);
      expect(playWidget.density, HeaderCapsuleActionButtonDensity.iconOnly);
      expect(tester.getSize(playButton).width, lessThanOrEqualTo(40));
      expect(tester.getSize(playButton).height, lessThanOrEqualTo(40));
    });

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

    testWidgets('renders bare loading state without GlassPanel', (
      tester,
    ) async {
      addTearDown(() async => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      final completer = Completer<PodcastEpisodeModel?>();
      await tester.pumpWidget(
        _createWidgetWithEpisodeLoader(() => completer.future),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('podcast_episode_detail_loading_content')),
        findsOneWidget,
      );
            expect(find.byType(SurfacePanel), findsNothing);

      completer.complete(_episode());
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });
  });
}

Widget _createWidget({required PodcastEpisodeModel? episode}) {
  return ProviderScope(
    overrides: [
      audioPlayerProvider.overrideWith(_MockAudioPlayerNotifier.new),
      episodeDetailProvider.overrideWith((ref, episodeId) async => episode),
      summaryProvider(1).overrideWith(_SummaryWithContentNotifier.new),
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

Widget _createWidgetWithEpisodeLoader(
  Future<PodcastEpisodeModel?> Function() loader,
) {
  return ProviderScope(
    overrides: [
      audioPlayerProvider.overrideWith(_MockAudioPlayerNotifier.new),
      episodeDetailProvider.overrideWith((ref, episodeId) => loader()),
      summaryProvider(1).overrideWith(_SummaryWithContentNotifier.new),
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

PodcastEpisodeModel _episode() {
  final now = DateTime(2026, 3, 11, 9, 30);
  return PodcastEpisodeModel(
    id: 1,
    subscriptionId: 1,
    title: 'Test Episode',
    description: List.filled(
      24,
      '<h2>Opening</h2><p>Description with enough body text to scroll the shownotes area.</p>',
    ).join(),
    audioUrl: 'https://example.com/audio.mp3',
    itemLink: 'https://example.com/source',
    audioDuration: 180,
    publishedAt: now,
    aiSummary: 'summary',
    transcriptContent: 'Transcript content',
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
