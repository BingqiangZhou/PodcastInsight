import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/app/config/app_config.dart' as config;
import '../../core/auth/auth_event.dart';
import '../utils/app_logger.dart' as logger;

/// Reason why token refresh failed
enum TokenRefreshFailureReason {
  invalidSession,
  transientFailure,
  unknownFailure,
}

/// Result of a token refresh attempt
class TokenRefreshResult {
  final bool success;
  final TokenRefreshFailureReason? reason;
  final String? accessToken;
  final int? expiresInSeconds;

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
  final Dio _dio;
  final FlutterSecureStorage _secureStorage;
  Completer<TokenRefreshResult>? _refreshCompleter;

  TokenRefreshService({
    required Dio dio,
    FlutterSecureStorage? secureStorage,
  }) : _dio = dio,
       _secureStorage = secureStorage ?? const FlutterSecureStorage();

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
      final refreshToken = await _secureStorage.read(
        key: config.AppConstants.refreshTokenKey,
      );
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
          await _secureStorage.write(
            key: config.AppConstants.accessTokenKey,
            value: newAccessToken,
          );
          if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
            await _secureStorage.write(
              key: config.AppConstants.refreshTokenKey,
              value: newRefreshToken,
            );
          }
          if (expiresInSeconds != null && expiresInSeconds > 0) {
            final expiryTime = DateTime.now().toUtc().add(
              Duration(seconds: expiresInSeconds),
            );
            await _secureStorage.write(
              key: config.AppConstants.tokenExpiryKey,
              value: expiryTime.toIso8601String(),
            );
            logger.AppLogger.debug(
              '[TokenRefresh] Saved UTC token expiry: $expiryTime',
            );
          }

          final expiresAt = responseData['expires_at'] as String?;
          if (expiresAt != null && expiresAt.isNotEmpty) {
            await _secureStorage.write(
              key: config.AppConstants.tokenExpiryKey,
              value: expiresAt,
            );
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
    await _secureStorage.delete(key: config.AppConstants.accessTokenKey);
    await _secureStorage.delete(key: config.AppConstants.refreshTokenKey);
    await _secureStorage.delete(key: config.AppConstants.tokenExpiryKey);
    await _secureStorage.delete(key: config.AppConstants.userProfileKey);
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
    return _secureStorage.read(key: config.AppConstants.accessTokenKey);
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
    String text = '';
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
