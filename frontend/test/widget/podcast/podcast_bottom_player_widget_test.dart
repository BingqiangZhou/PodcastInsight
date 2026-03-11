import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/audio_player_state_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_queue_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/podcast_bottom_player_widget.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/podcast_queue_sheet.dart';

void main() {
  group('PodcastBottomPlayerWidget', () {
    testWidgets('dock info tap expands into mobile sheet', (tester) async {
      _setMobileViewport(tester);
      final audioNotifier = TestAudioPlayerNotifier(
        AudioPlayerState(currentEpisode: _episode(), duration: 180000),
      );
      final queueController = TestPodcastQueueController();
      final uiNotifier = TestPodcastPlayerUiNotifier();

      await tester.pumpWidget(
        _createWidget(
          audioNotifier: audioNotifier,
          queueController: queueController,
          uiNotifier: uiNotifier,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('podcast_bottom_player_mini_info')),
      );
      await tester.pumpAndSettle();

      expect(uiNotifier.state.isExpanded, isTrue);
      expect(
        find.byKey(const Key('podcast_player_mobile_sheet')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('podcast_bottom_player_expanded')),
        findsOneWidget,
      );
    });

    testWidgets('dock playlist button opens queue sheet directly', (
      tester,
    ) async {
      _setMobileViewport(tester);
      final audioNotifier = TestAudioPlayerNotifier(
        AudioPlayerState(currentEpisode: _episode(), duration: 180000),
      );
      final queueController = TestPodcastQueueController();
      final uiNotifier = TestPodcastPlayerUiNotifier();

      await tester.pumpWidget(
        _createWidget(
          audioNotifier: audioNotifier,
          queueController: queueController,
          uiNotifier: uiNotifier,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('podcast_bottom_player_mini_playlist')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PodcastQueueSheet), findsOneWidget);
      expect(queueController.queueOpenPreparationCalls, 1);
    });

    testWidgets('expanded header shows direct speed and sleep actions', (
      tester,
    ) async {
      _setMobileViewport(tester);
      final audioNotifier = TestAudioPlayerNotifier(
        AudioPlayerState(currentEpisode: _episode(), duration: 180000),
      );
      final queueController = TestPodcastQueueController();
      final uiNotifier = TestPodcastPlayerUiNotifier(
        const PodcastPlayerUiState(
          presentation: PodcastPlayerPresentation.expanded,
        ),
      );

      await tester.pumpWidget(
        _createWidget(
          audioNotifier: audioNotifier,
          queueController: queueController,
          uiNotifier: uiNotifier,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('podcast_bottom_player_speed')));
      await tester.pumpAndSettle();
      expect(find.text('Playback Speed'), findsOneWidget);
      Navigator.of(tester.element(find.text('Playback Speed'))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('podcast_bottom_player_sleep')));
      await tester.pumpAndSettle();
      expect(find.text('Sleep Timer'), findsOneWidget);
    });

    testWidgets('expanded transport controls seek and toggle playback', (
      tester,
    ) async {
      _setMobileViewport(tester);
      final audioNotifier = TestAudioPlayerNotifier(
        AudioPlayerState(
          currentEpisode: _episode(),
          duration: 180000,
          position: 45000,
        ),
      );
      final queueController = TestPodcastQueueController();
      final uiNotifier = TestPodcastPlayerUiNotifier(
        const PodcastPlayerUiState(
          presentation: PodcastPlayerPresentation.expanded,
        ),
      );

      await tester.pumpWidget(
        _createWidget(
          audioNotifier: audioNotifier,
          queueController: queueController,
          uiNotifier: uiNotifier,
        ),
      );
      await tester.pumpAndSettle();

      final slider = tester.widget<Slider>(
        find.byKey(const Key('podcast_bottom_player_progress_slider')),
      );
      slider.onChangeStart?.call(60000);
      slider.onChanged?.call(60000);
      await tester.pump();
      expect(audioNotifier.seekToPositions, isEmpty);

      slider.onChangeEnd?.call(60000);
      await tester.pumpAndSettle();
      expect(audioNotifier.seekToPositions, <int>[60000]);

      await tester.tap(
        find.byKey(const Key('podcast_bottom_player_play_pause')),
      );
      await tester.pumpAndSettle();
      expect(audioNotifier.resumeCalls, 1);
    });

    testWidgets('dragging mobile handle collapses expanded sheet', (
      tester,
    ) async {
      _setMobileViewport(tester);
      final audioNotifier = TestAudioPlayerNotifier(
        AudioPlayerState(currentEpisode: _episode(), duration: 180000),
      );
      final queueController = TestPodcastQueueController();
      final uiNotifier = TestPodcastPlayerUiNotifier(
        const PodcastPlayerUiState(
          presentation: PodcastPlayerPresentation.expanded,
        ),
      );

      await tester.pumpWidget(
        _createWidget(
          audioNotifier: audioNotifier,
          queueController: queueController,
          uiNotifier: uiNotifier,
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(
        find.byKey(const Key('podcast_bottom_player_drag_handle')),
        const Offset(0, 80),
      );
      await tester.pumpAndSettle();

      expect(uiNotifier.state.isExpanded, isFalse);
      expect(
        find.byKey(const Key('podcast_bottom_player_expanded')),
        findsNothing,
      );
    });

    testWidgets('desktop layout uses side panel instead of mobile sheet', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final audioNotifier = TestAudioPlayerNotifier(
        AudioPlayerState(currentEpisode: _episode(), duration: 180000),
      );
      final queueController = TestPodcastQueueController();
      final uiNotifier = TestPodcastPlayerUiNotifier(
        const PodcastPlayerUiState(
          presentation: PodcastPlayerPresentation.expanded,
        ),
      );

      await tester.pumpWidget(
        _createWidget(
          audioNotifier: audioNotifier,
          queueController: queueController,
          uiNotifier: uiNotifier,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('podcast_player_desktop_panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('podcast_player_mobile_sheet')),
        findsNothing,
      );
    });

    testWidgets('expanded title tap navigates to episode detail', (
      tester,
    ) async {
      _setMobileViewport(tester);
      final audioNotifier = TestAudioPlayerNotifier(
        AudioPlayerState(currentEpisode: _episode(), duration: 180000),
      );
      final queueController = TestPodcastQueueController();
      final uiNotifier = TestPodcastPlayerUiNotifier(
        const PodcastPlayerUiState(
          presentation: PodcastPlayerPresentation.expanded,
        ),
      );

      await tester.pumpWidget(
        _createRouterWidget(
          audioNotifier: audioNotifier,
          queueController: queueController,
          uiNotifier: uiNotifier,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('podcast_bottom_player_expanded_title')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Episode Detail Page'), findsOneWidget);
    });
  });
}

void _setMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _createWidget({
  required TestAudioPlayerNotifier audioNotifier,
  required TestPodcastQueueController queueController,
  required TestPodcastPlayerUiNotifier uiNotifier,
}) {
  return ProviderScope(
    overrides: [
      audioPlayerProvider.overrideWith(() => audioNotifier),
      podcastQueueControllerProvider.overrideWith(() => queueController),
      podcastPlayerUiProvider.overrideWith(() => uiNotifier),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(
        body: SizedBox.shrink(),
        bottomNavigationBar: PodcastBottomPlayerWidget(),
      ),
    ),
  );
}

Widget _createRouterWidget({
  required TestAudioPlayerNotifier audioNotifier,
  required TestPodcastQueueController queueController,
  required TestPodcastPlayerUiNotifier uiNotifier,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(
          body: Text('Home Page'),
          bottomNavigationBar: PodcastBottomPlayerWidget(),
        ),
      ),
      GoRoute(
        name: 'episodeDetail',
        path: '/podcast/episodes/:subscriptionId/:episodeId',
        builder: (context, state) => const Scaffold(
          body: Text('Episode Detail Page'),
          bottomNavigationBar: PodcastBottomPlayerWidget(),
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      audioPlayerProvider.overrideWith(() => audioNotifier),
      podcastQueueControllerProvider.overrideWith(() => queueController),
      podcastPlayerUiProvider.overrideWith(() => uiNotifier),
    ],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

PodcastEpisodeModel _episode() {
  final now = DateTime.now();
  return PodcastEpisodeModel(
    id: 1,
    subscriptionId: 1,
    title: 'Test Episode',
    description: 'Description',
    audioUrl: 'https://example.com/audio.mp3',
    publishedAt: now,
    createdAt: now,
  );
}

class TestAudioPlayerNotifier extends AudioPlayerNotifier {
  TestAudioPlayerNotifier(this._initialState);

  final AudioPlayerState _initialState;
  final List<int> seekToPositions = <int>[];
  int pauseCalls = 0;
  int resumeCalls = 0;

  @override
  AudioPlayerState build() => _initialState;

  @override
  Future<void> seekTo(int position) async {
    seekToPositions.add(position);
    state = state.copyWith(position: position);
  }

  @override
  Future<void> pause() async {
    pauseCalls += 1;
    state = state.copyWith(isPlaying: false);
  }

  @override
  Future<void> resume() async {
    resumeCalls += 1;
    state = state.copyWith(isPlaying: true);
  }
}

class TestPodcastPlayerUiNotifier extends PodcastPlayerUiNotifier {
  TestPodcastPlayerUiNotifier([
    this._initialState = const PodcastPlayerUiState(),
  ]);

  final PodcastPlayerUiState _initialState;

  @override
  PodcastPlayerUiState build() => _initialState;
}

class TestPodcastQueueController extends PodcastQueueController {
  int refreshQueueInBackgroundCalls = 0;
  int loadQueueCalls = 0;

  int get queueOpenPreparationCalls =>
      refreshQueueInBackgroundCalls + loadQueueCalls;

  @override
  Future<PodcastQueueModel> build() async => PodcastQueueModel.empty();

  @override
  Future<PodcastQueueModel> loadQueue({bool forceRefresh = true}) async {
    loadQueueCalls += 1;
    state = const AsyncValue.data(PodcastQueueModel());
    return PodcastQueueModel.empty();
  }

  @override
  Future<void> refreshQueueInBackground() async {
    refreshQueueInBackgroundCalls += 1;
    state = const AsyncValue.data(PodcastQueueModel());
  }

  @override
  Future<PodcastQueueModel> activateEpisode(int episodeId) async {
    return PodcastQueueModel.empty();
  }
}
