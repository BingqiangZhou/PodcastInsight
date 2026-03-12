class SummarySanitizer {
  const SummarySanitizer._();

  static const String _htmlErrorMessage =
      'Summary generation failed because the server returned an HTML error page.';

  /// Remove model reasoning tags while preserving normal markdown content.
  static String clean(String? input) {
    if (input == null || input.isEmpty) {
      return '';
    }

    var cleaned = input;
    final patterns = <RegExp>[
      RegExp(r'<thinking>.*?</thinking>', caseSensitive: false, dotAll: true),
      RegExp(r'<think>.*?</think>', caseSensitive: false, dotAll: true),
    ];

    for (final pattern in patterns) {
      cleaned = cleaned.replaceAll(pattern, '');
    }

    return cleaned.trim();
  }

  static String? detectFailureReason(String? input) {
    if (input == null || input.isEmpty) {
      return null;
    }

    final lowered = input.toLowerCase();
    const markers = <String>[
      '<!doctype html',
      '<html',
      '<head',
      'cloudflare',
      '524: a timeout occurred',
      '/cdn-cgi/',
    ];

    for (final marker in markers) {
      if (lowered.contains(marker)) {
        return _htmlErrorMessage;
      }
    }

    return null;
  }
}
