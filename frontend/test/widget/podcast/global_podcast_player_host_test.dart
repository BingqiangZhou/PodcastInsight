import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/providers/route_provider.dart';
import 'package:personal_ai_assistant/core/router/app_router.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/audio_player_state_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/global_podcast_player_host.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/podcast_bottom_player_widget.dart';

void main() {
  group('GlobalPodcastPlayerHost route transitions', () {
    testWidgets('collapsed player keeps the same anchor across routes', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _createRouterHarness(
          audioNotifier: _TestAudioPlayerNotifier(
            AudioPlayerState(currentEpisode: _episode(), duration: 180000),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final miniFinder = find.byKey(const Key('podcast_bottom_player_mini'));
      expect(miniFinder, findsOneWidget);
      final homeRect = tester.getRect(miniFinder);

      await tester.tap(find.byKey(const Key('route_to_episodes')));
      await tester.pumpAndSettle();
      expect(find.byType(PodcastBottomPlayerWidget), findsOneWidget);
      expect(tester.getRect(miniFinder).top, closeTo(homeRect.top, 0.1));

      await tester.tap(find.byKey(const Key('route_to_detail')));
      await tester.pumpAndSettle();
      expect(find.byType(PodcastBottomPlayerWidget), findsOneWidget);
      expect(tester.getRect(miniFinder).top, closeTo(homeRect.top, 0.1));
    });

    testWidgets('global host hides on the full-screen player route', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _createRouterHarness(
          audioNotifier: _TestAudioPlayerNotifier(
            AudioPlayerState(currentEpisode: _episode(), duration: 180000),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PodcastBottomPlayerWidget), findsOneWidget);

      await tester.tap(find.byKey(const Key('route_to_player')));
      await tester.pumpAndSettle();

      expect(find.text('Player Route'), findsOneWidget);
      expect(find.byType(PodcastBottomPlayerWidget), findsNothing);
    });

    testWidgets('sleep timer sheet opens from the global host overlay', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _createRouterHarness(
          audioNotifier: _TestAudioPlayerNotifier(
            AudioPlayerState(
              currentEpisode: _episode(),
              duration: 180000,
              isExpanded: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('podcast_bottom_player_sleep')));
      await tester.pumpAndSettle();

      expect(find.text('Sleep Timer'), findsOneWidget);
    });

    testWidgets('playback speed sheet opens from the global host overlay', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _createRouterHarness(
          audioNotifier: _TestAudioPlayerNotifier(
            AudioPlayerState(
              currentEpisode: _episode(),
              duration: 180000,
              isExpanded: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('podcast_bottom_player_speed')));
      await tester.pumpAndSettle();

      expect(find.text('Playback Speed'), findsOneWidget);
    });
    testWidgets(
      'wide direct detail route uses detail pane insets on first frame',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _createRouterHarness(
            audioNotifier: _TestAudioPlayerNotifier(
              AudioPlayerState(currentEpisode: _episode(), duration: 180000),
            ),
            initialLocation: '/podcast/episode/detail/1',
          ),
        );
        await tester.pumpAndSettle();

        final miniFinder = find.byKey(const Key('podcast_bottom_player_mini'));
        expect(miniFinder, findsOneWidget);

        final hostFinder = find.byKey(const Key('global_podcast_player'));
        final container = ProviderScope.containerOf(
          tester.element(hostFinder),
          listen: false,
        );
        final expectedSpec = resolvePodcastPlayerViewportSpec(
          tester.element(hostFinder),
          container.read(podcastPlayerHostLayoutProvider),
          route: '/podcast/episode/detail/1',
        );
        final miniRect = tester.getRect(miniFinder);
        expect(miniRect.left, closeTo(expectedSpec.leftInset, 0.5));
        expect(miniRect.right, closeTo(1200 - expectedSpec.rightInset, 0.5));
      },
    );
  });
}

Widget _createRouterHarness({
  required _TestAudioPlayerNotifier audioNotifier,
  String initialLocation = '/',
}) {
  final router = GoRouter(
    navigatorKey: appNavigatorKey,
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const _RoutePage(title: 'Home'),
      ),
      GoRoute(
        path: '/episodes',
        builder: (context, state) => const _RoutePage(title: 'Episodes'),
      ),
      GoRoute(
        path: '/detail',
        builder: (context, state) => const _RoutePage(title: 'Detail'),
      ),
      GoRoute(
        path: '/podcast/episode/detail/:episodeId',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Direct Detail'))),
      ),
      GoRoute(
        path: '/podcast/player/:episodeId',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Player Route'))),
      ),
    ],
  );

  return ProviderScope(
    overrides: [audioPlayerProvider.overrideWith(() => audioNotifier)],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) => Overlay(
        initialEntries: [
          OverlayEntry(builder: (_) => child ?? const SizedBox.shrink()),
          OverlayEntry(builder: (_) => _RouteSyncBridge(router: router)),
          OverlayEntry(builder: (_) => const GlobalPodcastPlayerHost()),
        ],
      ),
    ),
  );
}

class _RouteSyncBridge extends ConsumerStatefulWidget {
  const _RouteSyncBridge({required this.router});

  final GoRouter router;

  @override
  ConsumerState<_RouteSyncBridge> createState() => _RouteSyncBridgeState();
}

class _RouteSyncBridgeState extends ConsumerState<_RouteSyncBridge> {
  late final VoidCallback _listener = _syncRoute;

  @override
  void initState() {
    super.initState();
    widget.router.routerDelegate.addListener(_listener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncRoute();
    });
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_listener);
    super.dispose();
  }

  void _syncRoute() {
    if (!mounted) {
      return;
    }
    final route = widget.router.routerDelegate.currentConfiguration.uri
        .toString();
    ref.read(currentRouteProvider.notifier).setRoute(route);
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _RoutePage extends StatelessWidget {
  const _RoutePage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title),
          TextButton(
            key: const Key('route_to_episodes'),
            onPressed: () => context.go('/episodes'),
            child: const Text('Episodes'),
          ),
          TextButton(
            key: const Key('route_to_detail'),
            onPressed: () => context.go('/detail'),
            child: const Text('Detail'),
          ),
          TextButton(
            key: const Key('route_to_player'),
            onPressed: () => context.go('/podcast/player/1'),
            child: const Text('Player'),
          ),
        ],
      ),
    );
  }
}

class _TestAudioPlayerNotifier extends AudioPlayerNotifier {
  _TestAudioPlayerNotifier(this._initialState);

  final AudioPlayerState _initialState;

  @override
  AudioPlayerState build() {
    return _initialState;
  }
}

PodcastEpisodeModel _episode() {
  final now = DateTime.now();
  return PodcastEpisodeModel(
    id: 1,
    subscriptionId: 1,
    title: 'Host Episode',
    description: 'Host test episode',
    audioUrl: 'https://example.com/audio.mp3',
    publishedAt: now,
    createdAt: now,
  );
}
