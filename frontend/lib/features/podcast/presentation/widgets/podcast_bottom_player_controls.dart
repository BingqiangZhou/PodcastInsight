part of 'podcast_bottom_player_widget.dart';

class _TransportRow extends StatelessWidget {
  const _TransportRow();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Speed chip: isolated Consumer — only rebuilds when rate changes.
        Consumer(
          builder: (context, ref, _) {
            return RepaintBoundary(
              child: _PlaybackSpeedChip(
                speed: ref.watch(audioPlaybackRateProvider),
                onTap: () => _showSpeedSelector(context, ref),
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        // Skip/play-pause: static buttons — no progress watch.
        const RepaintBoundary(
          child: _SkipButton(
            keyValue: 'podcast_bottom_player_rewind_10',
            deltaMs: -10000,
            icon: Icons.replay_10_rounded,
            tooltipLocalizationKey: _TooltipKey.rewind10,
          ),
        ),
        const SizedBox(width: 10),
        const RepaintBoundary(
          child: _PlayPauseButtonLarge(),
        ),
        const SizedBox(width: 10),
        const RepaintBoundary(
          child: _SkipButton(
            keyValue: 'podcast_bottom_player_forward_30',
            deltaMs: 30000,
            icon: Icons.forward_30_rounded,
            tooltipLocalizationKey: _TooltipKey.forward30,
          ),
        ),
        const SizedBox(width: 8),
        // Queue button: isolated Consumer — only rebuilds when sheet state changes.
        Consumer(
          builder: (context, ref, _) {
            final queueSheetOpen =
                ref.watch(podcastPlayerQueueSheetOpenProvider);
            return IconButton(
              key: const Key('podcast_bottom_player_playlist'),
              tooltip: l10n?.podcast_player_list ?? 'List',
              onPressed: queueSheetOpen
                  ? null
                  : () => _showQueueSheet(context, ref),
              icon: const Icon(Icons.playlist_play_rounded),
            );
          },
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
      color: Colors.transparent,
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
      icon: Transform.flip(
        flipX: true,
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
    final tooltip = switch (tooltipLocalizationKey) {
      _TooltipKey.rewind10 => l10n?.podcast_player_rewind_10 ?? 'Rewind 10s',
      _TooltipKey.forward30 => l10n?.podcast_player_forward_30 ?? 'Forward 30s',
    };

    return IconButton(
      key: Key(keyValue),
      tooltip: tooltip,
      iconSize: 30,
      onPressed: () {
        // Use ref.read to avoid rebuilding on every progress tick (500ms).
        // Position is only needed at tap time, not reactively.
        final progress = ref.read(audioMiniProgressProvider);
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
    return RepaintBoundary(
      child: LinearProgressIndicator(
        key: const Key('podcast_bottom_player_mini_progress'),
        value: progress.progress,
        minHeight: 4,
        color: progressColor,
        backgroundColor: progressTrackColor,
      ),
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
