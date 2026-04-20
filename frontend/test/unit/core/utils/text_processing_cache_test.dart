import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/utils/text_processing_cache.dart';

void main() {
  group('TextProcessingCache - getCachedDescription', () {
    setUp(TextProcessingCache.clearAll);

    test('returns empty string for null input', () {
      expect(TextProcessingCache.getCachedDescription(null), '');
    });

    test('returns empty string for empty input', () {
      expect(TextProcessingCache.getCachedDescription(''), '');
    });

    test('strips HTML tags and extracts text', () {
      const html = '<p>Hello <b>world</b></p>';
      final result = TextProcessingCache.getCachedDescription(html);
      expect(result, contains('Hello'));
      expect(result, contains('world'));
      expect(result, isNot(contains('<')));
      expect(result, isNot(contains('>')));
    });

    test('handles complex HTML with style attributes', () {
      const html =
          '<p style="color:#333333;font-size:16px">This preview should stay visible.</p>';
      final result = TextProcessingCache.getCachedDescription(html);
      expect(result, contains('This preview should stay visible'));
    });

    test('decodes HTML entities', () {
      const html = 'Hello &amp; welcome';
      final result = TextProcessingCache.getCachedDescription(html);
      expect(result, contains('&'));
      expect(result, isNot(contains('&amp;')));
    });

    test('handles malformed HTML gracefully', () {
      const malformed = 'Content <a href="http://example.com" broken';
      final result = TextProcessingCache.getCachedDescription(malformed);
      expect(result, contains('Content'));
    });

    test('inserts newlines for block elements', () {
      const html = '<p>Line 1</p><p>Line 2</p>';
      final result = TextProcessingCache.getCachedDescription(html);
      expect(result, contains('Line 1'));
      expect(result, contains('Line 2'));
    });

    test('returns same result for repeated calls (caching)', () {
      const input = 'Test description for caching';
      final result1 = TextProcessingCache.getCachedDescription(input);
      final result2 = TextProcessingCache.getCachedDescription(input);
      expect(result1, result2);
    });

    test('removes CSS style tag content', () {
      const html = '<style>body { color: red; }</style><p>Actual content</p>';
      final result = TextProcessingCache.getCachedDescription(html);
      expect(result, contains('Actual content'));
      expect(result, isNot(contains('color')));
    });
  });

  group('TextProcessingCache - getCachedSentences', () {
    setUp(TextProcessingCache.clearAll);

    test('returns empty list for empty input', () {
      expect(TextProcessingCache.getCachedSentences(''), []);
    });

    test('splits English sentences by period', () {
      const text = 'First sentence. Second sentence. Third sentence.';
      final result = TextProcessingCache.getCachedSentences(text);
      expect(result, isNotEmpty);
      expect(result.first, contains('First'));
    });

    test('splits Chinese sentences', () {
      const text = '第一句。第二句。第三句。';
      final result = TextProcessingCache.getCachedSentences(text);
      expect(result, isNotEmpty);
      expect(result.any((s) => s.contains('第一')), isTrue);
    });

    test('splits sentences by question marks', () {
      const text = 'Is this a question? Yes it is. Really?';
      final result = TextProcessingCache.getCachedSentences(text);
      expect(result, isNotEmpty);
      expect(result.any((s) => s.contains('Is this')), isTrue);
    });

    test('splits sentences by exclamation marks', () {
      const text = 'Wow! Amazing! Incredible!';
      final result = TextProcessingCache.getCachedSentences(text);
      expect(result, isNotEmpty);
      expect(result.any((s) => s.contains('Wow')), isTrue);
    });

    test('returns original text if no delimiters found', () {
      const text = 'No punctuation here';
      final result = TextProcessingCache.getCachedSentences(text);
      expect(result.length, 1);
      expect(result[0], 'No punctuation here');
    });

    test('returns same result for repeated calls (caching)', () {
      const input = 'First. Second.';
      final result1 = TextProcessingCache.getCachedSentences(input);
      final result2 = TextProcessingCache.getCachedSentences(input);
      expect(result1, result2);
    });
  });

  group('TextProcessingCache - clearAll', () {
    test('clearAll allows fresh processing after call', () {
      const input = 'Test input.';
      final result1 = TextProcessingCache.getCachedSentences(input);
      TextProcessingCache.clearAll();
      final result2 = TextProcessingCache.getCachedSentences(input);
      // Both should produce the same result; clearAll just resets the cache.
      expect(result1, result2);
    });
  });
}
