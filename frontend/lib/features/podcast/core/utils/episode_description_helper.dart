import 'dart:collection';

/// Helper utility for extracting and formatting episode descriptions
///
/// This class provides functions to:
/// 1. Extract the "main topics" section from AI-generated summaries
/// 2. Strip HTML tags from shownotes content
/// 3. Determine the best description to display based on available data
class EpisodeDescriptionHelper {
  static const int _stripHtmlCacheLimit = 300;
  static final Map<String, String> _stripHtmlCache = <String, String>{};
  static final Queue<String> _stripHtmlCacheOrder = Queue<String>();

  /// Extracts the "主要话题" (Main Topics) section from AI summary
  ///
  /// The AI summary format is:
  /// ```markdown
  /// ## 主要话题
  /// - Topic 1
  /// - Topic 2
  ///
  /// ## 关键见解
  /// ...
  /// ```
  ///
  /// [aiSummary] - The AI-generated summary string in Markdown format
  ///
  /// Returns the main topics content, or null if not found
  static String? extractMainTopicsFromAiSummary(String? aiSummary) {
    if (aiSummary == null || aiSummary.isEmpty) {
      return null;
    }

    // Match "主要话题" section (supports both Chinese and English headers)
    // Pattern: ## 主要-topic or ## Main Topics
    final mainTopicsPattern = RegExp(
      r'##\s*(?:主要话题|Main Topics|主要话题概述)\s*\n+(.*?)(?=\n##\s|\Z)',
      dotAll: true,
      caseSensitive: false,
    );

    final match = mainTopicsPattern.firstMatch(aiSummary);
    if (match != null && match.groupCount >= 1) {
      var topics = match.group(1)?.trim() ?? '';
      // Clean up bullet points and extra whitespace
      topics = topics
          .replaceAll(RegExp(r'^[\s-•*]+\s*', multiLine: true), '')
          .trim();
      // Replace multiple newlines with single space
      topics = topics.replaceAll(RegExp(r'\s+'), ' ');
      return topics.isNotEmpty ? topics : null;
    }

    // Try alternative pattern - just look for ## 主要-topic and get next ~300 chars
    final alternativePattern = RegExp(
      r'##\s*(?:主要话题|Main Topics|主要话题概述)\s*\n+(.{10,400})',
      dotAll: true,
      caseSensitive: false,
    );

    final altMatch = alternativePattern.firstMatch(aiSummary);
    if (altMatch != null && altMatch.groupCount >= 1) {
      var topics = altMatch.group(1)?.trim() ?? '';
      // Stop at next ## header if present
      final nextHeader = topics.indexOf('## ');
      if (nextHeader > 0) {
        topics = topics.substring(0, nextHeader);
      }
      topics = topics
          .replaceAll(RegExp(r'^[\s-•*]+\s*', multiLine: true), '')
          .trim();
      topics = topics.replaceAll(RegExp(r'\s+'), ' ');
      return topics.isNotEmpty ? topics : null;
    }

    return null;
  }

  /// Strips HTML tags from shownotes content and returns plain text
  ///
  /// [htmlContent] - The HTML string to strip tags from
  ///
  /// Returns plain text with HTML tags removed and cleaned
  static String stripHtmlTags(String? htmlContent) {
    if (htmlContent == null || htmlContent.isEmpty) {
      return '';
    }

    final cached = _stripHtmlCache[htmlContent];
    if (cached != null) {
      return cached;
    }

    var text = htmlContent;

    try {
      text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
      text = text.replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n');
      text = text.replaceAll(RegExp(r'</div\s*>', caseSensitive: false), '\n');
      text = text.replaceAll(RegExp(r'</li\s*>', caseSensitive: false), '\n');
      text = text.replaceAll(RegExp('<[^>]*>'), '');

      // Decode HTML entities (common ones)
      final htmlEntities = {
        '&nbsp;': ' ',
        '&amp;': '&',
        '&lt;': '<',
        '&gt;': '>',
        '&quot;': '"',
        '&apos;': "'",
        '&#39;': "'",
        '&#34;': '"',
        '&#160;': ' ',
        '&mdash;': '—',
        '&ndash;': '–',
        '&hellip;': '...',
        '&copy;': '©',
        '&reg;': '®',
        '&trade;': '™',
        '&euro;': '€',
        '&pound;': '£',
        '&yen;': '¥',
        '&cent;': '¢',
        '&sect;': '§',
        '&para;': '¶',
      };

      for (final entry in htmlEntities.entries) {
        text = text.replaceAll(entry.key, entry.value);
      }

      // Also handle numeric entities like &#123; and &#x1F600;
      text = text.replaceAllMapped(
        RegExp(r'&#(\d+);'),
        (match) =>
            String.fromCharCode(int.tryParse(match.group(1) ?? '0') ?? 0),
      );
      text = text.replaceAllMapped(
        RegExp('&#x([0-9a-fA-F]+);'),
        (match) => String.fromCharCode(
          int.tryParse(match.group(1) ?? '0', radix: 16) ?? 0,
        ),
      );
    } catch (e) {
      // If parsing fails, continue with original content
      text = htmlContent;
    }

    text = text.replaceAll(RegExp('<[^>]*>'), '');
    text = text.replaceAll('&nbsp;', ' ');
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    text = text.replaceAll('&quot;', '"');

    // Clean up extra whitespace and newlines
    text = text.replaceAll(RegExp(r'\r\n'), '\n'); // Normalize line endings
    text = text.replaceAll(
      RegExp(r'\n{3,}'),
      '\n\n',
    ); // Max 2 consecutive newlines
    text = text.replaceAll(
      RegExp(r'[ \t]{2,}'),
      ' ',
    ); // Multiple spaces/tabs to single space
    text = text.replaceAll(RegExp(r'\n[ \t]+'), '\n'); // Spaces after newline
    text = text.replaceAll(RegExp(r'[ \t]+\n'), '\n'); // Spaces before newline
    text = text.trim();

    _cacheStripHtmlResult(htmlContent, text);
    return text;
  }

  /// Gets the best description to display for an episode
  ///
  /// Returns the plain text from description (HTML tags removed)
  ///
  /// [aiSummary] - The AI-generated summary string (currently unused)
  /// [description] - The original shownotes description (may contain HTML)
  ///
  /// Returns plain text description with HTML tags removed
  static String getDisplayDescription({
    String? aiSummary,
    String? description,
  }) {
    // Directly return plain text description with HTML tags removed
    return stripHtmlTags(description);
  }

  /// Truncates description to a maximum length with ellipsis
  ///
  /// [description] - The description to truncate
  /// [maxLength] - Maximum number of characters (default: 200)
  ///
  /// Returns truncated description with ellipsis if needed
  static String truncateDescription(String description, {int maxLength = 200}) {
    if (description.length <= maxLength) {
      return description;
    }
    return '${description.substring(0, maxLength)}...';
  }

  static void clearStripHtmlCacheForTest() {
    _stripHtmlCache.clear();
    _stripHtmlCacheOrder.clear();
  }

  static void _cacheStripHtmlResult(String source, String parsed) {
    if (_stripHtmlCache.containsKey(source)) {
      return;
    }

    _stripHtmlCache[source] = parsed;
    _stripHtmlCacheOrder.addLast(source);

    while (_stripHtmlCacheOrder.length > _stripHtmlCacheLimit) {
      final oldestKey = _stripHtmlCacheOrder.removeFirst();
      _stripHtmlCache.remove(oldestKey);
    }
  }
}
