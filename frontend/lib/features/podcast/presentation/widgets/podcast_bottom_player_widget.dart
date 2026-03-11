import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/route_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../data/models/podcast_episode_model.dart';
import '../constants/playback_speed_options.dart';
import '../constants/podcast_ui_constants.dart';
import '../navigation/podcast_navigation.dart';
import '../providers/podcast_providers.dart';
import 'playback_speed_selector_sheet.dart';
import 'podcast_image_widget.dart';
import 'podcast_queue_sheet.dart';
import 'sleep_timer_selector_sheet.dart';

const _kPlayerTransition = Duration(milliseconds: 220);
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
        duration: _kPlayerTransition,
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
    return PodcastPlayerShell(
      applySafeArea: applySafeArea,
      viewportSpec: viewportSpec,
      embedExpandedInFlow: true,
    );
  }
}

class PodcastPlayerShell extends ConsumerWidget {
  const PodcastPlayerShell({
    super.key,
    this.applySafeArea = true,
    this.viewportSpec,
    this.embedExpandedInFlow = false,
  });

  final bool applySafeArea;
  final PodcastPlayerViewportSpec? viewportSpec;
  final bool embedExpandedInFlow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episode = ref.watch(audioCurrentEpisodeProvider);
    if (episode == null) {
      return const SizedBox.shrink();
    }

    final layout = ref.watch(podcastPlayerHostLayoutProvider);
    final spec =
        viewportSpec ?? resolvePodcastPlayerViewportSpec(context, layout);
    final isExpanded = ref.watch(podcastPlayerExpandedProvider);

    final dock = PodcastPlayerDock(
      episode: episode,
      viewportSpec: spec,
      applySafeArea: applySafeArea,
    );

    final expanded = !isExpanded
        ? const SizedBox.shrink()
        : switch (spec.layoutMode) {
            PodcastPlayerLayoutMode.mobile => PodcastPlayerMobileSheet(
              episode: episode,
              viewportSpec: spec,
              applySafeArea: applySafeArea,
            ),
            PodcastPlayerLayoutMode.tablet ||
            PodcastPlayerLayoutMode.desktop => PodcastPlayerDesktopPanel(
              episode: episode,
              viewportSpec: spec,
              applySafeArea: applySafeArea,
            ),
          };

    if (embedExpandedInFlow) {
      return AnimatedSize(
        duration: _kPlayerTransition,
        curve: Curves.easeOutCubic,
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedSwitcher(
              duration: _kPlayerTransition,
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: isExpanded ? expanded : const SizedBox.shrink(),
            ),
            dock,
          ],
        ),
      );
    }

    return Stack(
      key: const Key('podcast_player_shell'),
      children: [
        Align(alignment: Alignment.bottomCenter, child: dock),
        IgnorePointer(
          ignoring: !isExpanded,
          child: AnimatedSwitcher(
            duration: _kPlayerTransition,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: isExpanded ? expanded : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

class PodcastPlayerDock extends ConsumerWidget {
  const PodcastPlayerDock({
    super.key,
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
        viewportSpec.dockLeftInset + viewportSpec.dockHorizontalPadding,
        viewportSpec.dockTopPadding,
        viewportSpec.dockRightInset + viewportSpec.dockHorizontalPadding,
        viewportSpec.dockBottomOffset,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: viewportSpec.dockMaxWidth),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height: kPodcastGlobalPlayerMobileDockHeight,
            child: Material(
              key: const Key('podcast_bottom_player_mini'),
              color: theme.colorScheme.surface.withValues(alpha: 0.96),
              elevation: 10,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.4,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () =>
                          ref.read(podcastPlayerUiProvider.notifier).expand(),
                      child: _CoverImage(
                        imageUrl:
                            episode.subscriptionImageUrl ?? episode.imageUrl,
                        size: 40,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        key: const Key('podcast_bottom_player_mini_info'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () =>
                            ref.read(podcastPlayerUiProvider.notifier).expand(),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                      progressTrackColor: theme
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.18),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _MiniProgressText(
                                  textStyle:
                                      theme.textTheme.bodySmall?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
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
        ),
      ),
    );

    if (!applySafeArea) {
      return content;
    }

    return SafeArea(top: false, child: content);
  }
}

class PodcastPlayerMobileSheet extends ConsumerStatefulWidget {
  const PodcastPlayerMobileSheet({
    super.key,
    required this.episode,
    required this.viewportSpec,
    required this.applySafeArea,
  });

  final PodcastEpisodeModel episode;
  final PodcastPlayerViewportSpec viewportSpec;
  final bool applySafeArea;

  @override
  ConsumerState<PodcastPlayerMobileSheet> createState() =>
      _PodcastPlayerMobileSheetState();
}

class _PodcastPlayerMobileSheetState
    extends ConsumerState<PodcastPlayerMobileSheet> {
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
      ref.read(podcastPlayerUiProvider.notifier).collapse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: widget.applySafeArea
              ? 0
              : widget.viewportSpec.dockBottomOffset,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: widget.viewportSpec.mobileSheetMaxHeight,
            maxWidth: widget.viewportSpec.dockMaxWidth,
          ),
          child: Material(
            key: const Key('podcast_player_mobile_sheet'),
            color: Theme.of(context).colorScheme.surface,
            elevation: 16,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(
                  widget.viewportSpec.mobileSheetBorderRadius,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                  child: Column(
                    key: const Key('podcast_bottom_player_expanded'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                      _ExpandedHeader(episode: widget.episode),
                      const SizedBox(height: 12),
                      _ExpandedSummary(episode: widget.episode, dense: false),
                      const SizedBox(height: 12),
                      const _ExpandedProgressSection(),
                      const SizedBox(height: 12),
                      const _TransportRow(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return AnimatedSlide(
      duration: _kPlayerTransition,
      curve: Curves.easeOutCubic,
      offset: Offset.zero,
      child: content,
    );
  }
}

class PodcastPlayerDesktopPanel extends StatelessWidget {
  const PodcastPlayerDesktopPanel({
    super.key,
    required this.episode,
    required this.viewportSpec,
    required this.applySafeArea,
  });

  final PodcastEpisodeModel episode;
  final PodcastPlayerViewportSpec viewportSpec;
  final bool applySafeArea;

  @override
  Widget build(BuildContext context) {
    Widget content = Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.only(
          top: viewportSpec.desktopPanelTopInset,
          right: viewportSpec.desktopPanelRightInset,
          bottom: viewportSpec.desktopPanelBottomInset,
        ),
        child: SizedBox(
          width: viewportSpec.desktopPanelWidth,
          child: Material(
            key: const Key('podcast_player_desktop_panel'),
            color: Theme.of(context).colorScheme.surface,
            elevation: 14,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.45),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                key: const Key('podcast_bottom_player_expanded'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ExpandedHeader(episode: episode),
                  const SizedBox(height: 16),
                  _ExpandedSummary(episode: episode, dense: true),
                  const SizedBox(height: 12),
                  const _ExpandedProgressSection(),
                  const SizedBox(height: 12),
                  const _TransportRow(),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (applySafeArea) {
      content = SafeArea(top: false, child: content);
    }

    return AnimatedSlide(
      duration: _kPlayerTransition,
      curve: Curves.easeOutCubic,
      offset: Offset.zero,
      child: content,
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
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n?.podcast_player_now_playing ?? 'Now Playing',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        _PlaybackSpeedChip(
          speed: playbackRate,
          onTap: () => _showSpeedSelector(context, ref),
        ),
        const SizedBox(width: 4),
        IconButton(
          key: const Key('podcast_bottom_player_playlist'),
          tooltip: l10n?.podcast_player_list ?? 'List',
          onPressed: () => _showQueueSheet(context, ref),
          icon: const Icon(Icons.playlist_play),
        ),
        _SleepTimerButton(onPressed: () => _showSleepSelector(context, ref)),
        IconButton(
          key: const Key('podcast_bottom_player_collapse'),
          tooltip: l10n?.podcast_player_collapse ?? 'Collapse',
          onPressed: () =>
              ref.read(podcastPlayerUiProvider.notifier).collapse(),
          icon: const Icon(Icons.keyboard_arrow_down),
        ),
      ],
    );
  }
}

class _ExpandedSummary extends ConsumerWidget {
  const _ExpandedSummary({required this.episode, required this.dense});

  final PodcastEpisodeModel episode;
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurfaceVariant.withValues(
      alpha: 0.78,
    );
    final imageSize = dense ? 68.0 : 84.0;
    final currentLocation = ref.watch(currentRouteProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CoverImage(
          imageUrl: episode.subscriptionImageUrl ?? episode.imageUrl,
          size: imageSize,
        ),
        const SizedBox(width: 14),
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
                  maxLines: dense ? 3 : 4,
                  overflow: TextOverflow.ellipsis,
                  style:
                      (dense
                              ? theme.textTheme.titleMedium
                              : theme.textTheme.titleLarge)
                          ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if ((episode.subscriptionTitle ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      episode.subscriptionTitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
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
    final progress = ref.watch(audioMiniProgressProvider);
    final durationMs = progress.durationMs > 0 ? progress.durationMs : 1;
    final effectivePositionMs = _isScrubbing
        ? _draftPositionMs.clamp(0, durationMs)
        : progress.positionMs;

    return Column(
      children: [
        SliderTheme(
          data: theme.sliderTheme.copyWith(
            activeTrackColor: theme.colorScheme.primary,
            inactiveTrackColor: theme.colorScheme.primary.withValues(
              alpha: 0.2,
            ),
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
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatMilliseconds(effectivePositionMs),
                style: theme.textTheme.bodySmall,
              ),
              Text(
                _formatMilliseconds(progress.durationMs),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
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
              icon: Icons.replay_10,
              tooltipLocalizationKey: _TooltipKey.rewind10,
            ),
          ),
        ),
        SizedBox(width: 12),
        _PlayPauseButtonLarge(),
        SizedBox(width: 12),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: _SkipButton(
              keyValue: 'podcast_bottom_player_forward_30',
              deltaMs: 30000,
              icon: Icons.forward_30,
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
      iconSize: 32,
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
      borderRadius: BorderRadius.circular(10),
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
