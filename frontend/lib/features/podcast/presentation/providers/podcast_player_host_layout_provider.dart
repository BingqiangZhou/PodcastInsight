import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/breakpoints.dart';
import '../../../../core/providers/route_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../constants/podcast_ui_constants.dart';
import 'audio_playback_selectors.dart';

@immutable
enum PodcastPlayerHostRouteOwner { any, homeShell, episodeDetail }

@immutable
enum PodcastPlayerLayoutMode { mobile, tablet, desktop }

@immutable
enum PodcastPlayerSurfaceContext { standard, homeShell, episodeDetail }

@immutable
class PodcastPlayerViewportSpec {
  const PodcastPlayerViewportSpec({
    required this.layoutMode,
    required this.surfaceContext,
    required this.leftInset,
    required this.rightInset,
    required this.bottomOffset,
    required this.contentBottomInset,
    required this.miniHorizontalPadding,
    required this.miniTopPadding,
    required this.maxPlayerWidth,
    required this.fullScreenHorizontalPadding,
  });

  final PodcastPlayerLayoutMode layoutMode;
  final PodcastPlayerSurfaceContext surfaceContext;
  final double leftInset;
  final double rightInset;
  final double bottomOffset;
  final double contentBottomInset;
  final double miniHorizontalPadding;
  final double miniTopPadding;
  final double maxPlayerWidth;
  final double fullScreenHorizontalPadding;
}

@immutable
class PodcastPlayerHostPageOverride {
  const PodcastPlayerHostPageOverride({
    this.routeOwner = PodcastPlayerHostRouteOwner.any,
    this.surfaceContext,
    this.homeShellDesktopNavExpanded,
    this.hiddenByPage = false,
    this.contentBottomInset,
    this.overlayBottomOffset,
    this.applySafeArea,
  });

  final PodcastPlayerHostRouteOwner routeOwner;
  final PodcastPlayerSurfaceContext? surfaceContext;
  final bool? homeShellDesktopNavExpanded;
  final bool hiddenByPage;
  final double? contentBottomInset;
  final double? overlayBottomOffset;
  final bool? applySafeArea;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is PodcastPlayerHostPageOverride &&
        other.routeOwner == routeOwner &&
        other.surfaceContext == surfaceContext &&
        other.homeShellDesktopNavExpanded == homeShellDesktopNavExpanded &&
        other.hiddenByPage == hiddenByPage &&
        other.contentBottomInset == contentBottomInset &&
        other.overlayBottomOffset == overlayBottomOffset &&
        other.applySafeArea == applySafeArea;
  }

  @override
  int get hashCode => Object.hash(
    routeOwner,
    surfaceContext,
    homeShellDesktopNavExpanded,
    hiddenByPage,
    contentBottomInset,
    overlayBottomOffset,
    applySafeArea,
  );
}

@immutable
class PodcastPlayerHostLayout {
  const PodcastPlayerHostLayout({
    required this.visible,
    required this.surfaceContext,
    required this.homeShellDesktopNavExpanded,
    required this.contentBottomInset,
    required this.overlayBottomOffset,
    required this.applySafeArea,
    required this.hiddenByPage,
  });

  final bool visible;
  final PodcastPlayerSurfaceContext surfaceContext;
  final bool homeShellDesktopNavExpanded;
  final double contentBottomInset;
  final double? overlayBottomOffset;
  final bool applySafeArea;
  final bool hiddenByPage;
}

class PodcastPlayerHostPageOverrideNotifier
    extends Notifier<PodcastPlayerHostPageOverride?> {
  @override
  PodcastPlayerHostPageOverride? build() {
    return null;
  }

  void setOverride(PodcastPlayerHostPageOverride override) {
    state = override;
  }

  void clearOverride() {
    state = null;
  }

  void clearOverrideIfMatches(PodcastPlayerHostPageOverride? expected) {
    if (state == expected) {
      state = null;
    }
  }
}

final podcastPlayerHostPageOverrideProvider =
    NotifierProvider<
      PodcastPlayerHostPageOverrideNotifier,
      PodcastPlayerHostPageOverride?
    >(PodcastPlayerHostPageOverrideNotifier.new);

final podcastPlayerHostLayoutProvider = Provider<PodcastPlayerHostLayout>((
  ref,
) {
  final currentEpisodeId = ref.watch(audioCurrentEpisodeIdProvider);
  final route = ref.watch(currentRouteProvider);
  final rawPageOverride = ref.watch(podcastPlayerHostPageOverrideProvider);
  final pageOverride = _appliedOverrideForRoute(rawPageOverride, route);

  final hiddenByRoute =
      route.contains('/podcast/') && route.contains('/player');
  final hiddenByPage = pageOverride?.hiddenByPage ?? false;

  return PodcastPlayerHostLayout(
    visible: currentEpisodeId != null && !hiddenByRoute && !hiddenByPage,
    surfaceContext: _resolveSurfaceContext(route, pageOverride),
    homeShellDesktopNavExpanded:
        pageOverride?.homeShellDesktopNavExpanded ?? true,
    contentBottomInset:
        pageOverride?.contentBottomInset ?? kPodcastMiniPlayerBodyReserve,
    overlayBottomOffset: pageOverride?.overlayBottomOffset,
    applySafeArea: pageOverride?.applySafeArea ?? false,
    hiddenByPage: hiddenByPage,
  );
});

PodcastPlayerHostPageOverride? _appliedOverrideForRoute(
  PodcastPlayerHostPageOverride? override,
  String route,
) {
  if (override == null) {
    return null;
  }

  switch (override.routeOwner) {
    case PodcastPlayerHostRouteOwner.any:
      return override;
    case PodcastPlayerHostRouteOwner.homeShell:
      if (route == '/' ||
          route == '/home' ||
          route.startsWith('/home?') ||
          route == '/profile' ||
          route.startsWith('/profile?')) {
        return override;
      }
      return null;
    case PodcastPlayerHostRouteOwner.episodeDetail:
      if (isPodcastEpisodeDetailRoute(route)) {
        return override;
      }
      return null;
  }
}

bool isHomeShellRoute(String route) {
  return route == '/' ||
      route == '/home' ||
      route.startsWith('/home?') ||
      route == '/profile' ||
      route.startsWith('/profile?');
}

bool isPodcastEpisodeDetailRoute(String route) {
  return route.startsWith('/podcast/episodes/') ||
      route.startsWith('/podcast/episode/detail/');
}

PodcastPlayerSurfaceContext _resolveSurfaceContext(
  String route,
  PodcastPlayerHostPageOverride? override,
) {
  if (override?.surfaceContext case final surfaceContext?) {
    return surfaceContext;
  }
  if (isPodcastEpisodeDetailRoute(route)) {
    return PodcastPlayerSurfaceContext.episodeDetail;
  }
  if (isHomeShellRoute(route)) {
    return PodcastPlayerSurfaceContext.homeShell;
  }
  return PodcastPlayerSurfaceContext.standard;
}

PodcastPlayerLayoutMode resolvePodcastPlayerLayoutMode(double width) {
  if (width < AppBreakpoints.medium) {
    return PodcastPlayerLayoutMode.mobile;
  }
  if (width < AppBreakpoints.mediumLarge) {
    return PodcastPlayerLayoutMode.tablet;
  }
  return PodcastPlayerLayoutMode.desktop;
}

PodcastPlayerViewportSpec resolvePodcastPlayerViewportSpec(
  BuildContext context,
  PodcastPlayerHostLayout layout, {
  String? route,
}) {
  final width = MediaQuery.sizeOf(context).width;
  final layoutMode = resolvePodcastPlayerLayoutMode(width);
  final bottomOffset = resolvePodcastPlayerOverlayBottomOffset(
    context,
    override: layout.overlayBottomOffset,
  );
  final surfaceContext = route == null
      ? layout.surfaceContext
      : _resolveSurfaceContext(route, null);

  double leftInset = 0;
  double rightInset = 0;
  double miniHorizontalPadding = 0;
  double miniTopPadding = 4;
  double fullScreenHorizontalPadding =
      layoutMode == PodcastPlayerLayoutMode.mobile ? 16 : 24;

  switch (layoutMode) {
    case PodcastPlayerLayoutMode.mobile:
      miniHorizontalPadding = 20;
      miniTopPadding = 0;
      break;
    case PodcastPlayerLayoutMode.tablet:
      if (surfaceContext == PodcastPlayerSurfaceContext.homeShell) {
        leftInset = 98;
        rightInset = 12;
      }
      break;
    case PodcastPlayerLayoutMode.desktop:
      switch (surfaceContext) {
        case PodcastPlayerSurfaceContext.homeShell:
          leftInset = layout.homeShellDesktopNavExpanded ? 280 : 80;
          rightInset = 12;
          break;
        case PodcastPlayerSurfaceContext.episodeDetail:
          leftInset = 216;
          rightInset = 32;
          break;
        case PodcastPlayerSurfaceContext.standard:
          break;
      }
      break;
  }

  final maxPlayerWidth = _resolvePlayerMaxWidth(
    context,
    layoutMode: layoutMode,
    availableWidth: width - leftInset - rightInset,
    horizontalPadding: fullScreenHorizontalPadding,
  );

  return PodcastPlayerViewportSpec(
    layoutMode: layoutMode,
    surfaceContext: surfaceContext,
    leftInset: leftInset,
    rightInset: rightInset,
    bottomOffset: bottomOffset,
    contentBottomInset: layout.contentBottomInset,
    miniHorizontalPadding: miniHorizontalPadding,
    miniTopPadding: miniTopPadding,
    maxPlayerWidth: maxPlayerWidth,
    fullScreenHorizontalPadding: fullScreenHorizontalPadding,
  );
}

double _resolvePlayerMaxWidth(
  BuildContext context, {
  required PodcastPlayerLayoutMode layoutMode,
  required double availableWidth,
  required double horizontalPadding,
}) {
  final themeTokens =
      Theme.of(context).extension<MindriverThemeExtension>() ??
      MindriverThemeExtension.light;
  final maxContentWidth = switch (layoutMode) {
    PodcastPlayerLayoutMode.mobile => availableWidth,
    PodcastPlayerLayoutMode.tablet => 920.0,
    PodcastPlayerLayoutMode.desktop => themeTokens.contentMaxWidth,
  };
  final paddedWidth =
      MediaQuery.sizeOf(context).width - (horizontalPadding * 2);
  return [
    availableWidth,
    maxContentWidth,
    paddedWidth,
  ].reduce((value, element) => value < element ? value : element);
}

double resolvePodcastPlayerOverlayBottomOffset(
  BuildContext context, {
  double? override,
}) {
  if (override != null) {
    return override;
  }

  final screenWidth = MediaQuery.sizeOf(context).width;
  if (screenWidth >= 600) {
    return kPodcastGlobalPlayerDesktopBottomOffset;
  }

  final safeAreaBottom = MediaQuery.viewPaddingOf(context).bottom;
  final dockBottomPadding = safeAreaBottom > 0.0
      ? safeAreaBottom
      : kPodcastGlobalPlayerMobileViewportPadding;
  return dockBottomPadding +
      kPodcastGlobalPlayerMobileDockHeight +
      kPodcastGlobalPlayerMobileDockGap;
}

double resolvePodcastPlayerTotalReservedSpace(
  BuildContext context,
  PodcastPlayerHostLayout layout,
) {
  final spec = resolvePodcastPlayerViewportSpec(context, layout);
  return spec.contentBottomInset + spec.bottomOffset;
}
