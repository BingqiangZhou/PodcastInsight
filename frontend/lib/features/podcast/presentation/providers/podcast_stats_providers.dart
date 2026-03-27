import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/cache_constants.dart';
import '../../../../core/utils/app_logger.dart' as logger;
import '../../data/models/playback_history_lite_model.dart';
import '../../data/models/podcast_episode_model.dart';
import '../../data/models/podcast_playback_model.dart';
import '../../data/models/profile_stats_model.dart';
import '../../data/repositories/podcast_repository.dart';
import 'base/cached_async_notifier.dart';
import 'podcast_core_providers.dart';

// === Stats Provider ===
final podcastStatsProvider = FutureProvider.autoDispose<PodcastStatsResponse?>((ref) async {
  final repository = ref.read(podcastRepositoryProvider);
  try {
    return await repository.getStats();
  } catch (error) {
    return null;
  }
});

final profileStatsProvider =
    AsyncNotifierProvider<ProfileStatsNotifier, ProfileStatsModel?>(
      ProfileStatsNotifier.new,
    );
class ProfileStatsNotifier extends CachedAsyncNotifier<ProfileStatsModel?> {
  late final PodcastRepository _repository;

  @override
  FutureOr<ProfileStatsModel?> build() async {
    _repository = ref.read(podcastRepositoryProvider);
    return load(forceRefresh: false);
  }

  /// Reset the notifier state completely.
  /// Called when switching servers or on login to ensure clean state.
  void reset() {
    resetCache();
    state = const AsyncValue.data(null);
  }

  Future<ProfileStatsModel?> load({bool forceRefresh = false}) async {
    final hasError = state.hasError;
    final isLoading = state.isLoading;

    // If has error or loading, skip cache check and continue to fetch
    final effectiveForce = forceRefresh || hasError || isLoading;
    return runWithCache(
      forceRefresh: effectiveForce,
      fetcher: () => _repository.getProfileStats(),
      onError: (error, _) {
        logger.AppLogger.debug('Failed to load profile stats: $error');
      },
    );
  }
}

final playbackHistoryProvider = FutureProvider.autoDispose<PodcastEpisodeListResponse?>((
  ref,
) async {
  final repository = ref.read(podcastRepositoryProvider);
  try {
    return await repository.getPlaybackHistory(page: 1, size: 100);
  } catch (error) {
    logger.AppLogger.debug('Failed to load playback history: $error');
    return null;
  }
});

final playbackHistoryLiteProvider =
    AsyncNotifierProvider<
      PlaybackHistoryLiteNotifier,
      PlaybackHistoryLiteResponse?
    >(PlaybackHistoryLiteNotifier.new);
class PlaybackHistoryLiteNotifier
    extends CachedAsyncNotifier<PlaybackHistoryLiteResponse?> {
  late final PodcastRepository _repository;

  @override
  FutureOr<PlaybackHistoryLiteResponse?> build() async {
    _repository = ref.read(podcastRepositoryProvider);
    return load(forceRefresh: false);
  }

  /// Reset the notifier state completely.
  /// Called when switching servers or on login to ensure clean state.
  void reset() {
    resetCache();
    state = const AsyncValue.data(null);
  }

  Future<PlaybackHistoryLiteResponse?> load({bool forceRefresh = false}) async {
    final hasError = state.hasError;
    final isLoading = state.isLoading;

    // If has error or loading, skip cache check and continue to fetch
    final effectiveForce = forceRefresh || hasError || isLoading;
    return runWithCache(
      forceRefresh: effectiveForce,
      fetcher: () => _repository.getPlaybackHistoryLite(page: 1, size: 100),
      onError: (error, _) {
        logger.AppLogger.debug('Failed to load playback history lite: $error');
      },
    );
  }
}
