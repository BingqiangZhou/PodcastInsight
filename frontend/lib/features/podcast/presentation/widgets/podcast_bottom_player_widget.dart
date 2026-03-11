import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/route_provider.dart';
import '../../data/models/podcast_episode_model.dart';
import '../../data/models/podcast_queue_model.dart';
import '../constants/playback_speed_options.dart';
import '../constants/podcast_ui_constants.dart';
import '../navigation/podcast_navigation.dart';
import '../providers/podcast_providers.dart';
import 'playback_speed_selector_sheet.dart';
import 'podcast_image_widget.dart';
import 'podcast_queue_sheet.dart';
import 'sleep_timer_selector_sheet.dart';

const _kMiniPlayerTransition = Duration(milliseconds: 200);
const _kPlayerModalScrimOpacity = 0.18;
const _kPlayerDragDismissThreshold = 56.0;

class PodcastPlayerModalBarrier extends StatelessWidget {
  const PodcastPlayerModalBarrier({
    super.key,
    required this.visible,
    required this.onDismiss,
    this.interactive = true,
  });

  final bool visible;
  final VoidCallback onDismiss;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible || !interactive,
      child: AnimatedOpacity(
        duration: _kMiniPlayerTransition,
        curve: Curves.easeOutCubic,
        opacity: visible ? 1 : 0,
        child: GestureDetector(
          key: const Key('podcast_player_modal_barrier'),
          behavior: HitTestBehavior.opaque,
          onTap: onDismiss,
          child: ColoredBox(
            color: Colors.black.withValues(alpha: _kPlayerModalScrimOpacity),
          ),
        ),
      ),
    );
  }
}

class PodcastExpandedPlayerPanel extends StatelessWidget {
  const PodcastExpandedPlayerPanel({
    super.key,
    required this.episode,
    this.onCollapse,
    this.showDragHandle = false,
    this.constrainHeight = false,
    this.fullScreen = false,
    this.padding,
    this.elevation = 8,
    this.borderRadius,
  });

  final PodcastEpisodeModel episode;
  final VoidCallback? onCollapse;
  final bool showDragHandle;
  final bool constrainHeight;
  final bool fullScreen;
  final EdgeInsetsGeometry? padding;
  final double elevation;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final effectivePadding =
        padding ??
        EdgeInsets.fromLTRB(
          fullScreen ? 20 : 12,
          showDragHandle ? 10 : 16,
          fullScreen ? 20 : 12,
          fullScreen ? 18 : 10,
        );

    Widget child = SingleChildScrollView(
      child: Padding(
        padding: effectivePadding,
        child: _ExpandedPlayerContent(
          episode: episode,
          onCollapse: onCollapse,
          showDragHandle: showDragHandle,
          fullScreen: fullScreen,
        ),
      ),
    );

    if (constrainHeight) {
      child = ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.48,
        ),
        child: child,
      );
    }

    return Material(
      key: key,
      color: Theme.of(context).colorScheme.surface,
      elevation: elevation,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius:
            borderRadius ??
            (fullScreen
                ? BorderRadius.circular(24)
                : BorderRadius.circular(20)),
      ),
      child: child,
    );
  }
}

class PodcastBottomPlayerWidget extends ConsumerWidget {
  const PodcastBottomPlayerWidget({super.key, this.applySafeArea = true});

  final bool applySafeArea;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episode = ref.watch(audioCurrentEpisodeProvider);
    if (episode == null) {
      return const SizedBox.shrink();
    }
    final isExpanded = ref.watch(
      audioPlayerProvider.select((state) => state.isExpanded),
    );

    Widget content = AnimatedSwitcher(
      duration: _kMiniPlayerTransition,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: isExpanded
          ? PodcastExpandedPlayerPanel(
              key: const ValueKey('expanded'),
              episode: episode,
              showDragHandle: true,
              constrainHeight: true,
              onCollapse: () =>
                  ref.read(audioPlayerProvider.notifier).setExpanded(false),
            )
          : _MiniBottomPlayer(key: const ValueKey('mini'), episode: episode),
    );

    if (applySafeArea) {
      content = SafeArea(top: false, child: content);
    }

    return AnimatedSize(
      duration: _kMiniPlayerTransition,
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: content,
    );
  }
}

class _MiniBottomPlayer extends ConsumerWidget {
  const _MiniBottomPlayer({super.key, required this.episode});

  final PodcastEpisodeModel episode;
  static const double _miniHeight = kPodcastMiniPlayerHeight;
  static const double _mobileHorizontalInset = 20;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideLayout = screenWidth >= 600;
    final isMobileLayout = !isWideLayout;
    final horizontalInset = isMobileLayout ? _mobileHorizontalInset : 0.0;
    final progressColor = theme.colorScheme.onSurfaceVariant;
    final progressTrackColor = theme.colorScheme.onSurfaceVariant.withValues(
      alpha: 0.25,
    );

    return Padding(
      key: const Key('podcast_bottom_player_mini_wrapper'),
      padding: EdgeInsets.fromLTRB(
        horizontalInset,
        isWideLayout ? 4 : 0,
        horizontalInset,
        0,
      ),
      child: SizedBox(
        height: _miniHeight,
        child: Material(
          key: const Key('podcast_bottom_player_mini'),
          color: theme.colorScheme.surface,
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kPodcastMiniCornerRadius),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () =>
                      ref.read(audioPlayerProvider.notifier).setExpanded(true),
                  child: _CoverImage(
                    imageUrl: episode.subscriptionImageUrl ?? episode.imageUrl,
                    size: 42,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    key: const Key('podcast_bottom_player_mini_info'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => ref
                        .read(audioPlayerProvider.notifier)
                        .setExpanded(true),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          episode.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: _MiniProgressIndicator(
                                  progressColor: progressColor,
                                  progressTrackColor: progressTrackColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _MiniProgressText(
                              textStyle:
                                  theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
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
                  icon: const Icon(Icons.playlist_play),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpandedPlayerContent extends ConsumerStatefulWidget {
  const _ExpandedPlayerContent({
    required this.episode,
    required this.showDragHandle,
    required this.fullScreen,
    this.onCollapse,
  });

  final PodcastEpisodeModel episode;
  final VoidCallback? onCollapse;
  final bool showDragHandle;
  final bool fullScreen;

  @override
  ConsumerState<_ExpandedPlayerContent> createState() =>
      _ExpandedPlayerContentState();
}

class _ExpandedPlayerContentState
    extends ConsumerState<_ExpandedPlayerContent> {
  double _dragOffset = 0;

  void _onDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    if (delta <= 0) {
      return;
    }
    _dragOffset += delta;
  }

  void _onDragEnd(DragEndDetails details) {
    final shouldCollapse = _dragOffset >= _kPlayerDragDismissThreshold;
    _dragOffset = 0;
    if (shouldCollapse) {
      widget.onCollapse?.call();
    }
  }

  Future<void> _showSpeedSelector() async {
    final playbackRate = ref.read(audioPlaybackRateProvider);
    final selection = await showPlaybackSpeedSelectorSheet(
      context: context,
      initialSpeed: playbackRate,
    );
    if (!mounted || selection == null) {
      return;
    }

    await ref
        .read(audioPlayerProvider.notifier)
        .setPlaybackRate(
          selection.speed,
          applyToSubscription: selection.applyToSubscription,
        );
  }

  Future<void> _showSleepSelector() async {
    final isTimerActive = ref.read(audioSleepTimerActiveProvider);
    final selection = await showSleepTimerSelectorSheet(
      context: context,
      isTimerActive: isTimerActive,
    );
    if (!mounted || selection == null) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      key: const Key('podcast_bottom_player_expanded'),
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showDragHandle)
          GestureDetector(
            key: const Key('podcast_bottom_player_drag_handle'),
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: _onDragUpdate,
            onVerticalDragEnd: _onDragEnd,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.35,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        Row(
          children: [
            Text(
              l10n?.podcast_player_now_playing ?? 'Now Playing',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            _SleepTimerButton(onPressed: _showSleepSelector),
            if (widget.onCollapse != null)
              IconButton(
                key: const Key('podcast_bottom_player_collapse'),
                tooltip: l10n?.podcast_player_collapse ?? 'Collapse',
                onPressed: widget.onCollapse,
                icon: const Icon(Icons.keyboard_arrow_down),
              ),
          ],
        ),
        _EpisodeSummary(episode: widget.episode, fullScreen: widget.fullScreen),
        const SizedBox(height: 8),
        const _ExpandedProgressSection(),
        const SizedBox(height: 8),
        _ExpandedTransportControls(
          onShowSpeedSelector: _showSpeedSelector,
          onShowQueue: () => _showQueueSheet(context, ref),
        ),
      ],
    );
  }
}

class _EpisodeSummary extends ConsumerWidget {
  const _EpisodeSummary({required this.episode, required this.fullScreen});

  final PodcastEpisodeModel episode;
  final bool fullScreen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurfaceVariant.withValues(
      alpha: 0.72,
    );
    final imageSize = fullScreen ? 76.0 : 52.0;
    final currentLocation = ref.watch(currentRouteProvider);

    return Row(
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
              } catch (_) {
                // Fall back to the globally tracked route when rendered from
                // the player host overlay outside of the route subtree.
              }
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
                  maxLines: fullScreen ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      (fullScreen
                              ? theme.textTheme.titleLarge
                              : theme.textTheme.titleSmall)
                          ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _MetaChip(
                      icon: Icons.calendar_today_outlined,
                      label: episode.publishedAt.toString().split(' ')[0],
                      color: textColor,
                    ),
                    _MetaChip(
                      icon: Icons.access_time,
                      label: episode.formattedDuration,
                      color: textColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: color, fontSize: 11),
        ),
      ],
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
    final miniProgress = ref.watch(audioMiniProgressProvider);
    final sliderActiveColor = theme.colorScheme.onSurfaceVariant;
    final sliderInactiveColor = theme.colorScheme.onSurfaceVariant.withValues(
      alpha: 0.25,
    );
    final durationMs = miniProgress.durationMs > 0
        ? miniProgress.durationMs
        : 1;
    final effectivePositionMs = _isScrubbing
        ? _draftPositionMs.clamp(0, durationMs)
        : miniProgress.positionMs;
    final sliderValue = effectivePositionMs.clamp(0, durationMs).toDouble();

    return Column(
      children: [
        SliderTheme(
          data: theme.sliderTheme.copyWith(
            activeTrackColor: sliderActiveColor,
            inactiveTrackColor: sliderInactiveColor,
            thumbColor: sliderActiveColor,
            overlayColor: sliderActiveColor.withValues(alpha: 0.12),
            valueIndicatorColor: sliderActiveColor,
          ),
          child: Slider(
            key: const Key('podcast_bottom_player_progress_slider'),
            value: sliderValue,
            max: durationMs.toDouble(),
            onChangeStart: _startScrub,
            onChanged: _updateScrub,
            onChangeEnd: _finishScrub,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatMilliseconds(effectivePositionMs),
                style: theme.textTheme.bodySmall,
              ),
              Text(
                _formatMilliseconds(miniProgress.durationMs),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExpandedTransportControls extends StatelessWidget {
  const _ExpandedTransportControls({
    required this.onShowSpeedSelector,
    required this.onShowQueue,
  });

  final Future<void> Function() onShowSpeedSelector;
  final Future<void> Function() onShowQueue;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _PlaybackSpeedChip(onTap: onShowSpeedSelector),
              const SizedBox(width: 8),
              const _SkipButton(
                keyValue: 'podcast_bottom_player_rewind_10',
                deltaMs: -10000,
                icon: Icons.replay_10,
                tooltipLocalizationKey: _TooltipKey.rewind10,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        const _PlayPauseButtonLarge(),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const _SkipButton(
                keyValue: 'podcast_bottom_player_forward_30',
                deltaMs: 30000,
                icon: Icons.forward_30,
                tooltipLocalizationKey: _TooltipKey.forward30,
              ),
              const SizedBox(width: 8),
              _QueueButton(onPressed: onShowQueue),
            ],
          ),
        ),
      ],
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

class _PlaybackSpeedChip extends ConsumerWidget {
  const _PlaybackSpeedChip({required this.onTap});

  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final playbackRate = ref.watch(audioPlaybackRateProvider);

    return Container(
      key: const Key('podcast_bottom_player_speed'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
        color: theme.colorScheme.surface.withValues(alpha: 0.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(
            formatPlaybackSpeed(playbackRate),
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
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
    final miniProgress = ref.watch(audioMiniProgressProvider);
    final tooltip = switch (tooltipLocalizationKey) {
      _TooltipKey.rewind10 => l10n?.podcast_player_rewind_10 ?? 'Rewind 10s',
      _TooltipKey.forward30 => l10n?.podcast_player_forward_30 ?? 'Forward 30s',
    };

    return IconButton(
      key: Key(keyValue),
      tooltip: tooltip,
      iconSize: 32,
      onPressed: () {
        final next = (miniProgress.positionMs + deltaMs).clamp(
          0,
          miniProgress.durationMs,
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
        iconSize: 48,
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
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 3),
              )
            : Icon(transport.isPlaying ? Icons.pause : Icons.play_arrow),
      ),
    );
  }
}

class _QueueButton extends StatelessWidget {
  const _QueueButton({required this.onPressed});

  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      key: const Key('podcast_bottom_player_playlist'),
      tooltip: l10n?.podcast_player_list ?? 'List',
      iconSize: 32,
      onPressed: onPressed,
      icon: const Icon(Icons.playlist_play),
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
    final miniProgress = ref.watch(audioMiniProgressProvider);
    return LinearProgressIndicator(
      key: const Key('podcast_bottom_player_mini_progress'),
      value: miniProgress.progress,
      minHeight: 3,
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
    final miniProgress = ref.watch(audioMiniProgressProvider);
    return Text(
      key: const Key('podcast_bottom_player_mini_time'),
      '${miniProgress.formattedPosition} / ${miniProgress.formattedDuration}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: textStyle,
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
                  ? Icons.pause_circle_outline
                  : Icons.play_circle_outline,
              size: 26,
            ),
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
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: size,
        height: size,
        child: PodcastImageWidget(
          imageUrl: imageUrl,
          width: size,
          height: size,
          iconSize: size * 0.52,
        ),
      ),
    );
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
  final queueController = ref.read(podcastQueueControllerProvider.notifier);
  final queueState = ref.read(podcastQueueControllerProvider);
  if (queueState.hasValue && queueState.value != null) {
    unawaited(queueController.refreshQueueInBackground());
  } else {
    unawaited(
      queueController.loadQueue(forceRefresh: false).catchError((_) {
        // Let the sheet render its own error state if the initial fetch fails.
        return PodcastQueueModel.empty();
      }),
    );
  }
  await PodcastQueueSheet.show(context);
}
