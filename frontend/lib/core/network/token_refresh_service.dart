import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:personal_ai_assistant/core/app/config/app_config.dart' as config;
import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;
import 'package:personal_ai_assistant/features/auth/data/events/auth_event.dart';

/// Reason why token refresh failed
enum TokenRefreshFailureReason {
  invalidSession,
  transientFailure,
  unknownFailure,
}

/// Result of a token refresh attempt
class TokenRefreshResult {

  const TokenRefreshResult._({
    required this.success,
    this.reason,
    this.accessToken,
    this.expiresInSeconds,
  });

  const TokenRefreshResult.success({
    required String accessToken,
    int? expiresInSeconds,
  }) : this._(
         success: true,
         accessToken: accessToken,
         expiresInSeconds: expiresInSeconds,
       );

  const TokenRefreshResult.failure(TokenRefreshFailureReason reason)
    : this._(success: false, reason: reason);
  final bool success;
  final TokenRefreshFailureReason? reason;
  final String? accessToken;
  final int? expiresInSeconds;

  bool get isInvalidSessionFailure =>
      !success && reason == TokenRefreshFailureReason.invalidSession;
}

/// Service for handling authentication token refresh.
///
/// Extracted from DioClient to:
/// - Reduce complexity in DioClient
/// - Allow reuse across multiple Dio instances
/// - Enable easier testing of token refresh logic
class TokenRefreshService {

  TokenRefreshService({
    required Dio dio,
    FlutterSecureStorage? secureStorage,
  }) : _dio = dio,
       _secureStorage = secureStorage ?? const FlutterSecureStorage();
  final Dio _dio;
  final FlutterSecureStorage _secureStorage;
  Completer<TokenRefreshResult>? _refreshCompleter;

  /// Attempt to refresh the session token.
  ///
  /// Uses a Completer to ensure only one refresh request happens at a time.
  /// If a refresh is already in progress, returns that future.
  Future<TokenRefreshResult> refreshToken() async {
    final completer = _refreshCompleter;
    if (completer != null && !completer.isCompleted) {
      logger.AppLogger.debug(
        '[TokenRefresh] Token refresh already in progress, waiting...',
      );
      return completer.future;
    }

    logger.AppLogger.debug('[TokenRefresh] Starting new token refresh...');
    _refreshCompleter = Completer<TokenRefreshResult>();
    final currentCompleter = _refreshCompleter!;

    try {
      final refreshToken = await _safeRead(config.AppConstants.refreshTokenKey);
      if (refreshToken == null || refreshToken.isEmpty) {
        logger.AppLogger.debug('[TokenRefresh] No refresh token found');
        const result = TokenRefreshResult.failure(
          TokenRefreshFailureReason.invalidSession,
        );
        currentCompleter.complete(result);
        return result;
      }

      logger.AppLogger.debug('[TokenRefresh] Sending refresh token request...');
      final response = await _dio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final responseData = response.data as Map<String, dynamic>;
        final newAccessToken = responseData['access_token'] as String?;
        final newRefreshToken = responseData['refresh_token'] as String?;
        final expiresInRaw = responseData['expires_in'];
        final expiresInSeconds = expiresInRaw is int
            ? expiresInRaw
            : (expiresInRaw is num
                  ? expiresInRaw.toInt()
                  : int.tryParse(expiresInRaw?.toString() ?? ''));

        if (newAccessToken != null && newAccessToken.isNotEmpty) {
          await _safeWrite(config.AppConstants.accessTokenKey, newAccessToken);
          if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
            await _safeWrite(config.AppConstants.refreshTokenKey, newRefreshToken);
          }
          if (expiresInSeconds != null && expiresInSeconds > 0) {
            final expiryTime = DateTime.now().toUtc().add(
              Duration(seconds: expiresInSeconds),
            );
            await _safeWrite(config.AppConstants.tokenExpiryKey, expiryTime.toIso8601String());
            logger.AppLogger.debug(
              '[TokenRefresh] Saved UTC token expiry: $expiryTime',
            );
          }

          final expiresAt = responseData['expires_at'] as String?;
          if (expiresAt != null && expiresAt.isNotEmpty) {
            await _safeWrite(config.AppConstants.tokenExpiryKey, expiresAt);
            logger.AppLogger.debug(
              '[TokenRefresh] Saved server UTC token expiry: $expiresAt',
            );
          }

          logger.AppLogger.debug(
            '[TokenRefresh] Token refresh successful - New token: ${newAccessToken.substring(0, 20)}...',
          );
          final result = TokenRefreshResult.success(
            accessToken: newAccessToken,
            expiresInSeconds: expiresInSeconds,
          );
          currentCompleter.complete(result);
          return result;
        }
      }

      logger.AppLogger.debug(
        '[TokenRefresh] Token refresh failed: invalid response format',
      );
      const result = TokenRefreshResult.failure(
        TokenRefreshFailureReason.unknownFailure,
      );
      currentCompleter.complete(result);
      return result;
    } catch (e) {
      logger.AppLogger.debug('[TokenRefresh] Token refresh failed: $e');
      final result = _buildRefreshFailureResult(e);
      currentCompleter.complete(result);
      return result;
    } finally {
      _refreshCompleter = null;
    }
  }

  /// Clear all stored tokens
  Future<void> clearTokens() async {
    await _safeDelete(config.AppConstants.accessTokenKey);
    await _safeDelete(config.AppConstants.refreshTokenKey);
    await _safeDelete(config.AppConstants.tokenExpiryKey);
    await _safeDelete(config.AppConstants.userProfileKey);
    logger.AppLogger.debug(
      '[TokenRefresh] Tokens cleared, user will need to re-login',
    );

    AuthEventNotifier.instance.notify(
      AuthEvent(
        type: AuthEventType.tokenCleared,
        message: 'Tokens cleared due to authentication failure',
      ),
    );
  }

  /// Get the current access token
  Future<String?> getAccessToken() async {
    return _safeRead(config.AppConstants.accessTokenKey);
  }

  Future<void> _safeWrite(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
    } on PlatformException catch (e) {
      logger.AppLogger.warning('[TokenRefresh] write($key) failed: ${e.message}');
    }
  }

  Future<String?> _safeRead(String key) async {
    try {
      return _secureStorage.read(key: key);
    } on PlatformException catch (e) {
      logger.AppLogger.warning('[TokenRefresh] read($key) failed: ${e.message}');
      return null;
    }
  }

  Future<void> _safeDelete(String key) async {
    try {
      await _secureStorage.delete(key: key);
    } on PlatformException catch (e) {
      logger.AppLogger.warning('[TokenRefresh] delete($key) failed: ${e.message}');
    }
  }

  TokenRefreshResult _buildRefreshFailureResult(Object error) {
    if (error is DioException) {
      logger.AppLogger.debug(
        '[TokenRefresh] Refresh failure status=${error.response?.statusCode} type=${error.type} response=${error.response?.data}',
      );
      return TokenRefreshResult.failure(classifyRefreshFailure(error));
    }
    return const TokenRefreshResult.failure(
      TokenRefreshFailureReason.unknownFailure,
    );
  }

  /// Classify a DioException into a refresh failure reason
  static TokenRefreshFailureReason classifyRefreshFailure(DioException error) {
    final statusCode = error.response?.statusCode;
    final responseData = error.response?.data;

    if (statusCode == 401) {
      return TokenRefreshFailureReason.invalidSession;
    }

    if (_looksLikeInvalidSessionResponse(responseData) &&
        (statusCode == 404 || statusCode == 400 || statusCode == 422)) {
      return TokenRefreshFailureReason.invalidSession;
    }

    final isTransientType =
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError;

    if (isTransientType || (statusCode != null && statusCode >= 500)) {
      return TokenRefreshFailureReason.transientFailure;
    }

    return TokenRefreshFailureReason.unknownFailure;
  }

  static bool _looksLikeInvalidSessionResponse(dynamic responseData) {
    var text = '';
    if (responseData is Map) {
      text =
          '${responseData['detail'] ?? ''} ${responseData['message'] ?? ''} ${responseData['type'] ?? ''}'
              .toLowerCase();
    } else if (responseData is String) {
      text = responseData.toLowerCase();
    }
    return text.contains('invalid') ||
        text.contains('session') ||
        text.contains('refresh token');
  }

  /// Check if tokens should be cleared for a given failure reason
  static bool shouldClearTokensForRefreshFailure(
    TokenRefreshFailureReason reason,
  ) {
    return reason == TokenRefreshFailureReason.invalidSession;
  }
}
