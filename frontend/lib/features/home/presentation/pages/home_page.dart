import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/route_provider.dart';
import '../../../../core/widgets/custom_adaptive_navigation.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../podcast/presentation/pages/podcast_feed_page.dart';
import '../../../podcast/presentation/pages/podcast_list_page.dart';
import '../../../podcast/presentation/constants/podcast_ui_constants.dart';
import '../../../podcast/presentation/providers/podcast_providers.dart';
import '../../../profile/presentation/pages/profile_page.dart';

class HomePage extends ConsumerStatefulWidget {
  final Widget? child;
  final int? initialTab;

  const HomePage({super.key, this.child, this.initialTab});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  static const int _tabCount = 3;
  static const double _tabletSidebarWidth = 86;
  static const double _tabletContentGap = 12;
  static const double _desktopContentRightInset = 12;

  late int _currentIndex;
  bool _hasAttemptedPlaybackRestore = false;
  bool _desktopNavExpanded = true;
  bool _hasPrefetchedLibraryFeed = false;
  final Set<int> _visitedTabs = <int>{};
  PodcastPlayerHostPageOverride? _lastPlayerHostOverride;
  late final PodcastPlayerHostPageOverrideNotifier _playerHostOverrideNotifier;

  @override
  void initState() {
    super.initState();
    _playerHostOverrideNotifier = ref.read(
      podcastPlayerHostPageOverrideProvider.notifier,
    );
    _currentIndex = (widget.initialTab ?? 0).clamp(0, _tabCount - 1);
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
    if (_lastPlayerHostOverride == override) {
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

  PodcastPlayerHostPageOverride _buildPlayerHostOverride(double width) {
    if (width < 600) {
      return const PodcastPlayerHostPageOverride(
        routeOwner: PodcastPlayerHostRouteOwner.homeShell,
      );
    }

    if (width < 840) {
      return const PodcastPlayerHostPageOverride(
        routeOwner: PodcastPlayerHostRouteOwner.homeShell,
        overlayLeftInset: _tabletSidebarWidth + _tabletContentGap,
        overlayRightInset: _desktopContentRightInset,
      );
    }

    return PodcastPlayerHostPageOverride(
      routeOwner: PodcastPlayerHostRouteOwner.homeShell,
      overlayLeftInset: _desktopNavExpanded ? 280 : 80,
      overlayRightInset: _desktopContentRightInset,
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
    final hasCurrentEpisode = ref.watch(
      audioCurrentEpisodeIdProvider.select((episodeId) => episodeId != null),
    );
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isHomeShellRoute =
        currentRoute == '/' ||
        currentRoute == '/home' ||
        currentRoute.startsWith('/home?') ||
        currentRoute == '/profile' ||
        currentRoute.startsWith('/profile?');

    if (isHomeShellRoute) {
      _syncPlayerHostOverride(_buildPlayerHostOverride(screenWidth));
    }

    return CustomAdaptiveNavigation(
      key: const ValueKey('home_custom_adaptive_navigation'),
      destinations: _buildDestinations(context),
      selectedIndex: _currentIndex,
      onDestinationSelected: _handleNavigation,
      appBar: null,
      floatingActionButton: _buildFloatingActionButton(),
      globalOverlayBodyPadding: hasCurrentEpisode
          ? kPodcastMiniPlayerBodyReserve
          : 0,
      desktopNavExpanded: _desktopNavExpanded,
      onDesktopNavToggle: () {
        setState(() {
          _desktopNavExpanded = !_desktopNavExpanded;
        });
      },
      body: _buildTabContent(),
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
