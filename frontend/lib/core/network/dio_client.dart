import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:meta/meta.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import ETag interceptor (now with integrated cache)
import 'etag_interceptor.dart';
import 'token_refresh_service.dart';

// Import AppConfig and ApiConstants from the canonical config file
import '../../core/app/config/app_config.dart' as config;
import 'exceptions/network_exceptions.dart';
import '../utils/app_logger.dart' as logger;

/// Normalizes API responses to handle inconsistent response shapes.
///
/// This addresses the backend inconsistency where list endpoints may return
/// data under either 'items' or 'subscriptions' keys.
///
/// Expected normalized shape for list responses:
/// ```json
/// {
///   "items": [...],      // Standardized list key
///   "total": 123,        // Total count (when paginated)
///   "page": 1,           // Current page (when paginated)
///   "size": 20           // Page size (when paginated)
/// }
/// ```
///
/// Example backend responses that need normalization:
/// ```json
/// // Subscriptions endpoint - uses 'subscriptions' key
/// {"subscriptions": [...], "total": 10}
///
/// // Other endpoints - use 'items' key
/// {"items": [...], "total": 50}
/// ```
@immutable
class ApiResponseNormalizer {
  /// Normalize a response data map to use consistent field names.
  ///
  /// This handles cases where the backend returns 'subscriptions' instead
  /// of 'items' for list endpoints.
  static Map<String, dynamic> normalize(dynamic data) {
    if (data == null) {
      return {};
    }

    if (data is! Map) {
      return data is List ? {'items': data} : {'data': data};
    }

    final map = Map<String, dynamic>.from(data);

    // Normalize 'subscriptions' to 'items' for consistency
    if (map.containsKey('subscriptions') && !map.containsKey('items')) {
      final normalized = Map<String, dynamic>.from(map);
      normalized['items'] = normalized.remove('subscriptions');
      logger.AppLogger.debug(
        '[ApiResponseNormalizer] Normalized "subscriptions" -> "items"',
      );
      return normalized;
    }

    // Ensure 'items' exists for list responses
    if (!map.containsKey('items') && map.containsKey('total')) {
      // Has 'total' but no 'items' - likely a list response
      final normalized = Map<String, dynamic>.from(map);
      // Find the list value
      for (final key in map.keys) {
        if (map[key] is List) {
          normalized['items'] = normalized.remove(key);
          logger.AppLogger.debug(
            '[ApiResponseNormalizer] Normalized "$key" -> "items"',
          );
          break;
        }
      }
      return normalized;
    }

    return map;
  }

  /// Extract the items list from a normalized response.
  static List<T> extractItems<T>(dynamic data) {
    final normalized = normalize(data);
    final items = normalized['items'];

    if (items == null) {
      return [];
    }

    if (items is! List) {
      logger.AppLogger.warning(
        '[ApiResponseNormalizer] Expected "items" to be a List, got ${items.runtimeType}',
      );
      return [];
    }

    return items.cast<T>();
  }

  /// Extract total count from a normalized response.
  static int extractTotal(dynamic data, {int defaultValue = 0}) {
    final normalized = normalize(data);
    final total = normalized['total'];

    if (total == null) {
      return defaultValue;
    }

    if (total is int) {
      return total;
    }

    if (total is String) {
      return int.tryParse(total) ?? defaultValue;
    }

    return defaultValue;
  }

  /// Check if a response is a paginated list response.
  static bool isPaginatedResponse(dynamic data) {
    final normalized = normalize(data);
    return normalized.containsKey('items') && normalized.containsKey('total');
  }
}

typedef SavedServerBaseUrlLoader = Future<String?> Function();

/// Options for configuring retry behavior on network failures.
@immutable
class RetryOptions {
  /// Maximum number of retry attempts for transient failures.
  final int maxRetries;

  /// Initial delay before the first retry.
  final Duration initialDelay;

  /// Multiplier for exponential backoff (e.g., 2.0 = delay doubles each retry).
  final double backoffMultiplier;

  const RetryOptions({
    this.maxRetries = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.backoffMultiplier = 2.0,
  });

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
  double result = 1.0;
  for (int i = 0; i < exponent; i++) {
    result *= base;
  }
  return result;
}

@immutable
class DioClientInitOptions {
  final bool applySavedBaseUrlOnInit;
  final String? initialServerBaseUrl;
  final SavedServerBaseUrlLoader? savedBaseUrlLoader;
  final RetryOptions retryOptions;

  const DioClientInitOptions({
    this.applySavedBaseUrlOnInit = false,
    this.initialServerBaseUrl,
    this.savedBaseUrlLoader,
    this.retryOptions = const RetryOptions(),
  });
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
  final DioClientInitOptions _initOptions;
  late final Dio _dio;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  late final TokenRefreshService _tokenRefreshService;

  // ETag interceptor
  late final ETagInterceptor _etagInterceptor;

  // Request cancellation support
  final Map<String, CancelToken> _cancelTokens = {};

  // Retry options
  final RetryOptions _retryOptions;

  // In-memory token cache to avoid secure storage I/O on every request
  String? _cachedAccessToken;

  // Retry tracking for in-flight requests
  final Map<String, int> _retryAttempts = {};

  // Storage key for custom backend server base URL
  static const String _serverBaseUrlKey = 'server_base_url';
  static const String _etagInvalidateAfterWriteKey =
      'etag_invalidate_after_write';

  DioClient({DioClientInitOptions initOptions = const DioClientInitOptions()})
    : _initOptions = initOptions,
      _retryOptions = initOptions.retryOptions {
    // Initialize ETag interceptor
    _etagInterceptor = ETagInterceptor();

    // Initialize with default/empty baseUrl first.
    // The actual baseUrl is set by _initializeBaseUrl().
    _dio = Dio(
      BaseOptions(
        baseUrl: '',
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

    // Apply base URL synchronously before returning.
    _initializeBaseUrl(initialServerBaseUrl: _initOptions.initialServerBaseUrl);

    if (_initOptions.applySavedBaseUrlOnInit) {
      unawaited(initializeFromStorage());
    }
  }

  /// Initialize baseUrl from saved storage or default config
  void _initializeBaseUrl({String? initialServerBaseUrl}) {
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

    // Add trailing slash to prevent double slash when Retrofit paths start with '/'
    final apiBaseUrl = savedBaseUrl.isNotEmpty
        ? '$savedBaseUrl/api/v1/'
        : '${config.AppConfig.serverBaseUrl}/api/v1/';

    _dio.options.baseUrl = apiBaseUrl;
    logger.AppLogger.debug(
      ' [DioClient] Initialized with baseUrl: $apiBaseUrl',
    );
  }

  Dio get dio => _dio;

  /// Update the base URL dynamically
  void updateBaseUrl(String newBaseUrl) {
    _dio.options.baseUrl = newBaseUrl;
    logger.AppLogger.debug(' [DioClient] Base URL updated to: $newBaseUrl');
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
        var normalizedUrl = savedUrl.trim();
        while (normalizedUrl.endsWith('/')) {
          normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1);
        }
        if (normalizedUrl.endsWith('/api/v1')) {
          normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 7);
        } else if (normalizedUrl.contains('/api/v1/')) {
          normalizedUrl = normalizedUrl.replaceFirst('/api/v1/', '/');
        }
        // Add trailing slash to prevent double slash when Retrofit paths start with '/'
        updateBaseUrl('$normalizedUrl/api/v1/');
        logger.AppLogger.debug(
          ' [DioClient] Applied saved backend API baseUrl: $savedUrl',
        );
      }
    } catch (e) {
      final message = e.toString();
      if (message.contains('Binding has not yet been initialized')) {
        return;
      }
      logger.AppLogger.debug(' [DioClient] Failed to apply saved baseUrl: $e');
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
    final fullUrl = '${_dio.options.baseUrl}/${options.path}';
    logger.AppLogger.debug(' [API REQUEST] ${options.method} $fullUrl');
    if (options.data != null) {
      logger.AppLogger.debug('   Data: ${options.data}');
    }
    if (options.queryParameters.isNotEmpty) {
      logger.AppLogger.debug('   Query: ${options.queryParameters}');
    }

    // Only add token if not already set
    if (!options.headers.containsKey('Authorization')) {
      // Use in-memory cache first to avoid slow platform channel calls
      String? token = _cachedAccessToken;

      if (token == null) {
        // Cache miss: fall back to secure storage and cache the result
        token = await _secureStorage.read(
          key: config.AppConstants.accessTokenKey,
        );
        if (token != null) {
          _cachedAccessToken = token;
          logger.AppLogger.debug(
            '[AUTH] Token loaded from secure storage and cached',
          );
        }
      } else {
        logger.AppLogger.debug(
          '[AUTH] Token served from in-memory cache',
        );
      }

      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
        logger.AppLogger.debug(
          '[AUTH] Token added: ${token.substring(0, 20)}...',
        );
      } else {
        logger.AppLogger.debug(
          '[AUTH] No token found - skipping auth, will return 401 if protected route',
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

    // Normalize response data for consistent API response handling
    final originalData = response.data;
    final normalizedData = ApiResponseNormalizer.normalize(originalData);

    // Only update if normalization changed the structure
    if (normalizedData != originalData) {
      response.data = normalizedData;
      logger.AppLogger.debug(
        '[ApiResponseNormalizer] Normalized response for ${response.requestOptions.path}',
      );
    }

    // Debug subscriptions list response shape
    if (response.requestOptions.path == '/subscriptions/podcasts') {
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

  void _onError(DioException error, ErrorInterceptorHandler handler) async {
    final errorUrl =
        '${error.requestOptions.baseUrl}/${error.requestOptions.path}';
    logger.AppLogger.debug(
      '[API ERROR] ${error.requestOptions.method} $errorUrl',
    );
    logger.AppLogger.debug('   Type: ${error.type}');
    logger.AppLogger.debug('   Message: ${error.message}');

    // Check if we should retry this request
    final retryKey = _getRetryKey(error.requestOptions);
    final currentAttempt = _retryAttempts[retryKey] ?? 0;

    if (_shouldRetry(error, currentAttempt)) {
      final nextAttempt = currentAttempt + 1;
      _retryAttempts[retryKey] = nextAttempt;

      final delay = _retryOptions.getDelay(currentAttempt);
      logger.AppLogger.debug(
        '[RETRY] Attempt $nextAttempt/${_retryOptions.maxRetries} '
        'after ${delay.inMilliseconds}ms',
      );

      // Wait before retrying
      await Future.delayed(delay);

      try {
        final response = await _dio.fetch(error.requestOptions);
        // Success - remove retry tracking
        _retryAttempts.remove(retryKey);
        logger.AppLogger.debug(
          '[RETRY] Success on attempt $nextAttempt',
        );
        handler.resolve(response);
        return;
      } on DioException catch (retryError) {
        // Retry failed, will be handled by this interceptor again
        logger.AppLogger.debug(
          '[RETRY] Attempt $nextAttempt failed: ${retryError.type}',
        );
        // Continue to normal error handling below
      }
    } else if (currentAttempt > 0) {
      // Exhausted retries or non-retryable error after retries
      _retryAttempts.remove(retryKey);
      if (currentAttempt >= _retryOptions.maxRetries) {
        logger.AppLogger.debug(
          '[RETRY] Exhausted $currentAttempt attempts, giving up',
        );
      }
    }

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

  Future<void> _handle401Error(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    logger.AppLogger.debug(
      '[AUTH] ?401 Error: ${error.requestOptions.method} ${error.requestOptions.path}',
    );
    logger.AppLogger.debug('   Response: ${error.response?.data}');

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
          logger.AppLogger.debug(
            '[AUTH] refresh_reason=none should_clear_tokens=false retry_result=success',
          );
          handler.resolve(response);
          return;
        } on DioException catch (retryError) {
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
          logger.AppLogger.debug(
            '[AUTH]  Retry failed with status: ${retryError.response?.statusCode}',
          );
          logger.AppLogger.debug(
            '[AUTH] refresh_reason=none should_clear_tokens=false retry_result=failed_status_${retryError.response?.statusCode}',
          );
          handler.reject(retryError);
          return;
        } catch (e) {
          logger.AppLogger.debug('?Unexpected error during retry: $e');
          logger.AppLogger.debug(
            '[AUTH] refresh_reason=none should_clear_tokens=false retry_result=unexpected_error',
          );
          handler.reject(error);
          return;
        }
      } else {
        final reason =
            refreshResult.reason ?? TokenRefreshFailureReason.unknownFailure;
        final shouldClearTokens =
            TokenRefreshService.shouldClearTokensForRefreshFailure(reason);
        logger.AppLogger.debug(
          '[AUTH] refresh_reason=${reason.name} should_clear_tokens=$shouldClearTokens retry_result=not_attempted',
        );

        if (shouldClearTokens) {
          logger.AppLogger.debug(
            '[AUTH] ?Token refresh failed due to invalid session, clearing tokens',
          );
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
  }

  Future<Response> _retryRequest(RequestOptions options, String token) async {
    final newHeaders = Map<String, dynamic>.from(options.headers);
    newHeaders.removeWhere(
      (key, value) => key.toLowerCase() == 'authorization',
    );
    newHeaders['Authorization'] = 'Bearer $token';

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

  // HTTP methods

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
    logger.AppLogger.debug('[DioClient] All caches cleared');
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
    logger.AppLogger.debug('[DioClient] In-memory token cache cleared');
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
      logger.AppLogger.debug('[DioClient] Cancelled request: $tag');
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
    logger.AppLogger.debug('[DioClient] Cancelled all pending requests');
  }

  /// Remove a completed request's token
  void removeCancelToken(String tag) {
    _cancelTokens.remove(tag);
  }

  /// Check if a request is cancelled
  bool isRequestCancelled(String tag) {
    return _cancelTokens[tag]?.isCancelled ?? true;
  }

  // Retry support methods

  /// Generate a unique key for tracking retry attempts.
  String _getRetryKey(RequestOptions options) {
    return '${options.method}:${options.path}:${options.queryParameters.toString()}';
  }

  /// Determine if an error should trigger a retry.
  bool _shouldRetry(DioException error, int currentAttempt) {
    // Check if we've exceeded max retries
    if (currentAttempt >= _retryOptions.maxRetries) {
      return false;
    }

    // Only retry on transient failures
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        // Retry on timeout
        return true;
      case DioExceptionType.connectionError:
        // Retry on connection failure
        return true;
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode != null) {
          // Retry on 5xx server errors
          if (statusCode >= 500 && statusCode < 600) {
            return true;
          }
          // Retry on 429 Too Many Requests
          if (statusCode == 429) {
            return true;
          }
        }
        // Don't retry on 4xx client errors (except 429)
        return false;
      case DioExceptionType.cancel:
        // Don't retry cancelled requests
        return false;
      case DioExceptionType.badCertificate:
        // Don't retry on certificate errors
        return false;
      case DioExceptionType.unknown:
        // Check if it's a network-related error
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

  // Static factory method for ServiceLocator
  static Dio createDio({
    DioClientInitOptions initOptions = const DioClientInitOptions(),
  }) {
    return DioClient(initOptions: initOptions)._dio;
  }
}
