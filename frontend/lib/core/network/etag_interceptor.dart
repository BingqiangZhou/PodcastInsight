import 'dart:collection';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;

/// Cache entry for ETag and response data.
/// Stores only the response data and headers (not the full Response object)
/// to reduce memory footprint.
class _ETagCacheEntry {

  _ETagCacheEntry({
    required this.etag,
    required this.data,
    required this.headers,
    required this.requestOptions,
    this.statusCode,
    this.statusMessage,
    this.maxAge,
  }) : timestamp = DateTime.now();
  final String etag;
  final dynamic data;
  final Headers headers;
  final int? statusCode;
  final String? statusMessage;
  final RequestOptions requestOptions;
  final DateTime timestamp;
  final Duration? maxAge;

  /// Reconstruct a Response from cached data.
  Response toResponse() {
    return Response(
      data: data,
      headers: headers,
      requestOptions: requestOptions,
      statusCode: statusCode,
      statusMessage: statusMessage,
    );
  }
}

/// ETag Interceptor with integrated cache for Dio.
///
/// This interceptor handles HTTP ETag caching by:
/// 1. Adding If-None-Match header to requests with cached ETags.
/// 2. Storing ETags from successful responses.
/// 3. Returning cached data on 304 Not Modified.
/// 4. Fast-serving fresh cached responses during max-age window.
///
/// The cache is integrated directly (no separate service) to:
/// - Reduce complexity and file count
/// - Avoid double-caching with DioCacheInterceptor
/// - Provide precise cache control for API calls
class ETagInterceptor extends Interceptor {

  /// Create ETag interceptor.
  ///
  /// [maxEntries] maximum number of cache entries (default 256).
  /// [defaultTtl] default time-to-live for cache entries (default 1 hour).
  /// [enabled] enable or disable ETag behavior.
  ETagInterceptor({
    int maxEntries = 256,
    Duration defaultTtl = const Duration(hours: 1),
    bool enabled = true,
  }) : _maxEntries = maxEntries,
       _defaultTtl = defaultTtl,
       _enabled = enabled;
  final LinkedHashMap<String, _ETagCacheEntry> _cache = LinkedHashMap();
  final int _maxEntries;
  final Duration _defaultTtl;
  final bool _enabled;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!_enabled) {
      handler.next(options);
      return;
    }

    if (options.extra['etag_skip'] == true) {
      handler.next(options);
      return;
    }

    if (options.method.toUpperCase() != 'GET') {
      handler.next(options);
      return;
    }

    final key = _generateKey(options);
    final freshCachedResponse = _getFreshCachedResponse(key);

    // Fast path: serve local cache directly when still inside max-age window.
    if (!_shouldForceRevalidate(options) && freshCachedResponse != null) {
      logger.AppLogger.debug('[ETag] Using fresh local cache for $key');
      handler.resolve(freshCachedResponse);
      return;
    }

    final etag = _getETag(key);
    if (etag != null && etag.isNotEmpty) {
      options.headers['If-None-Match'] = etag;
      logger.AppLogger.debug('[ETag] Adding If-None-Match: $etag for $key');
    }

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (!_enabled) {
      handler.next(response);
      return;
    }

    if (response.requestOptions.extra['etag_skip'] == true) {
      handler.next(response);
      return;
    }

    if (response.requestOptions.method.toUpperCase() != 'GET') {
      handler.next(response);
      return;
    }

    final etag = response.headers.value('etag');
    if (etag != null && etag.isNotEmpty) {
      final key = _generateKey(response.requestOptions);
      final maxAge = _extractMaxAge(response.headers.value('cache-control'));
      _setETag(key, etag, response, maxAge: maxAge);
      logger.AppLogger.debug('[ETag] Cached: $etag for $key');
    }

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (!_enabled) {
      handler.next(err);
      return;
    }

    if (err.requestOptions.extra['etag_skip'] == true) {
      handler.next(err);
      return;
    }

    if (err.response?.statusCode == 304) {
      final key = _generateKey(err.requestOptions);
      final cached = _getCachedResponse(key);

      if (cached != null) {
        final response = err.response;
        final headers = response?.headers;
        if (headers != null) {
          headers.forEach((name, values) {
            cached.headers.set(name, values);
          });
        }
        logger.AppLogger.debug('[ETag] Using cached response for $key (304)');
        handler.resolve(cached);
        return;
      }

      logger.AppLogger.warning(
        '[ETag] 304 received but no cached response for $key',
      );
    }

    handler.next(err);
  }

  // ============================================================
  // CACHE MANAGEMENT METHODS
  // ============================================================

  /// Clear all cached ETags and responses.
  void clearCache() {
    _cache.clear();
    logger.AppLogger.debug('[ETag] Cache cleared');
  }

  /// Clear cached ETag for specific key.
  void clearKey(String key) {
    _cache.remove(key);
    logger.AppLogger.debug('[ETag] Cleared key: $key');
  }

  /// Clear cached ETags matching a pattern.
  void clearPattern(String pattern) {
    _evictExpired();
    final regex = RegExp(pattern);
    _cache.removeWhere((key, _) => regex.hasMatch(key));
    logger.AppLogger.debug('[ETag] Cleared pattern: $pattern');
  }

  /// Get cache statistics.
  Map<String, dynamic> getStats() {
    _evictExpired();
    return {
      'enabled': _enabled,
      'cacheSize': _cache.length,
      'keys': _cache.keys.toList(),
    };
  }

  // ============================================================
  // PRIVATE CACHE METHODS
  // ============================================================

  Duration _entryTtl(_ETagCacheEntry entry) => entry.maxAge ?? _defaultTtl;

  bool _isExpired(_ETagCacheEntry entry) {
    final age = DateTime.now().difference(entry.timestamp);
    return age > _entryTtl(entry);
  }

  void _evictExpired() {
    final expiredKeys = <String>[];
    _cache.forEach((key, entry) {
      if (_isExpired(entry)) {
        expiredKeys.add(key);
      }
    });
    for (final key in expiredKeys) {
      _cache.remove(key);
    }
  }

  void _touch(String key, _ETagCacheEntry entry) {
    _cache.remove(key);
    _cache[key] = entry;
  }

  _ETagCacheEntry? _getValidEntry(String key) {
    final entry = _cache[key];
    if (entry == null) {
      return null;
    }
    if (_isExpired(entry)) {
      _cache.remove(key);
      return null;
    }
    _touch(key, entry);
    return entry;
  }

  String? _getETag(String key) => _getValidEntry(key)?.etag;

  Response? _getCachedResponse(String key) => _getValidEntry(key)?.toResponse();

  Response? _getFreshCachedResponse(String key) {
    final entry = _getValidEntry(key);
    if (entry == null) {
      return null;
    }

    final maxAge = entry.maxAge;
    if (maxAge == null || maxAge <= Duration.zero) {
      return null;
    }

    final age = DateTime.now().difference(entry.timestamp);
    if (age > maxAge) {
      _cache.remove(key);
      return null;
    }

    return entry.toResponse();
  }

  void _setETag(
    String key,
    String etag,
    Response response, {
    Duration? maxAge,
  }) {
    _evictExpired();
    _cache.remove(key);
    _cache[key] = _ETagCacheEntry(
      etag: etag,
      data: response.data,
      headers: response.headers,
      requestOptions: response.requestOptions,
      statusCode: response.statusCode,
      statusMessage: response.statusMessage,
      maxAge: maxAge,
    );
    while (_cache.length > _maxEntries) {
      _cache.remove(_cache.keys.first);
    }
  }

  /// Generate cache key from RequestOptions
  String _generateKey(RequestOptions options) {
    // Sort query parameters for consistent key generation
    final sortedParams = <String, dynamic>{};
    if (options.queryParameters.isNotEmpty) {
      final sortedKeys = options.queryParameters.keys.toList()..sort();
      for (final key in sortedKeys) {
        sortedParams[key] = options.queryParameters[key];
      }
    }

    // Create query string
    final queryString = sortedParams.entries
        .map((e) => '${e.key}=${_normalizeValue(e.value)}')
        .join('&');

    // Combine method, path, and query string
    return '${options.method}:${options.path}:$queryString';
  }

  /// Normalize query parameter value for consistent key generation
  String _normalizeValue(dynamic value) {
    if (value == null) return '';
    if (value is List || value is Map) {
      return jsonEncode(value);
    }
    return value.toString();
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================

  bool _shouldForceRevalidate(RequestOptions options) {
    if (options.extra['etag_force_revalidate'] == true) {
      return true;
    }

    final cacheControl = options.headers['Cache-Control']?.toString();
    if (cacheControl != null) {
      final lower = cacheControl.toLowerCase();
      if (lower.contains('no-cache') ||
          lower.contains('no-store') ||
          lower.contains('max-age=0')) {
        return true;
      }
    }

    final pragma = options.headers['Pragma']?.toString().toLowerCase();
    return pragma == 'no-cache';
  }

  Duration? _extractMaxAge(String? cacheControl) {
    if (cacheControl == null || cacheControl.isEmpty) {
      return null;
    }

    final directives = cacheControl
        .split(',')
        .map((entry) => entry.trim().toLowerCase())
        .where((entry) => entry.isNotEmpty)
        .toList();

    if (directives.contains('no-store')) {
      return null;
    }

    for (final directive in directives) {
      if (directive.startsWith('max-age=')) {
        final raw = directive.substring('max-age='.length);
        final seconds = int.tryParse(raw);
        if (seconds == null) {
          return null;
        }
        return Duration(seconds: seconds);
      }
    }

    return null;
  }
}
