import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

/// Cache entry with timestamp for expiry.
class _Entry<T> {
  _Entry(this.value) : createdAt = DateTime.now();
  final T value;
  final DateTime createdAt;
}

/// Simplified text processing cache.
///
/// Provides cached HTML-to-plain-text conversion and sentence splitting.
/// Uses the `html` package for robust HTML parsing instead of regex-based stripping.
class TextProcessingCache {
  static final _descriptionCache = <String, _Entry<String>>{};
  static final _sentenceCache = <String, _Entry<String>>{};
  static const _maxCacheSize = 100;
  static const _entryTtl = Duration(minutes: 30);

  /// Converts HTML to plain text and caches the result.
  static String getCachedDescription(String? rawDescription) {
    if (rawDescription == null || rawDescription.isEmpty) return '';

    final cached = _descriptionCache[rawDescription];
    if (cached != null && DateTime.now().difference(cached.createdAt) < _entryTtl) {
      return cached.value;
    }

    final processed = _htmlToPlainText(rawDescription);

    if (_descriptionCache.length >= _maxCacheSize) {
      _descriptionCache.remove(_descriptionCache.keys.first);
    }
    _descriptionCache[rawDescription] = _Entry(processed);

    return processed;
  }

  /// Splits text into sentences and caches the result.
  static List<String> getCachedSentences(String text) {
    if (text.isEmpty) return [];

    final cached = _sentenceCache[text];
    if (cached != null && DateTime.now().difference(cached.createdAt) < _entryTtl) {
      // Split on read -- stored as joined string for compact storage.
      return cached.value.split('\x00');
    }

    final sentences = _splitSentences(text);
    final joined = sentences.join('\x00');

    if (_sentenceCache.length >= _maxCacheSize) {
      _sentenceCache.remove(_sentenceCache.keys.first);
    }
    _sentenceCache[text] = _Entry(joined);

    return sentences;
  }

  /// Converts HTML to plain text using the `html` package.
  static String _htmlToPlainText(String html) {
    final document = html_parser.parse(html);
    // Extract text content from the body. parse() wraps fragments in <html><body>.
    final body = document.body;
    if (body == null) return '';

    final buffer = StringBuffer();
    _extractText(body, buffer);
    return buffer.toString().trim();
  }

  /// Recursively extracts text from DOM nodes, inserting newlines for block elements.
  static void _extractText(Node node, StringBuffer buffer) {
    if (node is Text) {
      buffer.write(node.text);
    } else if (node is Element) {
      final tag = node.localName?.toLowerCase() ?? '';
      final isBlock = const {
        'p', 'div', 'br', 'li', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
        'tr', 'blockquote', 'hr',
      }.contains(tag);

      if (isBlock && buffer.isNotEmpty) {
        buffer.write('\n');
      }

      for (final child in node.nodes) {
        _extractText(child, buffer);
      }

      if (isBlock) {
        buffer.write('\n');
      }
    }
  }

  /// Splits text into sentences by Chinese/English punctuation.
  static List<String> _splitSentences(String text) {
    final pattern = RegExp('[^。.！!？?]+[。.！!？?]');
    final matches = pattern.allMatches(text);
    final sentences = <String>[];

    for (final match in matches) {
      final s = match.group(0)?.trim();
      if (s != null && s.isNotEmpty) sentences.add(s);
    }

    // If no delimiters found, return the whole text as one segment.
    if (sentences.isEmpty && text.trim().isNotEmpty) {
      sentences.add(text.trim());
    }

    return sentences;
  }

  /// Clears all caches. Used in tests.
  static void clearAll() {
    _descriptionCache.clear();
    _sentenceCache.clear();
  }
}
