import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_ai_assistant/core/constants/breakpoints.dart';
import 'package:personal_ai_assistant/core/providers/route_provider.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/constants/podcast_ui_constants.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/audio_playback_selectors.dart';

enum PodcastPlayerHostRouteOwner { any, homeShell, episodeDetail }

enum PodcastPlayerLayoutMode { mobile, tablet, desktop }

enum PodcastPlayerSurfaceContext { standard, homeShell, episodeDetail }

enum PodcastPlayerPageMode { embedded, hidden }

@immutable
class PodcastPlayerViewportSpec {
  const PodcastPlayerViewportSpec({
    required this.layoutMode,
    required this.surfaceContext,
    required this.pageMode,
    required this.dockBottomSpacing,
    required this.contentBottomInset,
    required this.dockHorizontalPadding,
    required this.dockTopPadding,
    required this.dockMaxWidth,
    required this.desktopPanelWidth,
    required this.desktopPanelGap,
    required this.desktopPanelInnerPadding,
    required this.mobileDrawerMaxHeight,
    required this.mobileDrawerBorderRadius,
    required this.fullScreenHorizontalPadding,
  });

  final PodcastPlayerLayoutMode layoutMode;
  final PodcastPlayerSurfaceContext surfaceContext;
  final PodcastPlayerPageMode pageMode;
  final double dockBottomSpacing;
  final double contentBottomInset;
  final double dockHorizontalPadding;
  final double dockTopPadding;
  final double dockMaxWidth;
  final double desktopPanelWidth;
  final double desktopPanelGap;
  final double desktopPanelInnerPadding;
  final double mobileDrawerMaxHeight;
  final double mobileDrawerBorderRadius;
  final double fullScreenHorizontalPadding;

  double get leftInset => 0;
  double get rightInset => 0;
  double get bottomOffset => dockBottomSpacing;
  double get miniHorizontalPadding => dockHorizontalPadding;
  double get miniTopPadding => dockTopPadding;
  double get maxPlayerWidth => dockMaxWidth;
}

@immutable
class PodcastPlayerHostPageOverride {
  const PodcastPlayerHostPageOverride({
    this.routeOwner = PodcastPlayerHostRouteOwner.any,
    this.pageMode = PodcastPlayerPageMode.embedded,
    this.surfaceContext,
    this.homeShellDesktopNavExpanded,
    this.contentBottomInset,
  });

  final PodcastPlayerHostRouteOwner routeOwner;
  final PodcastPlayerPageMode pageMode;
  final PodcastPlayerSurfaceContext? surfaceContext;
  final bool? homeShellDesktopNavExpanded;
  final double? contentBottomInset;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is PodcastPlayerHostPageOverride &&
        other.routeOwner == routeOwner &&
        other.pageMode == pageMode &&
        other.surfaceContext == surfaceContext &&
        other.homeShellDesktopNavExpanded == homeShellDesktopNavExpanded &&
        other.contentBottomInset == contentBottomInset;
  }

  @override
  int get hashCode => Object.hash(
    routeOwner,
    pageMode,
    surfaceContext,
    homeShellDesktopNavExpanded,
    contentBottomInset,
  );
}

@immutable
class PodcastPlayerHostLayout {
  const PodcastPlayerHostLayout({
    required this.hasActiveEpisode,
    required this.pageMode,
    required this.surfaceContext,
    required this.homeShellDesktopNavExpanded,
    required this.contentBottomInset,
  });

  final bool hasActiveEpisode;
  final PodcastPlayerPageMode pageMode;
  final PodcastPlayerSurfaceContext surfaceContext;
  final bool homeShellDesktopNavExpanded;
  final double contentBottomInset;

  bool get miniPlayerVisible =>
      hasActiveEpisode && pageMode == PodcastPlayerPageMode.embedded;

  bool get hidden => pageMode == PodcastPlayerPageMode.hidden;

  bool get visible => miniPlayerVisible;
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

  return PodcastPlayerHostLayout(
    hasActiveEpisode: currentEpisodeId != null,
    pageMode: pageOverride?.pageMode ?? PodcastPlayerPageMode.embedded,
    surfaceContext: _resolveSurfaceContext(route, pageOverride),
    homeShellDesktopNavExpanded:
        pageOverride?.homeShellDesktopNavExpanded ?? true,
    contentBottomInset:
        pageOverride?.contentBottomInset ?? kPodcastMiniPlayerBodyReserve,
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
      if (isHomeShellRoute(route)) {
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
      route == '/discover' ||
      route.startsWith('/discover?') ||
      route == '/feed' ||
      route.startsWith('/feed?') ||
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
  if (width < Breakpoints.medium) {
    return PodcastPlayerLayoutMode.mobile;
  }
  if (width < Breakpoints.mediumLarge) {
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
  final surfaceContext = route == null
      ? layout.surfaceContext
      : _resolveSurfaceContext(route, null);

  double dockHorizontalPadding = 0;
  double dockTopPadding = 0;
  double dockBottomSpacing = 12;
  double desktopPanelWidth = 0;
  double desktopPanelGap = 20;
  double desktopPanelInnerPadding = 20;
  final fullScreenHorizontalPadding =
      layoutMode == PodcastPlayerLayoutMode.mobile ? 16.0 : 24.0;
  final mobileDrawerMaxHeight = MediaQuery.sizeOf(context).height * 0.88;
  const double mobileDrawerBorderRadius = 30;

  switch (layoutMode) {
    case PodcastPlayerLayoutMode.mobile:
      dockHorizontalPadding = 16;
      dockTopPadding = 0;
      dockBottomSpacing =
          surfaceContext == PodcastPlayerSurfaceContext.homeShell
          ? 0
          : kPodcastGlobalPlayerMobileViewportPadding;
    case PodcastPlayerLayoutMode.tablet:
      dockHorizontalPadding = 16;
      dockBottomSpacing = 16;
      desktopPanelWidth = 356;
      desktopPanelGap = 18;
      desktopPanelInnerPadding = 18;
    case PodcastPlayerLayoutMode.desktop:
      desktopPanelWidth =
          surfaceContext == PodcastPlayerSurfaceContext.episodeDetail
          ? 380
          : 360;
      dockHorizontalPadding = 16;
      dockBottomSpacing = 16;
      desktopPanelGap = surfaceContext == PodcastPlayerSurfaceContext.homeShell
          ? 20
          : 24;
      desktopPanelInnerPadding = 20;
  }

  final dockMaxWidth = _resolvePlayerMaxWidth(
    context,
    layoutMode: layoutMode,
    availableWidth: width,
    horizontalPadding: fullScreenHorizontalPadding,
  );

  return PodcastPlayerViewportSpec(
    layoutMode: layoutMode,
    surfaceContext: surfaceContext,
    pageMode: layout.pageMode,
    dockBottomSpacing: dockBottomSpacing,
    contentBottomInset: layout.contentBottomInset,
    dockHorizontalPadding: dockHorizontalPadding,
    dockTopPadding: dockTopPadding,
    dockMaxWidth: dockMaxWidth,
    desktopPanelWidth: desktopPanelWidth,
    desktopPanelGap: desktopPanelGap,
    desktopPanelInnerPadding: desktopPanelInnerPadding,
    mobileDrawerMaxHeight: mobileDrawerMaxHeight,
    mobileDrawerBorderRadius: mobileDrawerBorderRadius,
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
      Theme.of(context).extension<AppThemeExtension>() ??
      AppThemeExtension.light;
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

double resolvePodcastPlayerTotalReservedSpace(
  BuildContext context,
  PodcastPlayerHostLayout layout,
) {
  final spec = resolvePodcastPlayerViewportSpec(context, layout);
  if (!layout.miniPlayerVisible) {
    return 0;
  }
  return spec.contentBottomInset;
}
