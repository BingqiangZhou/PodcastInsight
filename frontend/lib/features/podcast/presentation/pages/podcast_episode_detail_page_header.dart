part of 'podcast_episode_detail_page.dart';

extension _PodcastEpisodeDetailPageHeader on _PodcastEpisodeDetailPageState {
  bool get _isCompactPhoneLayout =>
      MediaQuery.sizeOf(context).width < AppBreakpoints.medium;

  bool get _isUltraCompactPhoneLayout => MediaQuery.sizeOf(context).width < 360;

  Widget _buildHeader(PodcastEpisodeDetailResponse episode) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isHeaderExpandedNotifier,
      builder: (context, isExpanded, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _buildHeroHeaderCard(
            episode,
            isWide: false,
            key: ValueKey(
              'podcast_episode_detail_mobile_hero_$isExpanded',
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedHeader(PodcastEpisodeDetailResponse episode) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isHeaderExpandedNotifier,
      builder: (context, isExpanded, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _buildHeroHeaderCard(
            episode,
            isWide: true,
            key: ValueKey(
              'podcast_episode_detail_wide_hero_$isExpanded',
            ),
          ),
        );
      },
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
    final metadata = <Widget>[
      _buildPodcastTitleChip(episode, l10n),
      _buildDateChip(episode),
      if (episode.audioDuration != null) _buildDurationChip(episode),
      _buildPlaybackStateBadge(episode, l10n),
      if (episode.itemLink != null && episode.itemLink!.trim().isNotEmpty)
        _buildSourceLinkChip(episode, l10n),
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
      return SurfacePanel(
        key: key,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildHeroArtwork(episode, isWide: true),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                key: const Key('podcast_episode_detail_wide_hero_content'),
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.08,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    key: const Key('podcast_episode_detail_hero_metadata_row'),
                    spacing: 8,
                    runSpacing: 6,
                    children: metadata.whereType<Widget>().toList(
                      growable: false,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            _buildWideHeaderActionColumn(episode, l10n),
          ],
        ),
      );
    }

    final mobileMetadata = _buildCompactHeaderMetadataText(
      podcastTitle: _resolvePodcastTitle(episode, l10n),
      publishedAt: episode.publishedAt,
      durationMilliseconds: episode.audioDuration == null
          ? null
          : episode.audioDuration! * 1000,
    );

    return SurfacePanel(
      key: key,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: SizedBox(
        key: const Key('podcast_episode_detail_mobile_hero_body'),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroArtwork(episode, isWide: false),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.02,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mobileMetadata,
                    key: const Key(
                      'podcast_episode_detail_mobile_hero_metadata',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (episode.itemLink != null &&
                      episode.itemLink!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _buildMobileSourceLinkAction(episode, l10n),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildMobileHeroActionColumn(episode, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroArtwork(
    PodcastEpisodeDetailResponse episode, {
    required bool isWide,
  }) {
    final size = isWide ? 76.0 : 56.0;

    return Container(
      key: Key(
        isWide
            ? 'podcast_episode_detail_wide_hero_artwork'
            : 'podcast_episode_detail_mobile_hero_artwork',
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isWide ? 18 : 16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isWide ? 18 : 16),
        child: PodcastImageWidget(
          imageUrl: episode.imageUrl,
          fallbackImageUrl: episode.subscriptionImageUrl,
          width: size,
          height: size,
          iconSize: size * 0.32,
        ),
      ),
    );
  }

  Widget _buildWideHeaderActionColumn(
    PodcastEpisodeDetailResponse episode,
    AppLocalizations l10n,
  ) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 124, maxWidth: 168),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          const SizedBox(height: 8),
          _buildPlayButton(
            episode,
            l10n,
            compact: false,
            density: HeaderCapsuleActionButtonDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileHeroActionColumn(
    PodcastEpisodeDetailResponse episode,
    AppLocalizations l10n,
  ) {
    return Column(
      key: const Key('podcast_episode_detail_mobile_hero_actions'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPlayButton(
          episode,
          l10n,
          compact: true,
          density: HeaderCapsuleActionButtonDensity.iconOnly,
        ),
        const SizedBox(height: 8),
        _buildQueueButton(),
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

  Widget _buildPodcastTitleChip(
    PodcastEpisodeDetailResponse episode,
    AppLocalizations l10n,
  ) {
    return StatusBadge(
      key: const Key('podcast_episode_detail_podcast_title_chip'),
      label: _resolvePodcastTitle(episode, l10n),
      color: Theme.of(context).colorScheme.primary,
    );
  }

  Widget _buildMetadataActionBadge({
    required Key key,
    required String label,
    required IconData icon,
    Color? color,
    bool iconOnly = false,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final resolvedColor = color ?? scheme.primary;

    return Tooltip(
      message: label,
      child: Material(
        key: key,
        color: resolvedColor.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(color: resolvedColor.withValues(alpha: 0.18)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: iconOnly
              ? SizedBox(
                  width: 30,
                  height: 30,
                  child: Center(
                    child: Icon(icon, size: 13, color: resolvedColor),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 13, color: resolvedColor),
                      const SizedBox(width: 4),
                      Text(
                        label,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: resolvedColor,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  String _buildCompactHeaderMetadataText({
    required String podcastTitle,
    required DateTime publishedAt,
    required int? durationMilliseconds,
  }) {
    final segments = <String>[podcastTitle, EpisodeCardUtils.formatDate(publishedAt)];
    if (durationMilliseconds != null) {
      segments.add(_formatDurationLabel(durationMilliseconds));
    }
    return segments.join(' / ');
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
        isSameEpisode &&
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
    EdgeInsetsGeometry? padding,
  }) {
    return Consumer(
      builder: (context, ref, _) {
        final playerState = ref.watch(audioPlayerProvider);
        final effectiveDensity =
            density ??
            (_isUltraCompactPhoneLayout
                ? HeaderCapsuleActionButtonDensity.iconOnly
                : _isCompactPhoneLayout || compact
                ? HeaderCapsuleActionButtonDensity.compact
                : HeaderCapsuleActionButtonDensity.regular);
        final playState = _resolveEpisodePlayState(playerState, episode);
        final showLabel =
            effectiveDensity != HeaderCapsuleActionButtonDensity.iconOnly;

        final buttonText = switch (playState) {
          _EpisodeDetailPlayState.playing => l10n.podcast_episode_playing,
          _EpisodeDetailPlayState.resume => l10n.podcast_resume_episode,
          _EpisodeDetailPlayState.play =>
            _isCompactPhoneLayout
                ? l10n.podcast_play_episode
                : l10n.podcast_play_episode_full,
        };

        final icon = switch (playState) {
          _EpisodeDetailPlayState.playing => Icons.graphic_eq_rounded,
          _EpisodeDetailPlayState.resume => Icons.play_circle_fill_rounded,
          _EpisodeDetailPlayState.play => Icons.play_arrow_rounded,
        };

        final tooltip = switch (playState) {
          _EpisodeDetailPlayState.playing => l10n.podcast_episode_playing,
          _EpisodeDetailPlayState.resume => l10n.podcast_resume_episode,
          _EpisodeDetailPlayState.play => l10n.podcast_play_episode_full,
        };

        return HeaderCapsuleActionButton(
          key: const Key('podcast_episode_detail_play_button'),
          tooltip: tooltip,
          icon: icon,
          density: effectiveDensity,
          padding: padding,
          label: showLabel ? Text(buttonText) : null,
          onPressed: () {
            unawaited(_playOrResumeFromDetail(_episodeToModel(episode)));
          },
        );
      },
    );
  }

  _EpisodeDetailPlayState _resolveEpisodePlayState(
    AudioPlayerState playerState,
    PodcastEpisodeDetailResponse episode,
  ) {
    final isSameEpisode = playerState.currentEpisode?.id == episode.id;
    final isCompleted =
        isSameEpisode &&
        playerState.processingState == ProcessingState.completed;
    if (isSameEpisode && playerState.isPlaying && !isCompleted) {
      return _EpisodeDetailPlayState.playing;
    }

    final resumePositionMs = _resolveResumePositionMs(playerState, episode);
    if (resumePositionMs > 0 && !isCompleted) {
      return _EpisodeDetailPlayState.resume;
    }

    return _EpisodeDetailPlayState.play;
  }

  int _resolveResumePositionMs(
    AudioPlayerState playerState,
    PodcastEpisodeDetailResponse episode,
  ) {
    final isSameEpisode = playerState.currentEpisode?.id == episode.id;
    if (isSameEpisode) {
      return playerState.position;
    }
    return (episode.playbackPosition ?? 0) * 1000;
  }

  Widget _buildPlaybackStateBadge(
    PodcastEpisodeDetailResponse episode,
    AppLocalizations l10n,
  ) {
    return Consumer(
      builder: (context, ref, _) {
        final theme = Theme.of(context);
        final playerState = ref.watch(audioPlayerProvider);
        final playState = _resolveEpisodePlayState(playerState, episode);
        final resumePositionMs = _resolveResumePositionMs(playerState, episode);

        return switch (playState) {
          _EpisodeDetailPlayState.playing => StatusBadge(
            label: l10n.podcast_episode_playing,
            icon: Icons.graphic_eq_rounded,
          ),
          _EpisodeDetailPlayState.resume => StatusBadge(
            label:
                '${l10n.podcast_resume_episode} ${_formatPlaybackProgress(resumePositionMs)}',
            icon: Icons.history_rounded,
            color: theme.colorScheme.secondary,
          ),
          _EpisodeDetailPlayState.play => const SizedBox.shrink(),
        };
      },
    );
  }

  Widget _buildQueueButton() {
    return HeaderCapsuleActionButton(
      tooltip: (AppLocalizations.of(context) ?? AppLocalizationsEn())
          .podcast_add_to_queue,
      icon: Icons.playlist_add_rounded,
      onPressed: _isAddingToQueue ? null : _addCurrentEpisodeToQueue,
      circular: true,
      isLoading: _isAddingToQueue,
      density: _isCompactPhoneLayout
          ? HeaderCapsuleActionButtonDensity.compact
          : HeaderCapsuleActionButtonDensity.regular,
      style: HeaderCapsuleActionButtonStyle.surfaceNeutral,
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
      style: HeaderCapsuleActionButtonStyle.surfaceNeutral,
    );
  }

  Widget _buildDateChip(PodcastEpisodeDetailResponse episode) {
    return StatusBadge(
      label: EpisodeCardUtils.formatDate(episode.publishedAt),
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

        return StatusBadge(
          label: _formatDurationLabel(displayDuration),
          icon: Icons.schedule_outlined,
          color: Theme.of(context).colorScheme.tertiary,
        );
      },
    );
  }

  Widget _buildSourceLinkChip(
    PodcastEpisodeDetailResponse episode,
    AppLocalizations l10n, {
    bool iconOnly = false,
  }) {
    return _buildMetadataActionBadge(
      key: const Key('podcast_episode_detail_source_button'),
      label: l10n.podcast_source,
      icon: Icons.link_rounded,
      color: Theme.of(context).colorScheme.secondary,
      iconOnly: iconOnly,
      onTap: () {
        unawaited(_launchEpisodeSource(episode));
      },
    );
  }

  Widget _buildMobileSourceLinkAction(
    PodcastEpisodeDetailResponse episode,
    AppLocalizations l10n,
  ) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('podcast_episode_detail_source_button'),
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          unawaited(_launchEpisodeSource(episode));
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.link_rounded,
                size: 13,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(width: 4),
              Text(
                l10n.podcast_source,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                  decorationColor: theme.colorScheme.secondary.withValues(
                    alpha: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPlaybackProgress(int milliseconds) {
    return _formatDurationLabel(milliseconds.clamp(0, 1 << 31));
  }

  String _formatDurationLabel(int milliseconds) {
    return TimeFormatter.formatDuration(
      Duration(milliseconds: milliseconds),
      padHours: false,
    );
  }
}

enum _EpisodeDetailPlayState { play, resume, playing }
