import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations_extension.dart';
import '../../../../core/utils/text_processing_cache.dart';
import '../../../../core/widgets/top_floating_notice.dart';
import 'podcast_empty_state.dart';
import '../providers/transcription_providers.dart';
import '../../data/models/podcast_transcription_model.dart';
import '../services/content_image_share_service.dart';

class TranscriptDisplayWidget extends ConsumerStatefulWidget {
  final int episodeId;
  final String episodeTitle;
  final PodcastTranscriptionResponse? transcription;
  final Function(String)? onSearchChanged;

  const TranscriptDisplayWidget({
    super.key,
    required this.episodeId,
    required this.episodeTitle,
    this.transcription,
    this.onSearchChanged,
  });

  @override
  ConsumerState<TranscriptDisplayWidget> createState() =>
      TranscriptDisplayWidgetState();
}

class TranscriptDisplayWidgetState
    extends ConsumerState<TranscriptDisplayWidget> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<String> _searchResults = [];
  bool _isSearching = false;
  String _lastSelectedTranscriptText = '';
  final Map<String, String> _selectedTranscriptSegments = <String, String>{};

  /// 滚动到顶部
  void scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    _clearSelectedTranscriptSegments();
    if (query.isNotEmpty) {
      setState(() {
        _isSearching = true;
      });
      _performSearch(query);
    } else {
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
    setState(() {
      _selectedTranscriptSegments.clear();
    });
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

    return Column(
      children: [
        // Search bar
        _buildSearchBar(context),
        if (_selectedTranscriptSegments.isNotEmpty)
          _buildSelectionToolbar(context),

        // Content
        Expanded(
          child: _isSearching
              ? _buildSearchResults(context)
              : _buildFullTranscript(context, content),
        ),
      ],
    );
  }

  Widget _buildSelectionToolbar(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selectedCount = _selectedTranscriptSegments.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.podcast_transcript_search_hint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isSearching
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearch,
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide(color: scheme.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide(color: scheme.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide(
                    color: scheme.primary,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullTranscript(BuildContext context, String content) {
    // 根据句号分段（支持中英文句号）
    final segments = TextProcessingCache.getCachedSentences(content);

    return Container(
      padding: const EdgeInsets.all(16),
      child: ListView.separated(
        controller: _scrollController,
        itemCount: segments.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _buildSentenceSegment(context, segments[index], index);
        },
      ),
    );
  }

  Widget _buildSentenceSegment(
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected
              ? scheme.primary
              : scheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
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
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
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
            const SizedBox(height: 16),
            Text(
              l10n.podcast_transcript_no_match,
              style: TextStyle(
                fontSize: 16,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final result = _searchResults[index];
          return _buildSearchResultItem(context, result, index);
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
    final scheme = Theme.of(context).colorScheme;
    final selectionKey = 'search_$index';
    final isSelected = _selectedTranscriptSegments.containsKey(selectionKey);
    final query = _searchController.text;
    final highlightedText = _highlightSearchText(result, query);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected
              ? scheme.primary
              : scheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n.podcast_transcript_match(index + 1),
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
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
          const SizedBox(height: 4),
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
        style: TextStyle(
          fontSize: 15,
          height: 1.6,
          color: scheme.onSurface,
        ),
      );
    }

    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) break;

      // Add text before match
      if (index > start) {
        spans.add(
          TextSpan(
            text: text.substring(start, index),
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: scheme.onSurface,
            ),
          ),
        );
      }

      // Add highlighted match
      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: TextStyle(
            fontSize: 15,
            height: 1.6,
            color: scheme.primary,
            fontWeight: FontWeight.bold,
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
          style: TextStyle(
            fontSize: 15,
            height: 1.6,
            color: scheme.onSurface,
          ),
        ),
      );
    }

    return TextSpan(children: spans);
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = context.l10n;
    return PodcastEmptyState(
      icon: Icons.article_outlined,
      title: l10n.podcast_no_transcript,
      subtitle: l10n.podcast_click_to_transcribe,
    );
  }
}

/// Widget for displaying formatted transcription with speaker labels and timestamps
class FormattedTranscriptWidget extends ConsumerWidget {
  final PodcastTranscriptionResponse? transcription;

  const FormattedTranscriptWidget({super.key, this.transcription});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = getTranscriptionText(transcription);

    if (content == null || content.isEmpty) {
      return const TranscriptDisplayWidget(
        transcription: null,
        episodeId: 0,
        episodeTitle: '',
      );
    }

    // Try to parse the transcript for dialogue format
    final segments = _parseTranscriptSegments(content);

    if (segments.isEmpty) {
      // Fall back to plain text display
      return TranscriptDisplayWidget(
        transcription: transcription,
        episodeId: 0,
        episodeTitle: '',
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: ListView.builder(
        itemCount: segments.length,
        itemBuilder: (context, index) {
          final segment = segments[index];
          return _buildDialogueSegment(context, segment);
        },
      ),
    );
  }

  List<TranscriptDialogueSegment> _parseTranscriptSegments(String content) {
    final segments = <TranscriptDialogueSegment>[];
    final lines = content.split('\n');

    for (var line in lines) {
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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with speaker/timestamp
          if (segment.speaker != null || segment.timestamp != null)
            Row(
              children: [
                if (segment.speaker != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      segment.speaker!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                if (segment.speaker != null && segment.timestamp != null)
                  const SizedBox(width: 8),
                if (segment.timestamp != null)
                  Text(
                    segment.timestamp!,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          if (segment.speaker != null || segment.timestamp != null)
            const SizedBox(height: 6),
          // Text content
          SelectableText(
            segment.text,
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
