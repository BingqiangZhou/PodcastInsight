import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:personal_ai_assistant/core/app/config/app_config.dart' as config;
import 'package:personal_ai_assistant/core/network/exceptions/network_exceptions.dart';
import 'package:personal_ai_assistant/core/network/token_refresh_service.dart';
import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;
import 'package:personal_ai_assistant/core/utils/url_normalizer.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef SavedServerBaseUrlLoader = Future<String?> Function();

@immutable
class DioClientInitOptions {
  const DioClientInitOptions({
    this.applySavedBaseUrlOnInit = false,
    this.initialServerBaseUrl,
    this.savedBaseUrlLoader,
  });
  final bool applySavedBaseUrlOnInit;
  final String? initialServerBaseUrl;
  final SavedServerBaseUrlLoader? savedBaseUrlLoader;
}

class DioClient {
  static const int _maxRetries = 3;

  DioClient({DioClientInitOptions initOptions = const DioClientInitOptions()})
    : _initOptions = initOptions {
    _dio = Dio(BaseOptions(
      headers: config.ApiConstants.headers,
      connectTimeout: config.AppConfig.connectionTimeout,
      receiveTimeout: config.AppConfig.receiveTimeout,
      sendTimeout: config.AppConfig.sendTimeout,
    ));
    _tokenRefreshService = TokenRefreshService(dio: _dio);
    _cacheOptions = CacheOptions(
      store: MemCacheStore(),
      policy: CachePolicy.refreshForceCache,
      maxStale: const Duration(hours: 1),
      hitCacheOnErrorCodes: [500],
    );
    _dio.interceptors.addAll([
      DioCacheInterceptor(options: _cacheOptions),
      InterceptorsWrapper(onRequest: _onRequest, onError: _onError),
    ]);
    _initializeBaseUrl(initialServerBaseUrl: _initOptions.initialServerBaseUrl);
    if (_initOptions.applySavedBaseUrlOnInit) {
      unawaited(initializeFromStorage());
    }
  }

  final DioClientInitOptions _initOptions;
  late final Dio _dio;
  late final TokenRefreshService _tokenRefreshService;
  late final CacheOptions _cacheOptions;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, Future<Response>> _inFlightRequests = {};
  String? _cachedAccessToken;
  static const String _serverBaseUrlKey = 'server_base_url';

  // --- Public API ---------------------------------------------------------

  Dio get dio => _dio;
  String get currentBaseUrl => _dio.options.baseUrl;

  void updateBaseUrl(String url) {
    _dio.options.baseUrl = url;
    _log('Base URL updated to: $url');
  }

  Future<void> initializeFromStorage() async {
    try {
      final loader = _initOptions.savedBaseUrlLoader;
      final savedUrl = await (loader != null
          ? loader()
          : _loadSavedBaseUrlFromSharedPrefs());
      if (savedUrl != null && savedUrl.isNotEmpty) {
        updateBaseUrl('${UrlNormalizer.normalize(savedUrl)}/api/v1');
      }
    } catch (e) {
      if (!e.toString().contains('Binding has not yet been initialized')) {
        _log('Failed to apply saved baseUrl: $e');
      }
    }
  }

  // HTTP methods
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) =>
      _dio.get(path, queryParameters: queryParameters);

  Future<Response> getDeduplicated(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    final key = 'GET:$path:$queryParameters';
    return _inFlightRequests.putIfAbsent(
      key,
      () => _dio
          .get(path, queryParameters: queryParameters, options: options)
          .whenComplete(() => _inFlightRequests.remove(key)),
    );
  }

  Future<Response> post(String path, {dynamic data, bool invalidateCache = false}) =>
      _dio.post(path, data: data, options: _cacheOpts(invalidateCache));

  Future<Response> put(String path, {dynamic data, bool invalidateCache = true}) =>
      _dio.put(path, data: data, options: _cacheOpts(invalidateCache));

  Future<Response> delete(String path, {bool invalidateCache = true}) =>
      _dio.delete(path, options: _cacheOpts(invalidateCache));

  // Cache & token management
  Future<void> clearCache() async {
    await _cacheOptions.store!.clean();
    _log('All caches cleared');
  }
  void clearETagCache() => clearCache();
  Future<TokenRefreshResult> refreshSessionToken() =>
      _tokenRefreshService.refreshToken();
  void clearTokenCache() {
    _cachedAccessToken = null;
    _log('In-memory token cache cleared');
  }
  void setToken(String? token) {
    _cachedAccessToken = token;
    _log('Token cache ${token != null ? "updated" : "cleared"}');
  }

  // Request cancellation
  CancelToken createCancelToken(String tag) {
    cancelRequest(tag);
    final token = CancelToken();
    _cancelTokens[tag] = token;
    return token;
  }
  void cancelRequest(String tag, [String? reason]) {
    final token = _cancelTokens.remove(tag);
    if (token != null && !token.isCancelled) {
      token.cancel(reason ?? 'Request cancelled by client');
    }
  }
  void cancelAllRequests([String? reason]) {
    for (final t in _cancelTokens.values) {
      if (!t.isCancelled) t.cancel(reason ?? 'All requests cancelled');
    }
    _cancelTokens.clear();
  }
  void removeCancelToken(String tag) => _cancelTokens.remove(tag);
  bool isRequestCancelled(String tag) =>
      _cancelTokens[tag]?.isCancelled ?? true;
  void dispose() {
    cancelAllRequests('DioClient disposed');
    clearTokenCache();
    _inFlightRequests.clear();
    _dio.close(force: true);
    logger.AppLogger.debug('[DioClient] Disposed');
  }

  // --- Interceptors -------------------------------------------------------

  Future<void> _onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    _log('${options.method} ${options.baseUrl}${options.path}');
    if (options.headers.containsKey('Authorization')) {
      handler.next(options);
      return;
    }
    var token = _cachedAccessToken;
    if (token == null) {
      try {
        token = await _secureStorage.read(key: config.AppConstants.accessTokenKey);
      } on PlatformException catch (e) {
        logger.AppLogger.warning('[AUTH] read token failed: ${e.message}');
      }
      if (token != null) _cachedAccessToken = token;
    }
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  Future<void> _onError(DioException err, ErrorInterceptorHandler handler) async {
    _log('ERROR ${err.type} ${err.requestOptions.path}');
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        final count = (err.requestOptions.extra['_retryCount'] as int? ?? 0) + 1;
        if (count <= _maxRetries) {
          try {
            await Future.delayed(Duration(seconds: count));
            final response = await _dio.fetch(err.requestOptions.copyWith(
              extra: {...err.requestOptions.extra, '_retryCount': count},
            ));
            handler.resolve(response);
            return;
          } catch (_) { /* fall through */ }
        }
        handler.reject(DioException(
          requestOptions: err.requestOptions,
          error: const NetworkException('Connection timeout'),
        ));
      case DioExceptionType.badResponse:
        final status = err.response?.statusCode;
        if (status == 401) {
          await _handle401(err, handler);
        } else if (status == 403) {
          handler.reject(DioException(
            requestOptions: err.requestOptions,
            response: err.response,
            type: DioExceptionType.badResponse,
            error: AuthException.fromDioError(err),
          ));
        } else {
          handler.reject(DioException(
            requestOptions: err.requestOptions,
            response: err.response,
            type: DioExceptionType.badResponse,
            error: ServerException.fromDioError(err),
          ));
        }
      default:
        handler.reject(DioException(
          requestOptions: err.requestOptions,
          error: NetworkException.fromDioError(err),
        ));
    }
  }

  Future<void> _handle401(DioException err, ErrorInterceptorHandler handler) async {
    try {
      final response = await _tokenRefreshService.handle401(
        err.requestOptions,
        onTokenUpdated: (t) => _cachedAccessToken = t,
      );
      handler.resolve(response);
    } on DioException catch (e) {
      handler.reject(DioException(
        requestOptions: e.requestOptions,
        response: e.response ?? err.response,
        type: DioExceptionType.badResponse,
        error: AuthException.fromDioError(err),
      ));
    } catch (_) {
      handler.reject(DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        error: const NetworkException('Session refresh temporarily unavailable.'),
      ));
    }
  }

  // --- Private helpers ----------------------------------------------------

  void _initializeBaseUrl({String? initialServerBaseUrl}) {
    final raw = initialServerBaseUrl ?? config.AppConfig.serverBaseUrl;
    final normalized = raw.isNotEmpty ? UrlNormalizer.normalize(raw) : '';
    final base = normalized.isNotEmpty
        ? '$normalized/api/v1'
        : '${config.AppConfig.serverBaseUrl}/api/v1';
    _dio.options.baseUrl = base;
    _log('Initialized with baseUrl: $base');
  }

  Future<String?> _loadSavedBaseUrlFromSharedPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_serverBaseUrlKey);
    } catch (e) {
      if (e.toString().contains('Binding has not yet been initialized')) return null;
      rethrow;
    }
  }

  Options? _cacheOpts(bool invalidate) {
    if (!invalidate) return null;
    return Options(
      extra: {'cacheOptions': _cacheOptions.copyWith(policy: CachePolicy.refresh)},
    );
  }

  void _log(String message) {
    if (kDebugMode) logger.AppLogger.debug('[DioClient] $message');
  }
}
