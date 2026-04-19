part of 'podcast_episode_detail_page.dart';

const double _artworkBorderRadiusWide = 18;
const double _artworkBorderRadiusCompact = 10;

extension _PodcastEpisodeDetailPageHeader on _PodcastEpisodeDetailPageState {
  bool get _isCompactPhoneLayout =>
      MediaQuery.sizeOf(context).width < Breakpoints.medium;

  HeaderCapsuleActionButtonDensity get _buttonDensity =>
      _isCompactPhoneLayout
          ? HeaderCapsuleActionButtonDensity.compact
          : HeaderCapsuleActionButtonDensity.regular;

  bool get _isUltraCompactPhoneLayout => MediaQuery.sizeOf(context).width < 360;

  Widget _buildHeader(PodcastEpisodeModel episode) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isHeaderExpandedNotifier,
      builder: (context, isExpanded, _) {
        return AnimatedSwitcher(
          duration: AppDurations.navigationTransition,
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

  Widget _buildAnimatedHeader(PodcastEpisodeModel episode) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isHeaderExpandedNotifier,
      builder: (context, isExpanded, _) {
        return AnimatedSwitcher(
          duration: AppDurations.navigationTransition,
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
    PodcastEpisodeModel episode, {
    required bool isWide,
    Key? key,
  }) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
    final theme = Theme.of(context);
    final metadata = <Widget>[
      _buildPodcastTitleChip(episode, l10n),
      _buildDateChip(episode),
      if (episode.audioDuration != null) _buildDurationChip(episode),
      _buildPlaybackStateBadge(episode, l10n),
      if (episode.itemLink != null && episode.itemLink!.trim().isNotEmpty)
        _buildSourceLinkChip(episode, l10n),
      if (episode.episodeNumber != null)
        StatusBadge(
          label: l10n.podcast_episode_number(episode.episodeNumber!),
          icon: Icons.radio_outlined,
        ),
      if (episode.explicit)
        StatusBadge(
          label: l10n.podcast_explicit_label,
          icon: Icons.explicit_outlined,
          color: theme.colorScheme.tertiary,
        ),
    ];

    if (isWide) {
      return SurfacePanel(
        key: key,
        padding: EdgeInsets.fromLTRB(context.spacing.md, context.spacing.mdLg, context.spacing.md, context.spacing.mdLg),
        child: Row(
          children: [
            _buildHeroArtwork(episode, isWide: true),
            SizedBox(width: context.spacing.mdLg),
            Expanded(
              child: Column(
                key: const Key('podcast_episode_detail_wide_hero_content'),
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    key: const Key('podcast_episode_detail_hero_metadata_row'),
                    spacing: context.spacing.sm,
                    runSpacing: context.spacing.smMd,
                    children: metadata.whereType<Widget>().toList(
                      growable: false,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: context.spacing.mdLg),
            _buildWideHeaderActionColumn(episode, l10n),
          ],
        ),
      );
    }

    final mobileMetadata = _buildCompactHeaderMetadataText(
      publishedAt: episode.publishedAt,
      durationMilliseconds: episode.audioDuration == null
          ? null
          : episode.audioDuration! * 1000,
    );

    return Row(
      key: key,
      children: [
        _buildHeroArtwork(episode, isWide: false),
        SizedBox(width: context.spacing.smMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                mobileMetadata,
                key: const Key(
                  'podcast_episode_detail_mobile_hero_metadata',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: context.spacing.xs),
        _buildQueueButton(),
        SizedBox(width: context.spacing.xs),
        _buildDownloadButton(episode),
        SizedBox(width: context.spacing.xs),
        _buildShareButton(episode),
        if (episode.itemLink != null &&
            episode.itemLink!.trim().isNotEmpty) ...[
          SizedBox(width: context.spacing.xs),
          _buildSourceLinkIconButton(episode, l10n),
        ],
      ],
    );
  }

  Widget _buildHeroArtwork(
    PodcastEpisodeModel episode, {
    required bool isWide,
  }) {
    final size = isWide ? 76.0 : 44.0;
    final borderRadius = BorderRadius.circular(isWide ? _artworkBorderRadiusWide : _artworkBorderRadiusCompact);
    final artwork = Container(
      key: Key(
        isWide
            ? 'podcast_episode_detail_wide_hero_artwork'
            : 'podcast_episode_detail_mobile_hero_artwork',
      ),
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: PodcastImageWidget(
          imageUrl: episode.imageUrl,
          fallbackImageUrl: episode.subscriptionImageUrl,
          width: size,
          height: size,
          iconSize: size * 0.32,
        ),
      ),
    );

    return Hero(
      tag: 'episode_cover_${episode.id}',
      child: Semantics(
        button: true,
        hint: 'Play episode',
        child: GestureDetector(
          onTap: () => unawaited(_playOrResumeFromDetail(episode)),
          child: Stack(
          alignment: Alignment.center,
          children: [
            artwork,
            Consumer(
              builder: (context, ref, _) {
                final playState = ref.watch(audioEpisodePlayStateProvider.select(
                  (s) => (s.currentEpisodeId, s.isPlaying),
                ));
                final isPlaying = playState.$1 == episode.id && playState.$2;
                return Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.3),
                    borderRadius: borderRadius,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    isPlaying
                        ? Icons.graphic_eq_rounded
                        : Icons.play_arrow_rounded,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: size * 0.4,
                  ),
                );
              },
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildWideHeaderActionColumn(
    PodcastEpisodeModel episode,
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
              _buildDownloadButton(episode),
              SizedBox(width: context.spacing.sm),
              _buildQueueButton(),
              SizedBox(width: context.spacing.sm),
              _buildShareButton(episode),
            ],
          ),
          SizedBox(height: context.spacing.sm),
          _buildPlayButton(
            episode,
            l10n,
            compact: false,
            density: HeaderCapsuleActionButtonDensity.compact,
            padding: EdgeInsets.symmetric(horizontal: context.spacing.xsSm, vertical: context.spacing.xs),
          ),
        ],
      ),
    );
  }

  String _resolvePodcastTitle(
    PodcastEpisodeModel episode,
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
    PodcastEpisodeModel episode,
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
    required VoidCallback onTap, Color? color,
    bool iconOnly = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final resolvedColor = color ?? scheme.primary;

    return Tooltip(
      message: label,
      child: Material(
        key: key,
        color: resolvedColor.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.pillRadius,
          side: BorderSide(color: resolvedColor.withValues(alpha: 0.18)),
        ),
        child: AdaptiveInkWell(
          borderRadius: AppRadius.pillRadius,
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
                  padding: EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: context.spacing.xs,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 13, color: resolvedColor),
                      SizedBox(width: context.spacing.xs),
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
    required DateTime publishedAt,
    required int? durationMilliseconds,
  }) {
    final segments = <String>[EpisodeCardUtils.formatDate(publishedAt)];
    if (durationMilliseconds != null) {
      segments.add(_formatDurationLabel(durationMilliseconds));
    }
    return segments.join(' / ');
  }

  Future<void> _launchEpisodeSource(
    PodcastEpisodeModel episode,
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
        final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
        showTopFloatingNotice(
          context,
          message: l10n.added_to_queue,
          extraTopOffset: 72,
        );
      }
    } catch (error) {
      if (mounted) {
        final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
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
    PodcastEpisodeModel episode,
    AppLocalizations l10n, {
    required bool compact,
    HeaderCapsuleActionButtonDensity? density,
    EdgeInsetsGeometry? padding,
    HeaderCapsuleActionButtonStyle? style,
  }) {
    return RepaintBoundary(
      child: Consumer(
      builder: (context, ref, _) {
        final playStateInfo = ref.watch(audioEpisodePlayStateProvider);
        final effectiveDensity =
            density ??
            (_isUltraCompactPhoneLayout
                ? HeaderCapsuleActionButtonDensity.iconOnly
                : _isCompactPhoneLayout || compact
                ? HeaderCapsuleActionButtonDensity.compact
                : HeaderCapsuleActionButtonDensity.regular);
        final playState = _resolveEpisodePlayState(playStateInfo, episode);
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
          style: style ?? HeaderCapsuleActionButtonStyle.surfaceNeutral,
          label: showLabel ? Text(buttonText) : null,
          onPressed: () {
            unawaited(_playOrResumeFromDetail(episode));
          },
        );
      },
    ),
    );
  }

  _EpisodeDetailPlayState _resolveEpisodePlayState(
    AudioEpisodePlayState playStateInfo,
    PodcastEpisodeModel episode,
  ) {
    final isSameEpisode = playStateInfo.currentEpisodeId == episode.id;
    final isCompleted =
        isSameEpisode &&
        playStateInfo.processingState == ProcessingState.completed;
    if (isSameEpisode && playStateInfo.isPlaying && !isCompleted) {
      return _EpisodeDetailPlayState.playing;
    }

    final resumePositionMs = _resolveResumePositionMs(playStateInfo, episode);
    if (resumePositionMs > 0 && !isCompleted) {
      return _EpisodeDetailPlayState.resume;
    }

    return _EpisodeDetailPlayState.play;
  }

  int _resolveResumePositionMs(
    AudioEpisodePlayState playStateInfo,
    PodcastEpisodeModel episode,
  ) {
    final isSameEpisode = playStateInfo.currentEpisodeId == episode.id;
    if (isSameEpisode) {
      return playStateInfo.currentPositionMs;
    }
    return (episode.playbackPosition ?? 0) * 1000;
  }

  Widget _buildPlaybackStateBadge(
    PodcastEpisodeModel episode,
    AppLocalizations l10n,
  ) {
    return RepaintBoundary(
      child: Consumer(
      builder: (context, ref, _) {
        final theme = Theme.of(context);
        final playStateInfo = ref.watch(audioEpisodePlayStateProvider);
        final playState = _resolveEpisodePlayState(playStateInfo, episode);
        final resumePositionMs = _resolveResumePositionMs(playStateInfo, episode);

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
    ),
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
      density: _buttonDensity,
    );
  }

  Widget _buildDateChip(PodcastEpisodeModel episode) {
    return StatusBadge(
      label: EpisodeCardUtils.formatDate(episode.publishedAt),
      icon: Icons.calendar_today_outlined,
      color: Theme.of(context).colorScheme.secondary,
    );
  }

  Widget _buildDurationChip(PodcastEpisodeModel episode) {
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
    PodcastEpisodeModel episode,
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

  String _formatPlaybackProgress(int milliseconds) {
    return _formatDurationLabel(milliseconds.clamp(0, 1 << 31));
  }

  String _formatDurationLabel(int milliseconds) {
    return TimeFormatter.formatDuration(
      Duration(milliseconds: milliseconds),
      padHours: false,
    );
  }
  Widget _buildShareButton(PodcastEpisodeModel episode) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
    return HeaderCapsuleActionButton(
      tooltip: l10n.share,
      icon: Icons.adaptive.share,
      onPressed: () => _shareEpisode(episode),
      circular: true,
      density: _buttonDensity,
    );
  }

  Widget _buildSourceLinkIconButton(
    PodcastEpisodeModel episode,
    AppLocalizations l10n,
  ) {
    return HeaderCapsuleActionButton(
      tooltip: l10n.podcast_source,
      icon: Icons.link_rounded,
      onPressed: () => unawaited(_launchEpisodeSource(episode)),
      circular: true,
      density: _buttonDensity,
    );
  }

  Future<void> _shareEpisode(PodcastEpisodeModel episode) async {
    AdaptiveHaptic.mediumImpact();
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();

    // Generate a deep link to the episode
    // For now, use the audio URL as the shareable link
    // In production, this should be a proper deep link to the app
    final podcastName = _resolvePodcastTitle(episode, l10n);
    final shareUrl = episode.audioUrl;

    try {
      await AdaptiveShare.shareEpisode(
        title: episode.title,
        url: shareUrl,
        podcastName: podcastName,
        description: episode.description?.trim(),
      );
    } catch (error) {
      if (mounted) {
        showTopFloatingNotice(
          context,
          message: l10n.podcast_share_episode_failed(error.toString()),
          isError: true,
          extraTopOffset: 72,
        );
      }
    }
  }

  Widget _buildDownloadButton(PodcastEpisodeModel episode) {
    return Consumer(
      builder: (context, ref, _) {
        final asyncTask = ref.watch(episodeDownloadStatusProvider(episode.id));
        final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();

        return asyncTask.when(
          data: (task) {
            if (task == null) {
              return HeaderCapsuleActionButton(
                tooltip: l10n.download_button_download,
                icon: Icons.download_outlined,
                onPressed: () => _startDownload(episode),
                circular: true,
                density: _isCompactPhoneLayout
                    ? HeaderCapsuleActionButtonDensity.compact
                    : HeaderCapsuleActionButtonDensity.regular,
              );
            }

            return switch (task.status) {
              DownloadStatus.pending => HeaderCapsuleActionButton(
                  tooltip: l10n.download_button_downloading,
                  icon: Icons.downloading,
                  onPressed: () => _cancelDownload(episode.id),
                  circular: true,
                  density: _isCompactPhoneLayout
                      ? HeaderCapsuleActionButtonDensity.compact
                      : HeaderCapsuleActionButtonDensity.regular,
                  style: HeaderCapsuleActionButtonStyle.primaryTinted,
                ),
              DownloadStatus.downloading => HeaderCapsuleActionButton(
                  tooltip:
                      '${(task.progress * 100).toStringAsFixed(0)}% — ${l10n.download_button_cancel}',
                  icon: Icons.downloading,
                  onPressed: () => _cancelDownload(episode.id),
                  circular: true,
                  isLoading: true,
                  density: _isCompactPhoneLayout
                      ? HeaderCapsuleActionButtonDensity.compact
                      : HeaderCapsuleActionButtonDensity.regular,
                  style: HeaderCapsuleActionButtonStyle.primaryTinted,
                ),
              DownloadStatus.completed => HeaderCapsuleActionButton(
                  tooltip: l10n.download_button_delete,
                  icon: Icons.download_done,
                  onPressed: () => _deleteDownload(episode.id),
                  circular: true,
                  density: _isCompactPhoneLayout
                      ? HeaderCapsuleActionButtonDensity.compact
                      : HeaderCapsuleActionButtonDensity.regular,
                  style: HeaderCapsuleActionButtonStyle.primaryTinted,
                ),
              DownloadStatus.failed => HeaderCapsuleActionButton(
                  tooltip: l10n.download_button_retry,
                  icon: Icons.error_outline,
                  onPressed: () => _startDownload(episode),
                  circular: true,
                  density: _isCompactPhoneLayout
                      ? HeaderCapsuleActionButtonDensity.compact
                      : HeaderCapsuleActionButtonDensity.regular,
                ),
              _ => HeaderCapsuleActionButton(
                  tooltip: l10n.download_button_download,
                  icon: Icons.download_outlined,
                  onPressed: () => _startDownload(episode),
                  circular: true,
                  density: _isCompactPhoneLayout
                      ? HeaderCapsuleActionButtonDensity.compact
                      : HeaderCapsuleActionButtonDensity.regular,
                ),
            };
          },
          loading: () => HeaderCapsuleActionButton(
            tooltip: l10n.download_button_download,
            icon: Icons.download_outlined,
            onPressed: null,
            circular: true,
            density: _isCompactPhoneLayout
                ? HeaderCapsuleActionButtonDensity.compact
                : HeaderCapsuleActionButtonDensity.regular,
          ),
          error: (_, _) => HeaderCapsuleActionButton(
            tooltip: l10n.download_button_download,
            icon: Icons.download_outlined,
            onPressed: () => _startDownload(episode),
            circular: true,
            density: _isCompactPhoneLayout
                ? HeaderCapsuleActionButtonDensity.compact
                : HeaderCapsuleActionButtonDensity.regular,
          ),
        );
      },
    );
  }

  void _startDownload(PodcastEpisodeModel episode) {
    final sub = episode.subscription;
    final podcastTitle = sub?['title'] as String? ??
        sub?['name'] as String? ??
        episode.metadata?['podcast_title'] as String?;
    ref.read(downloadManagerProvider).download(
          episodeId: episode.id,
          audioUrl: episode.audioUrl,
          title: episode.title,
          subscriptionTitle: podcastTitle,
          imageUrl: episode.imageUrl,
          subscriptionImageUrl: episode.subscriptionImageUrl,
          subscriptionId: episode.subscriptionId,
          audioDuration: episode.audioDuration,
          publishedAt: episode.publishedAt,
        );
  }

  void _cancelDownload(int episodeId) {
    ref.read(downloadManagerProvider).cancel(episodeId);
  }

  void _deleteDownload(int episodeId) {
    ref.read(downloadManagerProvider).delete(episodeId);
  }
}

enum _EpisodeDetailPlayState { play, resume, playing }
