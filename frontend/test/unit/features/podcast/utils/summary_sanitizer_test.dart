import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/podcast/core/utils/summary_sanitizer.dart';

void main() {
  group('SummarySanitizer', () {
    test('removes thinking tags with multiline content', () {
      const input = '''
Before
<thinking>
step 1
step 2
</thinking>
After
''';

      final output = SummarySanitizer.clean(input);
      expect(output, 'Before\n\nAfter');
    });

    test('removes think tags case-insensitively', () {
      const input = '<ThInK>internal</ThInK>Final answer';
      final output = SummarySanitizer.clean(input);
      expect(output, 'Final answer');
    });

    test('keeps markdown content', () {
      const input = '## Title\n- item 1\n- item 2';
      final output = SummarySanitizer.clean(input);
      expect(output, input);
    });

    test('returns empty string for null or empty input', () {
      expect(SummarySanitizer.clean(null), '');
      expect(SummarySanitizer.clean(''), '');
    });

    test('does not truncate long summary text', () {
      final longText = List.filled(2000, 'A').join();
      final output = SummarySanitizer.clean(longText);
      expect(output.length, longText.length);
      expect(output, longText);
    });

    test('detects HTML timeout pages as invalid summary content', () {
      const input =
          '<!DOCTYPE html><html><head><title>524: A timeout occurred</title></head></html>';
      expect(SummarySanitizer.detectFailureReason(input), isNotNull);
    });
  });
}
