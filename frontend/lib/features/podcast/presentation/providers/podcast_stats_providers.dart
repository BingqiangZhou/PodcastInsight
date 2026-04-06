import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;
import 'package:personal_ai_assistant/features/podcast/data/models/playback_history_lite_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_playback_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/profile_stats_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/repositories/podcast_repository.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/base/cached_async_notifier.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_core_providers.dart';

// === Stats Provider ===
final podcastStatsProvider =
    AsyncNotifierProvider<PodcastStatsNotifier, PodcastStatsResponse?>(
      PodcastStatsNotifier.new,
    );

class PodcastStatsNotifier extends CachedAsyncNotifier<PodcastStatsResponse?> {
  PodcastRepository get _repository => ref.read(podcastRepositoryProvider);

  @override
  FutureOr<PodcastStatsResponse?> build() {
    return load();
  }

  Future<PodcastStatsResponse?> load({bool forceRefresh = false}) async {
    final hasError = state.hasError;
    final isLoading = state.isLoading;

    final effectiveForce = forceRefresh || hasError || isLoading;
    return runWithCache(
      forceRefresh: effectiveForce,
      fetcher: () => _repository.getStats(),
      onError: (error, _) {
        logger.AppLogger.debug('Failed to load podcast stats: $error');
      },
    );
  }

  /// Reset the notifier state completely.
  void reset() {
    resetCache();
    state = const AsyncValue.data(null);
  }
}

final profileStatsProvider =
    AsyncNotifierProvider<ProfileStatsNotifier, ProfileStatsModel?>(
      ProfileStatsNotifier.new,
    );
class ProfileStatsNotifier extends CachedAsyncNotifier<ProfileStatsModel?> {
  PodcastRepository get _repository => ref.read(podcastRepositoryProvider);

  @override
  FutureOr<ProfileStatsModel?> build() async {
    return load();
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

final playbackHistoryProvider =
    AsyncNotifierProvider<PlaybackHistoryNotifier, PodcastEpisodeListResponse?>(
      PlaybackHistoryNotifier.new,
    );

class PlaybackHistoryNotifier
    extends CachedAsyncNotifier<PodcastEpisodeListResponse?> {
  PodcastRepository get _repository => ref.read(podcastRepositoryProvider);

  @override
  FutureOr<PodcastEpisodeListResponse?> build() {
    return load();
  }

  Future<PodcastEpisodeListResponse?> load({bool forceRefresh = false}) async {
    final hasError = state.hasError;
    final isLoading = state.isLoading;

    final effectiveForce = forceRefresh || hasError || isLoading;
    return runWithCache(
      forceRefresh: effectiveForce,
      fetcher: () => _repository.getPlaybackHistory(size: 100),
      onError: (error, _) {
        logger.AppLogger.debug('Failed to load playback history: $error');
      },
    );
  }

  /// Reset the notifier state completely.
  void reset() {
    resetCache();
    state = const AsyncValue.data(null);
  }
}

final playbackHistoryLiteProvider =
    AsyncNotifierProvider<
      PlaybackHistoryLiteNotifier,
      PlaybackHistoryLiteResponse?
    >(PlaybackHistoryLiteNotifier.new);
class PlaybackHistoryLiteNotifier
    extends CachedAsyncNotifier<PlaybackHistoryLiteResponse?> {
  PodcastRepository get _repository => ref.read(podcastRepositoryProvider);

  @override
  FutureOr<PlaybackHistoryLiteResponse?> build() async {
    return load();
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
      fetcher: () => _repository.getPlaybackHistoryLite(),
      onError: (error, _) {
        logger.AppLogger.debug('Failed to load playback history lite: $error');
      },
    );
  }
}
