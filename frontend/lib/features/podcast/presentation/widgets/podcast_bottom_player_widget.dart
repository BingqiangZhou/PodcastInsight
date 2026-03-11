import 'dart:async';

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
const _kPlayerDesktopPanelRadius = 28.0;

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

    if (!applySafeArea) {
      return dock;
    }

    return SafeArea(top: false, child: dock);
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
    final isExpanded = ref.watch(podcastPlayerExpandedProvider);
    final hasMiniPlayer = includeMiniPlayer && layout.miniPlayerVisible;
    final showDesktopPanel =
        layout.miniPlayerVisible &&
        layout.pageMode == PodcastPlayerPageMode.embedded &&
        isExpanded &&
        spec.layoutMode != PodcastPlayerLayoutMode.mobile;

    final bottomInset = manageBottomPadding && hasMiniPlayer
        ? resolvePodcastPlayerTotalReservedSpace(context, layout)
        : 0.0;
    final rightInset = manageDesktopPanelPadding && showDesktopPanel
        ? spec.desktopPanelWidth + spec.desktopPanelGap
        : 0.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedPadding(
          duration: _kPlayerTransition,
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(bottom: bottomInset, right: rightInset),
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
        if (showDesktopPanel)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.only(
                right: spec.desktopPanelGap,
                top: spec.desktopPanelGap,
                bottom: spec.desktopPanelGap,
              ),
              child: SizedBox(
                width: spec.desktopPanelWidth,
                child: _PodcastDesktopPanel(
                  episode: ref.watch(audioCurrentEpisodeProvider)!,
                  viewportSpec: spec,
                ),
              ),
            ),
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () =>
                        _openExpandedPlayer(context, ref, viewportSpec),
                    child: _CoverImage(
                      imageUrl:
                          episode.subscriptionImageUrl ?? episode.imageUrl,
                      size: 48,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      key: const Key('podcast_bottom_player_mini_info'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () =>
                          _openExpandedPlayer(context, ref, viewportSpec),
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
                          const SizedBox(height: 3),
                          Text(
                            episode.subscriptionTitle ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: _MiniProgressIndicator(
                                    progressColor: theme.colorScheme.primary,
                                    progressTrackColor: theme
                                        .colorScheme
                                        .surfaceContainerHighest,
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
                    key: const Key('podcast_bottom_player_mini_play_pause'),
                    iconColor: theme.colorScheme.onSurfaceVariant,
                    pauseTooltip: l10n?.podcast_player_pause ?? 'Pause',
                    playTooltip: l10n?.podcast_player_play ?? 'Play',
                  ),
                  IconButton(
                    key: const Key('podcast_bottom_player_mini_playlist'),
                    tooltip: l10n?.podcast_player_list ?? 'List',
                    onPressed: () => _showQueueSheet(context, ref),
                    icon: const Icon(Icons.playlist_play_rounded),
                  ),
                ],
              ),
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

class _PodcastDesktopPanel extends StatelessWidget {
  const _PodcastDesktopPanel({
    required this.episode,
    required this.viewportSpec,
  });

  final PodcastEpisodeModel episode;
  final PodcastPlayerViewportSpec viewportSpec;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      key: const Key('podcast_player_desktop_panel'),
      color: theme.colorScheme.surface,
      elevation: 8,
      shadowColor: theme.shadowColor.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_kPlayerDesktopPanelRadius),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.48),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(viewportSpec.desktopPanelInnerPadding),
        child: SingleChildScrollView(
          child: Column(
            key: const Key('podcast_bottom_player_expanded'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ExpandedHeader(episode: episode, mobile: false),
              const SizedBox(height: 18),
              _ExpandedHero(episode: episode, compact: false),
              const SizedBox(height: 18),
              const _ExpandedProgressSection(),
              const SizedBox(height: 16),
              const _TransportRow(),
            ],
          ),
        ),
      ),
    );
  }
}

class _PodcastMobileDrawer extends StatelessWidget {
  const _PodcastMobileDrawer({
    required this.episode,
    required this.viewportSpec,
  });

  final PodcastEpisodeModel episode;
  final PodcastPlayerViewportSpec viewportSpec;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      key: const Key('podcast_player_mobile_sheet'),
      color: theme.colorScheme.surface,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(viewportSpec.mobileDrawerBorderRadius),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
            child: Column(
              key: const Key('podcast_bottom_player_expanded'),
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: GestureDetector(
                    key: const Key('podcast_bottom_player_drag_handle'),
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragEnd: (_) => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _ExpandedHeader(episode: episode, mobile: true),
                const SizedBox(height: 18),
                _ExpandedHero(episode: episode, compact: true),
                const SizedBox(height: 18),
                const _ExpandedProgressSection(),
                const SizedBox(height: 16),
                const _TransportRow(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpandedHeader extends ConsumerWidget {
  const _ExpandedHeader({required this.episode, required this.mobile});

  final PodcastEpisodeModel episode;
  final bool mobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final playbackRate = ref.watch(audioPlaybackRateProvider);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n?.podcast_player_now_playing ?? 'Now Playing',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                mobile ? 'Player' : 'Playback Console',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        _PlaybackSpeedChip(
          speed: playbackRate,
          onTap: () => _showSpeedSelector(context, ref),
        ),
        const SizedBox(width: 6),
        IconButton(
          key: const Key('podcast_bottom_player_playlist'),
          tooltip: l10n?.podcast_player_list ?? 'List',
          onPressed: () => _showQueueSheet(context, ref),
          icon: const Icon(Icons.playlist_play_rounded),
        ),
        _SleepTimerButton(onPressed: () => _showSleepSelector(context, ref)),
        IconButton(
          key: const Key('podcast_bottom_player_collapse'),
          tooltip: l10n?.podcast_player_collapse ?? 'Collapse',
          onPressed: () {
            Navigator.of(context).maybePop();
            ref.read(podcastPlayerUiProvider.notifier).collapse();
          },
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }
}

class _ExpandedHero extends ConsumerWidget {
  const _ExpandedHero({required this.episode, required this.compact});

  final PodcastEpisodeModel episode;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurfaceVariant;
    final imageSize = compact ? 96.0 : 88.0;
    final currentLocation = ref.watch(currentRouteProvider);

    return Container(
      padding: EdgeInsets.all(compact ? 16 : 18),
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
          const SizedBox(width: 16),
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
                    maxLines: compact ? 3 : 4,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if ((episode.subscriptionTitle ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      episode.subscriptionTitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MetaPill(
                        icon: Icons.calendar_today_outlined,
                        label: episode.publishedAt.toString().split(' ')[0],
                      ),
                      _MetaPill(
                        icon: Icons.access_time_rounded,
                        label: episode.formattedDuration,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.36),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
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
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
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
    return Row(
      children: const [
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: _SkipButton(
              keyValue: 'podcast_bottom_player_rewind_10',
              deltaMs: -10000,
              icon: Icons.replay_10_rounded,
              tooltipLocalizationKey: _TooltipKey.rewind10,
            ),
          ),
        ),
        SizedBox(width: 14),
        _PlayPauseButtonLarge(),
        SizedBox(width: 14),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: _SkipButton(
              keyValue: 'podcast_bottom_player_forward_30',
              deltaMs: 30000,
              icon: Icons.forward_30_rounded,
              tooltipLocalizationKey: _TooltipKey.forward30,
            ),
          ),
        ),
      ],
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(
            formatPlaybackSpeed(speed),
            style: theme.textTheme.labelLarge?.copyWith(
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
      icon: Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(-1.0, 1.0, 1.0),
        child: Icon(
          isActive ? Icons.bedtime_rounded : Icons.bedtime_outlined,
          color: isActive
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
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
        iconSize: 46,
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

Future<void> _openExpandedPlayer(
  BuildContext context,
  WidgetRef ref,
  PodcastPlayerViewportSpec spec,
) async {
  if (spec.layoutMode == PodcastPlayerLayoutMode.mobile) {
    final currentEpisode = ref.read(audioCurrentEpisodeProvider);
    if (currentEpisode == null) {
      return;
    }
    final notifier = ref.read(podcastPlayerUiProvider.notifier);
    notifier.expand();
    final modalContext = _resolveNavigatorContext(context);
    await showModalBottomSheet<void>(
      context: modalContext,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: _PodcastMobileDrawer(
            episode: currentEpisode,
            viewportSpec: spec,
          ),
        );
      },
    );
    notifier.collapse();
    return;
  }

  ref.read(podcastPlayerUiProvider.notifier).expand();
}

Future<void> _showSpeedSelector(BuildContext context, WidgetRef ref) async {
  final playbackRate = ref.read(audioPlaybackRateProvider);
  final selection = await showPlaybackSpeedSelectorSheet(
    context: _resolveNavigatorContext(context),
    initialSpeed: playbackRate,
  );
  if (selection == null) {
    return;
  }
  await ref
      .read(audioPlayerProvider.notifier)
      .setPlaybackRate(
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
  final queueController = ref.read(podcastQueueControllerProvider.notifier);
  final queueState = ref.read(podcastQueueControllerProvider);

  if (queueState.isLoading) {
    await queueController.refreshQueueInBackground();
  } else {
    unawaited(queueController.refreshQueueInBackground());
  }

  if (!modalContext.mounted) {
    return;
  }

  await showModalBottomSheet<void>(
    context: modalContext,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const PodcastQueueSheet(),
  );
}
