part of 'podcast_bottom_player_widget.dart';

class _ReservedBottomBackground extends StatelessWidget {
  const _ReservedBottomBackground({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = appThemeOf(context);
    final baseColor = Color.alphaBlend(
      theme.colorScheme.surface.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.20 : 0.28,
      ),
      theme.scaffoldBackgroundColor,
    );

    return IgnorePointer(
      child: SizedBox(
        key: const Key('podcast_player_reserved_background'),
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: baseColor,
                gradient: tokens.shellGradient,
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    baseColor.withValues(alpha: 0),
                    baseColor.withValues(alpha: 0.52),
                    baseColor,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
    final l10n = context.l10n;
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
            color: Colors.transparent,
            elevation: 4,
            shadowColor: Colors.black.withValues(alpha: 0.15),
            borderRadius: AppRadius.lgRadius,
            clipBehavior: Clip.antiAlias,
            child: _MiniDockBody(
              episode: episode,
              onExpand: () => _openExpandedPlayer(ref),
              showPrimaryKeys: true,
              pauseTooltip: l10n.podcast_player_pause,
              playTooltip: l10n.podcast_player_play,
              listTooltip: l10n.podcast_player_list,
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
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final extension = appThemeOf(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15),
          width: 0.5,
        ),
        borderRadius: AppRadius.lgRadius,
      ),
      padding: EdgeInsets.fromLTRB(context.spacing.md, context.spacing.sm, context.spacing.smMd, context.spacing.sm),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: l10n.player_expand_player,
            child: GestureDetector(
              onTap: onExpand,
              child: RepaintBoundary(
                child: _CoverImage(
                  imageUrl: episode.subscriptionImageUrl ?? episode.imageUrl,
                  size: 48,
                ),
              ),
            ),
          ),
          SizedBox(width: context.spacing.md),
          Expanded(
            child: Semantics(
              button: true,
              label: episode.title,
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
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                      fontSize: Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14,
                    ),
                  ),
                  SizedBox(height: context.spacing.xs),
                  // Isolate progress repaints (500ms ticks) from the rest of the dock.
                  RepaintBoundary(
                    child: Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: AppRadius.pillRadius,
                            child: const _MiniProgressIndicator(),
                          ),
                        ),
                        SizedBox(width: context.spacing.sm),
                        const _MiniProgressText(),
                      ],
                    ),
                  ),
                ],
              ),
              ),
            ),
          ),
          SizedBox(width: context.spacing.sm),
          const _MiniPlayPauseButton(
            key: Key('podcast_bottom_player_mini_play_pause'),
          ),
          SizedBox(width: context.spacing.sm),
          // Queue button: isolated Consumer so the dock body does not
          // rebuild when queue-sheet state changes.
          Consumer(
            builder: (context, ref, _) {
              final queueSheetOpen =
                  ref.watch(podcastPlayerQueueSheetOpenProvider);
              return IconButton(
                key: showPrimaryKeys
                    ? const Key('podcast_bottom_player_mini_playlist')
                    : const ValueKey(
                        'podcast_bottom_player_mini_playlist_overlay',
                      ),
                tooltip: listTooltip,
                onPressed: queueSheetOpen
                    ? null
                    : () => _showQueueSheet(context, ref),
                icon: Icon(Icons.playlist_play_rounded, color: theme.colorScheme.onSurface),
                iconSize: 24,
              );
            },
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
              child: Container(
                key: visible ? const Key('podcast_player_mobile_sheet') : null,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(viewportSpec.mobileDrawerBorderRadius),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: _ExpandedPanelContent(
                    episode: episode,
                    showPrimaryKeys: visible,
                  ),
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
      padding: EdgeInsets.fromLTRB(context.spacing.md, context.spacing.smMd, context.spacing.md, context.spacing.md),
      child: Column(
        key: showPrimaryKeys
            ? const Key('podcast_bottom_player_expanded')
            : null,
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  borderRadius: AppRadius.pillRadius,
                ),
              ),
            ),
          ),
          SizedBox(height: context.spacing.smMd),
          _ExpandedHeader(episode: episode),
          SizedBox(height: context.spacing.smMd),
          _ExpandedHero(episode: episode),
          SizedBox(height: context.spacing.smMd),
          const _ExpandedProgressSection(),
          SizedBox(height: context.spacing.smMd),
          const RepaintBoundary(
            child: _TransportRow(),
          ),
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
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.podcast_player_now_playing,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        _SleepTimerButton(onPressed: () => _showSleepSelector(context, ref)),
        IconButton(
          key: const Key('podcast_bottom_player_collapse'),
          tooltip: l10n.podcast_player_collapse,
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
    const imageSize = 72.0;
    final currentLocation = ref.watch(currentRouteProvider);

    return Row(
      key: const Key('podcast_bottom_player_expanded_hero'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KeyedSubtree(
          key: const Key('podcast_bottom_player_expanded_cover'),
          child: RepaintBoundary(
            child: _CoverImage(
              imageUrl: episode.subscriptionImageUrl ?? episode.imageUrl,
              size: imageSize,
            ),
          ),
        ),
        SizedBox(width: context.spacing.smMd),
        Expanded(
          child: GestureDetector(
            key: const Key('podcast_bottom_player_expanded_title'),
            behavior: HitTestBehavior.opaque,
            onTap: () {
              var resolvedCurrentLocation = currentLocation;
              try {
                resolvedCurrentLocation = GoRouterState.of(context).uri.toString();
              } catch (e) {
                logger.AppLogger.debug('[BottomPlayer] Failed to get current route: $e');
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
            child: SizedBox(
              key: const Key('podcast_bottom_player_expanded_text_block'),
              height: imageSize,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final titleStyle = theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  );
                  final isSingleLineTitle = _isSingleLineTitle(
                    context,
                    titleStyle,
                    constraints.maxWidth,
                  );
                  return Column(
                    key: const Key(
                      'podcast_bottom_player_expanded_text_column',
                    ),
                    mainAxisAlignment: isSingleLineTitle
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        key: const Key(
                          'podcast_bottom_player_expanded_title_text',
                        ),
                        episode.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                      SizedBox(height: context.spacing.sm),
                      Text(
                        key: const Key('podcast_bottom_player_expanded_meta'),
                        _buildEpisodeMetaLine(episode),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool _isSingleLineTitle(
    BuildContext context,
    TextStyle? titleStyle,
    double maxWidth,
  ) {
    if (!maxWidth.isFinite || maxWidth <= 0) {
      return false;
    }
    final painter = TextPainter(
      text: TextSpan(text: episode.title, style: titleStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: 2,
    )..layout(maxWidth: maxWidth);
    return painter.computeLineMetrics().length <= 1;
  }

  String _buildEpisodeMetaLine(PodcastEpisodeModel episode) {
    final subscriptionTitle = episode.subscriptionTitle;
    final trimmedTitle = subscriptionTitle?.trim();
    final parts = <String>[
      if (trimmedTitle != null && trimmedTitle.isNotEmpty) trimmedTitle,
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

    return Column(
      key: const Key('podcast_bottom_player_expanded_progress'),
      children: [
        RepaintBoundary(
          child: SliderTheme(
            data: theme.sliderTheme.copyWith(
              activeTrackColor: theme.colorScheme.primary,
              inactiveTrackColor: Colors.transparent,
              thumbColor: theme.colorScheme.primary,
              overlayColor: theme.colorScheme.primary.withValues(alpha: 0.12),
              trackHeight: 3,
            ),
            child: Slider.adaptive(
              key: const Key('podcast_bottom_player_progress_slider'),
              value: effectivePositionMs.clamp(0, durationMs).toDouble(),
              max: durationMs.toDouble(),
              onChangeStart: _startScrub,
              onChanged: _updateScrub,
              onChangeEnd: _finishScrub,
            ),
          ),
        ),
        RepaintBoundary(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: context.spacing.xxs),
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
        ),
      ],
    );
  }
}
