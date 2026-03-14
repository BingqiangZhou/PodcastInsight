import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart' as dom;

/// HTML Sanitizer utility for podcast shownotes
///
/// This class provides XSS protection by sanitizing HTML content
/// from podcast RSS feeds before rendering.
///
/// Features:
/// - Tag allowlist for safe HTML elements
/// - Attribute allowlist for safe HTML attributes
/// - URL protocol validation (http, https, mailto, tel only)
/// - Removal of dangerous tags (script, iframe, object, embed, form, input)
/// - Removal of event handlers (onclick, onerror, onload, etc.)
class HtmlSanitizer {
  /// Allowed HTML tags that are considered safe
  static const allowedTags = {
    'p', 'br', 'strong', 'em', 'b', 'i', 'u',
    'ul', 'ol', 'li', 'dl', 'dt', 'dd',
    'a', 'img',
    'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
    'table', 'thead', 'tbody', 'tr', 'th', 'td',
    'blockquote', 'pre', 'code',
    'div', 'span', 'hr',
    // Structural tags (for HTML parsing)
    'html', 'body',
  };

  /// Dangerous tags that must be removed
  static const dangerousTags = {
    'script', 'iframe', 'object', 'embed',
    'form', 'input', 'button', 'select', 'textarea',
    'style', 'link', 'meta',
  };

  /// Allowed attributes for specific tags
  static const allowedAttributes = {
    'a': ['href', 'title', 'rel'],
    'img': ['src', 'alt', 'width', 'height', 'title'],
    'td': ['colspan', 'rowspan'],
    'th': ['colspan', 'rowspan'],
    'ol': ['start', 'type'],
    'ul': ['type'],
    'li': ['value'],
    '*': ['class', 'id'], // Generic attributes allowed on all elements
  };

  /// Allowed URL protocols
  static const allowedProtocols = [
    'http:',
    'https:',
    'mailto:',
    'tel:',
  ];

  /// Sanitizes HTML content by removing dangerous elements and attributes
  ///
  /// [html] - The raw HTML string to sanitize
  ///
  /// Returns a sanitized HTML string safe for rendering
  static String sanitize(String html) {
    if (html.isEmpty) return html;

    try {
      // Parse the HTML document
      final document = parser.parse(html);

      // Sanitize the document tree
      _sanitizeNode(document.body);

      // Return the sanitized HTML
      return document.body?.innerHtml ?? '';
    } catch (e) {
      // If parsing fails, return empty string to prevent XSS
      return '';
    }
  }

  /// Recursively sanitizes a DOM node and its children
  static void _sanitizeNode(dom.Node? node) {
    if (node == null || node.nodeType == dom.Node.TEXT_NODE) {
      return;
    }

    if (node is dom.Element) {
      final tagName = node.localName?.toLowerCase();

      // Remove dangerous tags
      if (dangerousTags.contains(tagName)) {
        node.remove();
        return;
      }

      // Remove disallowed tags
      if (tagName != null && !allowedTags.contains(tagName)) {
        // Replace with text node
        node.replaceWith(dom.Text(node.text));
        return;
      }

      // Sanitize attributes
      _sanitizeAttributes(node);

      // Sanitize event handlers (data-* attributes that might contain JS)
      _removeEventHandlers(node);
    }

    // Recursively sanitize children
    final children = node.nodes.toList();
    for (final child in children) {
      _sanitizeNode(child);
    }
  }

  /// Sanitizes element attributes
  static void _sanitizeAttributes(dom.Element element) {
    final tagName = element.localName?.toLowerCase();
    final attributes = element.attributes;

    // Get allowed attributes for this tag
    final allowedAttrsForTag = <String>{};
    if (tagName != null) {
      allowedAttrsForTag.addAll(allowedAttributes[tagName] ?? []);
    }
    allowedAttrsForTag.addAll(allowedAttributes['*'] ?? []);

    // Remove disallowed attributes
    final attrsToRemove = <String>[];
    for (final attr in attributes.keys.cast<String>()) {
      if (!allowedAttrsForTag.contains(attr)) {
        attrsToRemove.add(attr);
      }
    }

    for (final attr in attrsToRemove) {
      element.attributes.remove(attr);
    }

    // Validate URL attributes
    if (tagName == 'a' && element.attributes.containsKey('href')) {
      final href = element.attributes['href']!;
      if (!_isValidUrl(href)) {
        element.attributes.remove('href');
      } else {
        // Add rel="nofollow noopener" for external links
        element.attributes['rel'] = 'nofollow noopener';
      }
    }

    if (tagName == 'img' && element.attributes.containsKey('src')) {
      final src = element.attributes['src']!;
      if (!_isValidUrl(src)) {
        element.remove();
      }
    }
  }

  /// Removes event handlers from an element
  static void _removeEventHandlers(dom.Element element) {
    final attrsToRemove = <String>[];

    for (final attr in element.attributes.keys.cast<String>()) {
      // Remove on* event handlers
      if (attr.toLowerCase().startsWith('on')) {
        attrsToRemove.add(attr);
      }

      // Remove data-* attributes that might contain JavaScript
      if (attr.toLowerCase().startsWith('data-')) {
        final value = element.attributes[attr];
        if (value != null && _containsJavaScript(value)) {
          attrsToRemove.add(attr);
        }
      }

      // Remove style attributes with javascript:
      if (attr.toLowerCase() == 'style') {
        final value = element.attributes[attr];
        if (value != null && value.toLowerCase().contains('javascript:')) {
          attrsToRemove.add(attr);
        }
      }
    }

    for (final attr in attrsToRemove) {
      element.attributes.remove(attr);
    }
  }

  /// Validates if a URL is safe
  static bool _isValidUrl(String url) {
    if (url.isEmpty) return false;

    try {
      // Check for javascript: protocol
      if (url.toLowerCase().startsWith('javascript:')) {
        return false;
      }

      // Check for data: protocol (can be used for XSS)
      if (url.toLowerCase().startsWith('data:')) {
        return false;
      }

      // Check for vbscript: protocol
      if (url.toLowerCase().startsWith('vbscript:')) {
        return false;
      }

      // For http, https, mailto, tel - allow
      final lowerUrl = url.toLowerCase();
      for (final protocol in allowedProtocols) {
        if (lowerUrl.startsWith(protocol)) {
          return true;
        }
      }

      // Relative URLs are allowed (will be resolved against base URL)
      if (!url.contains('://')) {
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Checks if a string contains JavaScript code
  static bool _containsJavaScript(String value) {
    final lowerValue = value.toLowerCase();
    return lowerValue.contains('javascript:') ||
        lowerValue.contains('eval(') ||
        lowerValue.contains('expression(');
  }

  /// Extracts all image URLs from HTML content
  ///
  /// [html] - The HTML string to parse
  ///
  /// Returns a list of image URLs found in the HTML
  static List<String> extractImageUrls(String html) {
    if (html.isEmpty) return [];

    try {
      final document = parser.parse(html);
      final images = document.querySelectorAll('img');
      return images
          .map((img) => img.attributes['src'])
          .whereType<String>()
          .where(_isValidUrl)
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Extracts all links from HTML content
  ///
  /// [html] - The HTML string to parse
  ///
  /// Returns a list of (text, url) tuples found in the HTML
  static List<({String text, String url})> extractLinks(String html) {
    if (html.isEmpty) return [];

    try {
      final document = parser.parse(html);
      final links = document.querySelectorAll('a');
      return links
          .where((link) {
            final href = link.attributes['href'];
            return href != null && _isValidUrl(href);
          })
          .map((link) => (
            text: link.text.trim(),
            url: link.attributes['href']!,
          ))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // ============================================================
  // Model Reasoning Sanitization (merged from SummarySanitizer)
  // ============================================================

  static const String _htmlErrorMessage =
      'Summary generation failed because the server returned an HTML error page.';

  /// Remove model reasoning tags while preserving normal markdown content.
  ///
  /// This is used to clean AI-generated summaries that may contain
  /// internal reasoning tags like `<thinking>` or similar markers.
  ///
  /// [input] - The text to clean
  ///
  /// Returns cleaned text with reasoning tags removed
  static String cleanModelReasoning(String? input) {
    if (input == null || input.isEmpty) {
      return '';
    }

    var cleaned = input;
    final patterns = <RegExp>[
      RegExp(r'<thinking>.*?</thinking>', caseSensitive: false, dotAll: true),
      RegExp(r'<think\b[^>]*>.*?</think\b[^>]*>', caseSensitive: false, dotAll: true),
    ];

    for (final pattern in patterns) {
      cleaned = cleaned.replaceAll(pattern, '');
    }

    return cleaned.trim();
  }

  /// Detects if the input contains HTML error page content
  ///
  /// This helps identify when the AI summary endpoint returned an error
  /// page (e.g., Cloudflare timeout) instead of actual summary content.
  ///
  /// [input] - The text to check
  ///
  /// Returns an error message if failure detected, null otherwise
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
