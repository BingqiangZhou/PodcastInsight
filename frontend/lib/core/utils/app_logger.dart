import 'package:flutter/foundation.dart';

@immutable
class AppLoggerConfig {
  final bool debugEnabled;
  final bool infoEnabled;
  final bool warningEnabled;
  final bool errorEnabled;

  const AppLoggerConfig({
    required this.debugEnabled,
    required this.infoEnabled,
    required this.warningEnabled,
    required this.errorEnabled,
  });

  const AppLoggerConfig.debug()
    : debugEnabled = true,
      infoEnabled = true,
      warningEnabled = true,
      errorEnabled = true;

  const AppLoggerConfig.production()
    : debugEnabled = false,
      infoEnabled = false,
      warningEnabled = false,
      errorEnabled = true;

  const AppLoggerConfig.silent()
    : debugEnabled = false,
      infoEnabled = false,
      warningEnabled = false,
      errorEnabled = false;
}

class AppLogger {
  AppLogger._();

  static AppLoggerConfig _config = const AppLoggerConfig.production();

  static void configure(AppLoggerConfig config) {
    _config = config;
  }

  static void resetToDefault() {
    _config = const AppLoggerConfig.production();
  }

  /// Log a debug message.
  ///
  /// Short-circuits immediately in release builds via [kDebugMode] to avoid
  /// any overhead. The [_config.debugEnabled] flag provides a secondary guard
  /// that can be toggled at runtime in debug builds.
  static void debug(String message, {String? tag}) {
    if (!kDebugMode || !_config.debugEnabled) {
      return;
    }
    debugPrint('${_prefix(tag)}$message');
  }

  static void info(String message, {String? tag}) {
    if (!_config.infoEnabled) {
      return;
    }
    debugPrint('${_prefix(tag)}INFO: $message');
  }

  static void warning(String message, {String? tag}) {
    if (!_config.warningEnabled) {
      return;
    }
    debugPrint('${_prefix(tag)}WARN: $message');
  }

  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  }) {
    if (!_config.errorEnabled) {
      return;
    }
    final prefix = _prefix(tag);
    debugPrint('${prefix}ERROR: $message');
    if (error != null) {
      debugPrint('$prefix  Error: $error');
    }
    if (stackTrace != null) {
      debugPrint('$prefix  StackTrace:\n$stackTrace');
    }
  }

  static String _prefix(String? tag) => tag != null ? '[$tag] ' : '';
}
