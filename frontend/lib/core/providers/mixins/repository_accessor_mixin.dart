import '../../utils/app_logger.dart' as logger;

/// Mixin for async state management in Notifiers.
///
/// Provides loading and error state management methods.
/// Use with classes that have `isLoading` and `error` fields.
///
/// Usage:
/// ```dart
/// class MyState {
///   final bool isLoading;
///   final String? error;
///   // ...
/// }
///
/// class MyNotifier extends Notifier<MyState> with AsyncStateHelper<MyState> {
///   @override
///   MyState build() => MyState(isLoading: false);
///
///   Future<void> fetchData() async {
///     state = setLoading(state, true);
///     try {
///       // ...
///       state = setError(state, null);
///     } catch (e) {
///       state = setError(state, e.toString());
///     }
///   }
/// }
/// ```
mixin AsyncStateHelper<T> {
  /// Set loading state - returns new state with isLoading = true/false
  T setLoading(T currentState, bool loading);

  /// Set error state - returns new state with error message
  T setError(T currentState, String? error);
}

/// Mixin for generating cache keys.
///
/// Usage:
/// ```dart
/// class MyNotifier extends Notifier<MyState> with CacheKeyMixin {
///   void example() {
///     final key = generateCacheKey('podcasts', '45');
///     // key = 'podcasts_45'
///   }
/// }
/// ```
mixin CacheKeyMixin {
  /// Generate a cache key with prefix and optional suffix
  ///
  /// Example:
  /// - `generateCacheKey('users')` returns 'users_'
  /// - `generateCacheKey('users', '123')` returns 'users_123'
  String generateCacheKey(String prefix, [String? suffix]) {
    final effectiveSuffix = suffix ?? '';
    return '${prefix}_$effectiveSuffix';
  }

  /// Generate a cache key with multiple parts
  ///
  /// Example:
  /// - `generateMultiPartCacheKey(['users', '123', 'settings'])` returns 'users_123_settings'
  String generateMultiPartCacheKey(List<String> parts) {
    return parts.join('_');
  }
}

/// Mixin for logging in providers.
///
/// Provides convenient logging methods with provider context.
///
/// Usage:
/// ```dart
/// class MyNotifier extends Notifier<MyState> with ProviderLoggingMixin {
///   void example() {
///     logDebug('Operation started');
///     logError('Operation failed', error: e);
///   }
/// }
/// ```
mixin ProviderLoggingMixin {
  /// Log debug message with provider context
  void logDebug(String message, [String? tag]) {
    logger.AppLogger.debug('${tag != null ? '[$tag] ' : ''}$message');
  }

  /// Log info message with provider context
  void logInfo(String message, [String? tag]) {
    logger.AppLogger.info('${tag != null ? '[$tag] ' : ''}$message');
  }

  /// Log warning message with provider context
  void logWarning(String message, [String? tag]) {
    logger.AppLogger.warning('${tag != null ? '[$tag] ' : ''}$message');
  }

  /// Log error message with provider context
  void logError(String message, {Object? error, StackTrace? stackTrace, String? tag}) {
    logger.AppLogger.error(
      '${tag != null ? '[$tag] ' : ''}$message',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
