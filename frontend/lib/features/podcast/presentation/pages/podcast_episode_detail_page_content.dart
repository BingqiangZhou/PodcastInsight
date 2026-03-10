part of 'podcast_episode_detail_page.dart';

extension _PodcastEpisodeDetailPageContent on _PodcastEpisodeDetailPageState {
  Widget _buildTabContent(dynamic episode) {
    switch (_selectedTabIndex) {
      case 0:
        return ShownotesDisplayWidget(key: _shownotesKey, episode: episode);
      case 1:
        return _buildTranscriptContent(episode);
      case 2:
        return _buildAiSummaryContent(episode);
      case 3:
        return _buildConversationContent(episode);
      default:
        return ShownotesDisplayWidget(key: _shownotesKey, episode: episode);
    }
  }

  Widget _buildSingleTabContent(dynamic episode, int index) {
    switch (index) {
      case 0:
        return ShownotesDisplayWidget(key: _shownotesKey, episode: episode);
      case 1:
        return _buildTranscriptContent(episode);
      case 2:
        return _buildAiSummaryContent(episode);
      case 3:
        return _buildConversationContent(episode);
      default:
        return ShownotesDisplayWidget(key: _shownotesKey, episode: episode);
    }
  }

  Widget _buildTranscriptContent(dynamic episode) {
    final transcriptionProvider = getTranscriptionProvider(widget.episodeId);
    final transcriptionState = ref.watch(transcriptionProvider);

    return transcriptionState.when(
      data: (transcription) {
        // If transcription is completed, show the text
        if (transcription != null && isTranscriptionCompleted(transcription)) {
          return TranscriptDisplayWidget(
            key: _transcriptKey,
            episodeId: widget.episodeId,
            episodeTitle: episode.title ?? '',
            transcription: transcription,
          );
        }

        // Otherwise (pending, processing, failed, or null), show the status widget
        return TranscriptionStatusWidget(
          episodeId: widget.episodeId,
          transcription: transcription,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildTranscriptErrorState(context, error),
    );
  }

  Widget _buildTranscriptErrorState(BuildContext context, dynamic error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            (AppLocalizations.of(context) ?? AppLocalizationsEn())
                .podcast_transcription_failed,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
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

  Widget _buildAiSummaryContent(dynamic episode) {
    final provider = getSummaryProvider(widget.episodeId);
    final summaryState = ref.watch(provider);
    final summaryNotifier = ref.read(provider.notifier);
    final transcriptionProvider = getTranscriptionProvider(widget.episodeId);
    final transcriptionState = ref.watch(transcriptionProvider);

    if (episode.aiSummary != null &&
        episode.aiSummary!.isNotEmpty &&
        !summaryState.hasSummary &&
        !summaryState.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          summaryNotifier.updateSummary(episode.aiSummary!);
        }
      });
    }

    return ScrollableContentWrapper(
      key: _aiSummaryKey,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AISummaryControlWidget(
            episodeId: widget.episodeId,
            hasTranscript:
                transcriptionState.value?.transcriptContent != null &&
                transcriptionState.value!.transcriptContent!.isNotEmpty,
          ),

          const SizedBox(height: 16),

          if (summaryState.isLoading) ...[
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    (AppLocalizations.of(context) ?? AppLocalizationsEn())
                        .podcast_generating_summary,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (summaryState.hasError) ...[
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    summaryState.errorMessage ??
                        (AppLocalizations.of(context) ?? AppLocalizationsEn())
                            .podcast_summary_generate_failed,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (summaryState.hasSummary) ...[
            _buildSummaryCard(
              context,
              episodeTitle: episode.title ?? '',
              summary: summaryState.summary!,
            ),
          ] else if (episode.aiSummary != null &&
              episode.aiSummary!.isNotEmpty) ...[
            _buildSummaryCard(
              context,
              episodeTitle: episode.title ?? '',
              summary: episode.aiSummary!,
            ),
          ] else ...[
            _buildAiSummaryEmptyState(context),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required String episodeTitle,
    required String summary,
  }) {
    final l10n = (AppLocalizations.of(context) ?? AppLocalizationsEn());
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.podcast_filter_with_summary,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: onSurfaceColor,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () =>
                    unawaited(_shareAllSummaryAsImage(episodeTitle, summary)),
                icon: const Icon(Icons.ios_share_outlined, size: 16),
                label: Text(l10n.podcast_share_all_content),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                p: TextStyle(fontSize: 15, height: 1.6, color: onSurfaceColor),
                h1: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: onSurfaceColor,
                ),
                h2: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: onSurfaceColor,
                ),
                h3: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: onSurfaceColor,
                ),
                listBullet: TextStyle(color: onSurfaceColor),
                strong: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: onSurfaceColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiSummaryEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            (AppLocalizations.of(context) ?? AppLocalizationsEn())
                .podcast_summary_no_summary,
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            (AppLocalizations.of(context) ?? AppLocalizationsEn())
                .podcast_summary_empty_hint,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationContent(dynamic episode) {
    final episodeDetailAsync = ref.watch(
      episodeDetailProvider(widget.episodeId),
    );

    return episodeDetailAsync.when(
      data: (episode) {
        if (episode == null) {
          return Center(
            child: Text(
              (AppLocalizations.of(context) ?? AppLocalizationsEn())
                  .podcast_episode_not_found,
            ),
          );
        }
        return ConversationChatWidget(
          key: _conversationKey,
          episodeId: widget.episodeId,
          episodeTitle: episode.title,
          aiSummary: episode.aiSummary,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              (AppLocalizations.of(context) ?? AppLocalizationsEn())
                  .podcast_load_failed,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final localDate = date.isUtc ? date.toLocal() : date;
    final year = localDate.year;
    final month = localDate.month.toString().padLeft(2, '0');
    final day = localDate.day.toString().padLeft(2, '0');
    final l10n = (AppLocalizations.of(context) ?? AppLocalizationsEn());
    return l10n.date_format(year, month, day);
  }

  Widget _buildErrorState(BuildContext context, dynamic error) {
    final l10n = (AppLocalizations.of(context) ?? AppLocalizationsEn());
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            l10n.podcast_error_loading,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              context.pop();
            },
            child: Text(l10n.podcast_go_back),
          ),
        ],
      ),
    );
  }
}
