import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/local_storage_service.dart';
import '../../../../core/utils/app_logger.dart' as logger;
import '../../data/models/podcast_episode_model.dart';
import '../../data/models/podcast_state_models.dart';
import '../../data/repositories/podcast_repository.dart';
import 'podcast_core_providers.dart';

// === Episode Detail Provider ===
final episodeDetailProvider =
    FutureProvider.family<PodcastEpisodeDetailResponse?, int>((
      ref,
      episodeId,
    ) async {
      final repository = ref.read(podcastRepositoryProvider);
      try {
        return await repository.getEpisode(episodeId);
      } catch (error) {
        logger.AppLogger.debug('Failed to load episode detail: $error');
        return null;
      }
    });

// For Riverpod 3.0.3, we need to use a different approach for family providers
// Let's use a simple Notifier and pass the subscriptionId through methods
final podcastEpisodesProvider =
    NotifierProvider<PodcastEpisodesNotifier, PodcastEpisodesState>(
      PodcastEpisodesNotifier.new,
    );

class PodcastEpisodesNotifier extends Notifier<PodcastEpisodesState> {
  late PodcastRepository _repository;
  static const Duration _episodesCacheExpiration = Duration(hours: 6);

  @override
  PodcastEpisodesState build() {
    _repository = ref.read(podcastRepositoryProvider);
    return const PodcastEpisodesState();
  }

  String _episodesCacheKey({
    required int subscriptionId,
    required String? status,
    required bool? hasSummary,
    required int size,
  }) {
    final effectiveStatus = status?.trim().isEmpty ?? true ? null : status;
    final effectiveHasSummary = hasSummary == true ? true : null;
    return 'podcast_episodes_v1_sub_${subscriptionId}_status_${effectiveStatus ?? "all"}_summary_${effectiveHasSummary == true ? "1" : "0"}_size_$size';
  }

  Future<PodcastEpisodeListResponse?> _loadEpisodesPage1FromCache({
    required int subscriptionId,
    required int size,
    required String? status,
    required bool? hasSummary,
  }) async {
    try {
      final storage = ref.read(localStorageServiceProvider);
      final cached = await storage.getCachedData<dynamic>(
        _episodesCacheKey(
          subscriptionId: subscriptionId,
          status: status,
          hasSummary: hasSummary,
          size: size,
        ),
      );
      if (cached is Map<String, dynamic>) {
        return PodcastEpisodeListResponse.fromJson(cached);
      }
    } catch (e) {
      logger.AppLogger.debug('[Episodes] Failed to read episodes from cache: $e');
    }
    return null;
  }

  // Load episodes for a specific subscription
  Future<void> loadEpisodesForSubscription({
    required int subscriptionId,
    int page = 1,
    int size = 20,
    String? status,
    bool? hasSummary,
    bool forceRefresh = false,
  }) async {
    final normalizedStatus = status?.trim().isEmpty ?? true ? null : status;
    final normalizedHasSummary = hasSummary == true ? true : null;

    // Check if data is fresh and skip refresh if not forced (only for first page)
    if (!forceRefresh &&
        page == 1 &&
        state.isDataFresh() &&
        state.cachedSubscriptionId == subscriptionId &&
        state.cachedStatus == normalizedStatus &&
        state.cachedHasSummary == normalizedHasSummary) {
      logger.AppLogger.debug(
        '[Playback] Using cached episode data for sub $subscriptionId (fresh within 5 min)',
      );
      return;
    }

    logger.AppLogger.debug(
      '[Playback] Loading episodes for subscription $subscriptionId, page $page',
    );

    if (page == 1) {
      final cacheKey = _episodesCacheKey(
        subscriptionId: subscriptionId,
        status: normalizedStatus,
        hasSummary: normalizedHasSummary,
        size: size,
      );
      final cachedResponse = forceRefresh
          ? null
          : await _loadEpisodesPage1FromCache(
              subscriptionId: subscriptionId,
              size: size,
              status: normalizedStatus,
              hasSummary: normalizedHasSummary,
            );

      final shouldClearImmediately =
          state.cachedSubscriptionId != subscriptionId ||
          state.cachedStatus != normalizedStatus ||
          state.cachedHasSummary != normalizedHasSummary;

      if (cachedResponse != null && cachedResponse.episodes.isNotEmpty) {
        state = state.copyWith(
          episodes: cachedResponse.episodes,
          hasMore: 1 < cachedResponse.pages,
          nextPage: 1 < cachedResponse.pages ? 2 : null,
          currentPage: 1,
          total: cachedResponse.total,
          isLoading: true,
          error: null,
          cachedSubscriptionId: subscriptionId,
          cachedStatus: normalizedStatus,
          cachedHasSummary: normalizedHasSummary,
        );
      } else {
        state = state.copyWith(
          isLoading: true,
          episodes: shouldClearImmediately ? [] : state.episodes,
          error: null,
        );
      }
      if (state.episodes.isEmpty) {
        logger.AppLogger.debug('[Playback] No cached episodes for $cacheKey');
      } else {
        logger.AppLogger.debug(
          '[Playback] Showing cached episodes first for $cacheKey',
        );
      }
    } else {
      state = state.copyWith(isLoading: true);
    }

    try {
      final response = await _repository.listEpisodes(
        subscriptionId: subscriptionId,
        page: page,
        size: size,
        hasSummary: normalizedHasSummary,
        isPlayed: normalizedStatus == 'played'
            ? true
            : (normalizedStatus == 'unplayed' ? false : null),
      );

      logger.AppLogger.debug(
        '[Playback] Loaded ${response.episodes.length} episodes for subscription $subscriptionId',
      );

      state = state.copyWith(
        episodes: page == 1
            ? response.episodes
            : [...state.episodes, ...response.episodes],
        hasMore: page < response.pages,
        nextPage: page < response.pages ? page + 1 : null,
        currentPage: page,
        total: response.total,
        isLoading: false,
        cachedSubscriptionId: subscriptionId,
        cachedStatus: normalizedStatus,
        cachedHasSummary: normalizedHasSummary,
        lastRefreshTime: DateTime.now(), // Record refresh time
      );
      logger.AppLogger.debug('[OK] Episode data loaded at ${DateTime.now()}');

      if (page == 1) {
        try {
          final storage = ref.read(localStorageServiceProvider);
          await storage.cacheData(
            _episodesCacheKey(
              subscriptionId: subscriptionId,
              status: normalizedStatus,
              hasSummary: normalizedHasSummary,
              size: size,
            ),
            response.toJson(),
            expiration: _episodesCacheExpiration,
          );
        } catch (e) {
          logger.AppLogger.debug('[Episodes] Failed to cache episodes: $e');
        }
      }
    } catch (error) {
      logger.AppLogger.debug('[Error] Failed to load episodes: $error');
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  // Load more episodes for the current subscription
  Future<void> loadMoreEpisodesForSubscription({
    required int subscriptionId,
    String? status,
    bool? hasSummary,
  }) async {
    final currentState = state;
    if (currentState.isLoadingMore || !currentState.hasMore) return;

    final normalizedStatus = status?.trim().isEmpty ?? true ? null : status;
    final effectiveStatus = normalizedStatus ?? currentState.cachedStatus;
    final normalizedHasSummary = hasSummary == true ? true : null;
    final effectiveHasSummary =
        normalizedHasSummary ?? currentState.cachedHasSummary;

    state = state.copyWith(isLoadingMore: true);

    try {
      final response = await _repository.listEpisodes(
        subscriptionId: subscriptionId,
        page: currentState.nextPage ?? 1,
        size: 20,
        hasSummary: effectiveHasSummary,
        isPlayed: effectiveStatus == 'played'
            ? true
            : (effectiveStatus == 'unplayed' ? false : null),
      );

      state = state.copyWith(
        episodes: [...state.episodes, ...response.episodes],
        hasMore: state.nextPage != null && state.nextPage! < response.pages,
        nextPage: state.nextPage != null && state.nextPage! < response.pages
            ? state.nextPage! + 1
            : null,
        isLoadingMore: false,
      );
    } catch (error) {
      state = state.copyWith(isLoadingMore: false, error: error.toString());
    }
  }

  // Refresh episodes for a specific subscription
  Future<void> refreshEpisodesForSubscription({
    required int subscriptionId,
    String? status,
    bool? hasSummary,
  }) async {
    state = const PodcastEpisodesState();
    await loadEpisodesForSubscription(
      subscriptionId: subscriptionId,
      status: status,
      hasSummary: hasSummary,
      forceRefresh: true, // Bypass 5-minute cache check on explicit refresh
    );
  }
}
