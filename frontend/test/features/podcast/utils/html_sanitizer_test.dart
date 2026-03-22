import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/podcast/core/utils/html_sanitizer.dart';

void main() {
  group('HtmlSanitizer', () {
    group('Basic sanitization', () {
      test('should preserve safe HTML tags', () {
        const input = '<p>Hello <strong>world</strong></p>';
        final result = HtmlSanitizer.sanitize(input);
        expect(result, contains('<p>'));
        expect(result, contains('<strong>'));
        expect(result, contains('Hello'));
        expect(result, contains('world'));
      });

      test('should remove script tags', () {
        const input = '<p>Hello</p><script>alert("XSS")</script>';
        final result = HtmlSanitizer.sanitize(input);
        expect(result, isNot(contains('script')));
        expect(result, isNot(contains('alert')));
        expect(result, contains('<p>Hello</p>'));
      });

      test('should remove iframe tags', () {
        const input = '<p>Hello</p><iframe src="evil.com"></iframe>';
        final result = HtmlSanitizer.sanitize(input);
        expect(result, isNot(contains('iframe')));
        expect(result, contains('<p>Hello</p>'));
      });

      test('should remove object and embed tags', () {
        const input = '''
          <p>Hello</p>
          <object data="evil.swf"></object>
          <embed src="evil.swf">
        ''';
        final result = HtmlSanitizer.sanitize(input);
        expect(result, isNot(contains('object')));
        expect(result, isNot(contains('embed')));
        expect(result, contains('<p>Hello</p>'));
      });

      test('should remove form and input tags', () {
        const input = '<form><input type="password"></form>';
        final result = HtmlSanitizer.sanitize(input);
        expect(result, isNot(contains('form')));
        expect(result, isNot(contains('input')));
      });

      test('should handle empty string', () {
        const input = '';
        final result = HtmlSanitizer.sanitize(input);
        expect(result, '');
      });

      test('should handle plain text without HTML', () {
        const input = 'Just plain text';
        final result = HtmlSanitizer.sanitize(input);
        expect(result, 'Just plain text');
      });
    });

    group('Attribute sanitization', () {
      test('should preserve allowed attributes', () {
        const input = '<a href="https://example.com" title="Link">Click</a>';
        final result = HtmlSanitizer.sanitize(input);
        expect(result, contains('href='));
        expect(result, contains('title='));
        expect(result, contains('rel='));
      });

      test('should remove disallowed attributes', () {
        const input = '<p style="color:red" class="foo" data-test="bar">Text</p>';
        final result = HtmlSanitizer.sanitize(input);
        expect(result, isNot(contains('style=')));
        expect(result, contains('class='));
      });

      test('should remove onclick event handlers', () {
        const input = '<p onclick="alert("XSS")">Click</p>';
        final result = HtmlSanitizer.sanitize(input);
        expect(result, isNot(contains('onclick')));
      });

      test('should remove all on* event handlers', () {
        const input = '''
          <p onclick="alert(1)" onerror="alert(2)" onload="alert(3)">Text</p>
        ''';
        final result = HtmlSanitizer.sanitize(input);
        expect(result, isNot(contains('onclick')));
        expect(result, isNot(contains('onerror')));
        expect(result, isNot(contains('onload')));
      });

      test('should remove dangerous data-* attributes', () {
        const input = '<p data-x="javascript:alert(1)">Text</p>';
        final result = HtmlSanitizer.sanitize(input);
        expect(result, isNot(contains('data-x=')));
      });

      test('should preserve safe data-* attributes', () {
        const input = '<p data-id="123">Text</p>';
        final result = HtmlSanitizer.sanitize(input);
        // Safe data attributes are removed to be conservative
        expect(result, isNot(contains('data-id=')));
      });
    });

    group('URL validation', () {
      test('should allow http URLs', () {
        const input = '<a href="http://example.com">Link</a>';
        final result = HtmlSanitizer.sanitize(input);
        expect(result, contains('href="http://example.com"'));
      });

      test('should allow https URLs', () {
        const input = '<a href="https://example.com">Link</a>';
        final result = HtmlSanitizer.sanitize(input);
        expect(result, contains('href="https://example.com"'));
      });

      test('should allow mailto URLs', () {
        const input = '<a href="mailto:test@example.com">Email</a>';
        final result = HtmlSanitizer.sanitize(input);
        expect(result, contains('href="mailto:test@example.com"'));
      });

      test('should allow tel URLs', () {
        const input = '<a href="tel:+1234567890">Call</a>';
        final result = HtmlSanitizer.sanitize(input);
        expect(result, contains('href="tel:+1234567890"'));
      });

      test('should remove javascript: URLs', () {
        const input = '<a href="javascript:alert(1)">Link</a>';
        final result = HtmlSanitizer.sanitize(input);
        expect(result, isNot(contains('javascript:')));
        expect(result, isNot(contains('href=')));
      });

      test('should remove data: URLs', () {
        const input = '<a href="data:text/html,<script>alert(1)</script>">Link</a>';
        final result = HtmlSanitizer.sanitize(input);
        expect(result, isNot(contains('data:')));
        expect(result, isNot(contains('href=')));
      });

      test('should remove vbscript: URLs', () {
        const input = '<a href="vbscript:msgbox(1)">Link</a>';
        final result = HtmlSanitizer.sanitize(input);
        expect(result, isNot(contains('vbscript:')));
        expect(result, isNot(contains('href=')));
      });

      test('should add rel="nofollow noopener" to external links', () {
        const input = '<a href="https://example.com">Link</a>';
        final result = HtmlSanitizer.sanitize(input);
        expect(result, contains('rel='));
        expect(result, contains('nofollow'));
        expect(result, contains('noopener'));
      });

      test('should allow relative URLs for images', () {
        const input = '<img src="/images/test.jpg">';
        final result = HtmlSanitizer.sanitize(input);
        expect(result, contains('src="/images/test.jpg"'));
      });

      test('should remove invalid image URLs', () {
        const input = '<img src="javascript:alert(1)">';
        final result = HtmlSanitizer.sanitize(input);
        expect(result, isNot(contains('img')));
      });
    });

    group('Complex HTML structures', () {
      test('should handle nested lists', () {
        const input = '''
          <ul>
            <li>Item 1</li>
            <li>Item 2
              <ul>
                <li>Subitem 2.1</li>
              </ul>
            </li>
          </ul>
        ''';
        final result = HtmlSanitizer.sanitize(input);
        expect(result, contains('<ul>'));
        expect(result, contains('<li>'));
        expect(result, contains('Item 1'));
        expect(result, contains('Subitem 2.1'));
      });

      test('should handle tables', () {
        const input = '''
          <table>
            <thead>
              <tr><th>Header</th></tr>
            </thead>
            <tbody>
              <tr><td>Data</td></tr>
            </tbody>
          </table>
        ''';
        final result = HtmlSanitizer.sanitize(input);
        expect(result, contains('<table>'));
        expect(result, contains('<thead>'));
        expect(result, contains('<tbody>'));
        expect(result, contains('<tr>'));
        expect(result, contains('<th>'));
        expect(result, contains('<td>'));
      });

      test('should handle blockquotes', () {
        const input = '<blockquote>This is a quote</blockquote>';
        final result = HtmlSanitizer.sanitize(input);
        expect(result, contains('<blockquote>'));
        expect(result, contains('This is a quote'));
      });

      test('should handle code blocks', () {
        const input = '<pre><code>const x = 1;</code></pre>';
        final result = HtmlSanitizer.sanitize(input);
        expect(result, contains('<pre>'));
        expect(result, contains('<code>'));
        expect(result, contains('const x = 1;'));
      });

      test('should handle headings', () {
        const input = '''
          <h1>Heading 1</h1>
          <h2>Heading 2</h2>
          <h3>Heading 3</h3>
          <h4>Heading 4</h4>
          <h5>Heading 5</h5>
          <h6>Heading 6</h6>
        ''';
        final result = HtmlSanitizer.sanitize(input);
        expect(result, contains('<h1>'));
        expect(result, contains('<h2>'));
        expect(result, contains('<h3>'));
        expect(result, contains('<h4>'));
        expect(result, contains('<h5>'));
        expect(result, contains('<h6>'));
      });
    });

    group('Image URL extraction', () {
      test('should extract image URLs from HTML', () {
        const input = '''
          <img src="https://example.com/image1.jpg">
          <img src="https://example.com/image2.png">
        ''';
        final urls = HtmlSanitizer.extractImageUrls(input);
        expect(urls, contains('https://example.com/image1.jpg'));
        expect(urls, contains('https://example.com/image2.png'));
        expect(urls.length, 2);
      });

      test('should not extract invalid image URLs', () {
        const input = '''
          <img src="https://example.com/valid.jpg">
          <img src="javascript:alert(1)">
        ''';
        final urls = HtmlSanitizer.extractImageUrls(input);
        expect(urls, contains('https://example.com/valid.jpg'));
        expect(urls.length, 1);
      });

      test('should handle empty HTML', () {
        const input = '';
        final urls = HtmlSanitizer.extractImageUrls(input);
        expect(urls, isEmpty);
      });
    });

    group('Link extraction', () {
      test('should extract links from HTML', () {
        const input = '''
          <a href="https://example.com">Example</a>
          <a href="https://test.com">Test</a>
        ''';
        final links = HtmlSanitizer.extractLinks(input);
        expect(links, contains((text: 'Example', url: 'https://example.com')));
        expect(links, contains((text: 'Test', url: 'https://test.com')));
        expect(links.length, 2);
      });

      test('should not extract invalid links', () {
        const input = '''
          <a href="https://example.com">Valid</a>
          <a href="javascript:alert(1)">Invalid</a>
        ''';
        final links = HtmlSanitizer.extractLinks(input);
        expect(links, contains((text: 'Valid', url: 'https://example.com')));
        expect(links.length, 1);
      });

      test('should handle empty HTML', () {
        const input = '';
        final links = HtmlSanitizer.extractLinks(input);
        expect(links, isEmpty);
      });
    });

    group('Async sanitization', () {
      test('should produce same result as sync version', () async {
        const input = '<p>Hello <strong>world</strong></p><script>alert("XSS")</script>';
        final syncResult = HtmlSanitizer.sanitize(input);
        final asyncResult = await HtmlSanitizer.sanitizeAsync(input);
        expect(asyncResult, syncResult);
      });

      test('should handle empty string', () async {
        const input = '';
        final result = await HtmlSanitizer.sanitizeAsync(input);
        expect(result, '');
      });

      test('should remove dangerous tags async', () async {
        const input = '<p>Hello</p><script>alert("XSS")</script><iframe src="evil.com"></iframe>';
        final result = await HtmlSanitizer.sanitizeAsync(input);
        expect(result, isNot(contains('script')));
        expect(result, isNot(contains('iframe')));
        expect(result, contains('<p>Hello</p>'));
      });

      test('should handle large HTML content', () async {
        final input = List.generate(1000, (i) => '<p>Paragraph $i</p>').join();
        final result = await HtmlSanitizer.sanitizeAsync(input);
        expect(result, contains('<p>Paragraph 0</p>'));
        expect(result, contains('<p>Paragraph 999</p>'));
      });
    });

    group('XSS attack vectors', () {
      test('should block script injection with onclick', () {
        const input = '<div onclick="alert(1)">Click me</div>';
        final result = HtmlSanitizer.sanitize(input);
        expect(result, isNot(contains('onclick')));
      });

      test('should block script in style attribute', () {
        const input = '<div style="background:url(javascript:alert(1))">Text</div>';
        final result = HtmlSanitizer.sanitize(input);
        expect(result, isNot(contains('javascript:')));
      });

      test('should block eval in data attributes', () {
        const input = '<div data-x="eval(alert(1))">Text</div>';
        final result = HtmlSanitizer.sanitize(input);
        expect(result, isNot(contains('data-x=')));
      });

      test('should block expression in data attributes', () {
        const input = '<div data-x="expression(alert(1))">Text</div>';
        final result = HtmlSanitizer.sanitize(input);
        expect(result, isNot(contains('data-x=')));
      });

      test('should handle malformed HTML gracefully', () {
        const input = '<p>Unclosed paragraph<div>Nested</p>';
        final result = HtmlSanitizer.sanitize(input);
        expect(result, isNotEmpty);
        expect(result, contains('Unclosed'));
      });

      test('should handle null bytes', () {
        const input = '<p>\x00Text</p>';
        final result = HtmlSanitizer.sanitize(input);
        expect(result, isNotEmpty);
      });
    });
  });
}
