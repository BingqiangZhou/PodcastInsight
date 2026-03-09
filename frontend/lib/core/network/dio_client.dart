import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:meta/meta.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import ETag interceptor
import 'etag_interceptor.dart';

// Import the new AppConfig with dynamic baseUrl support
import '../../core/app/config/app_config.dart' as config;
import '../constants/app_constants.dart' as constants;
import 'exceptions/network_exceptions.dart';
import '../auth/auth_event.dart';
import '../utils/app_logger.dart' as logger;

enum TokenRefreshFailureReason {
  invalidSession,
  transientFailure,
  unknownFailure,
}

typedef SavedServerBaseUrlLoader = Future<String?> Function();

@immutable
class DioClientInitOptions {
  final bool applySavedBaseUrlOnInit;
  final String? initialServerBaseUrl;
  final SavedServerBaseUrlLoader? savedBaseUrlLoader;

  const DioClientInitOptions({
    this.applySavedBaseUrlOnInit = false,
    this.initialServerBaseUrl,
    this.savedBaseUrlLoader,
  });
}

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

class DioClient {
  final DioClientInitOptions _initOptions;
  late final Dio _dio;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _etagInvalidateAfterWriteKey =
      'etag_invalidate_after_write';

  // Token refresh state - use Completer for proper synchronization
  Completer<TokenRefreshResult>? _refreshCompleter;

  // Storage key for custom backend server base URL
  static const String _serverBaseUrlKey = 'server_base_url';

  // Cache store and interceptor
  late final CacheStore _cacheStore;
  late final DioCacheInterceptor _cacheInterceptor;

  // ETag interceptor
  late final ETagInterceptor _etagInterceptor;

  DioClient({DioClientInitOptions initOptions = const DioClientInitOptions()})
    : _initOptions = initOptions {
    // Initialize cache store
    _cacheStore = MemCacheStore();

    // Initialize cache interceptor with default policy
    _cacheInterceptor = DioCacheInterceptor(
      options: CacheOptions(
        store: _cacheStore,
        policy: CachePolicy.request,
        maxStale: const Duration(days: 7),
        priority: CachePriority.high,
        cipher: null,
        keyBuilder: CacheOptions.defaultCacheKeyBuilder,
        allowPostMethod: false,
      ),
    );

    // Initialize ETag interceptor
    _etagInterceptor = ETagInterceptor();

    // Initialize with default/empty baseUrl first.
    // The actual baseUrl is set by _initializeBaseUrl().
    _dio = Dio(
      BaseOptions(
        baseUrl: '',
        headers: constants.ApiConstants.headers,
        connectTimeout: Duration(
          milliseconds: constants.ApiConstants.connectTimeout.inMilliseconds,
        ),
        receiveTimeout: Duration(
          milliseconds: constants.ApiConstants.receiveTimeout.inMilliseconds,
        ),
        sendTimeout: Duration(
          milliseconds: constants.ApiConstants.sendTimeout.inMilliseconds,
        ),
      ),
    );

    // Add cache interceptor FIRST (before auth interceptor)
    _dio.interceptors.add(_cacheInterceptor);

    // Add ETag interceptor AFTER cache interceptor
    _dio.interceptors.add(_etagInterceptor);

    // Add interceptors
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onResponse: _onResponse,
        onError: _onError,
      ),
    );

    // Apply base URL synchronously before returning.
    _initializeBaseUrl(initialServerBaseUrl: _initOptions.initialServerBaseUrl);

    if (_initOptions.applySavedBaseUrlOnInit) {
      unawaited(initializeFromStorage());
    }
  }

  /// Initialize baseUrl from saved storage or default config
  /// This must be called synchronously during construction
  void _initializeBaseUrl({String? initialServerBaseUrl}) {
    // Try to get saved URL synchronously from AppConfig first
    // AppConfig.setServerBaseUrl() should have been called during app init
    String savedBaseUrl =
        initialServerBaseUrl ?? config.AppConfig.serverBaseUrl;

    // Normalize URL: remove trailing slashes
    if (savedBaseUrl.isNotEmpty) {
      savedBaseUrl = savedBaseUrl.trim();
      while (savedBaseUrl.endsWith('/')) {
        savedBaseUrl = savedBaseUrl.substring(0, savedBaseUrl.length - 1);
      }
      // Remove /api/v1 suffix if present
      if (savedBaseUrl.endsWith('/api/v1')) {
        savedBaseUrl = savedBaseUrl.substring(0, savedBaseUrl.length - 7);
      }
    }

    final apiBaseUrl = savedBaseUrl.isNotEmpty
        ? '$savedBaseUrl/api/v1'
        : '${config.AppConfig.serverBaseUrl}/api/v1';

    _dio.options.baseUrl = apiBaseUrl;
    logger.AppLogger.debug(
      ' [DioClient] Initialized with baseUrl: $apiBaseUrl',
    );
  }

  Dio get dio => _dio;

  /// Update the base URL dynamically
  /// This allows changing the API server at runtime without restarting the app
  void updateBaseUrl(String newBaseUrl) {
    _dio.options.baseUrl = newBaseUrl;
    logger.AppLogger.debug(' [DioClient] Base URL updated to: $newBaseUrl');
  }

  /// Get the current base URL
  String get currentBaseUrl => _dio.options.baseUrl;

  /// Apply saved baseUrl from local storage (called during initialization)
  Future<void> initializeFromStorage() async {
    await _applySavedBaseUrl();
  }

  Future<void> _applySavedBaseUrl() async {
    try {
      final savedUrl = await (_initOptions.savedBaseUrlLoader != null
          ? _initOptions.savedBaseUrlLoader!()
          : _loadSavedBaseUrlFromSharedPrefs());
      if (savedUrl != null && savedUrl.isNotEmpty) {
        // Normalize URL (remove trailing slashes, /api/v1 suffix)
        var normalizedUrl = savedUrl.trim();
        while (normalizedUrl.endsWith('/')) {
          normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1);
        }
        // Remove /api/v1 suffix if present (7 characters)
        if (normalizedUrl.endsWith('/api/v1')) {
          normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 7);
        } else if (normalizedUrl.contains('/api/v1/')) {
          normalizedUrl = normalizedUrl.replaceFirst('/api/v1/', '/');
        }

        // Apply with /api/v1 suffix
        updateBaseUrl('$normalizedUrl/api/v1');
        logger.AppLogger.debug(
          ' [DioClient] Applied saved backend API baseUrl: $savedUrl',
        );
      }
    } catch (e) {
      logger.AppLogger.debug(' [DioClient] Failed to apply saved baseUrl: $e');
    }
  }

  Future<String?> _loadSavedBaseUrlFromSharedPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_serverBaseUrlKey);
  }

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // DEBUG: Log full request URL.
    final fullUrl = '${_dio.options.baseUrl}/${options.path}';
    logger.AppLogger.debug(' [API REQUEST] ${options.method} $fullUrl');
    if (options.data != null) {
      logger.AppLogger.debug('   Data: ${options.data}');
    }
    if (options.queryParameters.isNotEmpty) {
      logger.AppLogger.debug('   Query: ${options.queryParameters}');
    }

    // Only add token if not already set (e.g., by retry logic)
    if (!options.headers.containsKey('Authorization')) {
      final token = await _secureStorage.read(
        key: config.AppConstants.accessTokenKey,
      );
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
        logger.AppLogger.debug(
          '[AUTH]    ?Token added: ${token.substring(0, 20)}...',
        );
      } else {
        logger.AppLogger.debug(
          '[AUTH]     No token found - skipping auth, will return 401 if protected route',
        );
      }
    }

    handler.next(options);
  }

  void _onResponse(Response response, ResponseInterceptorHandler handler) {
    if (_shouldInvalidateETagAfterWrite(
      response.requestOptions,
      response.statusCode,
    )) {
      _etagInterceptor.clearCache();
      logger.AppLogger.debug(
        ' [DioClient] Cleared ETag cache after ${response.requestOptions.method} ${response.requestOptions.path}',
      );
    }

    // Debug subscriptions list response shape
    if (response.requestOptions.path == '/subscriptions/podcasts') {
      final data = response.data;
      if (data is Map) {
        logger.AppLogger.debug(
          '?? [Subscriptions Response] keys=${data.keys.toList()} '
          'subscriptions=${(data['subscriptions'] as List?)?.length} '
          'items=${(data['items'] as List?)?.length} '
          'total=${data['total']}',
        );
      } else {
        logger.AppLogger.debug(
          '?? [Subscriptions Response] type=${data.runtimeType}',
        );
      }
    }
    // Debug: log AI summary related responses.
    if (response.requestOptions.path.contains('/episodes/')) {
      final data = response.data;
      if (data is Map && data.containsKey('ai_summary')) {
        logger.AppLogger.debug(
          ' [API RESPONSE] Episode ${data['id']} has ai_summary: ${data['ai_summary'] != null ? "YES (${data['ai_summary'].length} chars)" : "NO"}',
        );
      }
    }
    handler.next(response);
  }

  bool _shouldInvalidateETagAfterWrite(
    RequestOptions options,
    int? statusCode,
  ) {
    if (options.extra[_etagInvalidateAfterWriteKey] != true) {
      return false;
    }

    if (statusCode == null) {
      return false;
    }

    final method = options.method.toUpperCase();
    final isMutation =
        method == 'POST' ||
        method == 'PUT' ||
        method == 'PATCH' ||
        method == 'DELETE';
    final isSuccess = statusCode >= 200 && statusCode < 300;
    return isMutation && isSuccess;
  }

  Map<String, dynamic> _mutationCacheInvalidateExtra() {
    return {
      'dio_cache_interceptor_invalidate': true,
      _etagInvalidateAfterWriteKey: true,
    };
  }

  void _onError(DioException error, ErrorInterceptorHandler handler) async {
    // DEBUG: Log failed request URL.
    final errorUrl =
        '${error.requestOptions.baseUrl}/${error.requestOptions.path}';
    logger.AppLogger.debug(
      '[API ERROR] ${error.requestOptions.method} $errorUrl',
    );
    logger.AppLogger.debug('   Type: ${error.type}');
    logger.AppLogger.debug('   Message: ${error.message}');

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        logger.AppLogger.debug('    Timeout Error');
        handler.reject(
          DioException(
            requestOptions: error.requestOptions,
            type: DioExceptionType.unknown,
            error: NetworkException('Connection timeout'),
          ),
        );
        break;
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode != null) {
          if (statusCode == 401) {
            // Log 401 error details
            logger.AppLogger.debug(
              '[AUTH] ?401 Error: ${error.requestOptions.method} ${error.requestOptions.path}',
            );
            logger.AppLogger.debug('   Response: ${error.response?.data}');

            // Check if this is a refresh token request to avoid infinite loop
            final isRefreshRequest = error.requestOptions.path.contains(
              '/auth/refresh',
            );

            if (!isRefreshRequest) {
              // Try to refresh the token
              final refreshResult = await refreshSessionToken();
              if (refreshResult.success && refreshResult.accessToken != null) {
                // Retry the original request with new token
                try {
                  final response = await _retryRequest(
                    error.requestOptions,
                    refreshResult.accessToken!,
                  );
                  logger.AppLogger.debug(
                    '[AUTH] refresh_reason=none should_clear_tokens=false retry_result=success',
                  );
                  handler.resolve(response);
                  return;
                } on DioException catch (retryError) {
                  // Check if retry still fails with 401
                  if (retryError.response?.statusCode == 401) {
                    logger.AppLogger.debug(
                      '[AUTH] ?Retry still returns 401; treat as authorization/resource issue',
                    );
                    logger.AppLogger.debug(
                      '[AUTH] refresh_reason=none should_clear_tokens=false retry_result=still_401',
                    );
                    handler.reject(retryError);
                    return;
                  }
                  // Pass the retry error to handler (could be 404, 403, etc.)
                  logger.AppLogger.debug(
                    '[AUTH]  Retry failed with status: ${retryError.response?.statusCode}',
                  );
                  logger.AppLogger.debug(
                    '[AUTH] refresh_reason=none should_clear_tokens=false retry_result=failed_status_${retryError.response?.statusCode}',
                  );
                  handler.reject(retryError);
                  return;
                } catch (e) {
                  // Unexpected error during retry
                  logger.AppLogger.debug('?Unexpected error during retry: $e');
                  logger.AppLogger.debug(
                    '[AUTH] refresh_reason=none should_clear_tokens=false retry_result=unexpected_error',
                  );
                  handler.reject(error);
                  return;
                }
              } else {
                final reason =
                    refreshResult.reason ??
                    TokenRefreshFailureReason.unknownFailure;
                final shouldClearTokens = shouldClearTokensForRefreshFailure(
                  reason,
                );
                logger.AppLogger.debug(
                  '[AUTH] refresh_reason=${reason.name} should_clear_tokens=$shouldClearTokens retry_result=not_attempted',
                );

                if (shouldClearTokens) {
                  logger.AppLogger.debug(
                    '[AUTH] ?Token refresh failed due to invalid session, clearing tokens',
                  );
                  await _clearTokens();
                  handler.reject(
                    DioException(
                      requestOptions: error.requestOptions,
                      response: error.response,
                      type: DioExceptionType.badResponse,
                      error: AuthenticationException.fromDioError(error),
                    ),
                  );
                  return;
                }

                logger.AppLogger.debug(
                  '[AUTH]  Token refresh failed transiently; keeping tokens',
                );
                handler.reject(
                  DioException(
                    requestOptions: error.requestOptions,
                    response: error.response,
                    type: DioExceptionType.unknown,
                    error: reason == TokenRefreshFailureReason.transientFailure
                        ? const NetworkException(
                            'Session refresh temporarily unavailable. Please retry.',
                          )
                        : const UnknownException(
                            'Session refresh failed unexpectedly.',
                          ),
                  ),
                );
                return;
              }
            }

            handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                response: error.response,
                type: DioExceptionType.badResponse,
                error: AuthenticationException.fromDioError(error),
              ),
            );
          } else if (statusCode == 403) {
            handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                response: error.response,
                type: DioExceptionType.badResponse,
                error: AuthorizationException.fromDioError(error),
              ),
            );
          } else if (statusCode == 404) {
            handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                response: error.response,
                type: DioExceptionType.badResponse,
                error: NotFoundException.fromDioError(error),
              ),
            );
          } else if (statusCode == 409) {
            // Debug 409 errors
            logger.AppLogger.debug('=== Dio Client 409 Error ===');
            logger.AppLogger.debug('Response data: ${error.response?.data}');
            final conflictError = ConflictException.fromDioError(error);
            logger.AppLogger.debug(
              'ConflictException message: ${conflictError.message}',
            );
            logger.AppLogger.debug('============================');

            handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                response: error.response,
                type: DioExceptionType.badResponse,
                error: conflictError,
              ),
            );
          } else if (statusCode == 422) {
            // Debug 422 errors
            logger.AppLogger.debug('=== Dio Client 422 Error ===');
            logger.AppLogger.debug('Response data: ${error.response?.data}');
            final validationError = ValidationException.fromDioError(error);
            logger.AppLogger.debug(
              'ValidationException message: ${validationError.message}',
            );
            logger.AppLogger.debug(
              'ValidationException fieldErrors: ${validationError.fieldErrors}',
            );
            logger.AppLogger.debug('============================');

            handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                response: error.response,
                type: DioExceptionType.badResponse,
                error: validationError,
              ),
            );
          } else {
            handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                response: error.response,
                type: DioExceptionType.badResponse,
                error: ServerException.fromDioError(error),
              ),
            );
          }
        } else {
          handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              type: DioExceptionType.unknown,
              error: const UnknownException('Unknown error occurred'),
            ),
          );
        }
        break;
      default:
        handler.reject(
          DioException(
            requestOptions: error.requestOptions,
            type: DioExceptionType.unknown,
            error: NetworkException.fromDioError(error),
          ),
        );
    }
  }

  // Token refresh methods
  Future<TokenRefreshResult> refreshSessionToken() async {
    final completer = _refreshCompleter;
    if (completer != null && !completer.isCompleted) {
      logger.AppLogger.debug(
        '[AUTH]  Token refresh already in progress, waiting...',
      );
      return completer.future;
    }

    logger.AppLogger.debug('[AUTH]  Starting new token refresh...');
    _refreshCompleter = Completer<TokenRefreshResult>();
    final currentCompleter = _refreshCompleter!;

    try {
      final refreshToken = await _secureStorage.read(
        key: config.AppConstants.refreshTokenKey,
      );
      if (refreshToken == null || refreshToken.isEmpty) {
        logger.AppLogger.debug('[AUTH] ?No refresh token found in storage');
        const result = TokenRefreshResult.failure(
          TokenRefreshFailureReason.invalidSession,
        );
        currentCompleter.complete(result);
        return result;
      }

      logger.AppLogger.debug('[AUTH]  Sending refresh token request...');
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
            // Use UTC time to avoid timezone issues
            final expiryTime = DateTime.now().toUtc().add(
              Duration(seconds: expiresInSeconds),
            );
            await _secureStorage.write(
              key: config.AppConstants.tokenExpiryKey,
              value: expiryTime.toIso8601String(),
            );
            logger.AppLogger.debug(
              '[AUTH] ✅ Saved UTC token expiry: $expiryTime',
            );
          }

          // Check if server provided expires_at (UTC)
          final expiresAt = responseData['expires_at'] as String?;
          if (expiresAt != null && expiresAt.isNotEmpty) {
            await _secureStorage.write(
              key: config.AppConstants.tokenExpiryKey,
              value: expiresAt,  // Server already provides ISO format with timezone
            );
            logger.AppLogger.debug(
              '[AUTH] ✅ Saved server UTC token expiry: $expiresAt',
            );
          }

          logger.AppLogger.debug(
            '[AUTH] ?Token refresh successful - New token: ${newAccessToken.substring(0, 20)}...',
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
        '[AUTH] ?Token refresh failed: invalid response format',
      );
      const result = TokenRefreshResult.failure(
        TokenRefreshFailureReason.unknownFailure,
      );
      currentCompleter.complete(result);
      return result;
    } catch (e) {
      logger.AppLogger.debug('[AUTH] ?Token refresh failed: $e');
      final result = _buildRefreshFailureResult(e);
      currentCompleter.complete(result);
      return result;
    } finally {
      _refreshCompleter = null;
    }
  }

  TokenRefreshResult _buildRefreshFailureResult(Object error) {
    if (error is DioException) {
      logger.AppLogger.debug(
        '[AUTH]  Refresh failure status=${error.response?.statusCode} type=${error.type} response=${error.response?.data}',
      );
      return TokenRefreshResult.failure(classifyRefreshFailure(error));
    }
    return const TokenRefreshResult.failure(
      TokenRefreshFailureReason.unknownFailure,
    );
  }

  @visibleForTesting
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

  @visibleForTesting
  static bool shouldClearTokensForRefreshFailure(
    TokenRefreshFailureReason reason,
  ) {
    return reason == TokenRefreshFailureReason.invalidSession;
  }

  Future<Response> _retryRequest(RequestOptions options, String token) async {
    // Create a new headers map, removing any existing Authorization header (case-insensitive)
    // and adding the new one with the correct token
    final newHeaders = Map<String, dynamic>.from(options.headers);
    newHeaders.removeWhere(
      (key, value) => key.toLowerCase() == 'authorization',
    );
    newHeaders['Authorization'] = 'Bearer $token';

    // Use copyWith to create a new RequestOptions with updated headers
    final newOptions = options.copyWith(headers: newHeaders);

    logger.AppLogger.debug(
      '[AUTH]  Retrying ${options.method} ${options.path} with new token: ${token.substring(0, 20)}...',
    );
    logger.AppLogger.debug('   Query: ${newOptions.queryParameters}');
    logger.AppLogger.debug('   Data: ${newOptions.data}');

    try {
      final response = await _dio.fetch(newOptions);
      logger.AppLogger.debug(
        '[AUTH] ?Retry successful: ${response.statusCode}',
      );
      return response;
    } catch (e) {
      logger.AppLogger.debug('[AUTH] ?Retry failed: $e');
      rethrow;
    }
  }

  Future<void> _clearTokens() async {
    await _secureStorage.delete(key: config.AppConstants.accessTokenKey);
    await _secureStorage.delete(key: config.AppConstants.refreshTokenKey);
    await _secureStorage.delete(key: config.AppConstants.tokenExpiryKey);
    await _secureStorage.delete(key: config.AppConstants.userProfileKey);
    logger.AppLogger.debug(
      '[AUTH]  [DioClient] Tokens cleared, user will need to re-login',
    );

    // Notify auth state listeners that tokens were cleared
    AuthEventNotifier.instance.notify(
      AuthEvent(
        type: AuthEventType.tokenCleared,
        message: 'Tokens cleared due to authentication failure',
      ),
    );
  }

  // HTTP methods
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Duration? maxStale,
    CachePolicy? cachePolicy,
  }) async {
    final useDioCache = maxStale != null || cachePolicy != null;
    final cacheOptions = CacheOptions(
      store: _cacheStore,
      policy: useDioCache
          ? (cachePolicy ?? CachePolicy.request)
          : CachePolicy.noCache,
      maxStale: maxStale ?? const Duration(days: 7),
      priority: CachePriority.high,
      cipher: null,
      keyBuilder: CacheOptions.defaultCacheKeyBuilder,
      allowPostMethod: false,
    );
    final options = cacheOptions.toOptions();
    final extra = <String, dynamic>{
      ...(options.extra ?? const <String, dynamic>{}),
      if (useDioCache) 'etag_skip': true,
    };
    options.extra = extra;
    return _dio.get(path, queryParameters: queryParameters, options: options);
  }

  Future<Response> post(
    String path, {
    dynamic data,
    bool invalidateCache = false,
  }) async {
    final options = Options();

    // Invalidate cache for POST mutations (e.g., creating/updating resources)
    if (invalidateCache) {
      options.extra = {
        ...(options.extra ?? const <String, dynamic>{}),
        ..._mutationCacheInvalidateExtra(),
      };
    }

    return _dio.post(path, data: data, options: options);
  }

  Future<Response> put(
    String path, {
    dynamic data,
    bool invalidateCache = true,
  }) async {
    final options = Options();

    // Always invalidate cache for PUT updates
    if (invalidateCache) {
      options.extra = {
        ...(options.extra ?? const <String, dynamic>{}),
        ..._mutationCacheInvalidateExtra(),
      };
    }

    return _dio.put(path, data: data, options: options);
  }

  Future<Response> delete(String path, {bool invalidateCache = true}) async {
    final options = Options();

    // Always invalidate cache for DELETE
    if (invalidateCache) {
      options.extra = {
        ...(options.extra ?? const <String, dynamic>{}),
        ..._mutationCacheInvalidateExtra(),
      };
    }

    return _dio.delete(path, options: options);
  }

  /// Clear all cached responses
  Future<void> clearCache() async {
    await _cacheStore.clean();
    logger.AppLogger.debug('?[DioClient] Cache cleared');
  }

  /// Clear ETag cache
  void clearETagCache() {
    _etagInterceptor.clearCache();
  }

  /// Clear ETag cache for specific key pattern
  void clearETagPattern(String pattern) {
    _etagInterceptor.clearPattern(pattern);
  }

  // Static factory method for ServiceLocator
  static Dio createDio({
    DioClientInitOptions initOptions = const DioClientInitOptions(),
  }) {
    return DioClient(initOptions: initOptions)._dio;
  }
}
