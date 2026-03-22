import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_logger.dart' as logger;
import '../../data/models/playback_history_lite_model.dart';
import '../../data/models/podcast_episode_model.dart';
import '../../data/models/podcast_playback_model.dart';
import '../../data/models/profile_stats_model.dart';
import '../../data/repositories/podcast_repository.dart';
import 'podcast_core_providers.dart';

// === Stats Provider ===
final podcastStatsProvider = FutureProvider<PodcastStatsResponse?>((ref) async {
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
final profileStatsCacheDurationProvider = Provider<Duration>(
  (ref) => const Duration(minutes: 5),
);

class ProfileStatsNotifier extends AsyncNotifier<ProfileStatsModel?> {
  late final PodcastRepository _repository;
  DateTime? _lastLoadedAt;
  Future<ProfileStatsModel?>? _inFlightRequest;

  @override
  FutureOr<ProfileStatsModel?> build() async {
    _repository = ref.read(podcastRepositoryProvider);
    return load(forceRefresh: false);
  }

  bool _isFresh() {
    if (_lastLoadedAt == null) return false;
    final cacheDuration = ref.read(profileStatsCacheDurationProvider);
    return DateTime.now().difference(_lastLoadedAt!) < cacheDuration;
  }

  /// Reset the notifier state completely.
  /// Called when switching servers or on login to ensure clean state.
  void reset() {
    _lastLoadedAt = null;
    _inFlightRequest = null;
    state = const AsyncValue.data(null);
  }

  Future<ProfileStatsModel?> load({bool forceRefresh = false}) async {
    final hasError = state.hasError;
    final isLoading = state.isLoading;
    final previousData = state.value;

    // If has error or loading, skip cache check and continue to fetch
    if (!forceRefresh && !hasError && !isLoading && previousData != null && _isFresh()) {
      return previousData;
    }

    final inFlight = _inFlightRequest;
    if (inFlight != null) {
      return inFlight;
    }

    if (previousData == null) {
      state = const AsyncValue.loading();
    }

    final request = () async {
      try {
        final data = await _repository.getProfileStats();
        _lastLoadedAt = DateTime.now();
        state = AsyncValue.data(data);
        return data;
      } catch (error, stackTrace) {
        logger.AppLogger.debug('Failed to load profile stats: $error');
        if (previousData == null) {
          state = AsyncValue.error(error, stackTrace);
        } else {
          state = AsyncValue.data(previousData);
        }
        return previousData;
      } finally {
        _inFlightRequest = null;
      }
    }();

    _inFlightRequest = request;
    return request;
  }
}

final playbackHistoryProvider = FutureProvider<PodcastEpisodeListResponse?>((
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
final playbackHistoryLiteCacheDurationProvider = Provider<Duration>(
  (ref) => const Duration(minutes: 5),
);

class PlaybackHistoryLiteNotifier
    extends AsyncNotifier<PlaybackHistoryLiteResponse?> {
  late final PodcastRepository _repository;
  DateTime? _lastLoadedAt;
  Future<PlaybackHistoryLiteResponse?>? _inFlightRequest;

  @override
  FutureOr<PlaybackHistoryLiteResponse?> build() async {
    _repository = ref.read(podcastRepositoryProvider);
    return load(forceRefresh: false);
  }

  bool _isFresh() {
    if (_lastLoadedAt == null) return false;
    final cacheDuration = ref.read(playbackHistoryLiteCacheDurationProvider);
    return DateTime.now().difference(_lastLoadedAt!) < cacheDuration;
  }

  /// Reset the notifier state completely.
  /// Called when switching servers or on login to ensure clean state.
  void reset() {
    _lastLoadedAt = null;
    _inFlightRequest = null;
    state = const AsyncValue.data(null);
  }

  Future<PlaybackHistoryLiteResponse?> load({bool forceRefresh = false}) async {
    final hasError = state.hasError;
    final isLoading = state.isLoading;
    final previousData = state.value;

    // If has error or loading, skip cache check and continue to fetch
    if (!forceRefresh && !hasError && !isLoading && previousData != null && _isFresh()) {
      return previousData;
    }

    final inFlight = _inFlightRequest;
    if (inFlight != null) {
      return inFlight;
    }

    if (previousData == null) {
      state = const AsyncValue.loading();
    }

    final request = () async {
      try {
        final data = await _repository.getPlaybackHistoryLite(
          page: 1,
          size: 100,
        );
        _lastLoadedAt = DateTime.now();
        state = AsyncValue.data(data);
        return data;
      } catch (error, stackTrace) {
        logger.AppLogger.debug('Failed to load playback history lite: $error');
        if (previousData == null) {
          state = AsyncValue.error(error, stackTrace);
        } else {
          state = AsyncValue.data(previousData);
        }
        return previousData;
      } finally {
        _inFlightRequest = null;
      }
    }();

    _inFlightRequest = request;
    return request;
  }
}
