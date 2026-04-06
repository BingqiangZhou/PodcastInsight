import 'package:dio/dio.dart';

import 'package:personal_ai_assistant/core/network/dio_client.dart';
import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;

/// A Dio interceptor that automatically retries failed requests using
/// exponential backoff with optional `Retry-After` header support.
///
/// Retries are attempted for:
/// - Timeouts (connection, send, receive)
/// - Connection errors
/// - 5xx server errors
/// - 429 Too Many Requests (respects Retry-After header)
/// - Network-related unknown errors
class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required Dio dio,
    RetryOptions options = const RetryOptions(),
  })  : _dio = dio,
        _options = options;

  final Dio _dio;
  final RetryOptions _options;
  final Map<String, int> _retryAttempts = {};
  static const int _maxRetryKeys = 50;

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final retryKey = _getRetryKey(err.requestOptions);
    final currentAttempt = _retryAttempts[retryKey] ?? 0;

    if (_shouldRetry(err, currentAttempt)) {
      final nextAttempt = currentAttempt + 1;
      _retryAttempts[retryKey] = nextAttempt;
      _evictRetryKeysIfNeeded();

      // Respect Retry-After header for 429 responses
      var delay = _options.getDelay(currentAttempt);
      final statusCode = err.response?.statusCode;
      if (statusCode == 429) {
        final retryAfterHeader =
            err.response?.headers.value('retry-after');
        if (retryAfterHeader != null) {
          final retryAfterSeconds = int.tryParse(retryAfterHeader) ?? 0;
          if (retryAfterSeconds > 0) {
            delay = Duration(seconds: retryAfterSeconds);
          }
        }
      }

      logger.AppLogger.debug(
        '[RETRY] Attempt $nextAttempt/${_options.maxRetries} '
        'after ${delay.inMilliseconds}ms',
      );

      await Future.delayed(delay);

      try {
        final response = await _dio.fetch(err.requestOptions);
        _retryAttempts.remove(retryKey);
        logger.AppLogger.debug(
          '[RETRY] Success on attempt $nextAttempt',
        );
        handler.resolve(response);
        return;
      } on DioException catch (retryError) {
        logger.AppLogger.debug(
          '[RETRY] Attempt $nextAttempt failed: ${retryError.type}',
        );
        // Continue to pass the error through
      }
    } else if (currentAttempt > 0) {
      _retryAttempts.remove(retryKey);
      if (currentAttempt >= _options.maxRetries) {
        logger.AppLogger.debug(
          '[RETRY] Exhausted $currentAttempt attempts, giving up',
        );
      }
    }

    handler.next(err);
  }

  String _getRetryKey(RequestOptions options) {
    return '${options.method}:${options.path}:${options.queryParameters}';
  }

  void _evictRetryKeysIfNeeded() {
    while (_retryAttempts.length > _maxRetryKeys) {
      _retryAttempts.remove(_retryAttempts.keys.first);
    }
  }

  bool _shouldRetry(DioException error, int currentAttempt) {
    if (currentAttempt >= _options.maxRetries) {
      return false;
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return true;
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode != null) {
          if (statusCode >= 500 && statusCode < 600) return true;
          if (statusCode == 429) return true;
        }
        return false;
      case DioExceptionType.cancel:
        return false;
      case DioExceptionType.badCertificate:
        return false;
      case DioExceptionType.unknown:
        final errorText = error.message?.toLowerCase() ?? '';
        if (errorText.contains('socket') ||
            errorText.contains('network') ||
            errorText.contains('connection') ||
            errorText.contains('failed')) {
          return true;
        }
        return false;
    }
  }
}
