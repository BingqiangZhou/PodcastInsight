import 'package:share_plus/share_plus.dart';

/// Adaptive share service that provides platform-aware sharing.
///
/// Uses share_plus which automatically calls the native share sheet:
/// - iOS: UIActivityViewController (circular icons, horizontal layout)
/// - Android: Intent Chooser (list layout)
class AdaptiveShare {
  AdaptiveShare._();

  /// Share plain text content.
  ///
  /// [text] The text content to share.
  /// [subject] Optional subject line (primarily used on email).
  static Future<void> shareText(
    String text, {
    String? subject,
  }) {
    return Share.share(text, subject: subject);
  }

  /// Share a podcast episode.
  ///
  /// [title] The episode title.
  /// [url] The episode URL or deep link.
  /// [podcastName] Optional podcast/subscription name.
  /// [description] Optional episode description.
  static Future<void> shareEpisode({
    required String title,
    required String url,
    String? podcastName,
    String? description,
  }) {
    final buffer = StringBuffer();

    if (podcastName != null) {
      buffer.writeln('$podcastName');
    }

    buffer.writeln(title);
    buffer.writeln(url);

    if (description != null && description.isNotEmpty) {
      buffer.writeln();
      buffer.write(description);
    }

    return Share.share(buffer.toString().trim(), subject: title);
  }

  /// Share a podcast/show.
  ///
  /// [name] The podcast/show name.
  /// [url] The podcast URL or deep link.
  /// [description] Optional description.
  static Future<void> sharePodcast({
    required String name,
    required String url,
    String? description,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(name);
    buffer.writeln(url);

    if (description != null && description.isNotEmpty) {
      buffer.writeln();
      buffer.write(description);
    }

    return Share.share(buffer.toString().trim(), subject: name);
  }

  /// Share with multiple files (e.g., images, documents).
  ///
  /// [text] Optional text to include with the files.
  /// [files] List of file paths to share.
  static Future<void> shareFiles(
    List<String> files, {
    String? text,
  }) {
    return Share.shareFiles(files, text: text);
  }
}
