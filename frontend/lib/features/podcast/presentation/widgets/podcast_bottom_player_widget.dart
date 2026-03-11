import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/route_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../data/models/podcast_episode_model.dart';
import '../constants/playback_speed_options.dart';
import '../navigation/podcast_navigation.dart';
import '../providers/podcast_providers.dart';
import 'playback_speed_selector_sheet.dart';
import 'podcast_image_widget.dart';
import 'podcast_queue_sheet.dart';
import 'sleep_timer_selector_sheet.dart';

const _kPlayerTransition = Duration(milliseconds: 220);

class PodcastBottomPlayerWidget extends ConsumerWidget {
  const PodcastBottomPlayerWidget({
    super.key,
    this.applySafeArea = true,
    this.viewportSpec,
  });

  final bool applySafeArea;
  final PodcastPlayerViewportSpec? viewportSpec;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episode = ref.watch(audioCurrentEpisodeProvider);
    final layout = ref.watch(podcastPlayerHostLayoutProvider);
    final isExpanded = ref.watch(podcastPlayerExpandedProvider);
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
            ),
          ),
        if (canShowExpandedOverlay)
          _PodcastExpandedOverlay(
            episode: episode!,
            viewportSpec: spec,
            visible: isExpanded,
            applySafeArea: applyMiniPlayerSafeArea,
          ),
      ],
    );
  }
}

class _PodcastMiniDock extends ConsumerWidget {
  const _PodcastMiniDock({
    required this.episode,
    required this.viewportSpec,
    required this.applySafeArea,
  });

  final PodcastEpisodeModel episode;
  final PodcastPlayerViewportSpec viewportSpec;
  final bool applySafeArea;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final content = Padding(
      key: const Key('podcast_bottom_player_mini_wrapper'),
      padding: EdgeInsets.fromLTRB(
        viewportSpec.dockHorizontalPadding,
        viewportSpec.dockTopPadding,
        viewportSpec.dockHorizontalPadding,
        viewportSpec.dockBottomSpacing,
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: viewportSpec.dockMaxWidth),
          child: Material(
            key: const Key('podcast_bottom_player_mini'),
            color: theme.colorScheme.surfaceContainerLow,
            elevation: 4,
            shadowColor: theme.shadowColor.withValues(alpha: 0.10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: _MiniDockBody(
              episode: episode,
              onExpand: () => _openExpandedPlayer(ref),
              showPrimaryKeys: true,
              pauseTooltip: l10n?.podcast_player_pause ?? 'Pause',
              playTooltip: l10n?.podcast_player_play ?? 'Play',
              listTooltip: l10n?.podcast_player_list ?? 'List',
            ),
          ),
        ),
      ),
    );

    if (!applySafeArea) {
      return content;
    }
    return SafeArea(top: false, child: content);
  }
}

class _MiniDockBody extends ConsumerWidget {
  const _MiniDockBody({
    required this.episode,
    required this.onExpand,
    required this.showPrimaryKeys,
    required this.pauseTooltip,
    required this.playTooltip,
    required this.listTooltip,
  });

  final PodcastEpisodeModel episode;
  final VoidCallback onExpand;
  final bool showPrimaryKeys;
  final String pauseTooltip;
  final String playTooltip;
  final String listTooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final queueSheetOpen = ref.watch(podcastPlayerQueueSheetOpenProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: onExpand,
            child: _CoverImage(
              imageUrl: episode.subscriptionImageUrl ?? episode.imageUrl,
              size: 48,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              key: showPrimaryKeys
                  ? const Key('podcast_bottom_player_mini_info')
                  : null,
              behavior: HitTestBehavior.opaque,
              onTap: onExpand,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    episode.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: _MiniProgressIndicator(
                            progressColor: theme.colorScheme.primary,
                            progressTrackColor:
                                theme.colorScheme.surfaceContainerHighest,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _MiniProgressText(
                        textStyle:
                            theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ) ??
                            const TextStyle(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _MiniPlayPauseButton(
            key: showPrimaryKeys
                ? const Key('podcast_bottom_player_mini_play_pause')
                : const ValueKey(
                    'podcast_bottom_player_mini_play_pause_overlay',
                  ),
            iconColor: theme.colorScheme.onSurfaceVariant,
            pauseTooltip: pauseTooltip,
            playTooltip: playTooltip,
          ),
          const SizedBox(width: 6),
          IconButton(
            key: showPrimaryKeys
                ? const Key('podcast_bottom_player_mini_playlist')
                : const ValueKey('podcast_bottom_player_mini_playlist_overlay'),
            tooltip: listTooltip,
            onPressed: queueSheetOpen
                ? null
                : () => _showQueueSheet(context, ref),
            icon: const Icon(Icons.playlist_play_rounded),
          ),
        ],
      ),
    );
  }
}

class _PodcastExpandedOverlay extends ConsumerWidget {
  const _PodcastExpandedOverlay({
    required this.episode,
    required this.viewportSpec,
    required this.visible,
    required this.applySafeArea,
  });

  final PodcastEpisodeModel episode;
  final PodcastPlayerViewportSpec viewportSpec;
  final bool visible;
  final bool applySafeArea;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mediaSize = MediaQuery.sizeOf(context);
    final maxPanelWidth = math.min(
      mediaSize.width - (viewportSpec.dockHorizontalPadding * 2),
      viewportSpec.layoutMode == PodcastPlayerLayoutMode.mobile
          ? double.infinity
          : 720.0,
    );
    final surface = Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          viewportSpec.dockHorizontalPadding,
          viewportSpec.dockTopPadding,
          viewportSpec.dockHorizontalPadding,
          viewportSpec.dockBottomSpacing,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxPanelWidth),
          child: AnimatedSlide(
            duration: _kPlayerTransition,
            curve: Curves.easeOutCubic,
            offset: visible ? Offset.zero : const Offset(0, 1.08),
            child: AnimatedOpacity(
              duration: _kPlayerTransition,
              curve: Curves.easeOutCubic,
              opacity: visible ? 1 : 0,
              child: Material(
                key: visible ? const Key('podcast_player_mobile_sheet') : null,
                color: theme.colorScheme.surface,
                elevation: 10,
                shadowColor: theme.shadowColor.withValues(alpha: 0.16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    viewportSpec.mobileDrawerBorderRadius,
                  ),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.56,
                    ),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: _ExpandedPanelContent(
                  episode: episode,
                  showPrimaryKeys: visible,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final overlay = Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          ignoring: !visible,
          child: AnimatedOpacity(
            duration: _kPlayerTransition,
            curve: Curves.easeOutCubic,
            opacity: visible ? 1 : 0,
            child: GestureDetector(
              onTap: () =>
                  ref.read(podcastPlayerUiProvider.notifier).collapse(),
              child: ColoredBox(
                color: theme.colorScheme.scrim.withValues(alpha: 0.22),
              ),
            ),
          ),
        ),
        IgnorePointer(ignoring: !visible, child: surface),
      ],
    );

    if (!applySafeArea) {
      return overlay;
    }

    return SafeArea(top: false, child: overlay);
  }
}

class _ExpandedPanelContent extends StatelessWidget {
  const _ExpandedPanelContent({
    required this.episode,
    required this.showPrimaryKeys,
  });

  final PodcastEpisodeModel episode;
  final bool showPrimaryKeys;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        key: showPrimaryKeys
            ? const Key('podcast_bottom_player_expanded')
            : null,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: GestureDetector(
              key: showPrimaryKeys
                  ? const Key('podcast_bottom_player_drag_handle')
                  : null,
              behavior: HitTestBehavior.opaque,
              onVerticalDragEnd: (_) => ProviderScope.containerOf(
                context,
                listen: false,
              ).read(podcastPlayerUiProvider.notifier).collapse(),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _ExpandedHeader(episode: episode),
          const SizedBox(height: 10),
          _ExpandedHero(episode: episode),
          const SizedBox(height: 10),
          const _ExpandedProgressSection(),
          const SizedBox(height: 10),
          const _TransportRow(),
        ],
      ),
    );
  }
}

class _ExpandedHeader extends ConsumerWidget {
  const _ExpandedHeader({required this.episode});

  final PodcastEpisodeModel episode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final playbackRate = ref.watch(audioPlaybackRateProvider);
    final queueSheetOpen = ref.watch(podcastPlayerQueueSheetOpenProvider);
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n?.podcast_player_now_playing ?? 'Now Playing',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        IconButton(
          key: const Key('podcast_bottom_player_playlist'),
          tooltip: l10n?.podcast_player_list ?? 'List',
          onPressed: queueSheetOpen
              ? null
              : () => _showQueueSheet(context, ref),
          icon: const Icon(Icons.playlist_play_rounded),
        ),
        IconButton(
          key: const Key('podcast_bottom_player_collapse'),
          tooltip: l10n?.podcast_player_collapse ?? 'Collapse',
          onPressed: () =>
              ref.read(podcastPlayerUiProvider.notifier).collapse(),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }
}

class _ExpandedHero extends ConsumerWidget {
  const _ExpandedHero({required this.episode});

  final PodcastEpisodeModel episode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurfaceVariant;
    final imageSize = 72.0;
    final currentLocation = ref.watch(currentRouteProvider);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CoverImage(
            imageUrl: episode.subscriptionImageUrl ?? episode.imageUrl,
            size: imageSize,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              key: const Key('podcast_bottom_player_expanded_title'),
              behavior: HitTestBehavior.opaque,
              onTap: () {
                String resolvedCurrentLocation = currentLocation;
                try {
                  resolvedCurrentLocation = GoRouterState.of(
                    context,
                  ).uri.toString();
                } catch (_) {}
                final episodeDetailPath =
                    '/podcast/episodes/${episode.subscriptionId}/${episode.id}';
                if (resolvedCurrentLocation.startsWith(episodeDetailPath)) {
                  return;
                }
                PodcastNavigation.goToEpisodeDetail(
                  context,
                  episodeId: episode.id,
                  subscriptionId: episode.subscriptionId,
                  episodeTitle: episode.title,
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    episode.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _buildEpisodeMetaLine(episode),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildEpisodeMetaLine(PodcastEpisodeModel episode) {
    final parts = <String>[
      if ((episode.subscriptionTitle ?? '').trim().isNotEmpty)
        episode.subscriptionTitle!.trim(),
      episode.publishedAt.toString().split(' ')[0],
      episode.formattedDuration,
    ];
    return parts.join('  ·  ');
  }
}

class _ExpandedProgressSection extends ConsumerStatefulWidget {
  const _ExpandedProgressSection();

  @override
  ConsumerState<_ExpandedProgressSection> createState() =>
      _ExpandedProgressSectionState();
}

class _ExpandedProgressSectionState
    extends ConsumerState<_ExpandedProgressSection> {
  bool _isScrubbing = false;
  int _draftPositionMs = 0;

  void _startScrub(double value) {
    setState(() {
      _isScrubbing = true;
      _draftPositionMs = value.round();
    });
  }

  void _updateScrub(double value) {
    setState(() {
      _draftPositionMs = value.round();
    });
  }

  Future<void> _finishScrub(double value) async {
    final targetPosition = value.round();
    setState(() {
      _draftPositionMs = targetPosition;
    });
    await ref.read(audioPlayerProvider.notifier).seekTo(targetPosition);
    if (!mounted) {
      return;
    }
    setState(() {
      _isScrubbing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = ref.watch(audioMiniProgressProvider);
    final durationMs = progress.durationMs > 0 ? progress.durationMs : 1;
    final effectivePositionMs = _isScrubbing
        ? _draftPositionMs.clamp(0, durationMs)
        : progress.positionMs;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.42),
        ),
      ),
      child: Column(
        children: [
          SliderTheme(
            data: theme.sliderTheme.copyWith(
              activeTrackColor: theme.colorScheme.primary,
              inactiveTrackColor: theme.colorScheme.surfaceContainerHighest,
              thumbColor: theme.colorScheme.primary,
              overlayColor: theme.colorScheme.primary.withValues(alpha: 0.12),
              trackHeight: 3,
            ),
            child: Slider(
              key: const Key('podcast_bottom_player_progress_slider'),
              value: effectivePositionMs.clamp(0, durationMs).toDouble(),
              max: durationMs.toDouble(),
              onChangeStart: _startScrub,
              onChanged: _updateScrub,
              onChangeEnd: _finishScrub,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatMilliseconds(effectivePositionMs),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _formatMilliseconds(progress.durationMs),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransportRow extends StatelessWidget {
  const _TransportRow();

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _PlaybackSpeedChip(
              speed: ref.watch(audioPlaybackRateProvider),
              onTap: () => _showSpeedSelector(context, ref),
            ),
            const SizedBox(width: 8),
            const _SkipButton(
              keyValue: 'podcast_bottom_player_rewind_10',
              deltaMs: -10000,
              icon: Icons.replay_10_rounded,
              tooltipLocalizationKey: _TooltipKey.rewind10,
            ),
            const SizedBox(width: 10),
            const _PlayPauseButtonLarge(),
            const SizedBox(width: 10),
            const _SkipButton(
              keyValue: 'podcast_bottom_player_forward_30',
              deltaMs: 30000,
              icon: Icons.forward_30_rounded,
              tooltipLocalizationKey: _TooltipKey.forward30,
            ),
            const SizedBox(width: 8),
            _SleepTimerButton(
              onPressed: () => _showSleepSelector(context, ref),
            ),
          ],
        );
      },
    );
  }
}

class _PlaybackSpeedChip extends StatelessWidget {
  const _PlaybackSpeedChip({required this.speed, required this.onTap});

  final double speed;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: const Key('podcast_bottom_player_speed'),
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            formatPlaybackSpeed(speed),
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _SleepTimerButton extends ConsumerWidget {
  const _SleepTimerButton({required this.onPressed});

  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isActive = ref.watch(audioSleepTimerActiveProvider);
    final theme = Theme.of(context);

    return IconButton(
      key: const Key('podcast_bottom_player_sleep'),
      tooltip: l10n?.podcast_player_sleep_mode ?? 'Sleep Mode',
      onPressed: onPressed,
      icon: Icon(
        isActive ? Icons.bedtime_rounded : Icons.bedtime_outlined,
        color: isActive
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

enum _TooltipKey { rewind10, forward30 }

class _SkipButton extends ConsumerWidget {
  const _SkipButton({
    required this.keyValue,
    required this.deltaMs,
    required this.icon,
    required this.tooltipLocalizationKey,
  });

  final String keyValue;
  final int deltaMs;
  final IconData icon;
  final _TooltipKey tooltipLocalizationKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final progress = ref.watch(audioMiniProgressProvider);
    final tooltip = switch (tooltipLocalizationKey) {
      _TooltipKey.rewind10 => l10n?.podcast_player_rewind_10 ?? 'Rewind 10s',
      _TooltipKey.forward30 => l10n?.podcast_player_forward_30 ?? 'Forward 30s',
    };

    return IconButton(
      key: Key(keyValue),
      tooltip: tooltip,
      iconSize: 30,
      onPressed: () {
        final next = (progress.positionMs + deltaMs).clamp(
          0,
          progress.durationMs,
        );
        ref.read(audioPlayerProvider.notifier).seekTo(next);
      },
      icon: Icon(icon),
    );
  }
}

class _PlayPauseButtonLarge extends ConsumerWidget {
  const _PlayPauseButtonLarge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transport = ref.watch(audioPlayPauseStateProvider);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        key: const Key('podcast_bottom_player_play_pause'),
        iconSize: 42,
        tooltip: transport.isPlaying
            ? (l10n?.podcast_player_pause ?? 'Pause')
            : (l10n?.podcast_player_play ?? 'Play'),
        onPressed: () async {
          if (transport.isLoading) {
            return;
          }
          if (transport.isPlaying) {
            await ref.read(audioPlayerProvider.notifier).pause();
          } else {
            await ref.read(audioPlayerProvider.notifier).resume();
          }
        },
        icon: transport.isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 3),
              )
            : Icon(
                transport.isPlaying ? Icons.pause_rounded : Icons.play_arrow,
              ),
      ),
    );
  }
}

class _MiniPlayPauseButton extends ConsumerWidget {
  const _MiniPlayPauseButton({
    required super.key,
    required this.iconColor,
    required this.pauseTooltip,
    required this.playTooltip,
  });

  final Color iconColor;
  final String pauseTooltip;
  final String playTooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transport = ref.watch(audioPlayPauseStateProvider);
    return IconButton(
      key: key,
      tooltip: transport.isPlaying ? pauseTooltip : playTooltip,
      onPressed: () async {
        if (transport.isLoading) {
          return;
        }
        if (transport.isPlaying) {
          await ref.read(audioPlayerProvider.notifier).pause();
        } else {
          await ref.read(audioPlayerProvider.notifier).resume();
        }
      },
      style: IconButton.styleFrom(
        minimumSize: const Size(40, 40),
        maximumSize: const Size(40, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        foregroundColor: iconColor,
      ),
      icon: transport.isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              transport.isPlaying
                  ? Icons.pause_circle_outline_rounded
                  : Icons.play_circle_outline_rounded,
              size: 28,
            ),
    );
  }
}

class _MiniProgressIndicator extends ConsumerWidget {
  const _MiniProgressIndicator({
    required this.progressColor,
    required this.progressTrackColor,
  });

  final Color progressColor;
  final Color progressTrackColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(audioMiniProgressProvider);
    return LinearProgressIndicator(
      key: const Key('podcast_bottom_player_mini_progress'),
      value: progress.progress,
      minHeight: 4,
      color: progressColor,
      backgroundColor: progressTrackColor,
    );
  }
}

class _MiniProgressText extends ConsumerWidget {
  const _MiniProgressText({required this.textStyle});

  final TextStyle textStyle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(audioMiniProgressProvider);
    return Text(
      key: const Key('podcast_bottom_player_mini_time'),
      '${progress.formattedPosition} / ${progress.formattedDuration}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: textStyle,
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.imageUrl, required this.size});

  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: size,
        height: size,
        child: PodcastImageWidget(
          imageUrl: imageUrl,
          width: size,
          height: size,
          iconSize: size * 0.5,
        ),
      ),
    );
  }
}

BuildContext _resolveNavigatorContext(BuildContext context) {
  final navContext = appNavigatorKey.currentContext;
  if (navContext != null && navContext.mounted) {
    return navContext;
  }
  return context;
}

void _openExpandedPlayer(WidgetRef ref) {
  ref.read(podcastPlayerUiProvider.notifier).expand();
}

Future<void> _showSpeedSelector(BuildContext context, WidgetRef ref) async {
  final notifier = ref.read(audioPlayerProvider.notifier);
  final selectionState = await notifier
      .resolvePlaybackRateSelectionForCurrentContext();
  final selection = await showPlaybackSpeedSelectorSheet(
    context: _resolveNavigatorContext(context),
    initialSpeed: selectionState.speed,
    initialApplyToSubscription: selectionState.applyToSubscription,
  );
  if (selection == null) {
    return;
  }
  await notifier.setPlaybackRate(
    selection.speed,
    applyToSubscription: selection.applyToSubscription,
  );
}

Future<void> _showSleepSelector(BuildContext context, WidgetRef ref) async {
  final isTimerActive = ref.read(audioSleepTimerActiveProvider);
  final selection = await showSleepTimerSelectorSheet(
    context: _resolveNavigatorContext(context),
    isTimerActive: isTimerActive,
  );
  if (selection == null) {
    return;
  }

  final notifier = ref.read(audioPlayerProvider.notifier);
  if (selection.cancel) {
    notifier.cancelSleepTimer();
  } else if (selection.afterEpisode) {
    notifier.setSleepTimerAfterEpisode();
  } else if (selection.duration != null) {
    notifier.setSleepTimer(selection.duration!);
  }
}

String _formatMilliseconds(int value) {
  final duration = Duration(milliseconds: value.clamp(0, 1 << 31));
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

Future<void> _showQueueSheet(BuildContext context, WidgetRef ref) async {
  final modalContext = _resolveNavigatorContext(context);
  if (!modalContext.mounted) {
    return;
  }

  final uiNotifier = ref.read(podcastPlayerUiProvider.notifier);
  final uiState = ref.read(podcastPlayerUiProvider);
  if (uiState.queueSheetOpen) {
    return;
  }

  final queueController = ref.read(podcastQueueControllerProvider.notifier);
  final queueState = ref.read(podcastQueueControllerProvider);

  uiNotifier.openQueueSheet();
  try {
    final showFuture = PodcastQueueSheet.show(modalContext);
    unawaited(
      queueController
          .loadQueue(forceRefresh: queueState.hasValue)
          .catchError((_) => null),
    );
    await showFuture;
  } finally {
    uiNotifier.closeQueueSheet();
  }
}
