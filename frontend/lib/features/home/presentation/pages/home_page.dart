import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/route_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/custom_adaptive_navigation.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../podcast/presentation/pages/podcast_feed_page.dart';
import '../../../podcast/presentation/pages/podcast_list_page.dart';
import '../../../podcast/presentation/providers/podcast_providers.dart';
import '../../../podcast/presentation/widgets/podcast_bottom_player_widget.dart';
import '../../../profile/presentation/pages/profile_page.dart';

class HomePage extends ConsumerStatefulWidget {
  final Widget? child;
  final int? initialTab;

  const HomePage({super.key, this.child, this.initialTab});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> with RouteAware {
  static const int _tabCount = 3;

  late int _currentIndex;
  bool _hasAttemptedPlaybackRestore = false;
  bool _desktopNavExpanded = true;
  bool _hasPrefetchedLibraryFeed = false;
  final Set<int> _visitedTabs = <int>{};
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
    _currentIndex = (widget.initialTab ?? 1).clamp(0, _tabCount - 1);
    _visitedTabs.add(_currentIndex);
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
      ref.read(audioPlayerProvider.notifier).restoreLastPlayedEpisodeIfNeeded(),
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
    final l10n = AppLocalizations.of(context)!;
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
    if (widget.child != null) {
      return Scaffold(body: widget.child!);
    }

    final currentRoute = ref.watch(currentRouteProvider);
    final isHomeShellPlayerRoute =
        currentRoute.isNotEmpty && isHomeShellRoute(currentRoute);

    if (isHomeShellPlayerRoute) {
      _syncPlayerHostOverride(_buildPlayerHostOverride());
    }

    return CustomAdaptiveNavigation(
      key: const ValueKey('home_custom_adaptive_navigation'),
      destinations: _buildDestinations(context),
      selectedIndex: _currentIndex,
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
        child: _buildTabContent(),
      ),
    );
  }

  Widget? _buildFloatingActionButton() {
    return null;
  }

  void _handleNavigation(int index) {
    if (_currentIndex != index) {
      _visitedTabs.add(index);
    }

    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  Widget _buildTabContent() {
    return _buildIndexedTabContent();
  }

  Widget _buildIndexedTabContent() {
    return IndexedStack(
      index: _currentIndex,
      children: List<Widget>.generate(_tabCount, (index) {
        if (!_visitedTabs.contains(index)) {
          return const SizedBox.shrink();
        }
        return _buildPageContent(index);
      }),
    );
  }

  Widget _buildPageContent(int index) {
    switch (index) {
      case 0:
        return const PodcastListPage();
      case 1:
        return const PodcastFeedPage();
      case 2:
        return const ProfilePage();
      default:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.page_not_found,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.page_not_found_subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
    }
  }
}
