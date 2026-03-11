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

void main() {
  group('GlobalPodcastPlayerHost', () {
    testWidgets('collapsed dock stays anchored across routes', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_createRouterHarness());
      await tester.pumpAndSettle();

      final dockFinder = find.byKey(const Key('podcast_bottom_player_mini'));
      expect(dockFinder, findsOneWidget);
      final homeTop = tester.getRect(dockFinder).top;

      await tester.tap(find.byKey(const Key('route_to_episodes')));
      await tester.pumpAndSettle();
      expect(tester.getRect(dockFinder).top, closeTo(homeTop, 0.1));

      await tester.tap(find.byKey(const Key('route_to_detail')));
      await tester.pumpAndSettle();
      expect(tester.getRect(dockFinder).top, closeTo(homeTop, 0.1));
    });

    testWidgets('expanded desktop mode renders side panel and scrim', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _createRouterHarness(
          uiNotifier: TestPodcastPlayerUiNotifier(
            const PodcastPlayerUiState(
              presentation: PodcastPlayerPresentation.expanded,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('podcast_player_desktop_panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('podcast_player_modal_barrier')),
        findsOneWidget,
      );
    });

    testWidgets('barrier tap collapses expanded player', (tester) async {
      final uiNotifier = TestPodcastPlayerUiNotifier(
        const PodcastPlayerUiState(
          presentation: PodcastPlayerPresentation.expanded,
        ),
      );

      await tester.pumpWidget(_createRouterHarness(uiNotifier: uiNotifier));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('podcast_player_modal_barrier')));
      await tester.pumpAndSettle();

      expect(uiNotifier.state.isExpanded, isFalse);
      expect(
        find.byKey(const Key('podcast_bottom_player_expanded')),
        findsNothing,
      );
    });

    testWidgets('detail route uses detail surface insets', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _createRouterHarness(initialLocation: '/podcast/episode/detail/1'),
      );
      await tester.pumpAndSettle();

      final hostFinder = find.byKey(const Key('global_podcast_player'));
      final dockFinder = find.byKey(const Key('podcast_bottom_player_mini'));
      final container = ProviderScope.containerOf(
        tester.element(hostFinder),
        listen: false,
      );
      final spec = resolvePodcastPlayerViewportSpec(
        tester.element(hostFinder),
        container.read(podcastPlayerHostLayoutProvider),
        route: '/podcast/episode/detail/1',
      );
      final dockRect = tester.getRect(dockFinder);

      expect(spec.dockLeftInset, 20);
      expect(
        dockRect.left,
        closeTo(spec.dockLeftInset + spec.dockHorizontalPadding, 0.5),
      );
    });
  });
}

Widget _createRouterHarness({
  TestPodcastPlayerUiNotifier? uiNotifier,
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
    ],
  );

  return ProviderScope(
    overrides: [
      audioPlayerProvider.overrideWith(
        () => _TestAudioPlayerNotifier(
          AudioPlayerState(currentEpisode: _episode(), duration: 180000),
        ),
      ),
      podcastPlayerUiProvider.overrideWith(
        () => uiNotifier ?? TestPodcastPlayerUiNotifier(),
      ),
    ],
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncRoute());
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
    ref
        .read(currentRouteProvider.notifier)
        .setRoute(
          widget.router.routerDelegate.currentConfiguration.uri.toString(),
        );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
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
        ],
      ),
    );
  }
}

class _TestAudioPlayerNotifier extends AudioPlayerNotifier {
  _TestAudioPlayerNotifier(this._initialState);

  final AudioPlayerState _initialState;

  @override
  AudioPlayerState build() => _initialState;
}

class TestPodcastPlayerUiNotifier extends PodcastPlayerUiNotifier {
  TestPodcastPlayerUiNotifier([
    this._initialState = const PodcastPlayerUiState(),
  ]);

  final PodcastPlayerUiState _initialState;

  @override
  PodcastPlayerUiState build() => _initialState;
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
