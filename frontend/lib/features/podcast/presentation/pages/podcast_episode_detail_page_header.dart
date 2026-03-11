part of 'podcast_episode_detail_page.dart';

extension _PodcastEpisodeDetailPageHeader on _PodcastEpisodeDetailPageState {
  bool get _isCompactPhoneLayout => MediaQuery.sizeOf(context).width < 600;

  bool get _isUltraCompactPhoneLayout => MediaQuery.sizeOf(context).width < 360;

  HeaderCapsuleActionButtonDensity get _mobilePlayButtonDensity =>
      HeaderCapsuleActionButtonDensity.iconOnly;

  Widget _buildHeader(PodcastEpisodeDetailResponse episode) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: _isHeaderExpanded
          ? _buildHeroHeaderCard(
              episode,
              isWide: false,
              key: ValueKey(
                'podcast_episode_detail_mobile_hero_'
                '$_headerAnimationVersion',
              ),
            )
          : _buildCompactHeaderCard(
              episode,
              isWide: false,
              key: ValueKey(
                'podcast_episode_detail_mobile_compact_'
                '$_headerAnimationVersion',
              ),
            ),
    );
  }

  Widget _buildAnimatedHeader(PodcastEpisodeDetailResponse episode) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: _isHeaderExpanded
          ? _buildHeroHeaderCard(
              episode,
              isWide: true,
              key: ValueKey(
                'podcast_episode_detail_wide_hero_'
                '$_headerAnimationVersion',
              ),
            )
          : _buildCompactHeaderCard(
              episode,
              isWide: true,
              key: ValueKey(
                'podcast_episode_detail_wide_compact_'
                '$_headerAnimationVersion',
              ),
            ),
    );
  }

  Widget _buildHeroHeaderCard(
    PodcastEpisodeDetailResponse episode, {
    required bool isWide,
    Key? key,
  }) {
    final l10n = (AppLocalizations.of(context) ?? AppLocalizationsEn());
    final theme = Theme.of(context);
    final title = episode.title.trim().isEmpty
        ? l10n.episode_unknown_title
        : episode.title;
    final subtitle = _resolvePodcastTitle(episode, l10n);
    final metadata = <Widget>[
      _buildDateChip(episode),
      if (episode.audioDuration != null) _buildDurationChip(episode),
      if (episode.itemLink != null && episode.itemLink!.trim().isNotEmpty)
        _buildSourceLinkChip(
          episode,
          l10n,
          density: isWide
              ? HeaderCapsuleActionButtonDensity.compact
              : HeaderCapsuleActionButtonDensity.iconOnly,
        ),
      if (episode.episodeNumber != null)
        StatusBadge(
          label: 'EP ${episode.episodeNumber}',
          icon: Icons.radio_outlined,
        ),
      if (episode.explicit)
        StatusBadge(
          label: '18+',
          icon: Icons.explicit_outlined,
          color: theme.colorScheme.tertiary,
        ),
    ];

    if (isWide) {
      return GlassPanel(
        key: key,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroArtwork(episode, isWide: true),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: metadata),
                ],
              ),
            ),
            const SizedBox(width: 16),
            _buildWideHeaderActionColumn(episode, l10n),
          ],
        ),
      );
    }

    return GlassPanel(
      key: key,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroArtwork(episode, isWide: false),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: metadata),
          const SizedBox(height: 14),
          _buildHeaderActions(
            episode,
            l10n,
            compact: false,
            includeBack: false,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactHeaderCard(
    PodcastEpisodeDetailResponse episode, {
    required bool isWide,
    Key? key,
  }) {
    final l10n = (AppLocalizations.of(context) ?? AppLocalizationsEn());
    final title = episode.title.trim().isEmpty
        ? l10n.episode_unknown_title
        : episode.title;

    return GlassPanel(
      key: key,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          PodcastImageWidget(
            imageUrl: episode.imageUrl,
            fallbackImageUrl: episode.subscriptionImageUrl,
            width: isWide ? 38 : 34,
            height: isWide ? 38 : 34,
            iconSize: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(episode.publishedAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (isWide) ...[
            _buildCompactHeaderActionRow(episode, l10n, isWide: true),
          ] else
            _buildCompactHeaderActionRow(episode, l10n, isWide: false),
        ],
      ),
    );
  }

  Widget _buildHeroArtwork(
    PodcastEpisodeDetailResponse episode, {
    required bool isWide,
  }) {
    final size = isWide ? 92.0 : 78.0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: PodcastImageWidget(
          imageUrl: episode.imageUrl,
          fallbackImageUrl: episode.subscriptionImageUrl,
          width: size,
          height: size,
          iconSize: size * 0.34,
        ),
      ),
    );
  }

  Widget _buildWideHeaderActionColumn(
    PodcastEpisodeDetailResponse episode,
    AppLocalizations l10n,
  ) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 132, maxWidth: 176),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildQueueButton(),
              const SizedBox(width: 8),
              _buildBackButton(),
            ],
          ),
          const SizedBox(height: 10),
          _buildPlayButton(
            episode,
            l10n,
            compact: false,
            density: HeaderCapsuleActionButtonDensity.regular,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderActions(
    PodcastEpisodeDetailResponse episode,
    AppLocalizations l10n, {
    required bool compact,
    required bool includeBack,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (includeBack) _buildBackButton(),
        _buildPlayButton(
          episode,
          l10n,
          compact: compact,
          density: _mobilePlayButtonDensity,
        ),
        _buildQueueButton(),
      ],
    );
  }

  Widget _buildCompactHeaderActionRow(
    PodcastEpisodeDetailResponse episode,
    AppLocalizations l10n, {
    required bool isWide,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPlayButton(
          episode,
          l10n,
          compact: !isWide,
          density: isWide
              ? HeaderCapsuleActionButtonDensity.regular
              : _mobilePlayButtonDensity,
        ),
        const SizedBox(width: 8),
        _buildQueueButton(),
        if (isWide) ...[const SizedBox(width: 8), _buildBackButton()],
      ],
    );
  }

  String _resolvePodcastTitle(
    PodcastEpisodeDetailResponse episode,
    AppLocalizations l10n,
  ) {
    final subscription = episode.subscription;
    final candidates = <dynamic>[
      subscription?['title'],
      subscription?['name'],
      subscription?['podcast_title'],
      episode.metadata?['podcast_title'],
    ];

    for (final candidate in candidates) {
      final value = candidate?.toString().trim() ?? '';
      if (value.isNotEmpty) {
        return value;
      }
    }

    return l10n.podcast_default_podcast;
  }

  Future<void> _launchEpisodeSource(
    PodcastEpisodeDetailResponse episode,
  ) async {
    final itemLink = episode.itemLink;
    if (itemLink == null || itemLink.trim().isEmpty) {
      return;
    }

    final linkUri = Uri.tryParse(itemLink);
    if (linkUri == null) {
      return;
    }

    if (await canLaunchUrl(linkUri)) {
      await launchUrl(linkUri, mode: LaunchMode.externalApplication);
    }
  }

  PodcastEpisodeModel _episodeToModel(PodcastEpisodeDetailResponse episode) {
    return episode.toEpisodeModel();
  }

  Future<void> _playOrResumeFromDetail(PodcastEpisodeModel episodeModel) async {
    final notifier = ref.read(audioPlayerProvider.notifier);
    final playerState = ref.read(audioPlayerProvider);
    final isSameEpisode = playerState.currentEpisode?.id == episodeModel.id;
    final isCompleted =
        playerState.processingState == ProcessingState.completed;

    if (isSameEpisode && !isCompleted) {
      if (playerState.isPlaying) {
        return;
      }
      await notifier.resume();
      return;
    }

    await notifier.playManagedEpisode(episodeModel);
  }

  Future<void> _addCurrentEpisodeToQueue() async {
    if (_isAddingToQueue) {
      return;
    }
    _updatePageState(() {
      _isAddingToQueue = true;
    });

    try {
      await ref
          .read(podcastQueueControllerProvider.notifier)
          .addToQueue(widget.episodeId);
      if (mounted) {
        final l10n = (AppLocalizations.of(context) ?? AppLocalizationsEn());
        showTopFloatingNotice(
          context,
          message: l10n.added_to_queue,
          extraTopOffset: 72,
        );
      }
    } catch (error) {
      if (mounted) {
        final l10n = (AppLocalizations.of(context) ?? AppLocalizationsEn());
        showTopFloatingNotice(
          context,
          message: l10n.failed_to_add_to_queue(error.toString()),
          isError: true,
          extraTopOffset: 72,
        );
      }
    } finally {
      if (mounted) {
        _updatePageState(() {
          _isAddingToQueue = false;
        });
      }
    }
  }

  Widget _buildPlayButton(
    PodcastEpisodeDetailResponse episode,
    AppLocalizations l10n, {
    required bool compact,
    HeaderCapsuleActionButtonDensity? density,
  }) {
    final effectiveDensity =
        density ??
        (_isUltraCompactPhoneLayout
            ? HeaderCapsuleActionButtonDensity.iconOnly
            : _isCompactPhoneLayout || compact
            ? HeaderCapsuleActionButtonDensity.compact
            : HeaderCapsuleActionButtonDensity.regular);
    final showLabel =
        effectiveDensity != HeaderCapsuleActionButtonDensity.iconOnly;
    final label = showLabel
        ? Text(
            _isCompactPhoneLayout
                ? l10n.podcast_play_episode
                : l10n.podcast_play_episode_full,
          )
        : null;

    return HeaderCapsuleActionButton(
      key: const Key('podcast_episode_detail_play_button'),
      tooltip: l10n.podcast_play_episode_full,
      icon: Icons.play_arrow_rounded,
      density: effectiveDensity,
      label: label,
      onPressed: () {
        unawaited(_playOrResumeFromDetail(_episodeToModel(episode)));
      },
    );
  }

  Widget _buildQueueButton() {
    final theme = Theme.of(context);
    final isCompact = _isCompactPhoneLayout;
    final buttonSize = isCompact ? 36.0 : 40.0;
    final iconSize = isCompact ? 16.0 : 18.0;

    return Tooltip(
      message: (AppLocalizations.of(context) ?? AppLocalizationsEn())
          .podcast_add_to_queue,
      child: Material(
        color: theme.colorScheme.primary.withValues(alpha: 0.09),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(
            color: theme.colorScheme.primary.withValues(alpha: 0.22),
          ),
        ),
        child: InkWell(
          key: const Key('podcast_episode_detail_add_to_queue'),
          borderRadius: BorderRadius.circular(999),
          onTap: _isAddingToQueue ? null : _addCurrentEpisodeToQueue,
          child: ConstrainedBox(
            constraints: BoxConstraints.tightFor(
              width: buttonSize,
              height: buttonSize,
            ),
            child: Center(
              child: _isAddingToQueue
                  ? SizedBox(
                      width: iconSize,
                      height: iconSize,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  : Icon(
                      Icons.playlist_add_rounded,
                      size: iconSize,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedFloatingActions(
    PodcastEpisodeDetailResponse episode,
    AppLocalizations l10n,
  ) {
    return GlassPanel(
      key: const Key('podcast_episode_detail_collapsed_actions'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      borderRadius: 24,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildBackButton(),
          const SizedBox(width: 8),
          _buildPlayButton(episode, l10n, compact: true),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    final l10n = (AppLocalizations.of(context) ?? AppLocalizationsEn());
    return HeaderCapsuleActionButton(
      tooltip: l10n.back_button,
      icon: Icons.arrow_back,
      onPressed: () => context.pop(),
      circular: true,
      density: _isCompactPhoneLayout
          ? HeaderCapsuleActionButtonDensity.compact
          : HeaderCapsuleActionButtonDensity.regular,
    );
  }

  Widget _buildDateChip(PodcastEpisodeDetailResponse episode) {
    return StatusBadge(
      label: _formatDate(episode.publishedAt),
      icon: Icons.calendar_today_outlined,
      color: Theme.of(context).colorScheme.secondary,
    );
  }

  Widget _buildDurationChip(PodcastEpisodeDetailResponse episode) {
    return Consumer(
      builder: (context, ref, _) {
        final activeDuration = ref.watch(
          audioDurationForEpisodeProvider(episode.id),
        );
        final displayDuration =
            activeDuration ?? ((episode.audioDuration ?? 0) * 1000);
        final duration = Duration(milliseconds: displayDuration);
        final hours = duration.inHours;
        final minutes = duration.inMinutes.remainder(60);
        final seconds = duration.inSeconds.remainder(60);

        final formattedDuration = hours > 0
            ? '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
            : '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

        return StatusBadge(
          label: formattedDuration,
          icon: Icons.schedule_outlined,
          color: Theme.of(context).colorScheme.tertiary,
        );
      },
    );
  }

  bool _shouldShowDetailOwnedPlayer(PodcastEpisodeDetailResponse episode) {
    final currentEpisodeId = ref.read(audioCurrentEpisodeIdProvider);
    return currentEpisodeId == episode.id;
  }

  Widget _buildDetailOwnedPlayerCard(PodcastEpisodeDetailResponse episode) {
    final l10n = (AppLocalizations.of(context) ?? AppLocalizationsEn());
    final theme = Theme.of(context);

    return Container(
      key: const Key('podcast_episode_detail_owned_player'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.podcast_player_now_playing,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Episode Controls',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              _buildDetailPlaybackSpeedChip(),
              const SizedBox(width: 8),
              _buildDetailSleepButton(),
              const SizedBox(width: 8),
              _buildDetailQueueButton(),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroArtwork(episode, isWide: false),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      episode.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _resolvePodcastTitle(episode, l10n),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildDateChip(episode),
                        if (episode.audioDuration != null)
                          _buildDurationChip(episode),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDetailProgressCard(),
          const SizedBox(height: 16),
          _buildDetailTransportRow(),
        ],
      ),
    );
  }

  Widget _buildDetailPlaybackSpeedChip() {
    return Consumer(
      builder: (context, ref, _) {
        final speed = ref.watch(audioPlaybackRateProvider);
        return ActionChip(
          label: Text(formatPlaybackSpeed(speed)),
          avatar: const Icon(Icons.speed_rounded, size: 18),
          onPressed: () {
            unawaited(_showDetailSpeedSelector());
          },
        );
      },
    );
  }

  Widget _buildDetailSleepButton() {
    return Consumer(
      builder: (context, ref, _) {
        final isActive = ref.watch(audioSleepTimerActiveProvider);
        return IconButton.filledTonal(
          tooltip: (AppLocalizations.of(context) ?? AppLocalizationsEn())
              .podcast_player_sleep_mode,
          onPressed: () {
            unawaited(_showDetailSleepSelector());
          },
          icon: Icon(isActive ? Icons.bedtime_rounded : Icons.bedtime_outlined),
        );
      },
    );
  }

  Widget _buildDetailQueueButton() {
    return IconButton.filledTonal(
      tooltip: (AppLocalizations.of(context) ?? AppLocalizationsEn())
          .podcast_player_list,
      onPressed: () {
        PodcastQueueSheet.show(context);
      },
      icon: const Icon(Icons.playlist_play_rounded),
    );
  }

  Widget _buildDetailProgressCard() {
    return Consumer(
      builder: (context, ref, _) {
        final theme = Theme.of(context);
        final progress = ref.watch(audioMiniProgressProvider);
        final safeDuration = progress.durationMs <= 0 ? 1 : progress.durationMs;

        return Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.42),
            ),
          ),
          child: Column(
            children: [
              Slider(
                value: progress.positionMs.clamp(0, safeDuration).toDouble(),
                max: safeDuration.toDouble(),
                onChanged: (value) {
                  ref.read(audioPlayerProvider.notifier).seekTo(value.round());
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(progress.formattedPosition),
                  Text(progress.formattedDuration),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailTransportRow() {
    return Consumer(
      builder: (context, ref, _) {
        final transport = ref.watch(audioPlayPauseStateProvider);
        final progress = ref.watch(audioMiniProgressProvider);
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  final next = (progress.positionMs - 10000).clamp(
                    0,
                    progress.durationMs,
                  );
                  ref.read(audioPlayerProvider.notifier).seekTo(next);
                },
                icon: const Icon(Icons.replay_10_rounded),
                label: const Text('10s'),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.tonalIcon(
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
              icon: Icon(
                transport.isPlaying ? Icons.pause_rounded : Icons.play_arrow,
              ),
              label: Text(
                transport.isPlaying
                    ? ((AppLocalizations.of(context) ?? AppLocalizationsEn())
                          .podcast_player_pause)
                    : ((AppLocalizations.of(context) ?? AppLocalizationsEn())
                          .podcast_player_play),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  final next = (progress.positionMs + 30000).clamp(
                    0,
                    progress.durationMs,
                  );
                  ref.read(audioPlayerProvider.notifier).seekTo(next);
                },
                icon: const Icon(Icons.forward_30_rounded),
                label: const Text('30s'),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDetailSpeedSelector() async {
    final playbackRate = ref.read(audioPlaybackRateProvider);
    final selection = await showPlaybackSpeedSelectorSheet(
      context: context,
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

  Future<void> _showDetailSleepSelector() async {
    final selection = await showSleepTimerSelectorSheet(
      context: context,
      isTimerActive: ref.read(audioSleepTimerActiveProvider),
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

  Widget _buildSourceLinkChip(
    PodcastEpisodeDetailResponse episode,
    AppLocalizations l10n, {
    HeaderCapsuleActionButtonDensity? density,
  }) {
    final effectiveDensity =
        density ??
        (_isCompactPhoneLayout
            ? HeaderCapsuleActionButtonDensity.iconOnly
            : HeaderCapsuleActionButtonDensity.regular);
    final button = HeaderCapsuleActionButton(
      key: const Key('podcast_episode_detail_source_button'),
      tooltip: l10n.podcast_source,
      icon: Icons.link_rounded,
      density: effectiveDensity,
      label: Text(
        l10n.podcast_source,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onPressed: () {
        unawaited(_launchEpisodeSource(episode));
      },
    );

    if (effectiveDensity == HeaderCapsuleActionButtonDensity.iconOnly) {
      return button;
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: effectiveDensity == HeaderCapsuleActionButtonDensity.compact
            ? 112
            : 132,
      ),
      child: button,
    );
  }

  String _formatDate(DateTime dateTime) {
    final year = dateTime.year.toString().padLeft(4, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
