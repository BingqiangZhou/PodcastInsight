import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:personal_ai_assistant/core/constants/app_text_styles.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/constants/app_durations.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/platform/platform_helper.dart';
import 'package:personal_ai_assistant/core/constants/app_radius.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/theme/app_theme.dart';
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive.dart';
import 'package:personal_ai_assistant/core/utils/debounce.dart';
import 'package:personal_ai_assistant/core/utils/text_processing_cache.dart';
import 'package:personal_ai_assistant/core/widgets/top_floating_notice.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_highlight_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_transcription_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_highlights_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/conversation_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/services/content_image_share_service.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/highlight_card.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/highlight_detail_sheet.dart';
import 'package:personal_ai_assistant/shared/widgets/empty_state_widget.dart';

/// View mode for transcript display
enum TranscriptViewMode { highlights, fullTranscript }

class TranscriptDisplayWidget extends ConsumerStatefulWidget {

  const TranscriptDisplayWidget({
    required this.episodeId, required this.episodeTitle, super.key,
    this.transcription,
    this.onSearchChanged,
    this.highlights,
  });
  final int episodeId;
  final String episodeTitle;
  final PodcastTranscriptionResponse? transcription;
  final void Function(String)? onSearchChanged;
  final List<HighlightResponse>? highlights;

  @override
  ConsumerState<TranscriptDisplayWidget> createState() =>
      TranscriptDisplayWidgetState();
}

class TranscriptDisplayWidgetState
    extends ConsumerState<TranscriptDisplayWidget> {
  final TextEditingController _searchController = TextEditingController();
  // Separate scroll controllers for each view to avoid accessibility tree issues
  final ScrollController _highlightsScrollController = ScrollController();
  final ScrollController _fullTranscriptScrollController = ScrollController();
  List<String> _searchResults = [];
  bool _isSearching = false;
  String _lastSelectedTranscriptText = '';
  final Map<String, String> _selectedTranscriptSegments = <String, String>{};
  DebounceTimer? _searchDebounce;

  // View mode state - always default to highlights view
  TranscriptViewMode _viewMode = TranscriptViewMode.highlights;

  // Cached sorted highlights - only re-sorted when highlights data changes
  List<HighlightResponse>? _cachedSortedHighlights;
  List<HighlightResponse>? _lastRawHighlights;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  /// 滚动到顶部
  void scrollToTop() {
    final controller = _viewMode == TranscriptViewMode.highlights
        ? _highlightsScrollController
        : _fullTranscriptScrollController;
    if (controller.hasClients) {
      controller.animateTo(
        0,
        duration: AppDurations.scrollAnimation,
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _searchDebounce?.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _highlightsScrollController.dispose();
    _fullTranscriptScrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    _clearSelectedTranscriptSegments();
    if (query.isNotEmpty) {
      setState(() {
        _isSearching = true;
      });
      _searchDebounce?.cancel();
      _searchDebounce = DebounceTimer(
        AppDurations.debounceSearch,
        () => _performSearch(query),
      );
    } else {
      _searchDebounce?.cancel();
      setState(() {
        _isSearching = false;
        _searchResults.clear();
      });
    }
    widget.onSearchChanged?.call(query);
  }

  void _performSearch(String query) {
    final content = getTranscriptionText(widget.transcription) ?? '';
    searchTranscript(ref, content, query);

    // Get search results from provider
    final results = ref.read(transcriptionSearchResultsProvider);
    setState(() {
      _searchResults = results;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _clearSelectedTranscriptSegments();
    setState(() {
      _isSearching = false;
      _searchResults.clear();
    });
    clearTranscriptionSearchQuery(ref);
  }

  void _toggleTranscriptSegmentSelection(String key, String segment) {
    final normalized = segment.trim();
    if (normalized.isEmpty) {
      return;
    }
    setState(() {
      if (_selectedTranscriptSegments.containsKey(key)) {
        _selectedTranscriptSegments.remove(key);
      } else {
        _selectedTranscriptSegments[key] = normalized;
      }
    });
  }

  void _clearSelectedTranscriptSegments() {
    if (_selectedTranscriptSegments.isEmpty) {
      return;
    }
    setState(_selectedTranscriptSegments.clear);
  }

  int _segmentOrderFromKey(String key) {
    final parts = key.split('_');
    if (parts.length < 2) {
      return 0;
    }
    final index = int.tryParse(parts.last) ?? 0;
    final bucket = parts.first == 'full' ? 0 : 100000;
    return bucket + index;
  }

  String _buildSelectedTranscriptContent() {
    final entries = _selectedTranscriptSegments.entries.toList()
      ..sort(
        (a, b) =>
            _segmentOrderFromKey(a.key).compareTo(_segmentOrderFromKey(b.key)),
      );
    return entries.map((entry) => entry.value).join('\n\n').trim();
  }

  void _updateSelectedTranscriptText(
    String sourceText,
    TextSelection selection,
  ) {
    if (selection.isCollapsed ||
        selection.start < 0 ||
        selection.end <= selection.start ||
        selection.end > sourceText.length) {
      _lastSelectedTranscriptText = '';
      return;
    }
    _lastSelectedTranscriptText = sourceText
        .substring(selection.start, selection.end)
        .trim();
  }

  Future<void> _shareSelectedTranscriptAsImage() async {
    final l10n = context.l10n;
    try {
      await ContentImageShareService.shareAsImage(
        context,
        ShareImagePayload(
          episodeTitle: widget.episodeTitle,
          contentType: ShareContentType.transcript,
          content: _lastSelectedTranscriptText,
          sourceLabel: l10n.podcast_tab_transcript,
        ),
      );
    } on ContentImageShareException catch (e) {
      if (!mounted) {
        return;
      }
      showTopFloatingNotice(context, message: e.message, isError: true);
    }
  }

  Future<void> _shareSelectedTranscriptSegmentsAsImage() async {
    final l10n = context.l10n;
    try {
      await ContentImageShareService.shareAsImage(
        context,
        ShareImagePayload(
          episodeTitle: widget.episodeTitle,
          contentType: ShareContentType.transcript,
          content: _buildSelectedTranscriptContent(),
          sourceLabel: l10n.podcast_tab_transcript,
        ),
      );
    } on ContentImageShareException catch (e) {
      if (!mounted) {
        return;
      }
      showTopFloatingNotice(context, message: e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = getTranscriptionText(widget.transcription);

    if (content == null || content.isEmpty) {
      return _buildEmptyState(context);
    }

    final hasHighlights = widget.highlights != null && widget.highlights!.isNotEmpty;

    return Column(
      children: [
        // View mode toggle (Highlights | Full Text)
        _buildViewModeToggle(context),

        // Highlight extraction banner (show if no highlights)
        if (!hasHighlights && !_isSearching)
          _buildExtractHighlightsBanner(context),

        // Content - switch between highlights and full transcript
        Expanded(
          child: _viewMode == TranscriptViewMode.highlights
              ? _buildHighlightsView(context)
              : _buildFullTranscript(context, content),
        ),
      ],
    );
  }

  Widget _buildExtractHighlightsBanner(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final extension = appThemeOf(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: context.spacing.md, vertical: context.spacing.smMd),
      margin: EdgeInsets.fromLTRB(context.spacing.md, 0, context.spacing.md, context.spacing.sm),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(extension.itemRadius),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome_outlined,
            size: 20,
            color: scheme.primary,
          ),
          SizedBox(width: context.spacing.smMd),
          Expanded(
            child: Text(
              l10n.podcast_highlights_extract_hint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurface,
              ),
            ),
          ),
          SizedBox(width: context.spacing.sm),
          TextButton.icon(
            onPressed: _extractHighlights,
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: Text(l10n.podcast_highlights_extract_action),
            style: TextButton.styleFrom(
              foregroundColor: scheme.primary,
              padding: EdgeInsets.symmetric(horizontal: context.spacing.smMd, vertical: context.spacing.sm),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _extractHighlights() async {
    final response = await extractEpisodeHighlights(ref, widget.episodeId);
    if (!mounted) return;

    final l10n = context.l10n;
    if (response != null) {
      showTopFloatingNotice(
        context,
        message: l10n.podcast_highlights_extract_queued,
      );
    } else {
      showTopFloatingNotice(
        context,
        message: l10n.podcast_highlights_extract_failed,
        isError: true,
      );
    }
  }

  Widget _buildSelectionToolbar(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selectedCount = _selectedTranscriptSegments.length;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: context.spacing.md, vertical: context.spacing.sm),
      color: scheme.primaryContainer.withValues(alpha: 0.35),
      child: Row(
        children: [
          Text(
            l10n.podcast_selected_count(selectedCount),
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () =>
                unawaited(_shareSelectedTranscriptSegmentsAsImage()),
            icon: const Icon(Icons.ios_share_outlined, size: 16),
            label: Text(l10n.podcast_share_as_image),
          ),
          TextButton(
            onPressed: _clearSelectedTranscriptSegments,
            child: Text(l10n.podcast_deselect_all),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(context.spacing.md),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            // Inline platform branching: custom prefix/suffix and pill-shaped decoration
            // not supported by AdaptiveTextField/AdaptiveSearchBar APIs.
            child: PlatformHelper.isApple(context)
                ? CupertinoTextField(
                    controller: _searchController,
                    placeholder: l10n.podcast_transcript_search_hint,
                    prefix: Padding(
                      padding: EdgeInsetsDirectional.only(start: context.spacing.sm),
                      child: Icon(CupertinoIcons.search,
                          color: scheme.onSurfaceVariant, size: 18),
                    ),
                    suffix: _isSearching
                        ? CupertinoButton(
                            padding: EdgeInsets.zero,
                            minimumSize: Size(44, 44),
                            onPressed: _clearSearch,
                            child: Icon(CupertinoIcons.clear_thick_circled,
                                size: 16, color: scheme.onSurfaceVariant),
                          )
                        : null,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: AppRadius.xxlRadius,
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: context.spacing.md,
                      vertical: context.spacing.md,
                    ),
                  )
                : TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: l10n.podcast_transcript_search_hint,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _isSearching
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              tooltip: l10n.clear,
                              onPressed: _clearSearch,
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.xxlRadius,
                        borderSide: BorderSide(color: scheme.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppRadius.xxlRadius,
                        borderSide: BorderSide(color: scheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: AppRadius.xxlRadius,
                        borderSide: BorderSide(
                          color: scheme.primary,
                          width: 2,
                        ),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: context.spacing.md,
                        vertical: context.spacing.smMd,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeToggle(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.spacing.md, vertical: context.spacing.sm),
      child: AdaptiveSegmentedControl<TranscriptViewMode>(
        selected: _viewMode,
        onChanged: (value) {
          setState(() => _viewMode = value);
        },
        segments: {
          TranscriptViewMode.highlights: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome_outlined, size: 18),
              SizedBox(width: context.spacing.xs),
              Flexible(
                child: Text(
                  l10n.podcast_transcript_view_highlights,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          TranscriptViewMode.fullTranscript: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.article_outlined, size: 18),
              SizedBox(width: context.spacing.xs),
              Flexible(
                child: Text(
                  l10n.podcast_transcript_view_full,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        },
      ),
    );
  }

  Widget _buildHighlightsView(BuildContext context) {
    final highlights = widget.highlights;

    if (highlights == null || highlights.isEmpty) {
      return _buildEmptyHighlightsState(context);
    }

    // Only re-sort when the highlights reference changes (new data from parent)
    if (!identical(highlights, _lastRawHighlights)) {
      _lastRawHighlights = highlights;
      _cachedSortedHighlights = List<HighlightResponse>.from(highlights)
        ..sort((a, b) => b.overallScore.compareTo(a.overallScore));
    }
    final sortedHighlights = _cachedSortedHighlights!;

    return ListView.builder(
      controller: _highlightsScrollController,
      padding: EdgeInsets.all(context.spacing.md),
      itemCount: sortedHighlights.length,
      cacheExtent: 500,
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.only(bottom: context.spacing.smMd),
          child: RepaintBoundary(
            key: ValueKey('highlight_card_${sortedHighlights[index].id}'),
            child: HighlightCard(
              highlight: sortedHighlights[index],
              onTap: () => showHighlightDetailSheet(
                context: context,
                highlight: sortedHighlights[index],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyHighlightsState(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome_outlined,
            size: 64,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          SizedBox(height: context.spacing.md),
          Text(
            l10n.podcast_highlights_empty_title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.onSurface,
            ),
          ),
          SizedBox(height: context.spacing.sm),
          Text(
            l10n.podcast_highlights_empty_subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullTranscript(BuildContext context, String content) {
    // 根据句号分段（支持中英文句号）
    final segments = TextProcessingCache.getCachedSentences(content);

    return Column(
      children: [
        // Search bar (only in full transcript view)
        _buildSearchBar(context),

        // Selection toolbar (only in full transcript view)
        if (_selectedTranscriptSegments.isNotEmpty)
          _buildSelectionToolbar(context),

        // Content area
        Expanded(
          child: _isSearching
              ? _buildSearchResults(context)
              : Container(
                  padding: EdgeInsets.zero,
                  child: ListView.separated(
                    controller: _fullTranscriptScrollController,
                    itemCount: segments.length,
                    cacheExtent: 500,
                    separatorBuilder: (context, index) => SizedBox(height: context.spacing.smMd),
                    itemBuilder: (context, index) {
                      return RepaintBoundary(
                        key: ValueKey('transcript_segment_${segments[index].hashCode}'),
                        // Use normal segment only - no highlight styling in full transcript view
                        child: _buildNormalSegment(context, segments[index], index),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildNormalSegment(
    BuildContext context,
    String sentence,
    int index,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selectionKey = 'full_$index';
    final isSelected = _selectedTranscriptSegments.containsKey(selectionKey);
    return Container(
      padding: EdgeInsets.all(context.spacing.smMd),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(appThemeOf(context).itemRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '#${index + 1}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () =>
                    _toggleTranscriptSegmentSelection(selectionKey, sentence),
                icon: Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                ),
                tooltip: isSelected
                    ? l10n.podcast_deselect_all
                    : l10n.podcast_enter_select_mode,
                iconSize: 18,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          SelectableText(
            sentence,
            onSelectionChanged: (selection, _) {
              _updateSelectedTranscriptText(sentence, selection);
            },
            contextMenuBuilder: (context, editableTextState) {
              return AdaptiveTextSelectionToolbar.buttonItems(
                anchors: editableTextState.contextMenuAnchors,
                buttonItems: [
                  ...editableTextState.contextMenuButtonItems,
                  ContextMenuButtonItem(
                    label: l10n.podcast_share_as_image,
                    onPressed: () {
                      final value = editableTextState.textEditingValue;
                      final selected = value.selection
                          .textInside(value.text)
                          .trim();
                      _lastSelectedTranscriptText = selected;
                      ContextMenuController.removeAny();
                      unawaited(_shareSelectedTranscriptAsImage());
                    },
                  ),
                ],
              );
            },
            style: AppTextStyles.transcriptBody(scheme.onSurface),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: scheme.onSurfaceVariant,
            ),
            SizedBox(height: context.spacing.md),
            Text(
              l10n.podcast_transcript_no_match,
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(context.spacing.md),
      child: ListView.builder(
        controller: _fullTranscriptScrollController,
        itemCount: _searchResults.length,
        cacheExtent: 500,
        itemBuilder: (context, index) {
          final result = _searchResults[index];
          return RepaintBoundary(
            key: ValueKey('search_result_${result.hashCode}'),
            child: _buildSearchResultItem(context, result, index),
          );
        },
      ),
    );
  }

  Widget _buildSearchResultItem(
    BuildContext context,
    String result,
    int index,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selectionKey = 'search_$index';
    final isSelected = _selectedTranscriptSegments.containsKey(selectionKey);
    final query = _searchController.text;
    final highlightedText = _highlightSearchText(result, query);

    return Container(
      margin: EdgeInsets.only(bottom: context.spacing.smMd),
      padding: EdgeInsets.all(context.spacing.smMd),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(appThemeOf(context).itemRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n.podcast_transcript_match(index + 1),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () =>
                    _toggleTranscriptSegmentSelection(selectionKey, result),
                icon: Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                ),
                tooltip: isSelected
                    ? l10n.podcast_deselect_all
                    : l10n.podcast_enter_select_mode,
                iconSize: 18,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          SizedBox(height: context.spacing.xs),
          // Highlighted text
          SelectableText.rich(
            highlightedText,
            onSelectionChanged: (selection, _) {
              _updateSelectedTranscriptText(result, selection);
            },
            contextMenuBuilder: (context, editableTextState) {
              return AdaptiveTextSelectionToolbar.buttonItems(
                anchors: editableTextState.contextMenuAnchors,
                buttonItems: [
                  ...editableTextState.contextMenuButtonItems,
                  ContextMenuButtonItem(
                    label: l10n.podcast_share_as_image,
                    onPressed: () {
                      final value = editableTextState.textEditingValue;
                      final selected = value.selection
                          .textInside(value.text)
                          .trim();
                      _lastSelectedTranscriptText = selected;
                      ContextMenuController.removeAny();
                      unawaited(_shareSelectedTranscriptAsImage());
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  TextSpan _highlightSearchText(String text, String query) {
    final scheme = Theme.of(context).colorScheme;
    if (query.isEmpty) {
      return TextSpan(
        text: text,
        style: AppTextStyles.transcriptBody(scheme.onSurface),
      );
    }

    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    var start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) break;

      // Add text before match
      if (index > start) {
        spans.add(
          TextSpan(
            text: text.substring(start, index),
            style: AppTextStyles.transcriptBody(scheme.onSurface),
          ),
        );
      }

      // Add highlighted match
      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: AppTextStyles.transcriptBody(scheme.primary).copyWith(
            fontWeight: FontWeight.w700,
            backgroundColor: scheme.primary.withValues(alpha: 0.2),
          ),
        ),
      );

      start = index + query.length;
    }

    // Add remaining text
    if (start < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(start),
          style: AppTextStyles.transcriptBody(scheme.onSurface),
        ),
      );
    }

    return TextSpan(children: spans);
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = context.l10n;
    return EmptyStateWidget(
      icon: Icons.article_outlined,
      title: l10n.podcast_no_transcript,
      subtitle: l10n.podcast_click_to_transcribe,
    );
  }
}

/// Widget for displaying formatted transcription with speaker labels and timestamps
class FormattedTranscriptWidget extends ConsumerStatefulWidget {

  const FormattedTranscriptWidget({super.key, this.transcription});
  final PodcastTranscriptionResponse? transcription;

  @override
  ConsumerState<FormattedTranscriptWidget> createState() =>
      _FormattedTranscriptWidgetState();
}

class _FormattedTranscriptWidgetState
    extends ConsumerState<FormattedTranscriptWidget> {
  String? _cachedTranscriptContent;
  List<TranscriptDialogueSegment>? _cachedSegments;

  @override
  Widget build(BuildContext context) {
    final content = getTranscriptionText(widget.transcription);

    if (content == null || content.isEmpty) {
      return const TranscriptDisplayWidget(
        episodeId: 0,
        episodeTitle: '',
      );
    }

    // Cache regex parsing — only re-parse when content changes
    if (_cachedTranscriptContent != content) {
      _cachedTranscriptContent = content;
      _cachedSegments = _parseTranscriptSegments(content);
    }
    final segments = _cachedSegments!;

    if (segments.isEmpty) {
      // Fall back to plain text display
      return TranscriptDisplayWidget(
        transcription: widget.transcription,
        episodeId: 0,
        episodeTitle: '',
      );
    }

    return Container(
      padding: EdgeInsets.all(context.spacing.md),
      child: ListView.builder(
        itemCount: segments.length,
        cacheExtent: 500,
        itemBuilder: (context, index) {
          final segment = segments[index];
          return RepaintBoundary(
            key: ValueKey('dialogue_segment_$index'),
            child: _buildDialogueSegment(context, segment),
          );
        },
      ),
    );
  }

  List<TranscriptDialogueSegment> _parseTranscriptSegments(String content) {
    final segments = <TranscriptDialogueSegment>[];
    final lines = content.split('\n');

    for (final line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      // Try to match dialogue patterns
      // Pattern: [Speaker] Text
      final speakerMatch = RegExp(
        r'^\[([^\]]+)\]\s*(.*)$',
      ).firstMatch(trimmedLine);
      if (speakerMatch != null) {
        segments.add(
          TranscriptDialogueSegment(
            speaker: speakerMatch.group(1),
            text: speakerMatch.group(2) ?? '',
          ),
        );
        continue;
      }

      // Pattern: Speaker: Text
      final colonMatch = RegExp(r'^([^:]+):\s*(.*)$').firstMatch(trimmedLine);
      if (colonMatch != null) {
        segments.add(
          TranscriptDialogueSegment(
            speaker: colonMatch.group(1),
            text: colonMatch.group(2) ?? '',
          ),
        );
        continue;
      }

      // Pattern: [HH:MM:SS] Text
      final timestampMatch = RegExp(
        r'^\[(\d{1,2}:\d{2}(?::\d{2})?)\]\s*(.*)$',
      ).firstMatch(trimmedLine);
      if (timestampMatch != null) {
        segments.add(
          TranscriptDialogueSegment(
            timestamp: timestampMatch.group(1),
            text: timestampMatch.group(2) ?? '',
          ),
        );
        continue;
      }

      // Default: just text
      segments.add(TranscriptDialogueSegment(text: trimmedLine));
    }

    return segments;
  }

  Widget _buildDialogueSegment(
    BuildContext context,
    TranscriptDialogueSegment segment,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: EdgeInsets.only(bottom: context.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with speaker/timestamp
          if (segment.speaker != null || segment.timestamp != null)
            Row(
              children: [
                if (segment.speaker != null)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.spacing.sm,
                      vertical: context.spacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.1),
                      borderRadius: AppRadius.xsRadius,
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      segment.speaker!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                if (segment.speaker != null && segment.timestamp != null)
                  SizedBox(width: context.spacing.sm),
                if (segment.timestamp != null)
                  Text(
                    segment.timestamp!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          if (segment.speaker != null || segment.timestamp != null)
            SizedBox(height: context.spacing.sm),
          // Text content
          SelectableText(
            segment.text,
            style: AppTextStyles.transcriptBody(scheme.onSurface),
          ),
        ],
      ),
    );
  }
}
