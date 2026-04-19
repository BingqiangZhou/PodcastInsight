import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// Import AppConfig and ApiConstants from the canonical config file
import 'package:personal_ai_assistant/core/app/config/app_config.dart' as config;
// Import ETag interceptor (now with integrated cache)
import 'package:personal_ai_assistant/core/network/etag_interceptor.dart';
import 'package:personal_ai_assistant/core/network/exceptions/network_exceptions.dart';
import 'package:personal_ai_assistant/core/network/retry_interceptor.dart';
import 'package:personal_ai_assistant/core/network/token_refresh_service.dart';
import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;
import 'package:personal_ai_assistant/core/utils/url_normalizer.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef SavedServerBaseUrlLoader = Future<String?> Function();

/// Options for configuring retry behavior on network failures.
@immutable
class RetryOptions {

  const RetryOptions({
    this.maxRetries = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.backoffMultiplier = 2.0,
  });
  /// Maximum number of retry attempts for transient failures.
  final int maxRetries;

  /// Initial delay before the first retry.
  final Duration initialDelay;

  /// Multiplier for exponential backoff (e.g., 2.0 = delay doubles each retry).
  final double backoffMultiplier;

  /// Calculate delay for a given retry attempt (0-indexed).
  Duration getDelay(int attempt) {
    final delayMs = initialDelay.inMilliseconds * pow(backoffMultiplier, attempt);
    return Duration(milliseconds: delayMs.round());
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RetryOptions &&
        other.maxRetries == maxRetries &&
        other.initialDelay == initialDelay &&
        other.backoffMultiplier == backoffMultiplier;
  }

  @override
  int get hashCode => Object.hash(maxRetries, initialDelay, backoffMultiplier);
}

double pow(double base, int exponent) {
  if (exponent == 0) return 1.0;
  var result = 1.0;
  for (var i = 0; i < exponent; i++) {
    result *= base;
  }
  return result;
}

@immutable
class DioClientInitOptions {

  const DioClientInitOptions({
    this.applySavedBaseUrlOnInit = false,
    this.initialServerBaseUrl,
    this.savedBaseUrlLoader,
    this.retryOptions = const RetryOptions(),
  });
  final bool applySavedBaseUrlOnInit;
  final String? initialServerBaseUrl;
  final SavedServerBaseUrlLoader? savedBaseUrlLoader;
  final RetryOptions retryOptions;
}

/// Simplified HTTP client using Dio.
///
/// Features:
/// - ETag-based caching (via ETagInterceptor)
/// - Token refresh (via TokenRefreshService)
/// - Automatic base URL management
/// - Error handling with typed exceptions
/// - Request cancellation support
class DioClient {

  DioClient({DioClientInitOptions initOptions = const DioClientInitOptions()})
    : _initOptions = initOptions,
      _retryOptions = initOptions.retryOptions {
    // Initialize ETag interceptor
    _etagInterceptor = ETagInterceptor();

    // Initialize with default/empty baseUrl first.
    // The actual baseUrl is set by _initializeBaseUrl().
    _dio = Dio(
      BaseOptions(
        headers: config.ApiConstants.headers,
        connectTimeout: config.AppConfig.connectionTimeout,
        receiveTimeout: config.AppConfig.receiveTimeout,
        sendTimeout: config.AppConfig.sendTimeout,
      ),
    );

    // Initialize token refresh service
    _tokenRefreshService = TokenRefreshService(dio: _dio);

    // Add ETag interceptor FIRST
    _dio.interceptors.add(_etagInterceptor);

    // Add main interceptors
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onResponse: _onResponse,
        onError: _onError,
      ),
    );

    // Add retry interceptor after main interceptor
    _dio.interceptors.add(RetryInterceptor(dio: _dio, options: _retryOptions));

    // Apply base URL synchronously before returning.
    _initializeBaseUrl(initialServerBaseUrl: _initOptions.initialServerBaseUrl);

    if (_initOptions.applySavedBaseUrlOnInit) {
      unawaited(initializeFromStorage());
    }
  }
  final DioClientInitOptions _initOptions;
  late final Dio _dio;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  late final TokenRefreshService _tokenRefreshService;

  // ETag interceptor
  late final ETagInterceptor _etagInterceptor;

  // Request cancellation support
  final Map<String, CancelToken> _cancelTokens = {};

  // Retry options (passed to RetryInterceptor)
  final RetryOptions _retryOptions;

  // In-memory token cache to avoid secure storage I/O on every request
  String? _cachedAccessToken;

  // Request deduplication: maps GET request keys to their in-flight futures (NW-M3)
  final Map<String, Completer<Response>> _inFlightRequests = {};

  // Storage key for custom backend server base URL
  static const String _serverBaseUrlKey = 'server_base_url';
  static const String _etagInvalidateAfterWriteKey =
      'etag_invalidate_after_write';

  /// Initialize baseUrl from saved storage or default config
  void _initializeBaseUrl({String? initialServerBaseUrl}) {
    var savedBaseUrl =
        initialServerBaseUrl ?? config.AppConfig.serverBaseUrl;

    // Normalize URL: remove trailing slashes and API prefix
    if (savedBaseUrl.isNotEmpty) {
      savedBaseUrl = UrlNormalizer.normalize(savedBaseUrl);
    }

    // No trailing slash — Retrofit paths start with '/', so trailing slash
    // would produce double slashes when Dio concatenates baseUrl + path.
    final apiBaseUrl = savedBaseUrl.isNotEmpty
        ? '$savedBaseUrl/api/v1'
        : '${config.AppConfig.serverBaseUrl}/api/v1';

    _dio.options.baseUrl = apiBaseUrl;
    if (kDebugMode) {
      logger.AppLogger.debug(
        ' [DioClient] Initialized with baseUrl: $apiBaseUrl',
      );
    }
  }

  Dio get dio => _dio;

  /// Update the base URL dynamically
  void updateBaseUrl(String newBaseUrl) {
    _dio.options.baseUrl = newBaseUrl;
    if (kDebugMode) {
      logger.AppLogger.debug(' [DioClient] Base URL updated to: $newBaseUrl');
    }
  }

  /// Get the current base URL
  String get currentBaseUrl => _dio.options.baseUrl;

  /// Apply saved baseUrl from local storage
  Future<void> initializeFromStorage() async {
    await _applySavedBaseUrl();
  }

  Future<void> _applySavedBaseUrl() async {
    try {
      final loader = _initOptions.savedBaseUrlLoader;
      final savedUrl = await (loader != null
          ? loader()
          : _loadSavedBaseUrlFromSharedPrefs());
      if (savedUrl != null && savedUrl.isNotEmpty) {
        final normalizedUrl = UrlNormalizer.normalize(savedUrl);
        // No trailing slash — Retrofit paths start with '/', concatenation
        // produces the correct URL without double slashes.
        updateBaseUrl('$normalizedUrl/api/v1');
        if (kDebugMode) {
          logger.AppLogger.debug(
            ' [DioClient] Applied saved backend API baseUrl: $savedUrl',
          );
        }
      }
    } catch (e) {
      final message = e.toString();
      if (message.contains('Binding has not yet been initialized')) {
        return;
      }
      if (kDebugMode) {
        logger.AppLogger.debug(' [DioClient] Failed to apply saved baseUrl: $e');
      }
    }
  }

  Future<String?> _loadSavedBaseUrlFromSharedPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_serverBaseUrlKey);
    } catch (e) {
      if (e.toString().contains('Binding has not yet been initialized')) {
        return null;
      }
      rethrow;
    }
  }

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (kDebugMode) {
      final fullUrl = '${_dio.options.baseUrl}${options.path}';
      logger.AppLogger.debug(' [API REQUEST] ${options.method} $fullUrl');
      if (options.data != null) {
        logger.AppLogger.debug('   Data: ${options.data}');
      }
      if (options.queryParameters.isNotEmpty) {
        logger.AppLogger.debug('   Query: ${options.queryParameters}');
      }
    }

    // Only add token if not already set
    if (!options.headers.containsKey('Authorization')) {
      // Use in-memory cache first to avoid slow platform channel calls
      var token = _cachedAccessToken;

      if (token == null) {
        // Cache miss: fall back to secure storage and cache the result
        try {
          token = await _secureStorage.read(
            key: config.AppConstants.accessTokenKey,
          );
        } on PlatformException catch (e) {
          logger.AppLogger.warning('[AUTH] read token failed: ${e.message}');
        }
        if (token != null) {
          _cachedAccessToken = token;
          if (kDebugMode) {
            logger.AppLogger.debug(
              '[AUTH] Token loaded from secure storage and cached',
            );
          }
        }
      } else {
        if (kDebugMode) {
          logger.AppLogger.debug(
            '[AUTH] Token served from in-memory cache',
          );
        }
      }

      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
        if (kDebugMode) {
          logger.AppLogger.debug(
            '[AUTH] Token added: ${token.substring(0, 20)}...',
          );
        }
      } else {
        if (kDebugMode) {
          logger.AppLogger.debug(
            '[AUTH] No token found - skipping auth, will return 401 if protected route',
          );
        }
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
      if (kDebugMode) {
        logger.AppLogger.debug(
          ' [DioClient] Cleared ETag cache after ${response.requestOptions.method} ${response.requestOptions.path}',
        );
      }
    }

    // Debug subscriptions list response shape
    if (kDebugMode) {
      if (response.requestOptions.path == '/podcasts/subscriptions') {
        final data = response.data;
        if (data is Map) {
          logger.AppLogger.debug(
            '?? [Subscriptions Response] keys=${data.keys.toList()} '
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
    return {_etagInvalidateAfterWriteKey: true};
  }

  Future<void> _onError(DioException error, ErrorInterceptorHandler handler) async {
    if (kDebugMode) {
      final errorUrl =
          '${error.requestOptions.baseUrl}${error.requestOptions.path}';
      logger.AppLogger.debug(
        '[API ERROR] ${error.requestOptions.method} $errorUrl',
      );
      logger.AppLogger.debug('   Type: ${error.type}');
      logger.AppLogger.debug('   Message: ${error.message}');
    }

    // Retry logic is handled by RetryInterceptor (added in constructor).
    // This handler only classifies errors.

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        if (kDebugMode) {
          logger.AppLogger.debug('    Timeout Error');
        }
        handler.reject(
          DioException(
            requestOptions: error.requestOptions,
            error: const NetworkException('Connection timeout'),
          ),
        );
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode != null) {
          if (statusCode == 401) {
            await _handle401Error(error, handler);
            return;
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
            if (kDebugMode) {
              logger.AppLogger.debug('=== Dio Client 409 Error ===');
              logger.AppLogger.debug('Response data: ${error.response?.data}');
            }
            final conflictError = ConflictException.fromDioError(error);
            if (kDebugMode) {
              logger.AppLogger.debug(
                'ConflictException message: ${conflictError.message}',
              );
              logger.AppLogger.debug('============================');
            }
            handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                response: error.response,
                type: DioExceptionType.badResponse,
                error: conflictError,
              ),
            );
          } else if (statusCode == 422) {
            if (kDebugMode) {
              logger.AppLogger.debug('=== Dio Client 422 Error ===');
              logger.AppLogger.debug('Response data: ${error.response?.data}');
            }
            final validationError = ValidationException.fromDioError(error);
            if (kDebugMode) {
              logger.AppLogger.debug(
                'ValidationException message: ${validationError.message}',
              );
              logger.AppLogger.debug(
                'ValidationException fieldErrors: ${validationError.fieldErrors}',
              );
              logger.AppLogger.debug('============================');
            }
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
              error: const UnknownException('Unknown error occurred'),
            ),
          );
        }
      default:
        handler.reject(
          DioException(
            requestOptions: error.requestOptions,
            error: NetworkException.fromDioError(error),
          ),
        );
    }
  }

  Future<void> _handle401Error(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    if (kDebugMode) {
      logger.AppLogger.debug(
        '[AUTH] ?401 Error: ${error.requestOptions.method} ${error.requestOptions.path}',
      );
      logger.AppLogger.debug('   Response: ${error.response?.data}');
    }

    // Check if this is a refresh token request to avoid infinite loop
    final isRefreshRequest = error.requestOptions.path.contains('/auth/refresh');

    if (!isRefreshRequest) {
      final refreshResult = await _tokenRefreshService.refreshToken();
      final newAccessToken = refreshResult.accessToken;
      if (refreshResult.success && newAccessToken != null) {
        // Update in-memory cache with the refreshed token
        _cachedAccessToken = newAccessToken;
        try {
          final response = await _retryRequest(
            error.requestOptions,
            newAccessToken,
          );
          if (kDebugMode) {
            logger.AppLogger.debug(
              '[AUTH] refresh_reason=none should_clear_tokens=false retry_result=success',
            );
          }
          handler.resolve(response);
          return;
        } on DioException catch (retryError) {
          if (retryError.response?.statusCode == 401) {
            if (kDebugMode) {
              logger.AppLogger.debug(
                '[AUTH] ?Retry still returns 401; treat as authorization/resource issue',
              );
              logger.AppLogger.debug(
                '[AUTH] refresh_reason=none should_clear_tokens=false retry_result=still_401',
              );
            }
            handler.reject(retryError);
            return;
          }
          if (kDebugMode) {
            logger.AppLogger.debug(
              '[AUTH]  Retry failed with status: ${retryError.response?.statusCode}',
            );
            logger.AppLogger.debug(
              '[AUTH] refresh_reason=none should_clear_tokens=false retry_result=failed_status_${retryError.response?.statusCode}',
            );
          }
          handler.reject(retryError);
          return;
        } catch (e) {
          if (kDebugMode) {
            logger.AppLogger.debug('?Unexpected error during retry: $e');
            logger.AppLogger.debug(
              '[AUTH] refresh_reason=none should_clear_tokens=false retry_result=unexpected_error',
            );
          }
          handler.reject(error);
          return;
        }
      } else {
        final reason =
            refreshResult.reason ?? TokenRefreshFailureReason.unknownFailure;
        final shouldClearTokens =
            TokenRefreshService.shouldClearTokensForRefreshFailure(reason);
        if (kDebugMode) {
          logger.AppLogger.debug(
            '[AUTH] refresh_reason=${reason.name} should_clear_tokens=$shouldClearTokens retry_result=not_attempted',
          );
        }

        if (shouldClearTokens) {
          if (kDebugMode) {
            logger.AppLogger.debug(
              '[AUTH] ?Token refresh failed due to invalid session, clearing tokens',
            );
          }
          _cachedAccessToken = null;
          await _tokenRefreshService.clearTokens();
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

        if (kDebugMode) {
          logger.AppLogger.debug(
            '[AUTH]  Token refresh failed transiently; keeping tokens',
          );
        }
        handler.reject(
          DioException(
            requestOptions: error.requestOptions,
            response: error.response,
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
  }

  Future<Response> _retryRequest(RequestOptions options, String token) async {
    final newHeaders = Map<String, dynamic>.from(options.headers);
    newHeaders.removeWhere(
      (key, value) => key.toLowerCase() == 'authorization',
    );
    newHeaders['Authorization'] = 'Bearer $token';

    final newOptions = options.copyWith(headers: newHeaders);

    if (kDebugMode) {
      logger.AppLogger.debug(
        '[AUTH]  Retrying ${options.method} ${options.path} with new token: ${token.substring(0, 20)}...',
      );
      logger.AppLogger.debug('   Query: ${newOptions.queryParameters}');
      logger.AppLogger.debug('   Data: ${newOptions.data}');
    }

    try {
      final response = await _dio.fetch(newOptions);
      if (kDebugMode) {
        logger.AppLogger.debug(
          '[AUTH] ?Retry successful: ${response.statusCode}',
        );
      }
      return response;
    } catch (e) {
      if (kDebugMode) {
        logger.AppLogger.debug('[AUTH] ?Retry failed: $e');
      }
      rethrow;
    }
  }

  // HTTP methods

  /// GET request with automatic deduplication of concurrent identical requests.
  ///
  /// If an identical GET request is already in-flight, this method will wait
  /// for its response instead of sending a duplicate request. (NW-M3)
  Future<Response> getDeduplicated(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    final dedupKey = 'GET:$path:$queryParameters';

    // If an identical request is already in-flight, reuse its result
    if (_inFlightRequests.containsKey(dedupKey)) {
      return _inFlightRequests[dedupKey]!.future;
    }

    final completer = Completer<Response>();
    _inFlightRequests[dedupKey] = completer;

    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );
      completer.complete(response);
      return response;
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _inFlightRequests.remove(dedupKey);
    }
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(
    String path, {
    dynamic data,
    bool invalidateCache = false,
  }) async {
    final options = Options();

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

    if (invalidateCache) {
      options.extra = {
        ...(options.extra ?? const <String, dynamic>{}),
        ..._mutationCacheInvalidateExtra(),
      };
    }

    return _dio.delete(path, options: options);
  }

  // Cache management

  /// Clear all caches (ETag)
  Future<void> clearCache() async {
    _etagInterceptor.clearCache();
    if (kDebugMode) {
      logger.AppLogger.debug('[DioClient] All caches cleared');
    }
  }

  /// Clear ETag cache
  void clearETagCache() {
    _etagInterceptor.clearCache();
  }

  /// Clear ETag cache for specific key pattern
  void clearETagPattern(String pattern) {
    _etagInterceptor.clearPattern(pattern);
  }

  /// Get ETag cache statistics
  Map<String, dynamic> getETagStats() {
    return _etagInterceptor.getStats();
  }

  // Token management (delegates to TokenRefreshService)

  /// Refresh the session token
  Future<TokenRefreshResult> refreshSessionToken() {
    return _tokenRefreshService.refreshToken();
  }

  /// Clear the in-memory access token cache.
  ///
  /// Should be called on logout to ensure the next request does not use
  /// a stale cached token. The secure storage fallback is still available
  /// for robustness, but the cache will be empty until a fresh token is
  /// read or refreshed.
  void clearTokenCache() {
    _cachedAccessToken = null;
    if (kDebugMode) {
      logger.AppLogger.debug('[DioClient] In-memory token cache cleared');
    }
  }

  /// Update the in-memory token cache with a new access token.
  ///
  /// Call this after login or when a token is saved externally so that the
  /// next request uses the cached token instead of hitting SecureStorage
  /// (which requires a platform-channel round-trip).
  void setToken(String? token) {
    _cachedAccessToken = token;
    if (kDebugMode) {
      logger.AppLogger.debug(
        '[DioClient] In-memory token cache ${token != null ? "updated" : "cleared"}',
      );
    }
  }

  // Request cancellation support

  /// Create a CancelToken for a tagged request
  CancelToken createCancelToken(String tag) {
    // Cancel any existing request with the same tag
    cancelRequest(tag);
    final token = CancelToken();
    _cancelTokens[tag] = token;
    return token;
  }

  /// Cancel a request by its tag
  void cancelRequest(String tag, [String? reason]) {
    final token = _cancelTokens.remove(tag);
    if (token != null && !token.isCancelled) {
      token.cancel(reason ?? 'Request cancelled by client');
      if (kDebugMode) {
        logger.AppLogger.debug('[DioClient] Cancelled request: $tag');
      }
    }
  }

  /// Cancel all pending requests
  void cancelAllRequests([String? reason]) {
    for (final entry in _cancelTokens.entries) {
      if (!entry.value.isCancelled) {
        entry.value.cancel(reason ?? 'All requests cancelled by client');
      }
    }
    _cancelTokens.clear();
    if (kDebugMode) {
      logger.AppLogger.debug('[DioClient] Cancelled all pending requests');
    }
  }

  /// Remove a completed request's token
  void removeCancelToken(String tag) {
    _cancelTokens.remove(tag);
  }

  /// Check if a request is cancelled
  bool isRequestCancelled(String tag) {
    return _cancelTokens[tag]?.isCancelled ?? true;
  }

  /// Release all resources held by this client.
  ///
  /// Cancels pending requests, clears caches, and releases in-flight
  /// deduplicated request entries. Call from a Riverpod `ref.onDispose`
  /// callback so that provider disposal does not leak resources.
  void dispose() {
    cancelAllRequests('DioClient disposed');
    clearETagCache();
    clearTokenCache();
    for (final completer in _inFlightRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(
          DioException(
            requestOptions: RequestOptions(),
            type: DioExceptionType.cancel,
            error: 'Client disposed',
          ),
        );
      }
    }
    _inFlightRequests.clear();
    _dio.close(force: true);
    logger.AppLogger.debug('[DioClient] Disposed — all resources released');
  }

  // Static factory method for ServiceLocator
  static Dio createDio({
    DioClientInitOptions initOptions = const DioClientInitOptions(),
  }) {
    return DioClient(initOptions: initOptions)._dio;
  }
}
