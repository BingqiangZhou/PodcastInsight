import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/theme/mindriver_theme.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/audio_player_state_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_queue_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/navigation/podcast_navigation.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/pages/podcast_player_page.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/podcast_bottom_player_widget.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/podcast_queue_sheet.dart';

void main() {
  group('PodcastBottomPlayerWidget playlist behavior', () {
    testWidgets('mini playlist button opens queue sheet', (tester) async {
      final notifier = TestAudioPlayerNotifier(
        AudioPlayerState(
          currentEpisode: _testEpisode(),
          duration: 180000,
          isExpanded: false,
        ),
      );
      final queueController = TestPodcastQueueController();

      await tester.pumpWidget(
        _createWidget(notifier: notifier, queueController: queueController),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('podcast_bottom_player_mini_playlist')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PodcastQueueSheet), findsOneWidget);
      expect(queueController.queueOpenPreparationCalls, 1);
      await _closeQueueSheet(tester);
    });

    testWidgets(
      'queue sheet opens immediately while refreshing in background',
      (tester) async {
        final notifier = TestAudioPlayerNotifier(
          AudioPlayerState(
            currentEpisode: _testEpisode(),
            duration: 180000,
            isExpanded: false,
          ),
        );
        final queueController = TestPodcastQueueController(
          refreshDelay: const Duration(seconds: 1),
        );

        await tester.pumpWidget(
          _createWidget(notifier: notifier, queueController: queueController),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('podcast_bottom_player_mini_playlist')),
        );
        await tester.pump(const Duration(milliseconds: 250));

        expect(find.byType(PodcastQueueSheet), findsOneWidget);
        expect(queueController.queueOpenPreparationCalls, 1);
        await tester.pump(const Duration(seconds: 1));
        await _closeQueueSheet(tester);
      },
    );
  });

  group('PodcastBottomPlayerWidget interaction updates', () {
    testWidgets('mini info tap expands player and does not navigate', (
      tester,
    ) async {
      final notifier = TestAudioPlayerNotifier(
        AudioPlayerState(
          currentEpisode: _testEpisode(),
          duration: 180000,
          isExpanded: false,
        ),
      );
      final queueController = TestPodcastQueueController();

      await tester.pumpWidget(
        _createRouterWidget(
          notifier: notifier,
          queueController: queueController,
          initialLocation: '/',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('podcast_bottom_player_mini_info')),
      );
      await tester.pumpAndSettle();

      expect(notifier.state.isExpanded, isTrue);
      expect(find.text('Episode Detail Page'), findsNothing);
      expect(find.byKey(const Key('podcast_bottom_player_expanded')), findsOne);
    });

    testWidgets('expanded title tap navigates to episode detail', (
      tester,
    ) async {
      final notifier = TestAudioPlayerNotifier(
        AudioPlayerState(
          currentEpisode: _testEpisode(),
          duration: 180000,
          isExpanded: true,
        ),
      );
      final queueController = TestPodcastQueueController();

      await tester.pumpWidget(
        _createRouterWidget(
          notifier: notifier,
          queueController: queueController,
          initialLocation: '/',
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('podcast_bottom_player_expanded_title')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Episode Detail Page'), findsOneWidget);
    });

    testWidgets('expanded title tap no-ops when already on same detail route', (
      tester,
    ) async {
      final notifier = TestAudioPlayerNotifier(
        AudioPlayerState(
          currentEpisode: _testEpisode(),
          duration: 180000,
          isExpanded: true,
        ),
      );
      final queueController = TestPodcastQueueController();
      final observer = _TestNavigatorObserver();

      await tester.pumpWidget(
        _createRouterWidget(
          notifier: notifier,
          queueController: queueController,
          initialLocation: '/podcast/episodes/1/1',
          observers: [observer],
        ),
      );
      await tester.pumpAndSettle();

      final pushCountBeforeTap = observer.didPushCount;

      await tester.tap(
        find.byKey(const Key('podcast_bottom_player_expanded_title')),
      );
      await tester.pumpAndSettle();

      expect(observer.didPushCount, pushCountBeforeTap);
      expect(find.text('Episode Detail Page'), findsOneWidget);
    });

    testWidgets('expanded header removes close and keeps top sleep button', (
      tester,
    ) async {
      final notifier = TestAudioPlayerNotifier(
        AudioPlayerState(
          currentEpisode: _testEpisode(),
          duration: 180000,
          isExpanded: true,
        ),
      );
      final queueController = TestPodcastQueueController();

      await tester.pumpWidget(
        _createWidget(notifier: notifier, queueController: queueController),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close), findsNothing);
      expect(
        find.byKey(const Key('podcast_bottom_player_sleep')),
        findsOneWidget,
      );
    });

    testWidgets('expanded lower playlist button opens queue sheet', (
      tester,
    ) async {
      final notifier = TestAudioPlayerNotifier(
        AudioPlayerState(
          currentEpisode: _testEpisode(),
          duration: 180000,
          isExpanded: true,
        ),
      );
      final queueController = TestPodcastQueueController();

      await tester.pumpWidget(
        _createWidget(notifier: notifier, queueController: queueController),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('podcast_bottom_player_playlist')));
      await tester.pumpAndSettle();

      expect(find.byType(PodcastQueueSheet), findsOneWidget);
      expect(queueController.queueOpenPreparationCalls, 1);
      await _closeQueueSheet(tester);
    });

    testWidgets('expanded layout places sleep button above playlist button', (
      tester,
    ) async {
      final notifier = TestAudioPlayerNotifier(
        AudioPlayerState(
          currentEpisode: _testEpisode(),
          duration: 180000,
          isExpanded: true,
        ),
      );
      final queueController = TestPodcastQueueController();

      await tester.pumpWidget(
        _createWidget(notifier: notifier, queueController: queueController),
      );
      await tester.pumpAndSettle();

      final sleepCenter = tester.getCenter(
        find.byKey(const Key('podcast_bottom_player_sleep')),
      );
      final playlistCenter = tester.getCenter(
        find.byKey(const Key('podcast_bottom_player_playlist')),
      );

      expect(sleepCenter.dy, lessThan(playlistCenter.dy));
    });

    testWidgets(
      'expanded controls show speed and sleep, and now playing has no rate',
      (tester) async {
        final notifier = TestAudioPlayerNotifier(
          AudioPlayerState(
            currentEpisode: _testEpisode(),
            duration: 180000,
            isExpanded: true,
            playbackRate: 1.75,
          ),
        );
        final queueController = TestPodcastQueueController();

        await tester.pumpWidget(
          _createWidget(notifier: notifier, queueController: queueController),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('podcast_bottom_player_speed')), findsOne);
        expect(find.text('1.75x'), findsOneWidget);
        expect(find.byKey(const Key('podcast_bottom_player_sleep')), findsOne);
        expect(
          find.byKey(const Key('podcast_bottom_player_settings')),
          findsNothing,
        );
        expect(find.text('Now Playing (1.75x)'), findsNothing);
      },
    );

    testWidgets('expanded play button stays horizontally centered', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final notifier = TestAudioPlayerNotifier(
        AudioPlayerState(
          currentEpisode: _testEpisode(),
          duration: 180000,
          isExpanded: true,
        ),
      );
      final queueController = TestPodcastQueueController();

      await tester.pumpWidget(
        _createWidget(notifier: notifier, queueController: queueController),
      );
      await tester.pumpAndSettle();

      final playCenter = tester.getCenter(
        find.byKey(const Key('podcast_bottom_player_play_pause')),
      );
      expect(playCenter.dx, closeTo(390 / 2, 1));
    });

    testWidgets(
      'slider scrubbing previews position and seeks only on release',
      (tester) async {
        final notifier = TestAudioPlayerNotifier(
          AudioPlayerState(
            currentEpisode: _testEpisode(),
            position: 45000,
            duration: 180000,
            isExpanded: true,
          ),
        );
        final queueController = TestPodcastQueueController();

        await tester.pumpWidget(
          _createWidget(notifier: notifier, queueController: queueController),
        );
        await tester.pumpAndSettle();

        final slider = tester.widget<Slider>(
          find.byKey(const Key('podcast_bottom_player_progress_slider')),
        );

        slider.onChangeStart?.call(60000);
        slider.onChanged?.call(60000);
        await tester.pump();

        expect(notifier.seekToPositions, isEmpty);
        expect(find.text('01:00'), findsOneWidget);

        slider.onChangeEnd?.call(60000);
        await tester.pumpAndSettle();

        expect(notifier.seekToPositions, <int>[60000]);
        expect(find.text('01:00'), findsOneWidget);
      },
    );

    testWidgets('dragging handle downward collapses expanded player', (
      tester,
    ) async {
      final notifier = TestAudioPlayerNotifier(
        AudioPlayerState(
          currentEpisode: _testEpisode(),
          duration: 180000,
          isExpanded: true,
        ),
      );
      final queueController = TestPodcastQueueController();

      await tester.pumpWidget(
        _createWidget(notifier: notifier, queueController: queueController),
      );
      await tester.pumpAndSettle();

      await tester.drag(
        find.byKey(const Key('podcast_bottom_player_drag_handle')),
        const Offset(0, 80),
      );
      await tester.pumpAndSettle();

      expect(notifier.state.isExpanded, isFalse);
      expect(
        find.byKey(const Key('podcast_bottom_player_expanded')),
        findsNothing,
      );
    });
  });

  group('PodcastBottomPlayerWidget mini styling', () {
    testWidgets(
      'mobile mini width matches feed card width and has rounded border',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final notifier = TestAudioPlayerNotifier(
          AudioPlayerState(
            currentEpisode: _testEpisode(),
            duration: 180000,
            isExpanded: false,
          ),
        );
        final queueController = TestPodcastQueueController();

        await tester.pumpWidget(
          _createWidget(notifier: notifier, queueController: queueController),
        );
        await tester.pumpAndSettle();

        final miniFinder = find.byKey(const Key('podcast_bottom_player_mini'));
        expect(miniFinder, findsOneWidget);

        final miniRect = tester.getRect(miniFinder);
        expect(miniRect.width, closeTo(350, 1));

        final miniMaterial = tester.widget<Material>(miniFinder);
        expect(miniMaterial.shape, isA<RoundedRectangleBorder>());
        final theme = Theme.of(tester.element(miniFinder));
        expect(miniMaterial.color, theme.colorScheme.surface);
        expect(miniMaterial.elevation, 0);
        final roundedShape = miniMaterial.shape! as RoundedRectangleBorder;
        final borderRadius = roundedShape.borderRadius.resolve(
          TextDirection.ltr,
        );
        expect(borderRadius.topLeft.x, 12);
        expect(borderRadius.topRight.x, 12);
        expect(borderRadius.bottomLeft.x, 12);
        expect(borderRadius.bottomRight.x, 12);
        expect(roundedShape.side.width, 1);
      },
    );

    testWidgets('desktop mini keeps wide layout width', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final notifier = TestAudioPlayerNotifier(
        AudioPlayerState(
          currentEpisode: _testEpisode(),
          duration: 180000,
          isExpanded: false,
        ),
      );
      final queueController = TestPodcastQueueController();

      await tester.pumpWidget(
        _createWidget(notifier: notifier, queueController: queueController),
      );
      await tester.pumpAndSettle();

      final miniRect = tester.getRect(
        find.byKey(const Key('podcast_bottom_player_mini')),
      );
      expect(miniRect.width, greaterThan(1100));
    });

    testWidgets('mini shows progress before time with state progress value', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final notifier = TestAudioPlayerNotifier(
        AudioPlayerState(
          currentEpisode: _testEpisode(),
          position: 45000,
          duration: 180000,
          isExpanded: false,
        ),
      );
      final queueController = TestPodcastQueueController();

      await tester.pumpWidget(
        _createWidget(notifier: notifier, queueController: queueController),
      );
      await tester.pumpAndSettle();

      final progressFinder = find.byKey(
        const Key('podcast_bottom_player_mini_progress'),
      );
      final timeFinder = find.byKey(
        const Key('podcast_bottom_player_mini_time'),
      );
      expect(progressFinder, findsOneWidget);
      expect(timeFinder, findsOneWidget);

      final progressWidget = tester.widget<LinearProgressIndicator>(
        progressFinder,
      );
      expect(progressWidget.value, closeTo(0.25, 0.0001));
      expect(find.text('00:45 / 03:00'), findsOneWidget);

      final progressRect = tester.getRect(progressFinder);
      final timeRect = tester.getRect(timeFinder);
      expect(progressRect.center.dx, lessThan(timeRect.center.dx));
    });

    testWidgets('mini progress stays visible in dark theme', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final notifier = TestAudioPlayerNotifier(
        AudioPlayerState(
          currentEpisode: _testEpisode(),
          position: 45000,
          duration: 180000,
          isExpanded: false,
        ),
      );
      final queueController = TestPodcastQueueController();

      await tester.pumpWidget(
        _createWidget(
          notifier: notifier,
          queueController: queueController,
          theme: MindriverTheme.lightTheme,
          darkTheme: MindriverTheme.darkTheme,
          themeMode: ThemeMode.dark,
        ),
      );
      await tester.pumpAndSettle();

      final progressFinder = find.byKey(
        const Key('podcast_bottom_player_mini_progress'),
      );
      expect(progressFinder, findsOneWidget);

      final progressWidget = tester.widget<LinearProgressIndicator>(
        progressFinder,
      );
      final expectedColor =
          MindriverTheme.darkTheme.colorScheme.onSurfaceVariant;
      expect(progressWidget.color, expectedColor);
    });

    testWidgets('mini progress uses onSurfaceVariant in light theme', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final notifier = TestAudioPlayerNotifier(
        AudioPlayerState(
          currentEpisode: _testEpisode(),
          position: 45000,
          duration: 180000,
          isExpanded: false,
        ),
      );
      final queueController = TestPodcastQueueController();

      await tester.pumpWidget(
        _createWidget(
          notifier: notifier,
          queueController: queueController,
          theme: MindriverTheme.lightTheme,
          darkTheme: MindriverTheme.darkTheme,
          themeMode: ThemeMode.light,
        ),
      );
      await tester.pumpAndSettle();

      final progressFinder = find.byKey(
        const Key('podcast_bottom_player_mini_progress'),
      );
      expect(progressFinder, findsOneWidget);

      final progressWidget = tester.widget<LinearProgressIndicator>(
        progressFinder,
      );
      final expectedColor =
          MindriverTheme.lightTheme.colorScheme.onSurfaceVariant;
      expect(progressWidget.color, expectedColor);
    });
  });

  group('Podcast player modal overlay', () {
    testWidgets('tapping scrim collapses expanded player', (tester) async {
      final notifier = TestAudioPlayerNotifier(
        AudioPlayerState(
          currentEpisode: _testEpisode(),
          duration: 180000,
          isExpanded: true,
        ),
      );
      final queueController = TestPodcastQueueController();

      await tester.pumpWidget(
        _createOverlayHarness(
          notifier: notifier,
          queueController: queueController,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('podcast_player_modal_barrier')));
      await tester.pumpAndSettle();

      expect(notifier.state.isExpanded, isFalse);
    });
  });

  group('PodcastPlayerPage', () {
    testWidgets('full-screen route reuses shared playback state', (
      tester,
    ) async {
      final notifier = TestAudioPlayerNotifier(
        AudioPlayerState(
          currentEpisode: _testEpisode(),
          position: 45000,
          duration: 180000,
          isExpanded: false,
          playbackRate: 1.5,
        ),
      );
      final queueController = TestPodcastQueueController();

      await tester.pumpWidget(
        _createPlayerRouteWidget(
          notifier: notifier,
          queueController: queueController,
          initialLocation: '/podcast/player/1?subscriptionId=1',
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('podcast_fullscreen_player_panel')),
        findsOne,
      );
      expect(find.text('Test Episode'), findsOneWidget);
      expect(find.text('1.5x'), findsOneWidget);
      expect(find.text('00:45'), findsOneWidget);
    });
  });
}

Widget _createWidget({
  required TestAudioPlayerNotifier notifier,
  required TestPodcastQueueController queueController,
  ThemeData? theme,
  ThemeData? darkTheme,
  ThemeMode themeMode = ThemeMode.system,
}) {
  return ProviderScope(
    overrides: [
      audioPlayerProvider.overrideWith(() => notifier),
      podcastQueueControllerProvider.overrideWith(() => queueController),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: theme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      home: const Scaffold(
        body: SizedBox.shrink(),
        bottomNavigationBar: PodcastBottomPlayerWidget(),
      ),
    ),
  );
}

Widget _createRouterWidget({
  required TestAudioPlayerNotifier notifier,
  required TestPodcastQueueController queueController,
  required String initialLocation,
  List<NavigatorObserver> observers = const [],
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    observers: observers,
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
      audioPlayerProvider.overrideWith(() => notifier),
      podcastQueueControllerProvider.overrideWith(() => queueController),
    ],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

Widget _createOverlayHarness({
  required TestAudioPlayerNotifier notifier,
  required TestPodcastQueueController queueController,
}) {
  return ProviderScope(
    overrides: [
      audioPlayerProvider.overrideWith(() => notifier),
      podcastQueueControllerProvider.overrideWith(() => queueController),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Consumer(
        builder: (context, ref, _) {
          final isExpanded = ref.watch(
            audioPlayerProvider.select((state) => state.isExpanded),
          );
          return Scaffold(
            body: Stack(
              children: [
                const Align(
                  alignment: Alignment.bottomCenter,
                  child: PodcastBottomPlayerWidget(applySafeArea: false),
                ),
                Positioned.fill(
                  child: PodcastPlayerModalBarrier(
                    visible: isExpanded,
                    onDismiss: () {
                      ref.read(audioPlayerProvider.notifier).setExpanded(false);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

Widget _createPlayerRouteWidget({
  required TestAudioPlayerNotifier notifier,
  required TestPodcastQueueController queueController,
  required String initialLocation,
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/podcast/player/:episodeId',
        builder: (context, state) {
          final args = PodcastPlayerPageArgs.extractFromState(state);
          return PodcastPlayerPage(args: args);
        },
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      audioPlayerProvider.overrideWith(() => notifier),
      podcastQueueControllerProvider.overrideWith(() => queueController),
    ],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

PodcastEpisodeModel _testEpisode() {
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
  AudioPlayerState build() {
    return _initialState;
  }

  @override
  void setExpanded(bool expanded) {
    state = state.copyWith(isExpanded: expanded);
  }

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

class TestPodcastQueueController extends PodcastQueueController {
  TestPodcastQueueController({this.refreshDelay = Duration.zero});

  final Duration refreshDelay;
  int refreshQueueInBackgroundCalls = 0;
  int loadQueueCalls = 0;

  int get queueOpenPreparationCalls =>
      refreshQueueInBackgroundCalls + loadQueueCalls;

  @override
  Future<PodcastQueueModel> build() async {
    return PodcastQueueModel.empty();
  }

  @override
  Future<PodcastQueueModel> loadQueue({bool forceRefresh = true}) async {
    loadQueueCalls += 1;
    state = const AsyncValue.data(PodcastQueueModel());
    return PodcastQueueModel.empty();
  }

  @override
  Future<void> refreshQueueInBackground() async {
    refreshQueueInBackgroundCalls += 1;
    if (refreshDelay > Duration.zero) {
      await Future<void>.delayed(refreshDelay);
    }
    state = const AsyncValue.data(PodcastQueueModel());
  }

  @override
  Future<PodcastQueueModel> activateEpisode(int episodeId) async {
    return state.value ?? PodcastQueueModel.empty();
  }
}

class _TestNavigatorObserver extends NavigatorObserver {
  int didPushCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    didPushCount += 1;
  }
}

Future<void> _closeQueueSheet(WidgetTester tester) async {
  final sheetFinder = find.byType(PodcastQueueSheet);
  if (sheetFinder.evaluate().isNotEmpty) {
    final context = tester.element(sheetFinder.first);
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
  }
}
