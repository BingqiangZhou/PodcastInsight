import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/route_provider.dart';
import '../constants/podcast_ui_constants.dart';
import 'audio_playback_selectors.dart';

@immutable
enum PodcastPlayerHostRouteOwner { any, homeShell, episodeDetail }

@immutable
class PodcastPlayerHostPageOverride {
  const PodcastPlayerHostPageOverride({
    this.routeOwner = PodcastPlayerHostRouteOwner.any,
    this.hiddenByPage = false,
    this.contentBottomInset,
    this.overlayBottomOffset,
    this.overlayLeftInset,
    this.overlayRightInset,
    this.applySafeArea,
  });

  final PodcastPlayerHostRouteOwner routeOwner;
  final bool hiddenByPage;
  final double? contentBottomInset;
  final double? overlayBottomOffset;
  final double? overlayLeftInset;
  final double? overlayRightInset;
  final bool? applySafeArea;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is PodcastPlayerHostPageOverride &&
        other.routeOwner == routeOwner &&
        other.hiddenByPage == hiddenByPage &&
        other.contentBottomInset == contentBottomInset &&
        other.overlayBottomOffset == overlayBottomOffset &&
        other.overlayLeftInset == overlayLeftInset &&
        other.overlayRightInset == overlayRightInset &&
        other.applySafeArea == applySafeArea;
  }

  @override
  int get hashCode => Object.hash(
    routeOwner,
    hiddenByPage,
    contentBottomInset,
    overlayBottomOffset,
    overlayLeftInset,
    overlayRightInset,
    applySafeArea,
  );
}

@immutable
class PodcastPlayerHostLayout {
  const PodcastPlayerHostLayout({
    required this.visible,
    required this.contentBottomInset,
    required this.overlayBottomOffset,
    required this.overlayLeftInset,
    required this.overlayRightInset,
    required this.applySafeArea,
    required this.hiddenByPage,
  });

  final bool visible;
  final double contentBottomInset;
  final double? overlayBottomOffset;
  final double? overlayLeftInset;
  final double? overlayRightInset;
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
    contentBottomInset:
        pageOverride?.contentBottomInset ?? kPodcastMiniPlayerBodyReserve,
    overlayBottomOffset: pageOverride?.overlayBottomOffset,
    overlayLeftInset: pageOverride?.overlayLeftInset,
    overlayRightInset: pageOverride?.overlayRightInset,
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
      if (route.startsWith('/podcast/episodes/')) {
        return override;
      }
      return null;
  }
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
  return layout.contentBottomInset +
      resolvePodcastPlayerOverlayBottomOffset(
        context,
        override: layout.overlayBottomOffset,
      );
}
