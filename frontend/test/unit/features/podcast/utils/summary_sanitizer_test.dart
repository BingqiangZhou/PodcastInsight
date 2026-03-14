import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/podcast/core/utils/html_sanitizer.dart';

void main() {
  group('HtmlSanitizer.cleanModelReasoning', () {
    test('removes thinking tags with multiline content', () {
      const input = '''
Before
<thinking>
step 1
step 2
</thinking>
After
''';

      final output = HtmlSanitizer.cleanModelReasoning(input);
      expect(output, 'Before\n\nAfter');
    });

    test('removes think tags case-insensitively', () {
      const input = '<ThInK>internal</ThInK>Final answer';
      final output = HtmlSanitizer.cleanModelReasoning(input);
      expect(output, 'Final answer');
    });

    test('keeps markdown content', () {
      const input = '## Title\n- item 1\n- item 2';
      final output = HtmlSanitizer.cleanModelReasoning(input);
      expect(output, input);
    });

    test('returns empty string for null or empty input', () {
      expect(HtmlSanitizer.cleanModelReasoning(null), '');
      expect(HtmlSanitizer.cleanModelReasoning(''), '');
    });

    test('does not truncate long summary text', () {
      final longText = List.filled(2000, 'A').join();
      final output = HtmlSanitizer.cleanModelReasoning(longText);
      expect(output.length, longText.length);
      expect(output, longText);
    });
  });

  group('HtmlSanitizer.detectFailureReason', () {
    test('detects HTML timeout pages as invalid summary content', () {
      const input =
          '<!DOCTYPE html><html><head><title>524: A timeout occurred</title></head></html>';
      expect(HtmlSanitizer.detectFailureReason(input), isNotNull);
    });
  });
}
