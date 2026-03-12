part of 'podcast_episode_detail_page.dart';

extension _PodcastEpisodeDetailPageContent on _PodcastEpisodeDetailPageState {
  Widget _buildTabSurface(Widget child, {Key? key}) {
    final tokens = mindriverThemeOf(context);
    final theme = Theme.of(context);

    return GlassPanel(
      key: key,
      padding: EdgeInsets.zero,
      borderRadius: tokens.panelRadius,
      backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.22),
      showHighlight: false,
      child: child,
    );
  }

  Widget _buildPageLoadingState(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const AppPageBackdrop(),
        Center(
          child: GlassPanel(
            padding: const EdgeInsets.fromLTRB(28, 26, 28, 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  (AppLocalizations.of(context) ?? AppLocalizationsEn())
                      .loading,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabContent(PodcastEpisodeDetailResponse episode) {
    switch (_selectedTabIndex) {
      case 0:
        return ShownotesDisplayWidget(
          key: _shownotesKey,
          episode: episode,
          onAnchorsChanged: _updateShownotesAnchors,
        );
      case 1:
        return _buildTranscriptContent(episode);
      case 2:
        return _buildSummaryTabContent(episode);
      default:
        return ShownotesDisplayWidget(
          key: _shownotesKey,
          episode: episode,
          onAnchorsChanged: _updateShownotesAnchors,
        );
    }
  }

  Widget _buildSingleTabContent(
    PodcastEpisodeDetailResponse episode,
    int index,
  ) {
    switch (index) {
      case 0:
        return ShownotesDisplayWidget(
          key: _shownotesKey,
          episode: episode,
          onAnchorsChanged: _updateShownotesAnchors,
        );
      case 1:
        return _buildTranscriptContent(episode);
      case 2:
        return _buildSummaryTabContent(episode);
      default:
        return ShownotesDisplayWidget(
          key: _shownotesKey,
          episode: episode,
          onAnchorsChanged: _updateShownotesAnchors,
        );
    }
  }

  Widget _buildTranscriptContent(PodcastEpisodeDetailResponse episode) {
    final transcriptionProvider = getTranscriptionProvider(widget.episodeId);
    final transcriptionState = ref.watch(transcriptionProvider);

    return transcriptionState.when(
      data: (transcription) {
        if (transcription != null && isTranscriptionCompleted(transcription)) {
          return TranscriptDisplayWidget(
            key: _transcriptKey,
            episodeId: widget.episodeId,
            episodeTitle: episode.title,
            transcription: transcription,
          );
        }

        return TranscriptionStatusWidget(
          episodeId: widget.episodeId,
          transcription: transcription,
        );
      },
      loading: () => _buildCenteredLoadingState(
        (AppLocalizations.of(context) ?? AppLocalizationsEn()).loading,
      ),
      error: (error, stack) => _buildTranscriptErrorState(context, error),
    );
  }

  Widget _buildSummaryTabContent(PodcastEpisodeDetailResponse episode) {
    final isCompact = MediaQuery.sizeOf(context).width < 600;

    return ScrollableContentWrapper(
      key: _summaryKey,
      padding: EdgeInsets.all(isCompact ? 14 : 18),
      child: _buildAiSummarySection(episode, compact: isCompact),
    );
  }

  Widget _buildCenteredLoadingState(String label) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptErrorState(BuildContext context, dynamic error) {
    return AppEmptyState(
      icon: Icons.error_outline,
      title: (AppLocalizations.of(context) ?? AppLocalizationsEn())
          .podcast_transcription_failed,
      subtitle: error.toString(),
    );
  }

  void _showShareErrorNotice(String message) {
    if (!mounted) {
      return;
    }
    showTopFloatingNotice(
      context,
      message: message,
      isError: true,
      extraTopOffset: 72,
    );
  }

  Future<void> _shareSelectedSummaryAsImage(
    String episodeTitle,
    String fullSummaryMarkdown,
  ) async {
    final l10n = (AppLocalizations.of(context) ?? AppLocalizationsEn());
    final markdownSelection = await extractMarkdownSelectionAsync(
      markdown: fullSummaryMarkdown,
      selectedText: _selectedSummaryText,
    );
    if (!mounted) {
      return;
    }
    try {
      await ContentImageShareService.shareAsImage(
        context,
        ShareImagePayload(
          episodeTitle: episodeTitle,
          contentType: ShareContentType.summary,
          content: markdownSelection,
          sourceLabel: l10n.podcast_filter_with_summary,
          renderMode: ShareImageRenderMode.markdown,
        ),
      );
    } on ContentImageShareException catch (e) {
      _showShareErrorNotice(e.message);
    }
  }

  Future<void> _shareAllSummaryAsImage(
    String episodeTitle,
    String summary,
  ) async {
    final l10n = (AppLocalizations.of(context) ?? AppLocalizationsEn());
    try {
      await ContentImageShareService.shareAsImage(
        context,
        ShareImagePayload(
          episodeTitle: episodeTitle,
          contentType: ShareContentType.summary,
          content: summary,
          sourceLabel: l10n.podcast_filter_with_summary,
          renderMode: ShareImageRenderMode.markdown,
        ),
      );
    } on ContentImageShareException catch (e) {
      _showShareErrorNotice(e.message);
    }
  }

  Widget _buildRightRail(PodcastEpisodeDetailResponse episode) {
    return GlassPanel(
      key: const Key('podcast_episode_detail_side_rail'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      backgroundColor: Theme.of(
        context,
      ).colorScheme.surface.withValues(alpha: 0.18),
      showHighlight: false,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAnchorRailCard(),
            if ((episode.relatedEpisodes?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 16),
              _buildRelatedEpisodesCard(episode),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAiSummarySection(
    PodcastEpisodeDetailResponse episode, {
    bool compact = false,
  }) {
    final provider = getSummaryProvider(widget.episodeId);
    final summaryState = ref.watch(provider);
    final summaryNotifier = ref.read(provider.notifier);
    final transcriptionProvider = getTranscriptionProvider(widget.episodeId);
    final transcriptionState = ref.watch(transcriptionProvider);
    final hasEpisodeTranscript =
        episode.transcriptContent != null &&
        episode.transcriptContent!.isNotEmpty;
    final hasLoadedTranscript =
        transcriptionState.value?.transcriptContent != null &&
        transcriptionState.value!.transcriptContent!.isNotEmpty;
    final hasExistingSummary =
        summaryState.hasSummary ||
        (episode.aiSummary != null && episode.aiSummary!.isNotEmpty);
    final canManageSummary =
        hasEpisodeTranscript || hasLoadedTranscript || hasExistingSummary;

    if (episode.aiSummary != null &&
        episode.aiSummary!.isNotEmpty &&
        !summaryState.hasSummary &&
        !summaryState.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          summaryNotifier.updateSummary(
            episode.aiSummary!,
            modelUsed: episode.summaryModelUsed,
            processingTime: episode.summaryProcessingTime,
          );
        }
      });
    }

    final episodeSummaryFailure = SummarySanitizer.detectFailureReason(
      episode.aiSummary,
    );
    final sanitizedEpisodeSummary = episodeSummaryFailure == null
        ? SummarySanitizer.clean(episode.aiSummary)
        : '';

    return Column(
      key: const Key('podcast_episode_detail_summary_section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AISummaryControlWidget(
          episodeId: widget.episodeId,
          hasTranscript: canManageSummary,
          compact: compact,
        ),
        const SizedBox(height: 16),
        if (summaryState.isLoading &&
            !summaryState.hasSummary &&
            sanitizedEpisodeSummary.isEmpty)
          _buildCenteredLoadingState(
            (AppLocalizations.of(context) ?? AppLocalizationsEn())
                .podcast_generating_summary,
          )
        else if (summaryState.hasSummary)
          _buildSummaryCard(
            context,
            episodeTitle: episode.title,
            summary: summaryState.summary!,
            compact: compact,
          )
        else if (episodeSummaryFailure != null)
          _buildAiSummaryErrorState(context, episodeSummaryFailure)
        else if (sanitizedEpisodeSummary.isNotEmpty)
          _buildSummaryCard(
            context,
            episodeTitle: episode.title,
            summary: sanitizedEpisodeSummary,
            compact: compact,
          )
        else
          _buildAiSummaryEmptyState(context),
        if (summaryState.isLoading &&
            (summaryState.hasSummary || sanitizedEpisodeSummary.isNotEmpty)) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
      ],
    );
  }

  Widget _buildAiSummaryErrorState(BuildContext context, String message) {
    return AppEmptyState(
      icon: Icons.error_outline,
      title: (AppLocalizations.of(context) ?? AppLocalizationsEn())
          .podcast_transcription_failed,
      subtitle: message,
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required String episodeTitle,
    required String summary,
    bool compact = false,
  }) {
    final l10n = (AppLocalizations.of(context) ?? AppLocalizationsEn());
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () =>
                unawaited(_shareAllSummaryAsImage(episodeTitle, summary)),
            icon: const Icon(Icons.ios_share_outlined, size: 16),
            label: Text(l10n.podcast_share_all_content),
          ),
        ),
        const SizedBox(height: 10),
        SelectionArea(
          onSelectionChanged: (selectedContent) {
            _selectedSummaryText = selectedContent?.plainText.trim() ?? '';
          },
          contextMenuBuilder: (context, selectableRegionState) {
            return AdaptiveTextSelectionToolbar.buttonItems(
              anchors: selectableRegionState.contextMenuAnchors,
              buttonItems: [
                ...selectableRegionState.contextMenuButtonItems,
                ContextMenuButtonItem(
                  label: l10n.podcast_share_as_image,
                  onPressed: () {
                    ContextMenuController.removeAny();
                    unawaited(
                      _shareSelectedSummaryAsImage(episodeTitle, summary),
                    );
                  },
                ),
              ],
            );
          },
          child: MarkdownBody(
            data: summary,
            styleSheet: MarkdownStyleSheet(
              p: theme.textTheme.bodyLarge?.copyWith(
                height: compact ? 1.55 : 1.65,
              ),
              h1: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              h2: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              h3: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              listBullet: theme.textTheme.bodyLarge,
              strong: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAiSummaryEmptyState(BuildContext context) {
    final l10n = (AppLocalizations.of(context) ?? AppLocalizationsEn());
    return AppEmptyState(
      icon: Icons.auto_awesome,
      title: l10n.podcast_summary_no_summary,
      subtitle: l10n.podcast_summary_empty_hint,
    );
  }

  Widget _buildAnchorRailCard() {
    final l10n = (AppLocalizations.of(context) ?? AppLocalizationsEn());

    return Container(
      key: const Key('podcast_episode_detail_anchor_rail'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Shownotes',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.podcast_source,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          if (_shownotesAnchors.isEmpty)
            Text(
              (AppLocalizations.of(context) ?? AppLocalizationsEn())
                  .podcast_no_shownotes,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else
            Column(
              children: _shownotesAnchors
                  .map((anchor) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          key: Key(
                            'podcast_episode_detail_anchor_${anchor.index}',
                          ),
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _jumpToShownotesAnchor(anchor),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    anchor.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }

  Widget _buildRelatedEpisodesCard(PodcastEpisodeDetailResponse episode) {
    final relatedEpisodes = episode.relatedEpisodes ?? const <dynamic>[];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Related',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ...relatedEpisodes.take(4).map((relatedEpisode) {
            final title = relatedEpisode is Map<String, dynamic>
                ? (relatedEpisode['title']?.toString() ?? '')
                : relatedEpisode.toString();
            if (title.trim().isEmpty) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildChatDrawer(PodcastEpisodeDetailResponse episode) {
    final l10n = (AppLocalizations.of(context) ?? AppLocalizationsEn());
    final width = MediaQuery.sizeOf(context).width;
    final drawerWidth =
        width >= _PodcastEpisodeDetailPageState._wideLayoutBreakpoint
        ? 420.0
        : width * 0.94;

    return SizedBox(
      width: drawerWidth,
      child: Drawer(
        key: const Key('podcast_episode_detail_chat_drawer'),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.podcast_conversation_title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(child: _buildConversationContent(episode)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConversationContent(PodcastEpisodeDetailResponse episode) {
    final episodeDetailAsync = ref.watch(
      episodeDetailProvider(widget.episodeId),
    );

    return episodeDetailAsync.when(
      data: (episode) {
        if (episode == null) {
          return AppEmptyState(
            icon: Icons.error_outline,
            title: (AppLocalizations.of(context) ?? AppLocalizationsEn())
                .podcast_episode_not_found,
          );
        }
        return ConversationChatWidget(
          key: _conversationKey,
          episodeId: widget.episodeId,
          episodeTitle: episode.title,
          aiSummary: episode.aiSummary,
        );
      },
      loading: () => _buildCenteredLoadingState(
        (AppLocalizations.of(context) ?? AppLocalizationsEn()).loading,
      ),
      error: (error, stack) => AppEmptyState(
        icon: Icons.error_outline,
        title: (AppLocalizations.of(context) ?? AppLocalizationsEn())
            .podcast_load_failed,
        subtitle: error.toString(),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, dynamic error) {
    final l10n = (AppLocalizations.of(context) ?? AppLocalizationsEn());
    return Stack(
      fit: StackFit.expand,
      children: [
        const AppPageBackdrop(),
        Center(
          child: AppEmptyState(
            icon: Icons.error_outline,
            title: l10n.podcast_error_loading,
            subtitle: error.toString(),
            action: FilledButton(
              onPressed: () {
                context.pop();
              },
              child: Text(l10n.podcast_go_back),
            ),
          ),
        ),
      ],
    );
  }
}
