import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_discover_chart_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_search_model.dart';

class ApplePodcastRssService {
  ApplePodcastRssService({Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options = BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: const {'Content-Type': 'application/json'},
      validateStatus: (status) => status != null && status < 500,
    );
  }

  factory ApplePodcastRssService.ref() {
    return ApplePodcastRssService();
  }

  final Dio _dio;
  static const Duration _cacheTtl = Duration(minutes: 30);
  static const String _baseUrl = 'https://rss.marketingtools.apple.com/api/v2';
  final Map<String, _CachedChartResponse> _cache = {};

  Future<ApplePodcastChartResponse> fetchTopShows({
    required PodcastCountry country,
    int limit = 25,
    ApplePodcastRssFormat format = ApplePodcastRssFormat.json,
  }) {
    return _fetchChart(
      country: country,
      limit: limit,
      type: PodcastDiscoverKind.podcasts,
      format: format,
    );
  }

  Future<ApplePodcastChartResponse> fetchTopEpisodes({
    required PodcastCountry country,
    int limit = 25,
    ApplePodcastRssFormat format = ApplePodcastRssFormat.json,
  }) {
    return _fetchChart(
      country: country,
      limit: limit,
      type: PodcastDiscoverKind.podcastEpisodes,
      format: format,
    );
  }

  Future<String> fetchTopShowsRaw({
    required PodcastCountry country,
    int limit = 25,
    ApplePodcastRssFormat format = ApplePodcastRssFormat.rss,
  }) {
    return _fetchRawChart(
      country: country,
      limit: limit,
      type: PodcastDiscoverKind.podcasts,
      format: format,
    );
  }

  Future<String> fetchTopEpisodesRaw({
    required PodcastCountry country,
    int limit = 25,
    ApplePodcastRssFormat format = ApplePodcastRssFormat.rss,
  }) {
    return _fetchRawChart(
      country: country,
      limit: limit,
      type: PodcastDiscoverKind.podcastEpisodes,
      format: format,
    );
  }

  Future<ApplePodcastChartResponse> _fetchChart({
    required PodcastCountry country,
    required int limit,
    required PodcastDiscoverKind type,
    required ApplePodcastRssFormat format,
  }) async {
    final safeLimit = _normalizeLimit(limit);
    final cacheKey = _buildCacheKey(country, type, safeLimit, format);
    final cached = _getCachedResponse(cacheKey);
    if (cached != null) {
      return cached;
    }

    final url = _buildUrl(
      country: country,
      limit: safeLimit,
      type: type,
      format: format,
    );

    try {
      final response = await _dio.get(url);
      if (response.statusCode != 200) {
        throw Exception('Apple RSS API returned status ${response.statusCode}');
      }

      final data = _parseJsonMap(response.data);
      final parsed = ApplePodcastChartResponse.fromJson(data);
      _cache[cacheKey] = _CachedChartResponse(
        response: parsed,
        timestamp: DateTime.now(),
      );
      return parsed;
    } catch (error) {
      logger.AppLogger.debug('Apple RSS chart fetch failed: $error');
      rethrow;
    }
  }

  Future<String> _fetchRawChart({
    required PodcastCountry country,
    required int limit,
    required PodcastDiscoverKind type,
    required ApplePodcastRssFormat format,
  }) async {
    final safeLimit = _normalizeLimit(limit);
    final url = _buildUrl(
      country: country,
      limit: safeLimit,
      type: type,
      format: format,
    );

    final response = await _dio.get<String>(
      url,
      options: Options(responseType: ResponseType.plain),
    );

    if (response.statusCode != 200 || response.data == null) {
      throw Exception(
        'Apple RSS raw API returned status ${response.statusCode}',
      );
    }
    // At this point, response.data is guaranteed to be non-null
    return response.data!;
  }

  int _normalizeLimit(int limit) {
    if (limit <= 0) return 10;
    if (limit > 100) return 100;
    return limit;
  }

  String _buildCacheKey(
    PodcastCountry country,
    PodcastDiscoverKind type,
    int limit,
    ApplePodcastRssFormat format,
  ) {
    return '${country.code}_${type.value}_${limit}_${format.value}';
  }

  String _buildUrl({
    required PodcastCountry country,
    required int limit,
    required PodcastDiscoverKind type,
    required ApplePodcastRssFormat format,
  }) {
    return '$_baseUrl/${country.code}/podcasts/top/$limit/${type.value}.${format.value}';
  }

  Map<String, dynamic> _parseJsonMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    }
    throw const FormatException('Invalid Apple RSS JSON response');
  }

  ApplePodcastChartResponse? _getCachedResponse(String key) {
    final cached = _cache[key];
    if (cached == null) return null;
    if (DateTime.now().difference(cached.timestamp) > _cacheTtl) {
      _cache.remove(key);
      return null;
    }
    return cached.response;
  }

  void clearCache() {
    _cache.clear();
  }

  void clearExpiredCache() {
    final now = DateTime.now();
    _cache.removeWhere((_, item) => now.difference(item.timestamp) > _cacheTtl);
  }
}

class _CachedChartResponse {
  const _CachedChartResponse({required this.response, required this.timestamp});

  final ApplePodcastChartResponse response;
  final DateTime timestamp;
}
