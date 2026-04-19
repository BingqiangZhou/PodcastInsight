import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:personal_ai_assistant/core/constants/app_durations.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_en.dart';
import 'package:personal_ai_assistant/core/theme/app_theme.dart';
import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;
import 'package:personal_ai_assistant/core/widgets/top_floating_notice.dart';
import 'package:personal_ai_assistant/features/podcast/core/utils/html_sanitizer.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/shared/widgets/empty_state_widget.dart';
import 'package:url_launcher/url_launcher.dart';

@immutable
class ShownotesAnchor {
  const ShownotesAnchor({
    required this.id,
    required this.title,
    required this.index,
  });

  final String id;
  final String title;
  final int index;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is ShownotesAnchor &&
        other.id == id &&
        other.title == title &&
        other.index == index;
  }

  @override
  int get hashCode => Object.hash(id, title, index);
}

class ShownotesDisplayWidget extends ConsumerStatefulWidget {

  const ShownotesDisplayWidget({
    required this.episode, super.key,
    this.onAnchorsChanged,
  });
  final PodcastEpisodeModel episode;
  final ValueChanged<List<ShownotesAnchor>>? onAnchorsChanged;

  @override
  ConsumerState<ShownotesDisplayWidget> createState() =>
      ShownotesDisplayWidgetState();
}

class _ShownotesSection {
  const _ShownotesSection({required this.anchor, required this.contentHtml});

  final ShownotesAnchor anchor;
  final String contentHtml;
}

class ShownotesDisplayWidgetState
    extends ConsumerState<ShownotesDisplayWidget> {
  final ScrollController _scrollController = ScrollController();
  String _shownotes = '';
  String _sanitizedShownotes = '';
  List<ShownotesAnchor> _anchors = const <ShownotesAnchor>[];
  List<_ShownotesSection> _sections = const <_ShownotesSection>[];
  final Map<String, GlobalKey> _sectionKeys = <String, GlobalKey>{};
  bool _isLoading = false;

  void scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: AppDurations.scrollAnimation,
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> scrollToAnchor(String anchorId) async {
    final targetKey = _sectionKeys[anchorId];
    final targetContext = targetKey?.currentContext;
    if (targetContext == null) {
      scrollToTop();
      return;
    }

    await Scrollable.ensureVisible(
      targetContext,
      duration: AppDurations.transitionNormal,
      curve: Curves.easeInOutCubic,
      alignment: 0.08,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshShownotesCache();
    });
  }

  @override
  void didUpdateWidget(covariant ShownotesDisplayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_contentSignature(oldWidget.episode) !=
        _contentSignature(widget.episode)) {
      _refreshShownotesCache();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState(context);
    }

    if (_shownotes.isEmpty) {
      return _buildEmptyState(context);
    }

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
    final titleStyle = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurface,
    );

    return Padding(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        controller: _scrollController,
        child: SelectionArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(l10n.podcast_tab_shownotes, style: titleStyle)),
                  IconButton(
                    tooltip:
                        (AppLocalizations.of(context) ?? AppLocalizationsEn())
                            .podcast_copy,
                    onPressed: _copyShownotes,
                    icon: const Icon(Icons.content_copy_rounded, size: 18),
                  ),
                ],
              ),
              SizedBox(height: context.spacing.smMd),
              ..._buildSections(context),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refreshShownotesCache() async {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
    final nextShownotes = _resolveShownotesContent(widget.episode);
    if (nextShownotes.isEmpty) {
      if (mounted && _shownotes.isNotEmpty) {
        setState(() {
          _shownotes = '';
          _sanitizedShownotes = '';
          _sections = const <_ShownotesSection>[];
          _anchors = const <ShownotesAnchor>[];
          _sectionKeys.clear();
        });
        _notifyAnchorsChanged();
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    // Use async sanitization with compute for large content in production
    // Fall back to sync for small content or when compute fails (e.g., in tests)
    String nextSanitized;
    if (nextShownotes.length < 10000) {
      // For small content, use sync to avoid isolate overhead
      nextSanitized = HtmlSanitizer.sanitize(nextShownotes);
    } else {
      // For large content, use async with compute
      try {
        nextSanitized = await HtmlSanitizer.sanitizeAsync(nextShownotes);
      } catch (e) {
        // Fallback to sync if compute fails (e.g., in test environment)
        logger.AppLogger.debug('[Shownotes] Async sanitization failed, falling back to sync: $e');
        nextSanitized = HtmlSanitizer.sanitize(nextShownotes);
      }
    }
    final nextSections = nextSanitized.isEmpty
        ? const <_ShownotesSection>[]
        : _extractSections(nextSanitized, fallbackTitle: l10n.podcast_tab_shownotes);
    final nextAnchors = nextSections
        .map((section) => section.anchor)
        .toList(growable: false);

    if (nextShownotes == _shownotes &&
        nextSanitized == _sanitizedShownotes &&
        listEquals(nextAnchors, _anchors)) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    if (kDebugMode) {
      logger.AppLogger.debug(
        '[Shownotes] content=${nextShownotes.length}, sanitized=${nextSanitized.length}',
      );
    }

    if (!mounted) return;

    setState(() {
      _shownotes = nextShownotes;
      _sanitizedShownotes = nextSanitized;
      _isLoading = false;
      _applySections(nextSections);
    });
    _notifyAnchorsChanged();
  }

  String _resolveShownotesContent(PodcastEpisodeModel episode) {
    final description = episode.description;
    if (description != null && description.isNotEmpty) {
      return description;
    }

    final aiSummary = episode.aiSummary;
    if (aiSummary != null && aiSummary.isNotEmpty) {
      return aiSummary;
    }

    final metadata = episode.metadata;
    if (metadata != null) {
      final shownotes = metadata['shownotes'];
      if (shownotes != null) {
        return shownotes.toString();
      }
    }

    final subscription = episode.subscription;
    if (subscription != null) {
      final subscriptionDesc = subscription['description'];
      if (subscriptionDesc != null && subscriptionDesc.toString().isNotEmpty) {
        return subscriptionDesc.toString();
      }
    }

    return '';
  }

  String _contentSignature(PodcastEpisodeModel episode) {
    return '${episode.description}|${episode.aiSummary}|${episode.metadata?['shownotes']}|${episode.subscription?['description']}';
  }

  void _applySections(List<_ShownotesSection> sections) {
    _sections = sections;
    _anchors = sections
        .map((section) => section.anchor)
        .toList(growable: false);
    _sectionKeys
      ..clear()
      ..addEntries(
        sections.map(
          (section) =>
              MapEntry<String, GlobalKey>(section.anchor.id, GlobalKey()),
        ),
      );
  }

  void _notifyAnchorsChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.onAnchorsChanged?.call(_anchors);
    });
  }

  List<_ShownotesSection> _extractSections(
    String sanitizedShownotes, {
    String fallbackTitle = 'Shownotes',
  }) {
    final fragment = html_parser.parseFragment(sanitizedShownotes);
    final nodes = fragment.nodes
        .where((node) => _nodeText(node).isNotEmpty)
        .toList(growable: false);

    if (nodes.isEmpty) {
      return const <_ShownotesSection>[];
    }

    final hasHeading = nodes.any(_isHeadingNode);
    final sections = hasHeading
        ? _buildSectionsFromHeadings(nodes)
        : _buildFallbackSections(nodes);

    if (sections.isNotEmpty) {
      return sections;
    }

    return <_ShownotesSection>[
      _ShownotesSection(
        anchor: ShownotesAnchor(
          id: 'shownotes-0',
          title: fallbackTitle,
          index: 0,
        ),
        contentHtml: sanitizedShownotes,
      ),
    ];
  }

  List<_ShownotesSection> _buildSectionsFromHeadings(List<dom.Node> nodes) {
    final sections = <_ShownotesSection>[];
    final introNodes = <dom.Node>[];
    String? currentTitle;
    final currentNodes = <dom.Node>[];

    void flushSection() {
      final title = (currentTitle ?? '').trim();
      final html = currentNodes.map(_nodeOuterHtml).join();
      if (title.isEmpty && html.trim().isEmpty) {
        return;
      }

      final safeTitle = title.isEmpty
          ? 'Section ${sections.length + 1}'
          : title;
      sections.add(
        _ShownotesSection(
          anchor: ShownotesAnchor(
            id: _slugifyAnchor(safeTitle, sections.length),
            title: safeTitle,
            index: sections.length,
          ),
          contentHtml: html,
        ),
      );
      currentNodes.clear();
    }

    for (final node in nodes) {
      if (_isHeadingNode(node)) {
        if (currentTitle == null && introNodes.isNotEmpty) {
          currentNodes.addAll(introNodes);
          introNodes.clear();
        } else {
          flushSection();
        }
        currentTitle = _nodeText(node);
        continue;
      }

      if (currentTitle == null) {
        introNodes.add(node);
      } else {
        currentNodes.add(node);
      }
    }

    if (currentTitle == null) {
      return _buildFallbackSections(nodes);
    }

    if (currentNodes.isEmpty && introNodes.isNotEmpty) {
      currentNodes.addAll(introNodes);
    }
    flushSection();
    return sections;
  }

  List<_ShownotesSection> _buildFallbackSections(List<dom.Node> nodes) {
    final sections = <_ShownotesSection>[];
    final buffer = <dom.Node>[];
    var bufferLength = 0;

    void flushBuffer() {
      if (buffer.isEmpty) {
        return;
      }
      final title = _deriveFallbackTitle(buffer, sections.length);
      final html = buffer.map(_nodeOuterHtml).join();
      sections.add(
        _ShownotesSection(
          anchor: ShownotesAnchor(
            id: _slugifyAnchor(title, sections.length),
            title: title,
            index: sections.length,
          ),
          contentHtml: html,
        ),
      );
      buffer.clear();
      bufferLength = 0;
    }

    for (final node in nodes) {
      buffer.add(node);
      bufferLength += _nodeText(node).length;
      if (bufferLength >= 420 || buffer.length >= 3) {
        flushBuffer();
      }
    }

    flushBuffer();
    return sections;
  }

  String _deriveFallbackTitle(List<dom.Node> nodes, int index) {
    for (final node in nodes) {
      final text = _nodeText(node);
      if (text.isNotEmpty) {
        return text.length > 28 ? '${text.substring(0, 28)}...' : text;
      }
    }
    return 'Section ${index + 1}';
  }

  bool _isHeadingNode(dom.Node node) {
    return node is dom.Element &&
        const <String>{
          'h1',
          'h2',
          'h3',
          'h4',
          'h5',
          'h6',
        }.contains(node.localName);
  }

  String _slugifyAnchor(String title, int index) {
    final normalized = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fa5]+'), '-')
        .replaceAll(RegExp('-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return normalized.isEmpty ? 'shownotes-$index' : '$normalized-$index';
  }

  String _nodeText(dom.Node node) {
    return node.text?.trim() ?? '';
  }

  String _nodeOuterHtml(dom.Node node) {
    if (node is dom.Element) {
      return node.outerHtml;
    }
    final text = node.text?.trim() ?? '';
    return text.isEmpty ? '' : '<p>$text</p>';
  }

  List<Widget> _buildSections(BuildContext context) {
    final widgets = <Widget>[];
    for (var index = 0; index < _sections.length; index++) {
      final section = _sections[index];
      final sectionKey = _sectionKeys[section.anchor.id];
      if (sectionKey == null) continue; // Skip if key not found
      widgets.add(
        Container(
          key: sectionKey,
          padding: EdgeInsets.only(
            bottom: index == _sections.length - 1 ? 0 : 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (section.anchor.title.isNotEmpty) ...[
                Text(
                  section.anchor.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: context.spacing.smMd),
              ],
              _buildHtmlBody(context, section.contentHtml),
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  Widget _buildHtmlBody(BuildContext context, String html) {
    return HtmlWidget(
      html,
      textStyle: AppTheme.transcriptBody(Theme.of(context).colorScheme.onSurface),
      onTapUrl: (url) async {
        try {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            return true;
          }
          return false;
        } catch (e) {
          if (context.mounted) {
            final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
            showTopFloatingNotice(
              context,
              message: l10n.error_opening_link(e.toString()),
              isError: true,
            );
          }
          return false;
        }
      },
      onErrorBuilder: (context, error, stackTrace) {
        final errorL10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
        return Container(
          padding: EdgeInsets.all(context.spacing.md),
          child: Column(
            children: [
              Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              SizedBox(height: context.spacing.sm),
              Text(
                errorL10n.podcast_error_loading,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
        );
      },
      customStylesBuilder: (element) {
        final styles = <String, String>{};

        if (element.localName == 'blockquote') {
          styles['border-left'] =
              '4px solid ${_colorToHex(Theme.of(context).colorScheme.primary)}';
          styles['padding-left'] = '16px';
          styles['margin-left'] = '0';
          styles['color'] = _colorToHex(
            Theme.of(context).colorScheme.onSurfaceVariant,
          );
        }

        if (element.localName == 'pre' || element.localName == 'code') {
          styles['background-color'] = _colorToHex(
            Colors.transparent,
          );
          styles['padding'] = '8px';
          styles['border-radius'] = '4px';
          styles['font-family'] = 'monospace';
        }

        if (element.localName?.startsWith('h') == true) {
          styles['color'] = _colorToHex(
            Theme.of(context).colorScheme.onSurface,
          );
          styles['font-weight'] = 'bold';
        }

        if (element.localName == 'a') {
          styles['color'] = _colorToHex(Theme.of(context).colorScheme.primary);
          styles['text-decoration'] = 'underline';
        }

        return styles.isNotEmpty ? styles : null;
      },
      enableCaching: true,
    );
  }

  Future<void> _copyShownotes() async {
    if (_shownotes.isEmpty) {
      return;
    }

    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
    final plainText =
        html_parser.parseFragment(_sanitizedShownotes).text?.trim() ?? '';
    await Clipboard.setData(ClipboardData(text: plainText));
    if (!mounted) {
      return;
    }
    showTopFloatingNotice(context, message: l10n.podcast_copied(l10n.podcast_tab_shownotes));
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
    return EmptyStateWidget(
      icon: Icons.description_outlined,
      title: l10n.podcast_no_shownotes,
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
    return Padding(
      padding: EdgeInsets.all(context.spacing.md),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.podcast_tab_shownotes,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            SizedBox(height: context.spacing.lg),
            const CircularProgressIndicator.adaptive(),
          ],
        ),
      ),
    );
  }

  String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).substring(2)}';
  }
}
