import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;
import 'package:personal_ai_assistant/features/podcast/data/models/itunes_episode_lookup_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_search_model.dart';

/// iTunes Search Service.
///
/// Calls iTunes Search and Lookup APIs directly from frontend.
class ITunesSearchService {

  ITunesSearchService({Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options = BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
      validateStatus: (status) => status != null && status < 500,
    );
  }

  factory ITunesSearchService.ref() {
    return ITunesSearchService();
  }
  final Dio _dio;

  static const Duration _cacheExpiration = Duration(hours: 1);

  final Map<String, _CachedResponse> _cache = {};
  final Map<String, _CachedEpisodeSearchResponse> _episodeSearchCache = {};
  final Map<String, _CachedEpisodeLookupResponse> _episodeLookupCache = {};

  Future<ITunesSearchResponse> searchPodcasts({
    required String term,
    PodcastCountry country = PodcastCountry.china,
    int limit = 25,
  }) async {
    if (term.trim().isEmpty) {
      return const ITunesSearchResponse(resultCount: 0, results: []);
    }

    final safeLimit = _normalizeSearchLimit(limit);
    final cacheKey = 'search_${country.code}_$term${'_limit$safeLimit'}';
    final cachedResponse = _getCachedResponse(cacheKey);
    if (cachedResponse != null) {
      logger.AppLogger.debug('Cache hit for iTunes search: $term');
      return cachedResponse;
    }

    try {
      const url = 'https://itunes.apple.com/search';
      final response = await _dio.get(
        url,
        queryParameters: {
          'term': term,
          'media': 'podcast',
          'entity': 'podcast',
          'country': country.code,
          'limit': safeLimit,
        },
      );

      if (response.statusCode != 200) {
        throw Exception('iTunes API returned status ${response.statusCode}');
      }

      final data = _parseJsonMap(response.data);
      final parsed = ITunesSearchResponse.fromJson(data);
      _setCachedResponse(cacheKey, parsed);
      return parsed;
    } on DioException catch (dioError) {
      String errorMsg;
      switch (dioError.type) {
        case DioExceptionType.connectionTimeout:
          errorMsg =
              'Connection timeout. Please check your network or try using a VPN.';
        case DioExceptionType.sendTimeout:
          errorMsg = 'Send timeout. Please try again.';
        case DioExceptionType.receiveTimeout:
          errorMsg = 'Receive timeout. Server response too slow.';
        case DioExceptionType.badResponse:
          errorMsg = 'Server error: ${dioError.response?.statusCode}';
        case DioExceptionType.cancel:
          errorMsg = 'Request was cancelled.';
        case DioExceptionType.connectionError:
          errorMsg =
              'Connection failed. iTunes API may be blocked in your region. Try using a VPN.';
        default:
          errorMsg = 'Network error: ${dioError.message}';
      }
      throw Exception(errorMsg);
    } catch (error) {
      logger.AppLogger.debug('iTunes search failed: $error');
      rethrow;
    }
  }

  Future<List<ITunesPodcastEpisodeResult>> searchPodcastEpisodes({
    required String term,
    PodcastCountry country = PodcastCountry.china,
    int limit = 25,
  }) async {
    if (term.trim().isEmpty) {
      return const [];
    }

    final safeLimit = _normalizeSearchLimit(limit);
    final cacheKey =
        'search_episodes_${country.code}_$term${'_limit$safeLimit'}';
    final cached = _getCachedEpisodeSearchResponse(cacheKey);
    if (cached != null) {
      logger.AppLogger.debug('Cache hit for iTunes episode search: $term');
      return cached;
    }

    try {
      const url = 'https://itunes.apple.com/search';
      final response = await _dio.get(
        url,
        queryParameters: {
          'term': term,
          'media': 'podcast',
          'entity': 'podcastEpisode',
          'country': country.code,
          'limit': safeLimit,
        },
      );

      if (response.statusCode != 200) {
        throw Exception('iTunes API returned status ${response.statusCode}');
      }

      final data = _parseJsonMap(response.data);
      final results = (data['results'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ITunesPodcastEpisodeResult.fromJson)
          .where((episode) => episode.trackId > 0 && episode.trackName.isNotEmpty)
          .toList();
      _setCachedEpisodeSearchResponse(cacheKey, results);
      return results;
    } on DioException catch (dioError) {
      String errorMsg;
      switch (dioError.type) {
        case DioExceptionType.connectionTimeout:
          errorMsg =
              'Connection timeout. Please check your network or try using a VPN.';
        case DioExceptionType.sendTimeout:
          errorMsg = 'Send timeout. Please try again.';
        case DioExceptionType.receiveTimeout:
          errorMsg = 'Receive timeout. Server response too slow.';
        case DioExceptionType.badResponse:
          errorMsg = 'Server error: ${dioError.response?.statusCode}';
        case DioExceptionType.cancel:
          errorMsg = 'Request was cancelled.';
        case DioExceptionType.connectionError:
          errorMsg =
              'Connection failed. iTunes API may be blocked in your region. Try using a VPN.';
        default:
          errorMsg = 'Network error: ${dioError.message}';
      }
      throw Exception(errorMsg);
    } catch (error) {
      logger.AppLogger.debug('iTunes episode search failed: $error');
      rethrow;
    }
  }

  Future<PodcastSearchResult?> lookupPodcast({
    required int itunesId,
    PodcastCountry country = PodcastCountry.china,
  }) async {
    final cacheKey = 'lookup_${country.code}_$itunesId';
    final cachedResponse = _getCachedResponse(cacheKey);
    if (cachedResponse != null && cachedResponse.results.isNotEmpty) {
      logger.AppLogger.debug('Cache hit for iTunes lookup: $itunesId');
      return cachedResponse.results.first;
    }

    try {
      final response = await _dio.get(
        'https://itunes.apple.com/lookup',
        queryParameters: {'id': itunesId, 'country': country.code},
      );

      if (response.statusCode != 200) {
        throw Exception('iTunes API returned status ${response.statusCode}');
      }

      final data = _parseJsonMap(response.data);
      final parsed = ITunesSearchResponse.fromJson(data);
      if (parsed.results.isEmpty) {
        return null;
      }

      _setCachedResponse(cacheKey, parsed);
      return parsed.results.first;
    } catch (error) {
      logger.AppLogger.debug('iTunes lookup failed: $error');
      rethrow;
    }
  }

  Future<ITunesPodcastLookupResult> lookupPodcastEpisodes({
    required int showId,
    PodcastCountry country = PodcastCountry.china,
    int limit = 50,
  }) async {
    final safeLimit = _normalizeLookupLimit(limit);
    final cacheKey = 'lookup_episodes_${country.code}_${showId}_$safeLimit';
    final cached = _getCachedEpisodeLookupResponse(cacheKey);
    if (cached != null) {
      logger.AppLogger.debug('Cache hit for iTunes episode lookup: $showId');
      return cached;
    }

    try {
      final response = await _dio.get(
        'https://itunes.apple.com/lookup',
        queryParameters: {
          'id': showId,
          'entity': 'podcastEpisode',
          'country': country.code,
          'limit': safeLimit,
        },
      );

      if (response.statusCode != 200) {
        throw Exception('iTunes API returned status ${response.statusCode}');
      }

      final data = _parseJsonMap(response.data);
      final lookup = ITunesPodcastLookupResult.fromLookupJson(
        data,
        showId: showId,
      );
      _setCachedEpisodeLookupResponse(cacheKey, lookup);
      return lookup;
    } catch (error) {
      logger.AppLogger.debug('iTunes episode lookup failed: $error');
      rethrow;
    }
  }

  Future<ITunesPodcastEpisodeResult?> findEpisodeInLookup({
    required int showId,
    required int episodeTrackId,
    PodcastCountry country = PodcastCountry.china,
    int limit = 50,
  }) async {
    final lookup = await lookupPodcastEpisodes(
      showId: showId,
      country: country,
      limit: limit,
    );
    return lookup.findEpisodeByTrackId(episodeTrackId);
  }

  int? extractShowIdFromApplePodcastUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return null;
    }

    final match = RegExp(r'id(\d+)').firstMatch(uri.path);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1) ?? '');
  }

  int? extractEpisodeIdFromApplePodcastUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return null;
    }

    final queryValue = uri.queryParameters['i'];
    if (queryValue != null && queryValue.isNotEmpty) {
      return int.tryParse(queryValue);
    }

    final match = RegExp(r'[?&]i=(\d+)').firstMatch(url);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1) ?? '');
  }

  ITunesSearchResponse? _getCachedResponse(String key) {
    final cached = _cache[key];
    if (cached != null && !cached.isExpired) {
      return cached.response;
    }
    _cache.remove(key);
    return null;
  }

  void _setCachedResponse(String key, ITunesSearchResponse response) {
    _cache[key] = _CachedResponse(
      response: response,
      timestamp: DateTime.now(),
    );
  }

  List<ITunesPodcastEpisodeResult>? _getCachedEpisodeSearchResponse(String key) {
    final cached = _episodeSearchCache[key];
    if (cached != null && !cached.isExpired) {
      return cached.results;
    }
    _episodeSearchCache.remove(key);
    return null;
  }

  void _setCachedEpisodeSearchResponse(
    String key,
    List<ITunesPodcastEpisodeResult> results,
  ) {
    _episodeSearchCache[key] = _CachedEpisodeSearchResponse(
      results: results,
      timestamp: DateTime.now(),
    );
  }

  ITunesPodcastLookupResult? _getCachedEpisodeLookupResponse(String key) {
    final cached = _episodeLookupCache[key];
    if (cached != null && !cached.isExpired) {
      return cached.response;
    }
    _episodeLookupCache.remove(key);
    return null;
  }

  void _setCachedEpisodeLookupResponse(
    String key,
    ITunesPodcastLookupResult response,
  ) {
    _episodeLookupCache[key] = _CachedEpisodeLookupResponse(
      response: response,
      timestamp: DateTime.now(),
    );
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
    throw Exception('Unexpected response type: ${data.runtimeType}');
  }

  int _normalizeSearchLimit(int limit) {
    if (limit < 1 || limit > 50) {
      return 25;
    }
    return limit;
  }

  int _normalizeLookupLimit(int limit) {
    if (limit < 1) {
      return 1;
    }
    if (limit > 200) {
      return 200;
    }
    return limit;
  }

  void clearCache() {
    _cache.clear();
    _episodeSearchCache.clear();
    _episodeLookupCache.clear();
    logger.AppLogger.debug('iTunes search cache cleared');
  }

  void clearExpiredCache() {
    final now = DateTime.now();
    _cache.removeWhere(
      (_, cached) => now.difference(cached.timestamp) > _cacheExpiration,
    );
    _episodeSearchCache.removeWhere(
      (_, cached) => now.difference(cached.timestamp) > _cacheExpiration,
    );
    _episodeLookupCache.removeWhere(
      (_, cached) => now.difference(cached.timestamp) > _cacheExpiration,
    );
  }
}

class _CachedResponse {
  _CachedResponse({required this.response, required this.timestamp});

  final ITunesSearchResponse response;
  final DateTime timestamp;

  bool get isExpired {
    return DateTime.now().difference(timestamp) >
        ITunesSearchService._cacheExpiration;
  }
}

class _CachedEpisodeLookupResponse {
  _CachedEpisodeLookupResponse({
    required this.response,
    required this.timestamp,
  });

  final ITunesPodcastLookupResult response;
  final DateTime timestamp;

  bool get isExpired {
    return DateTime.now().difference(timestamp) >
        ITunesSearchService._cacheExpiration;
  }
}

class _CachedEpisodeSearchResponse {
  _CachedEpisodeSearchResponse({required this.results, required this.timestamp});

  final List<ITunesPodcastEpisodeResult> results;
  final DateTime timestamp;

  bool get isExpired {
    return DateTime.now().difference(timestamp) >
        ITunesSearchService._cacheExpiration;
  }
}
