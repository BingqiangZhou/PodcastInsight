import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/providers/route_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/app_logger.dart' as logger;
import '../../../../core/utils/time_formatter.dart';
import '../../data/models/podcast_episode_model.dart';
import '../constants/playback_speed_options.dart';
import '../navigation/podcast_navigation.dart';
import '../providers/podcast_providers.dart';
import 'playback_speed_selector_sheet.dart';
import 'podcast_image_widget.dart';
import 'podcast_queue_sheet.dart';
import 'sleep_timer_selector_sheet.dart';

part 'podcast_bottom_player_actions.dart';
part 'podcast_bottom_player_controls.dart';
part 'podcast_bottom_player_layouts.dart';

const _kPlayerTransition = Duration(milliseconds: 220);

class PodcastBottomPlayerWidget extends ConsumerWidget {
  const PodcastBottomPlayerWidget({
    super.key,
    this.applySafeArea = true,
    this.viewportSpec,
    this.episodeOverride,
    this.layoutOverride,
    this.isExpandedOverride,
  });

  final bool applySafeArea;
  final PodcastPlayerViewportSpec? viewportSpec;
  final PodcastEpisodeModel? episodeOverride;
  final PodcastPlayerHostLayout? layoutOverride;
  final bool? isExpandedOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PodcastEpisodeModel? episode =
        episodeOverride ?? ref.watch(audioCurrentEpisodeProvider);
    final PodcastPlayerHostLayout layout =
        layoutOverride ?? ref.watch(podcastPlayerHostLayoutProvider);
    final bool isExpanded =
        isExpandedOverride ?? ref.watch(podcastPlayerExpandedProvider);
    if (episode == null || !layout.miniPlayerVisible) {
      return const SizedBox.shrink();
    }

    final spec =
        viewportSpec ?? resolvePodcastPlayerViewportSpec(context, layout);
    final dock = _PodcastMiniDock(
      episode: episode,
      viewportSpec: spec,
      applySafeArea: applySafeArea,
    );

    final wrapped = IgnorePointer(
      ignoring: isExpanded,
      child: AnimatedSlide(
        duration: _kPlayerTransition,
        curve: Curves.easeOutCubic,
        offset: isExpanded ? const Offset(0, 0.14) : Offset.zero,
        child: AnimatedOpacity(
          duration: _kPlayerTransition,
          curve: Curves.easeOutCubic,
          opacity: isExpanded ? 0 : 1,
          child: dock,
        ),
      ),
    );

    if (!applySafeArea) {
      return wrapped;
    }

    return SafeArea(top: false, child: wrapped);
  }
}

class PodcastPlayerLayoutFrame extends ConsumerWidget {
  const PodcastPlayerLayoutFrame({
    super.key,
    required this.child,
    this.includeMiniPlayer = true,
    this.manageBottomPadding = true,
    this.manageDesktopPanelPadding = true,
    this.applyMiniPlayerSafeArea = true,
  });

  final Widget child;
  final bool includeMiniPlayer;
  final bool manageBottomPadding;
  final bool manageDesktopPanelPadding;
  final bool applyMiniPlayerSafeArea;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(podcastPlayerHostLayoutProvider);
    final spec = resolvePodcastPlayerViewportSpec(context, layout);
    final episode = ref.watch(audioCurrentEpisodeProvider);
    final isExpanded = ref.watch(podcastPlayerExpandedProvider);
    final hasMiniPlayer = includeMiniPlayer && layout.miniPlayerVisible;
    final canShowExpandedOverlay =
        episode != null && layout.pageMode == PodcastPlayerPageMode.embedded;

    final bottomInset = manageBottomPadding && hasMiniPlayer
        ? resolvePodcastPlayerTotalReservedSpace(context, layout)
        : 0.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasMiniPlayer &&
            manageBottomPadding &&
            bottomInset > 0 &&
            spec.surfaceContext != PodcastPlayerSurfaceContext.homeShell)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: bottomInset,
            child: _ReservedBottomBackground(height: bottomInset),
          ),
        AnimatedPadding(
          duration: _kPlayerTransition,
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(bottom: bottomInset),
          child: child,
        ),
        if (hasMiniPlayer)
          Align(
            alignment: Alignment.bottomCenter,
            child: PodcastBottomPlayerWidget(
              applySafeArea: applyMiniPlayerSafeArea,
              viewportSpec: spec,
              episodeOverride: episode,
              layoutOverride: layout,
              isExpandedOverride: isExpanded,
            ),
          ),
        if (canShowExpandedOverlay)
          _PodcastExpandedOverlay(
            episode: episode,
            viewportSpec: spec,
            visible: isExpanded,
            applySafeArea: applyMiniPlayerSafeArea,
          ),
      ],
    );
  }
}
