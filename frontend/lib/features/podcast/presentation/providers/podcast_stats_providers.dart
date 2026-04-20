import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_ai_assistant/core/constants/cache_constants.dart';
import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;
import 'package:personal_ai_assistant/features/podcast/data/models/playback_history_lite_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_playback_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/profile_stats_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/repositories/podcast_repository.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_core_providers.dart';

// === Stats Provider ===
final podcastStatsProvider =
    AsyncNotifierProvider<PodcastStatsNotifier, PodcastStatsResponse?>(
      PodcastStatsNotifier.new,
    );

class PodcastStatsNotifier extends AsyncNotifier<PodcastStatsResponse?> {
  PodcastRepository get _repository => ref.read(podcastRepositoryProvider);

  // Cache and deduplication state
  final Duration _cacheDuration = CacheConstants.defaultListCacheDuration;
  DateTime? _lastFetchTime;
  Future<PodcastStatsResponse?>? _inFlightRequest;
  bool _isDisposed = false;
  bool _onDisposeWired = false;

  @override
  FutureOr<PodcastStatsResponse?> build() {
    return load();
  }

  /// Whether the currently held data is still within the cache window.
  bool get isFresh {
    final fetchTime = _lastFetchTime;
    if (fetchTime == null) return false;
    return clock.now().difference(fetchTime) < _cacheDuration;
  }

  /// Executes [fetcher] with cache-aware deduplication.
  Future<PodcastStatsResponse?> runWithCache({
    required Future<PodcastStatsResponse> Function() fetcher,
    bool forceRefresh = false,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    if (!_onDisposeWired) {
      _onDisposeWired = true;
      ref.onDispose(markDisposed);
    }
    final previousData = state.value;

    if (!forceRefresh && previousData != null && isFresh) {
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
        final data = await fetcher();
        _lastFetchTime = clock.now();
        if (!_isDisposed) {
          state = AsyncValue.data(data);
        }
        return data;
      } catch (error, stackTrace) {
        if (onError != null) {
          onError(error, stackTrace);
        }
        if (previousData == null) {
          if (!_isDisposed) {
            state = AsyncValue.error(error, stackTrace);
          }
        } else {
          if (!_isDisposed) {
            state = AsyncValue.error(error, stackTrace);
          }
          Future.microtask(() {
            if (!_isDisposed) {
              state = AsyncValue.data(previousData);
            }
          });
        }
        return previousData;
      } finally {
        _inFlightRequest = null;
      }
    }();

    _inFlightRequest = request;
    return request;
  }

  /// Resets the cache state.
  void resetCache() {
    _lastFetchTime = null;
    _inFlightRequest = null;
  }

  /// Mark the notifier as disposed to prevent state updates after disposal.
  void markDisposed() {
    _isDisposed = true;
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
class ProfileStatsNotifier extends AsyncNotifier<ProfileStatsModel?> {
  PodcastRepository get _repository => ref.read(podcastRepositoryProvider);

  // Cache and deduplication state
  final Duration _cacheDuration = CacheConstants.defaultListCacheDuration;
  DateTime? _lastFetchTime;
  Future<ProfileStatsModel?>? _inFlightRequest;
  bool _isDisposed = false;
  bool _onDisposeWired = false;

  @override
  FutureOr<ProfileStatsModel?> build() async {
    return load();
  }

  /// Whether the currently held data is still within the cache window.
  bool get isFresh {
    final fetchTime = _lastFetchTime;
    if (fetchTime == null) return false;
    return clock.now().difference(fetchTime) < _cacheDuration;
  }

  /// Executes [fetcher] with cache-aware deduplication.
  Future<ProfileStatsModel?> runWithCache({
    required Future<ProfileStatsModel> Function() fetcher,
    bool forceRefresh = false,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    if (!_onDisposeWired) {
      _onDisposeWired = true;
      ref.onDispose(markDisposed);
    }
    final previousData = state.value;

    if (!forceRefresh && previousData != null && isFresh) {
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
        final data = await fetcher();
        _lastFetchTime = clock.now();
        if (!_isDisposed) {
          state = AsyncValue.data(data);
        }
        return data;
      } catch (error, stackTrace) {
        if (onError != null) {
          onError(error, stackTrace);
        }
        if (previousData == null) {
          if (!_isDisposed) {
            state = AsyncValue.error(error, stackTrace);
          }
        } else {
          if (!_isDisposed) {
            state = AsyncValue.error(error, stackTrace);
          }
          Future.microtask(() {
            if (!_isDisposed) {
              state = AsyncValue.data(previousData);
            }
          });
        }
        return previousData;
      } finally {
        _inFlightRequest = null;
      }
    }();

    _inFlightRequest = request;
    return request;
  }

  /// Resets the cache state.
  void resetCache() {
    _lastFetchTime = null;
    _inFlightRequest = null;
  }

  /// Mark the notifier as disposed to prevent state updates after disposal.
  void markDisposed() {
    _isDisposed = true;
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
    extends AsyncNotifier<PodcastEpisodeListResponse?> {
  PodcastRepository get _repository => ref.read(podcastRepositoryProvider);

  // Cache and deduplication state
  final Duration _cacheDuration = CacheConstants.defaultListCacheDuration;
  DateTime? _lastFetchTime;
  Future<PodcastEpisodeListResponse?>? _inFlightRequest;
  bool _isDisposed = false;
  bool _onDisposeWired = false;

  @override
  FutureOr<PodcastEpisodeListResponse?> build() {
    return load();
  }

  /// Whether the currently held data is still within the cache window.
  bool get isFresh {
    final fetchTime = _lastFetchTime;
    if (fetchTime == null) return false;
    return clock.now().difference(fetchTime) < _cacheDuration;
  }

  /// Executes [fetcher] with cache-aware deduplication.
  Future<PodcastEpisodeListResponse?> runWithCache({
    required Future<PodcastEpisodeListResponse> Function() fetcher,
    bool forceRefresh = false,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    if (!_onDisposeWired) {
      _onDisposeWired = true;
      ref.onDispose(markDisposed);
    }
    final previousData = state.value;

    if (!forceRefresh && previousData != null && isFresh) {
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
        final data = await fetcher();
        _lastFetchTime = clock.now();
        if (!_isDisposed) {
          state = AsyncValue.data(data);
        }
        return data;
      } catch (error, stackTrace) {
        if (onError != null) {
          onError(error, stackTrace);
        }
        if (previousData == null) {
          if (!_isDisposed) {
            state = AsyncValue.error(error, stackTrace);
          }
        } else {
          if (!_isDisposed) {
            state = AsyncValue.error(error, stackTrace);
          }
          Future.microtask(() {
            if (!_isDisposed) {
              state = AsyncValue.data(previousData);
            }
          });
        }
        return previousData;
      } finally {
        _inFlightRequest = null;
      }
    }();

    _inFlightRequest = request;
    return request;
  }

  /// Resets the cache state.
  void resetCache() {
    _lastFetchTime = null;
    _inFlightRequest = null;
  }

  /// Mark the notifier as disposed to prevent state updates after disposal.
  void markDisposed() {
    _isDisposed = true;
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
    extends AsyncNotifier<PlaybackHistoryLiteResponse?> {
  PodcastRepository get _repository => ref.read(podcastRepositoryProvider);

  // Cache and deduplication state
  final Duration _cacheDuration = CacheConstants.defaultListCacheDuration;
  DateTime? _lastFetchTime;
  Future<PlaybackHistoryLiteResponse?>? _inFlightRequest;
  bool _isDisposed = false;
  bool _onDisposeWired = false;

  @override
  FutureOr<PlaybackHistoryLiteResponse?> build() async {
    return load();
  }

  /// Whether the currently held data is still within the cache window.
  bool get isFresh {
    final fetchTime = _lastFetchTime;
    if (fetchTime == null) return false;
    return clock.now().difference(fetchTime) < _cacheDuration;
  }

  /// Executes [fetcher] with cache-aware deduplication.
  Future<PlaybackHistoryLiteResponse?> runWithCache({
    required Future<PlaybackHistoryLiteResponse> Function() fetcher,
    bool forceRefresh = false,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    if (!_onDisposeWired) {
      _onDisposeWired = true;
      ref.onDispose(markDisposed);
    }
    final previousData = state.value;

    if (!forceRefresh && previousData != null && isFresh) {
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
        final data = await fetcher();
        _lastFetchTime = clock.now();
        if (!_isDisposed) {
          state = AsyncValue.data(data);
        }
        return data;
      } catch (error, stackTrace) {
        if (onError != null) {
          onError(error, stackTrace);
        }
        if (previousData == null) {
          if (!_isDisposed) {
            state = AsyncValue.error(error, stackTrace);
          }
        } else {
          if (!_isDisposed) {
            state = AsyncValue.error(error, stackTrace);
          }
          Future.microtask(() {
            if (!_isDisposed) {
              state = AsyncValue.data(previousData);
            }
          });
        }
        return previousData;
      } finally {
        _inFlightRequest = null;
      }
    }();

    _inFlightRequest = request;
    return request;
  }

  /// Resets the cache state.
  void resetCache() {
    _lastFetchTime = null;
    _inFlightRequest = null;
  }

  /// Mark the notifier as disposed to prevent state updates after disposal.
  void markDisposed() {
    _isDisposed = true;
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
