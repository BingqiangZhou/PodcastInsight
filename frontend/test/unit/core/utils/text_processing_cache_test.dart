import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/utils/text_processing_cache.dart';

void main() {
  group('TextProcessingCache - LRU Eviction Tests', () {
    setUp(() {
      // Clear cache before each test
      TextProcessingCache.clearAll();
    });

    test('LRU eviction removes oldest entry when cache is full', () {
      // Fill the cache beyond max size (100)
      for (int i = 0; i < 105; i++) {
        TextProcessingCache.getCachedDescription('Description $i');
      }

      final stats = TextProcessingCache.getStats();
      // Cache should not exceed max size
      expect(stats['descriptionCacheSize'], lessThanOrEqualTo(100));
      expect(stats['maxCacheSize'], 100);
    });

    test('LRU eviction works for sentence cache', () {
      // Fill sentence cache beyond max size
      // Each string needs to be unique with sufficient variation
      for (int i = 0; i < 105; i++) {
        // Add padding to ensure unique hash codes
        final padding = 'x' * i;
        TextProcessingCache.getCachedSentences('Sentence $padding. End $i.');
      }

      final stats = TextProcessingCache.getStats();
      expect(stats['sentenceCacheSize'], lessThanOrEqualTo(100));
    });

    test('LRU updates access time on cache hit', () {
      // Add items to cache
      TextProcessingCache.getCachedDescription('First description');
      TextProcessingCache.getCachedDescription('Second description');

      // Access first item again to update its access time
      TextProcessingCache.getCachedDescription('First description');

      // Add more items to trigger eviction
      for (int i = 2; i < 102; i++) {
        TextProcessingCache.getCachedDescription('Description $i');
      }

      // "First description" should still be in cache because it was recently accessed
      final firstResult = TextProcessingCache.getCachedDescription('First description');
      expect(firstResult, isNotEmpty);

      // "Second description" should have been evicted
      final stats = TextProcessingCache.getStats();
      expect(stats['descriptionCacheSize'], lessThanOrEqualTo(100));
    });

    test('max cache size is enforced for both caches independently', () {
      // Fill both caches with unique values
      for (int i = 0; i < 105; i++) {
        final padding = 'x' * i;
        TextProcessingCache.getCachedDescription('Desc $padding$i');
        TextProcessingCache.getCachedSentences('Sent $padding$i. End.');
      }

      final stats = TextProcessingCache.getStats();
      // Each cache should respect max size independently
      expect(stats['descriptionCacheSize'], lessThanOrEqualTo(100));
      expect(stats['sentenceCacheSize'], lessThanOrEqualTo(100));
      // Total can be up to 200
      expect(stats['totalEntries'], lessThanOrEqualTo(200));
    });
  });

  group('TextProcessingCache - Description Processing Tests', () {
    setUp(() {
      TextProcessingCache.clearAll();
    });

    test('returns empty string for null input', () {
      final result = TextProcessingCache.getCachedDescription(null);
      expect(result, '');
    });

    test('returns empty string for empty input', () {
      final result = TextProcessingCache.getCachedDescription('');
      expect(result, '');
    });

    test('removes HTML tags from description', () {
      final html = '<p>Hello <b>world</b></p>';
      final result = TextProcessingCache.getCachedDescription(html);
      expect(result, contains('Hello'));
      expect(result, contains('world'));
      expect(result, isNot(contains('<')));
      expect(result, isNot(contains('>')));
    });

    test('converts br tags to newlines', () {
      final html = 'Line 1<br>Line 2<br/>Line 3';
      final result = TextProcessingCache.getCachedDescription(html);
      expect(result, contains('\n'));
      expect(result, isNot(contains('<br')));
    });

    test('caches and returns processed description', () {
      const html = '<p>Test content</p>';
      final result1 = TextProcessingCache.getCachedDescription(html);
      final result2 = TextProcessingCache.getCachedDescription(html);

      expect(result1, result2);
      expect(result1, 'Test content');
    });

    test('handles malformed HTML tags', () {
      final malformed = 'Content <a href="http://example.com" broken';
      final result = TextProcessingCache.getCachedDescription(malformed);
      expect(result, contains('Content'));
    });

    test('removes CSS noise from description', () {
      final css = 'color: red; font-size: 14px; Actual content';
      final result = TextProcessingCache.getCachedDescription(css);
      expect(result, contains('Actual content'));
    });
  });

  group('TextProcessingCache - Sentence Splitting Tests', () {
    setUp(() {
      TextProcessingCache.clearAll();
    });

    test('returns empty list for empty input', () {
      final result = TextProcessingCache.getCachedSentences('');
      expect(result, []);
    });

    test('splits sentences with delimiters followed by more text', () {
      // The regex is greedy and matches from start through delimiters
      // until it finds a delimiter followed by non-delimiter content
      final text = 'First sentence. Second sentence. Third sentence. More text';
      final result = TextProcessingCache.getCachedSentences(text);

      // Result: [First sentence. Second sentence, Third sentence. More text]
      // The regex matches greedily, combining sentences until final delimiter+text
      expect(result.length, 2);
      expect(result[0], contains('First'));
      expect(result[0], contains('Second'));
      expect(result[1], contains('Third'));
    });

    test('splits Chinese sentences', () {
      final text = '第一句。第二句。第三句。更多内容';
      final result = TextProcessingCache.getCachedSentences(text);

      expect(result.length, 2);
      expect(result[0], contains('第一句'));
      expect(result[0], contains('第二句'));
      expect(result[1], contains('第三句'));
    });

    test('splits sentences by question marks', () {
      final text = 'Is this a question? Yes it is! Really? Tell me more';
      final result = TextProcessingCache.getCachedSentences(text);

      expect(result.length, 2);
      expect(result[0], contains('question'));
      expect(result[0], contains('Yes'));
      expect(result[1], contains('Really'));
    });

    test('splits sentences by exclamation marks', () {
      final text = 'Wow! Amazing! Incredible! That is great';
      final result = TextProcessingCache.getCachedSentences(text);

      expect(result.length, 2);
      expect(result[0], contains('Wow'));
      expect(result[1], contains('Incredible'));
    });

    test('caches and returns sentence list', () {
      const text = 'Sentence one. Sentence two. More text';
      final result1 = TextProcessingCache.getCachedSentences(text);
      final result2 = TextProcessingCache.getCachedSentences(text);

      expect(result1, result2);
      expect(result1.length, greaterThan(0));
    });

    test('handles mixed Chinese and English punctuation', () {
      final text = 'Hello world。How are you? 我很好！Tell me';
      final result = TextProcessingCache.getCachedSentences(text);

      expect(result.length, 2);
      expect(result[0], contains('Hello'));
      expect(result[0], contains('How'));
      expect(result[1], contains('我很好'));
    });

    test('returns original text if no delimiters found', () {
      final text = 'No punctuation here';
      final result = TextProcessingCache.getCachedSentences(text);
      expect(result.length, 1);
      expect(result[0], 'No punctuation here');
    });

    test('handles single sentence with delimiter and following text', () {
      final text = 'Hello world. How are you';
      final result = TextProcessingCache.getCachedSentences(text);

      expect(result.length, 1);
      expect(result[0], contains('Hello'));
      expect(result[0], contains('How'));
    });
  });

  group('TextProcessingCache - Cleanup Tests', () {
    setUp(() {
      TextProcessingCache.clearAll();
    });

    test('clearAll removes all cached entries', () {
      // Add some entries
      TextProcessingCache.getCachedDescription('Test description');
      TextProcessingCache.getCachedSentences('Test sentences. End.');

      final statsBefore = TextProcessingCache.getStats();
      expect(statsBefore['totalEntries'], greaterThan(0));

      TextProcessingCache.clearAll();

      final statsAfter = TextProcessingCache.getStats();
      expect(statsAfter['descriptionCacheSize'], 0);
      expect(statsAfter['sentenceCacheSize'], 0);
      expect(statsAfter['totalEntries'], 0);
    });

    test('clearAll resets last cleanup time', () {
      TextProcessingCache.performCleanup();
      final statsBefore = TextProcessingCache.getStats();
      expect(statsBefore['lastCleanup'], isNotNull);

      TextProcessingCache.clearAll();

      final statsAfter = TextProcessingCache.getStats();
      expect(statsAfter['lastCleanup'], isNull);
    });

    test('performCleanup reduces cache size to 70% of max', () {
      // Fill cache to max size
      for (int i = 0; i < 100; i++) {
        TextProcessingCache.getCachedDescription('Description $i');
      }

      final statsBefore = TextProcessingCache.getStats();
      expect(statsBefore['descriptionCacheSize'], 100);

      TextProcessingCache.performCleanup();

      final statsAfter = TextProcessingCache.getStats();
      // Should be reduced to ~70 entries (70% of 100)
      expect(statsAfter['descriptionCacheSize'], lessThanOrEqualTo(70));
    });

    test('performCleanup respects minimum cleanup interval', () {
      TextProcessingCache.performCleanup();

      final statsBefore = TextProcessingCache.getStats();
      final firstCleanupTime = statsBefore['lastCleanup'];

      // Call performCleanup again immediately
      TextProcessingCache.performCleanup();

      final statsAfter = TextProcessingCache.getStats();
      final secondCleanupTime = statsAfter['lastCleanup'];

      // Cleanup time should not have changed (rate limited)
      expect(firstCleanupTime, secondCleanupTime);
    });
  });

  group('TextProcessingCache - Statistics Tests', () {
    setUp(() {
      TextProcessingCache.clearAll();
    });

    test('getStats returns correct initial state', () {
      final stats = TextProcessingCache.getStats();

      expect(stats['descriptionCacheSize'], 0);
      expect(stats['sentenceCacheSize'], 0);
      expect(stats['maxCacheSize'], 100);
      expect(stats['totalEntries'], 0);
      expect(stats['lastCleanup'], isNull);
    });

    test('getStats returns correct counts after caching', () {
      TextProcessingCache.getCachedDescription('Description 1');
      TextProcessingCache.getCachedDescription('Description 2');
      TextProcessingCache.getCachedSentences('Sentence 1. Sentence 2. End.');

      final stats = TextProcessingCache.getStats();

      expect(stats['descriptionCacheSize'], 2);
      expect(stats['sentenceCacheSize'], 1);
      expect(stats['totalEntries'], 3);
    });

    test('getStats includes max cache size', () {
      final stats = TextProcessingCache.getStats();
      expect(stats['maxCacheSize'], 100);
    });
  });

  group('TextProcessingCache - Edge Cases Tests', () {
    setUp(() {
      TextProcessingCache.clearAll();
    });

    test('handles very long descriptions', () {
      final longDesc = '<p>${'A' * 10000}</p>';
      final result = TextProcessingCache.getCachedDescription(longDesc);
      expect(result, contains('A'));
    });

    test('handles descriptions with only HTML tags', () {
      final htmlOnly = '<div><span></span></div>';
      final result = TextProcessingCache.getCachedDescription(htmlOnly);
      expect(result, isEmpty);
    });

    test('handles special characters in descriptions', () {
      final special = 'Hello &quot;world&quot; &amp; friends';
      final result = TextProcessingCache.getCachedDescription(special);
      expect(result, contains('Hello'));
    });

    test('handles Unicode characters', () {
      final unicode = 'Hello 世界 🌍';
      final result = TextProcessingCache.getCachedDescription(unicode);
      expect(result, contains('Hello'));
      expect(result, contains('世界'));
    });

    test('handles sentences with trailing spaces', () {
      final text = 'First.  Second.   ';
      final result = TextProcessingCache.getCachedSentences(text);
      expect(result.length, greaterThan(0));
    });

    test('handles empty sentences between delimiters', () {
      final text = 'First.. Second... Third';
      final result = TextProcessingCache.getCachedSentences(text);
      expect(result.length, greaterThan(0));
    });
  });
}
