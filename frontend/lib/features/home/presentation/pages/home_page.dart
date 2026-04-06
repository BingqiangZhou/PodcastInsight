import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/providers/route_provider.dart';
import 'package:personal_ai_assistant/core/router/app_router.dart';
import 'package:personal_ai_assistant/core/widgets/custom_adaptive_navigation.dart';
import 'package:personal_ai_assistant/core/widgets/keyboard_shortcuts.dart';
import 'package:personal_ai_assistant/features/auth/presentation/providers/auth_provider.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/podcast_bottom_player_widget.dart';

/// Shell widget for the main tab navigation using StatefulShellRoute.
///
/// Replaces the old `HomePage` which used local `IndexedStack` + `setState`.
/// GoRouter's `StatefulNavigationShell` now manages branch state persistence.
class HomeShellWidget extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const HomeShellWidget({super.key, required this.navigationShell});

  @override
  ConsumerState<HomeShellWidget> createState() => _HomeShellWidgetState();
}

class _HomeShellWidgetState extends ConsumerState<HomeShellWidget>
    with RouteAware {
  bool _hasAttemptedPlaybackRestore = false;
  bool _desktopNavExpanded = true;
  bool _hasPrefetchedLibraryFeed = false;
  PodcastPlayerHostPageOverride? _lastPlayerHostOverride;
  late final PodcastPlayerHostPageOverrideNotifier _playerHostOverrideNotifier;
  ModalRoute<dynamic>? _subscribedRoute;
  bool _returningFromCoveredRoute = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (_subscribedRoute == route) {
      return;
    }

    appRouteObserver.unsubscribe(this);
    _subscribedRoute = route;
    if (route != null) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPushNext() {
    _returningFromCoveredRoute = true;
    _lastPlayerHostOverride = null;
  }

  @override
  void didPopNext() {
    if (!_returningFromCoveredRoute) {
      return;
    }

    _returningFromCoveredRoute = false;
    final playerUi = ref.read(podcastPlayerUiProvider);
    if (playerUi.isExpanded) {
      ref.read(podcastPlayerUiProvider.notifier).collapse();
    }
  }

  @override
  void initState() {
    super.initState();
    _playerHostOverrideNotifier = ref.read(
      podcastPlayerHostPageOverrideProvider.notifier,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _restoreMiniPlayerOnHomeEnter();
      _prefetchLibraryFeedOnHomeEnter();
    });
  }

  void _restoreMiniPlayerOnHomeEnter() {
    if (_hasAttemptedPlaybackRestore) {
      return;
    }

    _hasAttemptedPlaybackRestore = true;
    unawaited(
      ref
          .read(audioPlayerProvider.notifier)
          .restoreLastPlayedEpisodeIfNeeded(),
    );
  }

  void _prefetchLibraryFeedOnHomeEnter() {
    if (_hasPrefetchedLibraryFeed) {
      return;
    }
    _hasPrefetchedLibraryFeed = true;

    final authState = ref.read(authProvider);
    if (!authState.isAuthenticated) {
      return;
    }

    final feedState = ref.read(podcastFeedProvider);
    if (feedState.episodes.isNotEmpty && feedState.isDataFresh()) {
      return;
    }

    unawaited(
      ref.read(podcastFeedProvider.notifier).loadInitialFeed(background: true),
    );
  }

  void _syncPlayerHostOverride(PodcastPlayerHostPageOverride override) {
    final currentOverride = ref.read(podcastPlayerHostPageOverrideProvider);
    if (_lastPlayerHostOverride == override && currentOverride == override) {
      return;
    }
    _lastPlayerHostOverride = override;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _playerHostOverrideNotifier.setOverride(override);
    });
  }

  PodcastPlayerHostPageOverride _buildPlayerHostOverride() {
    return PodcastPlayerHostPageOverride(
      routeOwner: PodcastPlayerHostRouteOwner.homeShell,
      surfaceContext: PodcastPlayerSurfaceContext.homeShell,
      homeShellDesktopNavExpanded: _desktopNavExpanded,
    );
  }

  List<NavigationDestination> _buildDestinations(BuildContext context) {
    final l10n = context.l10n;
    return [
      NavigationDestination(
        icon: const Icon(Icons.travel_explore_outlined),
        selectedIcon: const Icon(Icons.travel_explore),
        label: l10n.nav_podcast,
      ),
      NavigationDestination(
        icon: const Icon(Icons.library_books_outlined),
        selectedIcon: const Icon(Icons.library_books),
        label: l10n.nav_feed,
      ),
      NavigationDestination(
        icon: const Icon(Icons.person_outline),
        selectedIcon: const Icon(Icons.person),
        label: l10n.nav_profile,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final currentRoute = ref.watch(currentRouteProvider);
    final isHomeShellPlayerRoute =
        currentRoute.isNotEmpty && isHomeShellRoute(currentRoute);

    if (isHomeShellPlayerRoute) {
      _syncPlayerHostOverride(_buildPlayerHostOverride());
    }

    return PlaybackShortcuts(
      onTogglePlayPause: _togglePlayPause,
      onSeekBackward: _seekBackward,
      onSeekForward: _seekForward,
      onVolumeUp: _isDesktop ? _volumeUp : null,
      onVolumeDown: _isDesktop ? _volumeDown : null,
      onNextEpisode: _isDesktop ? _nextEpisode : null,
      onPreviousEpisode: _isDesktop ? _previousEpisode : null,
      child: CustomAdaptiveNavigation(
        key: const ValueKey('home_custom_adaptive_navigation'),
        destinations: _buildDestinations(context),
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: _handleNavigation,
        appBar: null,
        floatingActionButton: _buildFloatingActionButton(),
        desktopNavExpanded: _desktopNavExpanded,
        onDesktopNavToggle: () {
          setState(() {
            _desktopNavExpanded = !_desktopNavExpanded;
          });
        },
        body: PodcastPlayerLayoutFrame(
          includeMiniPlayer: true,
          applyMiniPlayerSafeArea: false,
          child: widget.navigationShell,
        ),
      ),
    );
  }

  Widget? _buildFloatingActionButton() {
    return null;
  }

  void _handleNavigation(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  void _togglePlayPause() {
    final notifier = ref.read(audioPlayerProvider.notifier);
    final playerState = ref.read(audioPlayerProvider);
    if (playerState.currentEpisode == null) return;

    if (playerState.isPlaying) {
      notifier.pause();
    } else {
      notifier.resume();
    }
  }

  void _seekBackward() {
    final notifier = ref.read(audioPlayerProvider.notifier);
    final playerState = ref.read(audioPlayerProvider);
    if (playerState.currentEpisode == null) return;

    final newPosition = (playerState.position - 10000).clamp(0, playerState.duration);
    notifier.seekTo(newPosition);
  }

  void _seekForward() {
    final notifier = ref.read(audioPlayerProvider.notifier);
    final playerState = ref.read(audioPlayerProvider);
    if (playerState.currentEpisode == null) return;

    final newPosition = (playerState.position + 30000).clamp(0, playerState.duration);
    notifier.seekTo(newPosition);
  }

  static bool get _isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  void _volumeUp() {
    ref.read(audioHandlerProvider).volumeUp();
  }

  void _volumeDown() {
    ref.read(audioHandlerProvider).volumeDown();
  }

  void _nextEpisode() {
    final queue = ref.read(podcastQueueControllerProvider).value;
    if (queue == null || queue.items.isEmpty) return;

    final currentIndex = queue.items.indexWhere(
      (item) => item.episodeId == queue.currentEpisodeId,
    );

    // If current is the last item or not found, wrap to first item.
    final nextIndex = currentIndex < queue.items.length - 1
        ? currentIndex + 1
        : 0;

    final nextItem = queue.items[nextIndex];
    ref.read(audioPlayerProvider.notifier).playManagedEpisode(
      nextItem.toEpisodeModel(),
    );
  }

  void _previousEpisode() {
    final queue = ref.read(podcastQueueControllerProvider).value;
    if (queue == null || queue.items.isEmpty) return;

    final currentIndex = queue.items.indexWhere(
      (item) => item.episodeId == queue.currentEpisodeId,
    );

    // If current is the first item or not found, wrap to last item.
    final prevIndex = currentIndex > 0
        ? currentIndex - 1
        : queue.items.length - 1;

    final prevItem = queue.items[prevIndex];
    ref.read(audioPlayerProvider.notifier).playManagedEpisode(
      prevItem.toEpisodeModel(),
    );
  }
}
