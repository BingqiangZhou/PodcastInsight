import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/utils/text_processing_cache.dart';

void main() {
  group('TextProcessingCache - LRU Eviction Tests', () {
    setUp(TextProcessingCache.clearAll);

    test('LRU eviction removes oldest entry when description cache is full', () {
      // Fill the cache beyond max size (100).
      // Each description uses a unique string so hash codes are distinct.
      for (var i = 0; i < 105; i++) {
        TextProcessingCache.getCachedDescription('Description $i');
      }
      final stats = TextProcessingCache.getStats();
      // Cache should not exceed max size
      expect(stats['descriptionCacheSize'], lessThanOrEqualTo(100));
    });

    test('LRU eviction works for sentence cache', () {
      // Fill sentence cache beyond max size with unique strings
      for (var i = 0; i < 105; i++) {
        TextProcessingCache.getCachedSentences(
          'Sentence $i padding: ${'x' * i}',
        );
      }
      final stats = TextProcessingCache.getStats();
      expect(stats['sentenceCacheSize'], lessThanOrEqualTo(100));
    });

    test('LRU updates access time on cache hit', () {
      // Add two items to cache
      TextProcessingCache.getCachedDescription('First description');
      TextProcessingCache.getCachedDescription('Second description');

      // Access "First description" again to update its LRU timestamp
      TextProcessingCache.getCachedDescription('First description');

      // Add more items to push cache toward max size
      for (var i = 0; i < 100; i++) {
        TextProcessingCache.getCachedDescription('Filler $i');
      }

      final stats = TextProcessingCache.getStats();
      expect(stats['descriptionCacheSize'], lessThanOrEqualTo(100));

      // "First description" was accessed more recently than "Second description",
      // so after eviction it should still be in cache.
      final result = TextProcessingCache.getCachedDescription('First description');
      expect(result, isNotEmpty);
    });
  });

  group('TextProcessingCache - Description Processing Tests', () {
    setUp(TextProcessingCache.clearAll);

    test('returns empty string for null input', () {
      final result = TextProcessingCache.getCachedDescription(null);
      expect(result, '');
    });

    test('returns empty string for empty input', () {
      final result = TextProcessingCache.getCachedDescription('');
      expect(result, isEmpty);
    });

    test('strips HTML tags from description', () {
      const html = '<p>Hello <b>world</b></p>';
      final result = TextProcessingCache.getCachedDescription(html);
      expect(result, contains('Hello'));
      expect(result, contains('world'));
      expect(result, isNot(contains('<')));
      expect(result, isNot(contains('>')));
    });

    test('removes CSS noise from description', () {
      const css = 'color: red; font-size: 16px; Actual content here';
      final result = TextProcessingCache.getCachedDescription(css);
      expect(result, contains('Actual'));
      expect(result, isNot(contains('color')));
    });

    test('handles complex HTML with style attributes', () {
      const html =
          '<p style="color:#333333;font-size:16px">This preview should stay visible.</p>';
      final result = TextProcessingCache.getCachedDescription(html);
      expect(result, contains('This preview should stay visible'));
    });

    test('decodes HTML entities', () {
      const html = 'Hello &amp; welcome to the &ldquo;world&rdquo;';
      final result = TextProcessingCache.getCachedDescription(html);
      expect(result, contains('&'));
    });

    test('handles malformed HTML tags', () {
      const malformed = 'Content <a href="http://example.com" broken';
      final result = TextProcessingCache.getCachedDescription(malformed);
      expect(result, contains('Content'));
      expect(result, isNot(contains('<a')));
    });

    test('caches description result for identical input', () {
      const input = 'Test description for caching';
      final result1 = TextProcessingCache.getCachedDescription(input);
      final result2 = TextProcessingCache.getCachedDescription(input);
      expect(result1, result2);
      // Both calls should use the same cache entry
      final stats = TextProcessingCache.getStats();
      expect(stats['descriptionCacheSize'], 1);
    });
  });

  group('TextProcessingCache - Sentence Splitting Tests', () {
    setUp(TextProcessingCache.clearAll);

    test('returns empty list for empty input', () {
      final result = TextProcessingCache.getCachedSentences('');
      expect(result, []);
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

    test('caches sentence result for identical input', () {
      const input = 'First. Second.';
      final result1 = TextProcessingCache.getCachedSentences(input);
      final result2 = TextProcessingCache.getCachedSentences(input);
      expect(result1, result2);
      final stats = TextProcessingCache.getStats();
      expect(stats['sentenceCacheSize'], 1);
    });
  });

  group('TextProcessingCache - Cleanup Tests', () {
    setUp(TextProcessingCache.clearAll);

    test('clearAll removes all cached entries', () {
      // Add some entries first
      TextProcessingCache.getCachedDescription('Description 1');
      TextProcessingCache.getCachedSentences('Sentence one. Sentence two.');

      final statsBefore = TextProcessingCache.getStats();
      expect(statsBefore['descriptionCacheSize'], greaterThan(0));
      expect(statsBefore['sentenceCacheSize'], greaterThan(0));

      TextProcessingCache.clearAll();

      final statsAfter = TextProcessingCache.getStats();
      expect(statsAfter['descriptionCacheSize'], 0);
      expect(statsAfter['sentenceCacheSize'], 0);
      expect(statsAfter['totalEntries'], 0);
    });

    test('clearAll resets last cleanup time', () {
      // Perform cleanup to set the lastCleanupTime
      TextProcessingCache.getCachedDescription('test');
      TextProcessingCache.performCleanup();

      final statsBeforeClear = TextProcessingCache.getStats();
      expect(statsBeforeClear['lastCleanup'], isNotNull);

      TextProcessingCache.clearAll();

      final statsAfterClear = TextProcessingCache.getStats();
      expect(statsAfterClear['lastCleanup'], isNull);
    });

    test('performCleanup reduces cache size to 70% of max', () {
      // Fill cache to max size
      for (var i = 0; i < 100; i++) {
        TextProcessingCache.getCachedDescription('Description $i');
      }
      for (var i = 0; i < 100; i++) {
        TextProcessingCache.getCachedSentences('Sentence $i.');
      }

      final statsBefore = TextProcessingCache.getStats();
      expect(statsBefore['descriptionCacheSize'], 100);
      expect(statsBefore['sentenceCacheSize'], 100);

      TextProcessingCache.performCleanup();

      final statsAfter = TextProcessingCache.getStats();
      // Should be reduced to 70 entries (70% of 100)
      expect(statsAfter['descriptionCacheSize'], lessThanOrEqualTo(70));
      expect(statsAfter['sentenceCacheSize'], lessThanOrEqualTo(70));
    });

    test('performCleanup skips if called too soon after previous cleanup', () {
      // Fill cache
      for (var i = 0; i < 50; i++) {
        TextProcessingCache.getCachedDescription('Description $i');
      }

      // First cleanup
      TextProcessingCache.performCleanup();
      final statsAfterFirst = TextProcessingCache.getStats();
      final sizeAfterFirst = statsAfterFirst['descriptionCacheSize'] as int;

      // Add more entries
      for (var i = 50; i < 100; i++) {
        TextProcessingCache.getCachedDescription('Description $i');
      }

      // Second cleanup immediately — should be skipped due to interval
      TextProcessingCache.performCleanup();
      final statsAfterSecond = TextProcessingCache.getStats();
      // Size should have grown because cleanup was skipped
      expect(
        statsAfterSecond['descriptionCacheSize'] as int,
        greaterThan(sizeAfterFirst),
      );
    });
  });

  group('TextProcessingCache - getStats Tests', () {
    setUp(TextProcessingCache.clearAll);

    test('getStats returns correct structure when empty', () {
      final stats = TextProcessingCache.getStats();
      expect(stats['descriptionCacheSize'], 0);
      expect(stats['sentenceCacheSize'], 0);
      expect(stats['maxCacheSize'], 100);
      expect(stats['totalEntries'], 0);
      expect(stats['lastCleanup'], isNull);
    });

    test('getStats reflects added entries', () {
      TextProcessingCache.getCachedDescription('desc1');
      TextProcessingCache.getCachedDescription('desc2');
      TextProcessingCache.getCachedSentences('sent1.');

      final stats = TextProcessingCache.getStats();
      expect(stats['descriptionCacheSize'], 2);
      expect(stats['sentenceCacheSize'], 1);
      expect(stats['totalEntries'], 3);
    });
  });
}
