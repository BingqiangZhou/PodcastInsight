import 'dart:async';
import 'package:dio/dio.dart';

import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;

/// Connection status enum for server health check
enum ConnectionStatus {
  /// Initial state, not yet verified
  unverified,
  /// Currently verifying the connection
  verifying,
  /// Connection successful
  success,
  /// Connection failed
  failed,
}

/// Result of a server health check
class HealthCheckResult {

  const HealthCheckResult({
    required this.status,
    this.message,
    this.responseTimeMs,
  });

  factory HealthCheckResult.success({String? message, int? responseTimeMs}) {
    return HealthCheckResult(
      status: ConnectionStatus.success,
      message: message,
      responseTimeMs: responseTimeMs,
    );
  }

  factory HealthCheckResult.failed({String? message}) {
    return HealthCheckResult(
      status: ConnectionStatus.failed,
      message: message,
    );
  }

  factory HealthCheckResult.verifying() {
    return const HealthCheckResult(
      status: ConnectionStatus.verifying,
    );
  }

  factory HealthCheckResult.unverified() {
    return const HealthCheckResult(
      status: ConnectionStatus.unverified,
    );
  }
  final ConnectionStatus status;
  final String? message;
  final int? responseTimeMs;
}

/// Service for checking server health and connectivity
class ServerHealthService {

  ServerHealthService(this._dio);
  final Dio _dio;
  CancelToken? _cancelToken;
  static const String _healthEndpoint = '/api/v1/health';

  /// Normalize the base URL by:
  /// 1. Trimming whitespace
  /// 2. Removing trailing slashes
  /// 3. Adding http:// scheme if missing
  static String normalizeBaseUrl(String url) {
    var normalized = url.trim();

    // Remove trailing slashes
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }

    // Add http:// scheme if missing
    if (!normalized.startsWith('http://') && !normalized.startsWith('https://')) {
      normalized = 'http://$normalized';
    }

    return normalized;
  }

  /// Verify the server connection by sending a health check request
  /// Returns a Stream of HealthCheckResult for real-time updates
  Stream<HealthCheckResult> verifyConnection(String baseUrl) async* {
    yield HealthCheckResult.verifying();

    // Cancel any previous request
    _cancelToken?.cancel('New verification started');
    _cancelToken = CancelToken();

    final normalizedUrl = normalizeBaseUrl(baseUrl);
    final healthCheckUrl = '$normalizedUrl$_healthEndpoint';

    logger.AppLogger.debug('🔍 [HealthCheck] Verifying: $healthCheckUrl');

    final stopwatch = Stopwatch()..start();

    try {
      final response = await _dio.get(
        healthCheckUrl,
        cancelToken: _cancelToken,
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      stopwatch.stop();

      // Check if response is successful (HTTP 200-299)
      if (response.statusCode == 200) {
        logger.AppLogger.debug('✅ [HealthCheck] Success (${stopwatch.elapsedMilliseconds}ms)');
        yield HealthCheckResult.success(
          message: 'Connected',
          responseTimeMs: stopwatch.elapsedMilliseconds,
        );
      } else {
        logger.AppLogger.debug('❌ [HealthCheck] Failed: HTTP ${response.statusCode}');
        yield HealthCheckResult.failed(
          message: 'Server returned HTTP ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      stopwatch.stop();

      if (e.type == DioExceptionType.cancel) {
        logger.AppLogger.debug('⚠️ [HealthCheck] Cancelled');
        return; // Don't yield anything if cancelled
      }

      String errorMessage;
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          errorMessage = 'Connection timeout';
        case DioExceptionType.connectionError:
          errorMessage = 'Cannot connect to server';
        case DioExceptionType.badResponse:
          errorMessage = 'Server error: ${e.response?.statusCode}';
        default:
          errorMessage = 'Connection failed: ${e.message}';
      }

      logger.AppLogger.debug('❌ [HealthCheck] Failed: $errorMessage');
      yield HealthCheckResult.failed(message: errorMessage);
    } catch (e) {
      stopwatch.stop();
      logger.AppLogger.debug('❌ [HealthCheck] Failed: $e');
      yield HealthCheckResult.failed(message: 'Unexpected error: $e');
    }
  }

  /// Cancel any ongoing verification
  void cancelVerification() {
    _cancelToken?.cancel();
    _cancelToken = null;
  }

  void dispose() {
    cancelVerification();
  }
}
