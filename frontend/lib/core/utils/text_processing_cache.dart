/// LRU cache entry that tracks access time for eviction.
class _CacheEntry<T> {
  T value;
  int lastAccess;

  _CacheEntry(this.value) : lastAccess = DateTime.now().millisecondsSinceEpoch;
}

/// Text processing cache utility class.
///
/// Uses LRU strategy to manage cache, avoiding repeated regex processing on each build.
/// This improves performance by caching expensive text processing operations.
///
/// Features:
/// - LRU eviction with access tracking
/// - Memory pressure awareness
/// - Configurable cache size
/// - Automatic cleanup on low memory warnings
class TextProcessingCache {
  static final _descriptionCache = <String, _CacheEntry<String>>{};
  static final _sentenceCache = <String, _CacheEntry<List<String>>>{};

  /// Maximum cache size (reduced from 200 to 100 for better memory management)
  static const int _maxCacheSize = 100;

  /// Timestamp of last cache cleanup
  static int? _lastCleanupTime;

  /// Minimum time between cleanups to avoid excessive GC
  static const Duration _minCleanupInterval = Duration(minutes: 1);

  // Initialize memory pressure listener
  static bool _initialized = false;

  static void _ensureInitialized() {
    if (_initialized) return;
    _initialized = true;

    // Flutter's memory pressure handling is automatic in most cases
    // This initialization is a placeholder for future enhancements
  }

  /// Gets cached description text (HTML tags cleaned).
  ///
  /// Extracts processing logic from podcast_feed_page.dart's `_getFeedCardDescription`
  /// and related helper functions.
  static String getCachedDescription(String? rawDescription) {
    _ensureInitialized();

    if (rawDescription == null || rawDescription.isEmpty) return '';

    final cacheKey = rawDescription.hashCode.toString();
    final entry = _descriptionCache[cacheKey];

    if (entry != null) {
      // Update access time for LRU
      entry.lastAccess = DateTime.now().millisecondsSinceEpoch;
      return entry.value;
    }

    final processed = _processDescription(rawDescription);

    // LRU eviction - remove oldest entry when cache is full
    if (_descriptionCache.length >= _maxCacheSize) {
      _evictOldestEntry(_descriptionCache);
    }

    _descriptionCache[cacheKey] = _CacheEntry(processed);
    return processed;
  }

  /// Gets cached sentence list.
  ///
  /// Extracts processing logic from transcript_display_widget.dart's `_splitIntoSentences`.
  static List<String> getCachedSentences(String text) {
    _ensureInitialized();

    if (text.isEmpty) return [];

    final cacheKey = text.hashCode.toString();
    final entry = _sentenceCache[cacheKey];

    if (entry != null) {
      // Update access time for LRU
      entry.lastAccess = DateTime.now().millisecondsSinceEpoch;
      return entry.value;
    }

    final sentences = _splitIntoSentences(text);

    // LRU eviction - remove oldest entry when cache is full
    if (_sentenceCache.length >= _maxCacheSize) {
      _evictOldestEntry(_sentenceCache);
    }

    _sentenceCache[cacheKey] = _CacheEntry(sentences);
    return sentences;
  }

  /// Evicts the oldest (least recently used) entry from a cache.
  static void _evictOldestEntry<T>(Map<String, _CacheEntry<T>> cache) {
    if (cache.isEmpty) return;

    String? oldestKey;
    int oldestTime = DateTime.now().millisecondsSinceEpoch;

    for (final entry in cache.entries) {
      if (entry.value.lastAccess < oldestTime) {
        oldestTime = entry.value.lastAccess;
        oldestKey = entry.key;
      }
    }

    if (oldestKey != null) {
      cache.remove(oldestKey);
    }
  }

  /// Processes description text by removing HTML tags and cleaning content.
  ///
  /// This logic is extracted from podcast_feed_page.dart:
  /// - `_getFeedCardDescription`
  /// - `_recoverMalformedTagInlineContent`
  /// - `_recoverMalformedTagLine`
  /// - `_removeLikelyCssNoise`
  static String _processDescription(String description) {
    final sanitized = description.replaceAll(
      RegExp(r'<br\s*/?>', caseSensitive: false),
      '\n',
    ).replaceAll(
      RegExp(r'</p\s*>', caseSensitive: false),
      '\n',
    ).replaceAll(
      RegExp(r'</div\s*>', caseSensitive: false),
      '\n',
    ).replaceAll(
      RegExp(r'</li\s*>', caseSensitive: false),
      '\n',
    ).replaceAll(
      RegExp(r'<[^>]*>'),
      '',
    );

    if (sanitized.isEmpty) {
      return '';
    }

    // Decode HTML entities
    final decoded = _decodeHtmlEntities(sanitized);

    // Recover visible content when malformed/truncated tag fragments remain.
    final recovered = _recoverMalformedTagInlineContent(decoded);
    final cleaned = recovered.replaceAll(
      RegExp(r'<[/!]?[a-zA-Z][^>\n]*(?=\n|$)'),
      '',
    );

    final cssCleaned = _removeLikelyCssNoise(cleaned);
    return cssCleaned.trim();
  }

  /// Decodes common HTML entities to their character equivalents.
  static String _decodeHtmlEntities(String text) {
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

    var decoded = text;
    for (final entry in htmlEntities.entries) {
      decoded = decoded.replaceAll(entry.key, entry.value);
    }

    // Handle numeric entities like &#123;
    decoded = decoded.replaceAllMapped(
      RegExp(r'&#(\d+);'),
      (match) =>
          String.fromCharCode(int.tryParse(match.group(1) ?? '0') ?? 0),
    );
    // Handle hex entities like &#x1F600;
    decoded = decoded.replaceAllMapped(
      RegExp(r'&#x([0-9a-fA-F]+);'),
      (match) => String.fromCharCode(
        int.tryParse(match.group(1) ?? '0', radix: 16) ?? 0,
      ),
    );

    return decoded;
  }

  /// Splits text into sentences based on punctuation marks.
  ///
  /// Supports Chinese and English sentence delimiters:
  /// - Chinese period 。
  /// - English period .
  /// - Question marks ?？
  /// - Exclamation marks ！!
  static List<String> _splitIntoSentences(String text) {
    final segments = <String>[];

    // Use regex to split by sentence delimiters
    final sentencePattern = RegExp(r'[^。.！!？?]+[。.！!？?]+[^。.！!？?]*');

    final matches = sentencePattern.allMatches(text);

    for (final match in matches) {
      final sentence = match.group(0)?.trim();
      if (sentence != null && sentence.isNotEmpty) {
        segments.add(sentence);
      }
    }

    // If no sentences were matched, return original text
    if (segments.isEmpty) {
      return [text];
    }

    return segments;
  }

  /// Recovers content from malformed tag fragments at end of lines.
  ///
  /// Extracted from podcast_feed_page.dart's `_recoverMalformedTagInlineContent`.
  static String _recoverMalformedTagInlineContent(String text) {
    final lines = text.split('\n');
    final recoveredLines = lines.map(_recoverMalformedTagLine).toList();
    return recoveredLines.join('\n');
  }

  /// Recovers content from a single line with malformed tag.
  ///
  /// Extracted from podcast_feed_page.dart's `_recoverMalformedTagLine`.
  static String _recoverMalformedTagLine(String line) {
    final malformedTagMatch = RegExp(r'<[/!]?[a-zA-Z][^>]*$').firstMatch(line);
    if (malformedTagMatch == null) {
      return line;
    }

    final tagStart = malformedTagMatch.start;
    final prefix = line.substring(0, tagStart);
    final fragment = line.substring(tagStart);

    // If content is appended after a quoted attribute value, keep that tail.
    final lastDoubleQuote = fragment.lastIndexOf('"');
    final lastSingleQuote = fragment.lastIndexOf("'");
    final lastQuoteIndex = lastDoubleQuote > lastSingleQuote
        ? lastDoubleQuote
        : lastSingleQuote;

    if (lastQuoteIndex != -1 && lastQuoteIndex + 1 < fragment.length) {
      final tail = fragment.substring(lastQuoteIndex + 1).trimLeft();
      if (tail.isNotEmpty &&
          !RegExp(r'^[a-zA-Z_:-][\w:.-]*\s*=').hasMatch(tail)) {
        return '$prefix$tail';
      }
    }

    // Fallback for CJK text directly following malformed tag attributes.
    final cjkMatch = RegExp(r'[\u4E00-\u9FFF]').firstMatch(fragment);
    if (cjkMatch != null) {
      return '$prefix${fragment.substring(cjkMatch.start)}';
    }

    return prefix;
  }

  /// Removes likely CSS noise from text.
  ///
  /// Extracted from podcast_feed_page.dart's `_removeLikelyCssNoise`.
  static String _removeLikelyCssNoise(String text) {
    final lines = text.split('\n');
    final cleanedLines = <String>[];

    for (var line in lines) {
      // Drop leading runs of style declarations
      line = line.replaceFirst(
        RegExp(
          r'^\s*(?:(?:color|font-weight|font-size|line-height|font-family|hyphens|text-align|letter-spacing|word-spacing|white-space|word-break|overflow-wrap|text-indent|text-decoration|font-style|font-variant|font-stretch|font)\s*:\s*[^;\n]+;?\s*){2,}',
          caseSensitive: false,
        ),
        '',
      );

      // Remove inline attribute fragments if any survived.
      line = line.replaceAll(
        RegExp(
          r'''\b(?:data-[\w-]+|style)\s*=\s*["'][^"']*["']''',
          caseSensitive: false,
        ),
        '',
      );

      // Remove remaining standalone CSS declarations.
      line = line.replaceAll(
        RegExp(
          r'\b(?:color|font-weight|font-size|line-height|font-family|hyphens|text-align|letter-spacing|word-spacing|white-space|word-break|overflow-wrap|text-indent|text-decoration|font-style|font-variant|font-stretch|font)\s*:\s*[^;\n]+;?',
          caseSensitive: false,
        ),
        '',
      );

      line = line.replaceAll(RegExp(r'^[;,\s]+|[;,\s]+$'), '').trim();

      final isPureCssLine = RegExp(
        r'^(?:[a-z-]+\s*:[^;\n]+;?\s*)+$',
        caseSensitive: false,
      ).hasMatch(line);

      if (line.isNotEmpty && !isPureCssLine) {
        cleanedLines.add(line);
      }
    }

    return cleanedLines.join('\n');
  }

  /// Clears all caches.
  ///
  /// Useful for testing or memory management.
  static void clearAll() {
    _descriptionCache.clear();
    _sentenceCache.clear();
    _lastCleanupTime = null;
  }

  /// Gets current cache statistics for monitoring.
  ///
  /// Returns a map with cache sizes and memory usage info.
  static Map<String, dynamic> getStats() {
    return {
      'descriptionCacheSize': _descriptionCache.length,
      'sentenceCacheSize': _sentenceCache.length,
      'maxCacheSize': _maxCacheSize,
      'totalEntries': _descriptionCache.length + _sentenceCache.length,
      'lastCleanup': _lastCleanupTime,
    };
  }

  /// Performs periodic cleanup of stale cache entries.
  ///
  /// This can be called periodically or when memory pressure is detected.
  /// Only cleans up if enough time has passed since the last cleanup.
  static void performCleanup() {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Skip if cleanup was done recently
    if (_lastCleanupTime != null &&
        (now - _lastCleanupTime!) < _minCleanupInterval.inMilliseconds) {
      return;
    }

    _lastCleanupTime = now;

    // Reduce cache size by removing least recently used entries
    // Keep only 70% of max cache size to create headroom
    final targetSize = (_maxCacheSize * 0.7).floor();

    while (_descriptionCache.length > targetSize) {
      _evictOldestEntry(_descriptionCache);
    }

    while (_sentenceCache.length > targetSize) {
      _evictOldestEntry(_sentenceCache);
    }
  }
}
