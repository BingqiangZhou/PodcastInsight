import 'dart:async';
import 'dart:io';
import 'dart:ui' show PathMetric;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:xml/xml.dart';
import 'package:dio/dio.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/top_floating_notice.dart';
import '../../../../core/utils/app_logger.dart' as logger;

typedef RssUrlValidator = Future<bool> Function(String url);

@visibleForTesting
RssUrlValidator? debugBulkImportRssUrlValidator;

/// Model to represent URL validation status
class UrlValidationItem {
  String url;
  final String? title; // Optional title from OPML file
  bool isValid;
  bool isChecking;
  String? errorMessage;

  UrlValidationItem({
    required this.url,
    this.title,
    this.isValid = false,
    this.isChecking = true,
    this.errorMessage,
  });
}

/// Model to represent URL with optional title from OPML
class UrlWithTitle {
  final String url;
  final String? title;

  UrlWithTitle({required this.url, this.title});
}

class BulkImportDialog extends StatefulWidget {
  final Future<void> Function(List<String> urls) onImport;

  const BulkImportDialog({super.key, required this.onImport});

  @override
  State<BulkImportDialog> createState() => _BulkImportDialogState();
}

class _BulkImportDialogState extends State<BulkImportDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _textController = TextEditingController();
  List<String> _previewUrls = [];
  List<UrlValidationItem> _validationItems = [];
  bool _isImporting = false;
  bool _isDragging = false;

  // UI State
  bool _isInputExpanded = true;
  int _selectedFilterIndex = 0; // 0: Valid, 1: Invalid

  final Dio _dio = Dio();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _textController.addListener(() {
      // Auto-expand if user starts typing
      if (!_isInputExpanded && _textController.text.isNotEmpty) {
        setState(() {
          _isInputExpanded = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    _dio.close();
    super.dispose();
  }

  // Regex to find http/https links
  final RegExp _urlRegex = RegExp(
    r'https?://(?:www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b(?:[-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
    caseSensitive: false,
    multiLine: true,
  );

  Future<void> _analyzeText() async {
    final text = _textController.text;
    if (text.isEmpty) return;

    final urls = _extractUrls(text);
    final l10n = AppLocalizations.of(context)!;

    if (urls.isEmpty) {
      if (mounted) {
        showTopFloatingNotice(
          context,
          message: l10n.podcast_bulk_import_no_urls_text,
          isError: true,
        );
      }
      return;
    }

    // Validate URLs in background (append to existing list)
    await _validateUrls(urls, append: true);

    if (mounted) {
      setState(() {
        _textController.clear();
        _isInputExpanded = false;
        // Switch to Valid tab if we found items, or Invalid if only invalid
        _selectedFilterIndex = 0;
      });

      final validCount = _validationItems.where((item) => item.isValid).length;
      showTopFloatingNotice(
        context,
        message: l10n.podcast_bulk_import_links_found(urls.length, validCount),
      );
    }
  }

  List<String> _extractUrls(String content) {
    final urls = _urlRegex
        .allMatches(content)
        .map((m) => m.group(0)!.trim())
        .toSet()
        .toList();
    return urls;
  }

  /// Extract RSS feed URLs from OPML file content
  List<UrlWithTitle> _extractOpmlUrls(String content) {
    final urlsWithTitles = <UrlWithTitle>[];

    try {
      final document = XmlDocument.parse(content);

      // Find all outline elements with xmlUrl attribute (RSS feeds)
      final outlines = document.findAllElements('outline');

      for (final outline in outlines) {
        String? feedUrl;
        String? feedTitle;

        // Try xmlUrl attribute first (standard OPML for RSS feeds)
        feedUrl = outline.getAttribute('xmlUrl');
        if (feedUrl == null || !feedUrl.startsWith('http')) {
          // Try url attribute as fallback (some OPML variants use this)
          feedUrl = outline.getAttribute('url');
          if (feedUrl == null || !feedUrl.startsWith('http')) {
            continue;
          }
        }

        // Extract title from title attribute (not text)
        feedTitle =
            outline.getAttribute('title') ?? outline.getAttribute('xmlUrl');

        urlsWithTitles.add(UrlWithTitle(url: feedUrl, title: feedTitle));
      }

      logger.AppLogger.debug(
        '== OPML parsing: found ${urlsWithTitles.length} RSS feeds with titles ==',
      );
    } catch (e) {
      logger.AppLogger.debug('Error parsing OPML: $e');
      // If OPML parsing fails, fall back to regex extraction (without titles)
      final urls = _extractUrls(content);
      return urls.map((url) => UrlWithTitle(url: url, title: null)).toList();
    }

    // Remove duplicates based on URL
    final uniqueMap = <String, UrlWithTitle>{};
    for (final item in urlsWithTitles) {
      uniqueMap[item.url] = item;
    }
    return uniqueMap.values.toList();
  }

  /// Validate if a URL is a valid RSS feed by checking the content
  Future<bool> _validateRssUrl(String url) async {
    final override = debugBulkImportRssUrlValidator;
    if (override != null) {
      return override(url);
    }

    try {
      // Set timeout to 5 seconds
      final response = await _dio.get(
        url,
        options: Options(
          responseType: ResponseType.plain,
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          headers: {'User-Agent': 'Mozilla/5.0 (Compatible; RSS Reader)'},
        ),
      );

      final content = response.data.toString().toLowerCase();

      // Check for RSS/Atom feed indicators
      final hasRssTag =
          content.contains('<rss') || content.contains('<rdf:rdf');
      final hasAtomTag =
          content.contains('<feed') || content.contains('<entry>');
      final hasXmlDecl = content.contains('<?xml');

      return hasRssTag ||
          hasAtomTag ||
          (hasXmlDecl && (hasRssTag || hasAtomTag));
    } catch (e) {
      logger.AppLogger.debug('Error validating RSS URL $url: $e');
      return false;
    }
  }

  /// Validate all URLs and update the validation items
  Future<void> _validateUrls(List<String> urls, {bool append = false}) async {
    final l10n = AppLocalizations.of(context)!;
    // Remove duplicates from new URLs
    final existingUrls = _validationItems
        .map((item) => item.url.trim())
        .toSet();
    final newUrls = urls
        .map((u) => u.trim())
        .where((url) => !existingUrls.contains(url))
        .toSet() // Dedupe within new list
        .toList();

    if (newUrls.isEmpty) {
      if (mounted && append) {
        showTopFloatingNotice(
          context,
          message: l10n.podcast_bulk_import_urls_exist,
          isError: true,
          duration: const Duration(seconds: 2),
        );
      }
      return;
    }

    final items = newUrls.map((url) => UrlValidationItem(url: url)).toList();

    setState(() {
      if (append) {
        _validationItems.addAll(items);
        // We probably don't need _previewUrls as separate list if we use _validationItems
        // but keeping it for consistency if used elsewhere, though it seems redundant now.
        // Actually _previewUrls is updated in original code, so let's update it.
        _previewUrls.addAll(newUrls);
      } else {
        _validationItems = items;
        _previewUrls = newUrls;
      }
    });

    await _startValidation(items);
  }

  /// Validate all URLs with titles and update the validation items
  Future<void> _validateUrlsWithTitles(
    List<UrlWithTitle> urlsWithTitles, {
    bool append = false,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    // Remove duplicates from new URLs
    final existingUrls = _validationItems
        .map((item) => item.url.trim())
        .toSet();
    final newUrlsWithTitles = urlsWithTitles
        .where((item) => !existingUrls.contains(item.url.trim()))
        .toList(); // Should also dedupe within itself

    // Dedupe within input
    final uniqueNewItems = <String, UrlWithTitle>{};
    for (var item in newUrlsWithTitles) {
      uniqueNewItems[item.url.trim()] = item;
    }
    final finalizedNewItems = uniqueNewItems.values.toList();

    if (finalizedNewItems.isEmpty) {
      if (mounted && append) {
        showTopFloatingNotice(
          context,
          message: l10n.podcast_bulk_import_urls_exist,
          isError: true,
          duration: const Duration(seconds: 2),
        );
      }
      return;
    }

    final items = finalizedNewItems
        .map(
          (item) => UrlValidationItem(url: item.url.trim(), title: item.title),
        )
        .toList();
    final newUrls = finalizedNewItems.map((item) => item.url.trim()).toList();

    setState(() {
      if (append) {
        _validationItems.addAll(items);
        _previewUrls.addAll(newUrls);
      } else {
        _validationItems = items;
        _previewUrls = newUrls;
      }
    });

    await _startValidation(items);
  }

  Future<void> _startValidation(List<UrlValidationItem> items) async {
    // Validate each URL in parallel with concurrency limit
    final futures = <Future<void>>[];
    const concurrencyLimit = 5;

    for (var i = 0; i < items.length; i++) {
      if (futures.length >= concurrencyLimit) {
        await Future.wait(futures);
        futures.clear();
      }
      final item = items[i];
      futures.add(_validateSingleUrl(item));
    }
    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
    if (!mounted) {
      return;
    }
    setState(() {}); // Trigger rebuild after batch
  }

  /// Validate a single URL and update its status
  Future<void> _validateSingleUrl(UrlValidationItem item) async {
    final l10n = AppLocalizations.of(context)!;
    if (!mounted) return;

    // Optimistic update if re-validating
    setState(() {
      item.isChecking = true;
      item.errorMessage = null;
    });

    final isValid = await _validateRssUrl(item.url);

    if (mounted) {
      setState(() {
        item.isValid = isValid;
        item.isChecking = false;
        item.errorMessage = isValid ? null : l10n.podcast_not_valid_rss;
      });
    }
  }

  Future<void> _showEditUrlDialog(UrlValidationItem item) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: item.url);
    try {
      final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.podcast_bulk_import_edit_url),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: l10n.podcast_bulk_import_hint_text,
              hintText: 'https://example.com/feed',
              border: const OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text(l10n.podcast_bulk_import_save_revalidate),
            ),
          ],
        ),
      );

      if (!mounted) {
        return;
      }

      if (result != null && result.isNotEmpty && result != item.url) {
        // Check duplication with OTHER items?
        // For now, let's just update this one.
        setState(() {
          item.url = result;
        });
        await _validateSingleUrl(item);
      }
    } finally {
      controller.dispose();
    }
  }

  Future<void> _processFile(String path) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      logger.AppLogger.debug('== Processing file: $path ==');
      final file = File(path);
      final content = await file.readAsString();

      // Check if this is an OPML file by extension
      final isOpmlFile = path.toLowerCase().endsWith('.opml');

      if (isOpmlFile) {
        logger.AppLogger.debug('== Detected OPML file, using OPML parser ==');
        final urlsWithTitles = _extractOpmlUrls(content);

        if (urlsWithTitles.isEmpty) {
          if (mounted) {
            showTopFloatingNotice(
              context,
              message: l10n.podcast_bulk_import_no_urls_file,
              isError: true,
            );
          }
          return;
        }

        // Validate URLs with titles (append to existing list)
        await _validateUrlsWithTitles(urlsWithTitles, append: true);

        if (mounted) {
          setState(() {
            _isInputExpanded = false;
          });
          final validCount = _validationItems
              .where((item) => item.isValid)
              .length;
          showTopFloatingNotice(
            context,
            message: l10n.podcast_bulk_import_links_found(
              urlsWithTitles.length,
              validCount,
            ),
          );
        }
      } else {
        logger.AppLogger.debug('== Detected text file, using regex parser ==');
        final urls = _extractUrls(content);

        if (urls.isEmpty) {
          if (mounted) {
            showTopFloatingNotice(
              context,
              message: l10n.podcast_bulk_import_no_urls_file,
              isError: true,
            );
          }
          return;
        }

        // Validate URLs in background (append to existing list)
        await _validateUrls(urls, append: true);

        if (mounted) {
          setState(() {
            _isInputExpanded = false;
          });
          final validCount = _validationItems
              .where((item) => item.isValid)
              .length;
          showTopFloatingNotice(
            context,
            message: l10n.podcast_bulk_import_links_found(
              urls.length,
              validCount,
            ),
          );
        }
      }
    } catch (e) {
      logger.AppLogger.debug('Error reading file: $e');
      if (mounted) {
        showTopFloatingNotice(
          context,
          message: l10n.podcast_bulk_import_file_error(e.toString()),
          isError: true,
        );
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (!mounted) {
        return;
      }

      if (result != null && result.files.single.path != null) {
        await _processFile(result.files.single.path!);
      }
    } catch (e) {
      logger.AppLogger.debug('Error picking file: $e');
    }
  }

  Future<void> _import() async {
    final l10n = AppLocalizations.of(context)!;
    if (_validationItems.isEmpty) return;

    // Only import valid RSS URLs
    final validUrls = _validationItems
        .where((item) => item.isValid)
        .map((item) => item.url)
        .toList();

    if (validUrls.isEmpty) {
      if (mounted) {
        showTopFloatingNotice(
          context,
          message: l10n.podcast_bulk_import_no_valid_feeds,
          isError: true,
        );
      }
      return;
    }

    setState(() {
      _isImporting = true;
    });

    try {
      await widget.onImport(validUrls);
      if (mounted) {
        final rootContext = Navigator.of(context, rootNavigator: true).context;
        Navigator.of(context).pop();
        if (!rootContext.mounted) {
          return;
        }
        showTopFloatingNotice(
          rootContext,
          message: l10n.podcast_bulk_import_imported_count(validUrls.length),
        );
      }
    } catch (e) {
      if (mounted) {
        showTopFloatingNotice(
          context,
          message: l10n.podcast_bulk_import_failed(e.toString()),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }
  }

  bool _hasValidUrls() {
    return _validationItems.any((item) => item.isValid);
  }

  String _getImportButtonText() {
    final l10n = AppLocalizations.of(context)!;
    final validCount = _validationItems.where((item) => item.isValid).length;
    if (validCount > 0) {
      return l10n.podcast_bulk_import_imported_count(validCount);
    }
    return l10n.podcast_import_all;
  }

  Widget _buildFilterTabs() {
    final l10n = AppLocalizations.of(context)!;
    final validCount = _validationItems
        .where((item) => item.isValid || item.isChecking)
        .length;
    final invalidCount = _validationItems
        .where((item) => !item.isValid && !item.isChecking)
        .length;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterTab(
              index: 0,
              label: l10n.podcast_bulk_import_valid_count(validCount),
              color: Colors.blue,
              isSelected: _selectedFilterIndex == 0,
            ),
          ),
          Expanded(
            child: _buildFilterTab(
              index: 1,
              label: l10n.podcast_bulk_import_invalid_count(invalidCount),
              color: Colors.red,
              isSelected: _selectedFilterIndex == 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab({
    required int index,
    required String label,
    required Color color,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => setState(() => _selectedFilterIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildCompressedInput() {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: () {
        setState(() {
          _tabController.index = 1; // Switch to file tab
          _isInputExpanded = true;
        });
        unawaited(_pickFile());
      },
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            style: BorderStyle
                .none, // We'll rely on the background color mostly or use dashed border if we could
          ),
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        // Dashed border effect can be achieved with CustomPainter, but for simplicity we use simple border or look
        child: DottedBorderWidget(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
          radius: 12,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.upload_file,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    children: [
                      TextSpan(text: l10n.podcast_bulk_import_drag_drop),
                      TextSpan(
                        text: l10n.podcast_bulk_import_select_file,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUrlListItem(UrlValidationItem item, int index) {
    final l10n = AppLocalizations.of(context)!;
    Color statusColor;
    IconData statusIcon;
    bool isValid = item.isValid;
    bool isChecking = item.isChecking;

    if (isChecking) {
      statusColor = Colors.orange;
      statusIcon = Icons.hourglass_empty;
    } else if (isValid) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.error;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 2), // More compact margin
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6), // Smaller radius
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(
          horizontal: 0,
          vertical: -4,
        ), // Compact density
        contentPadding: const EdgeInsets.fromLTRB(
          8,
          0,
          4,
          0,
        ), // More compact padding
        leading: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(statusIcon, color: statusColor, size: 14), // Smaller icon
        ),
        title: Text(
          item.title ?? l10n.podcast_unknown_title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.url,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (!isValid && !isChecking && item.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  item.errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 9),
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.copy, size: 14),
              onPressed: () => _copyUrlToClipboard(item.url, item.title),
              tooltip: l10n.podcast_copy,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              splashRadius: 16,
            ),
            const SizedBox(width: 4),
            if (!isValid && !isChecking)
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue, size: 14),
                onPressed: () => _showEditUrlDialog(item),
                tooltip: l10n.podcast_edit_retry,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 16,
              )
            else
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.grey,
                  size: 14,
                ),
                onPressed: () {
                  setState(() {
                    final originalIndex = _validationItems.indexOf(item);
                    if (originalIndex != -1) {
                      _validationItems.removeAt(originalIndex);
                      // Update _previewUrls as well
                      if (_previewUrls.contains(item.url)) {
                        _previewUrls.remove(item.url);
                      }

                      if (_validationItems.isEmpty && !_isInputExpanded) {
                        _isInputExpanded = true;
                      }
                    }
                  });
                },
                tooltip: l10n.podcast_remove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 16,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyUrlToClipboard(String url, String? title) async {
    final l10n = AppLocalizations.of(context)!;
    final text = (title != null && title.isNotEmpty) ? '$title - $url' : url;
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      showTopFloatingNotice(
        context,
        message: l10n.podcast_copied(text),
        duration: const Duration(seconds: 1),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Filter items based on selection
    final filteredItems = _validationItems.where((item) {
      if (_selectedFilterIndex == 0) {
        return item.isValid || item.isChecking;
      } else {
        return !item.isValid && !item.isChecking;
      }
    }).toList();

    return DropTarget(
      onDragEntered: (detail) {
        setState(() => _isDragging = true);
      },
      onDragExited: (detail) {
        setState(() => _isDragging = false);
      },
      onDragDone: (detail) async {
        for (final file in detail.files) {
          await _processFile(file.path);
        }
        if (!mounted) {
          return;
        }
        setState(() => _isDragging = false);
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Center(
          child: Container(
            width: 600,
            constraints: const BoxConstraints(maxHeight: 800),
            decoration: BoxDecoration(
              color: _isDragging
                  ? Theme.of(context).primaryColor.withValues(alpha: 0.15)
                  : Theme.of(context).colorScheme.surface,
              border: Border.all(
                color: _isDragging
                    ? Theme.of(context).primaryColor
                    : Colors.transparent,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title Bar with Toggles
                  Row(
                    children: [
                      Text(
                        l10n.podcast_bulk_import,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Input Tabs aligned to the right of title
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.outline.withValues(alpha: 0.3),
                          ),
                        ),
                        padding: const EdgeInsets.all(3),
                        child: Row(
                          children: [
                            _buildInputTab(
                              l10n.podcast_bulk_import_input_text,
                              0,
                            ),
                            _buildInputTab(
                              l10n.podcast_bulk_import_input_file,
                              1,
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  if (_isDragging)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          style: BorderStyle.solid,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.file_upload,
                              size: 48,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n.drop_files_here,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_isInputExpanded)
                    SizedBox(
                      height: 180,
                      child: TabBarView(
                        controller: _tabController,
                        physics:
                            const NeverScrollableScrollPhysics(), // Prevent swiping
                        children: [
                          // Tab 0: Paste Text
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _textController,
                                  maxLines: null,
                                  expands: true,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerLow,
                                    hintText:
                                        l10n.podcast_bulk_import_paste_hint,
                                    contentPadding: const EdgeInsets.all(12),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.icon(
                                  onPressed: _analyzeText,
                                  icon: const Icon(
                                    Icons.auto_awesome,
                                    size: 18,
                                  ),
                                  label: Text(l10n.podcast_bulk_import_extract),
                                  style: FilledButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Tab 1: File Upload
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Theme.of(context).dividerColor,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerLow,
                            ),
                            child: InkWell(
                              onTap: _pickFile,
                              borderRadius: BorderRadius.circular(12),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.folder_open,
                                      size: 40,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      l10n.podcast_bulk_import_click_select,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      l10n.podcast_bulk_import_or_drag_drop,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    // Collapsed Input
                    _buildCompressedInput(),

                  if (_validationItems.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildFilterTabs(),
                    const SizedBox(height: 12),
                    Text(
                      l10n.podcast_rss_list,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.only(
                          right: 4,
                        ), // Space for scrollbar
                        child: ListView.builder(
                          itemCount: filteredItems.length,
                          itemBuilder: (context, index) {
                            return _buildUrlListItem(
                              filteredItems[index],
                              index,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(l10n.cancel),
                        ),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: _hasValidUrls() && !_isImporting
                              ? _import
                              : null,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          child: _isImporting
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                )
                              : Text(_getImportButtonText()),
                        ),
                      ],
                    ),
                  ] else if (!_isInputExpanded) ...[
                    // This state shouldn't theoretically happen if logic is correct (collapsed only if items exist),
                    // but as a fallback:
                    Expanded(child: Center(child: Text(l10n.podcast_no_items))),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputTab(String text, int index) {
    final isSelected = _tabController.index == index && _isInputExpanded;

    return InkWell(
      onTap: () {
        setState(() {
          _isInputExpanded = true;
          _tabController.index = index;
        });
        if (index == 1) {
          unawaited(_pickFile());
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class DottedBorderWidget extends StatelessWidget {
  final Widget child;
  final Color color;
  final double radius;

  const DottedBorderWidget({
    super.key,
    required this.child,
    required this.color,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DottedBorderPainter(color: color, radius: radius),
      child: child,
    );
  }
}

class _DottedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  _DottedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(radius),
        ),
      );

    // Simple implementation for dotted effect
    final dashPath = Path();
    double dashWidth = 5.0;
    double dashSpace = 5.0;
    double distance = 0.0;

    for (PathMetric pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        dashPath.addPath(
          pathMetric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }

    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
