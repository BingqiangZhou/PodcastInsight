import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/app_localizations_en.dart';

/// Widget for displaying AI-generated podcast episode summaries.
///
/// Features:
/// - Markdown rendering with custom styling
/// - Text selection support
/// - Share functionality (all content or selected text)
/// - Scroll-to-top capability
/// - State persistence with AutomaticKeepAliveClientMixin
class SummaryDisplayWidget extends ConsumerStatefulWidget {
  /// Title of the podcast episode (used for sharing)
  final String episodeTitle;

  /// The summary content in markdown format
  final String summary;

  /// Whether to use compact layout (reduced spacing)
  final bool compact;

  /// Callback for sharing all summary content as image
  final Future<void> Function(String episodeTitle, String summary)?
      onShareAll;

  /// Callback for sharing selected text as image
  final Future<void> Function(
    String episodeTitle,
    String summary,
    String selectedText,
  )? onShareSelected;

  /// Whether to handle scrolling internally.
  /// When false, the widget content will not be wrapped in SingleChildScrollView.
  final bool useInternalScrolling;

  const SummaryDisplayWidget({
    super.key,
    required this.episodeTitle,
    required this.summary,
    this.compact = false,
    this.onShareAll,
    this.onShareSelected,
    this.useInternalScrolling = true,
  });

  @override
  ConsumerState<SummaryDisplayWidget> createState() =>
      SummaryDisplayWidgetState();
}

class SummaryDisplayWidgetState
    extends ConsumerState<SummaryDisplayWidget>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  String _selectedText = '';

  @override
  bool get wantKeepAlive => true;

  /// Scrolls the content view to the top with animation.
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
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
    final theme = Theme.of(context);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Share all button
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: widget.onShareAll != null
                ? () => unawaited(
                    widget.onShareAll!(widget.episodeTitle, widget.summary),
                  )
                : null,
            icon: const Icon(Icons.ios_share_outlined, size: 16),
            label: Text(l10n.podcast_share_all_content),
          ),
        ),
        const SizedBox(height: 10),
        // Markdown content with selection support
        SelectionArea(
          onSelectionChanged: (selectedContent) {
            _selectedText = selectedContent?.plainText.trim() ?? '';
          },
          contextMenuBuilder: (context, selectableRegionState) {
            final buttonItems = [
              ...selectableRegionState.contextMenuButtonItems,
            ];

            // Add custom share as image menu item if callback is provided
            if (widget.onShareSelected != null) {
              buttonItems.add(
                ContextMenuButtonItem(
                  label: l10n.podcast_share_as_image,
                  onPressed: () {
                    ContextMenuController.removeAny();
                    unawaited(
                      widget.onShareSelected!(
                        widget.episodeTitle,
                        widget.summary,
                        _selectedText,
                      ),
                    );
                  },
                ),
              );
            }

            return AdaptiveTextSelectionToolbar.buttonItems(
              anchors: selectableRegionState.contextMenuAnchors,
              buttonItems: buttonItems,
            );
          },
          child: RepaintBoundary(
            child: MarkdownBody(
              data: widget.summary,
              styleSheet: MarkdownStyleSheet(
                p: theme.textTheme.bodyLarge?.copyWith(
                  height: widget.compact ? 1.55 : 1.65,
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
        ),
      ],
    );

    if (widget.useInternalScrolling) {
      return SingleChildScrollView(
        controller: _scrollController,
        child: content,
      );
    }

    return content;
  }
}
