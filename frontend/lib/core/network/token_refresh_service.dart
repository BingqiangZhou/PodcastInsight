import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:personal_ai_assistant/core/app/config/app_config.dart' as config;
import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;
import 'package:personal_ai_assistant/features/auth/data/events/auth_event.dart';

/// Reason why token refresh failed.
enum TokenRefreshFailureReason {
  invalidSession,
  transientFailure,
  unknownFailure,
}

/// Result of a token refresh attempt.
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

/// Handles authentication token refresh and 401 retry logic.
class TokenRefreshService {
  TokenRefreshService({
    required Dio dio,
    FlutterSecureStorage? secureStorage,
  }) : _dio = dio,
       _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final Dio _dio;
  final FlutterSecureStorage _secureStorage;
  Completer<TokenRefreshResult>? _refreshCompleter;

  // --- Token refresh -------------------------------------------------------

  /// Attempts to refresh the session token. Uses a [Completer] to coalesce
  /// concurrent refresh calls into a single network request.
  Future<TokenRefreshResult> refreshToken() async {
    final existing = _refreshCompleter;
    if (existing != null && !existing.isCompleted) return existing.future;

    _refreshCompleter = Completer<TokenRefreshResult>();
    final completer = _refreshCompleter!;

    try {
      final refreshToken = await _safeRead(config.AppConstants.refreshTokenKey);
      if (refreshToken == null || refreshToken.isEmpty) {
        const result = TokenRefreshResult.failure(
          TokenRefreshFailureReason.invalidSession,
        );
        completer.complete(result);
        return result;
      }

      final response = await _dio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final newAccessToken = data['access_token'] as String?;
        final newRefreshToken = data['refresh_token'] as String?;
        final expiresRaw = data['expires_in'];
        final expiresInSeconds = expiresRaw is int
            ? expiresRaw
            : (expiresRaw is num
                  ? expiresRaw.toInt()
                  : int.tryParse(expiresRaw?.toString() ?? ''));

        if (newAccessToken != null && newAccessToken.isNotEmpty) {
          await _safeWrite(config.AppConstants.accessTokenKey, newAccessToken);
          if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
            await _safeWrite(
              config.AppConstants.refreshTokenKey,
              newRefreshToken,
            );
          }
          if (expiresInSeconds != null && expiresInSeconds > 0) {
            final expiry = DateTime.now()
                .toUtc()
                .add(Duration(seconds: expiresInSeconds));
            await _safeWrite(
              config.AppConstants.tokenExpiryKey,
              expiry.toIso8601String(),
            );
          }
          final expiresAt = data['expires_at'] as String?;
          if (expiresAt != null && expiresAt.isNotEmpty) {
            await _safeWrite(config.AppConstants.tokenExpiryKey, expiresAt);
          }

          logger.AppLogger.debug(
            '[TokenRefresh] success — ${newAccessToken.substring(0, 20)}...',
          );
          final result = TokenRefreshResult.success(
            accessToken: newAccessToken,
            expiresInSeconds: expiresInSeconds,
          );
          completer.complete(result);
          return result;
        }
      }

      logger.AppLogger.debug('[TokenRefresh] invalid response format');
      const result = TokenRefreshResult.failure(
        TokenRefreshFailureReason.unknownFailure,
      );
      completer.complete(result);
      return result;
    } catch (e) {
      logger.AppLogger.debug('[TokenRefresh] failed: $e');
      final result = e is DioException
          ? TokenRefreshResult.failure(classifyRefreshFailure(e))
          : const TokenRefreshResult.failure(
              TokenRefreshFailureReason.unknownFailure,
            );
      completer.complete(result);
      return result;
    } finally {
      _refreshCompleter = null;
    }
  }

  // --- 401 handling --------------------------------------------------------

  /// Handles a 401 error by attempting token refresh and retrying.
  ///
  /// Returns the retried [Response] on success, or throws a [DioException].
  Future<Response> handle401(
    RequestOptions failedOptions, {
    required void Function(String? newToken) onTokenUpdated,
  }) async {
    // Avoid infinite loop if the refresh request itself 401'd.
    if (failedOptions.path.contains('/auth/refresh')) {
      throw DioException(
        requestOptions: failedOptions,
        type: DioExceptionType.badResponse,
        error: const AuthRefreshException('Refresh token request failed'),
      );
    }

    final result = await refreshToken();
    final newToken = result.accessToken;

    if (!result.success || newToken == null) {
      onTokenUpdated(null);
      final reason = result.reason ?? TokenRefreshFailureReason.unknownFailure;
      if (shouldClearTokensForRefreshFailure(reason)) {
        await clearTokens();
      }
      throw DioException(
        requestOptions: failedOptions,
        error: reason == TokenRefreshFailureReason.transientFailure
            ? const TransientRefreshException()
            : const UnknownRefreshException(),
      );
    }

    // Retry with new token.
    onTokenUpdated(newToken);
    final headers = Map<String, dynamic>.from(failedOptions.headers)
      ..removeWhere((k, _) => k.toLowerCase() == 'authorization')
      ..['Authorization'] = 'Bearer $newToken';

    final retryResponse = await _dio.fetch(
      failedOptions.copyWith(headers: headers),
    );

    // If the retry still 401's, surface that as an auth error.
    if (retryResponse.statusCode == 401) {
      throw DioException(
        requestOptions: retryResponse.requestOptions,
        response: retryResponse,
        type: DioExceptionType.badResponse,
      );
    }
    return retryResponse;
  }

  // --- Token storage -------------------------------------------------------

  /// Clears all stored tokens and notifies listeners.
  Future<void> clearTokens() async {
    await _safeDelete(config.AppConstants.accessTokenKey);
    await _safeDelete(config.AppConstants.refreshTokenKey);
    await _safeDelete(config.AppConstants.tokenExpiryKey);
    await _safeDelete(config.AppConstants.userProfileKey);
    AuthEventNotifier.instance.notify(
      AuthEvent(
        type: AuthEventType.tokenCleared,
        message: 'Tokens cleared due to authentication failure',
      ),
    );
  }

  Future<String?> getAccessToken() =>
      _safeRead(config.AppConstants.accessTokenKey);

  // --- Classification helpers ----------------------------------------------

  static TokenRefreshFailureReason classifyRefreshFailure(DioException error) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;

    if (statusCode == 401) return TokenRefreshFailureReason.invalidSession;

    if (_looksLikeInvalidSession(data) &&
        (statusCode == 404 || statusCode == 400 || statusCode == 422)) {
      return TokenRefreshFailureReason.invalidSession;
    }

    final isTransient =
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError;

    if (isTransient || (statusCode != null && statusCode >= 500)) {
      return TokenRefreshFailureReason.transientFailure;
    }

    return TokenRefreshFailureReason.unknownFailure;
  }

  static bool shouldClearTokensForRefreshFailure(TokenRefreshFailureReason r) =>
      r == TokenRefreshFailureReason.invalidSession;

  static bool _looksLikeInvalidSession(dynamic data) {
    var text = '';
    if (data is Map) {
      text = '${data['detail'] ?? ''} ${data['message'] ?? ''} ${data['type'] ?? ''}'
          .toLowerCase();
    } else if (data is String) {
      text = data.toLowerCase();
    }
    return text.contains('invalid') ||
        text.contains('session') ||
        text.contains('refresh token');
  }

  // --- Secure storage helpers ----------------------------------------------

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
}

/// Marker exception types for 401 handling outcomes.
class AuthRefreshException implements Exception {
  const AuthRefreshException(this.message);
  final String message;
}

class TransientRefreshException implements Exception {
  const TransientRefreshException();
}

class UnknownRefreshException implements Exception {
  const UnknownRefreshException();
}
