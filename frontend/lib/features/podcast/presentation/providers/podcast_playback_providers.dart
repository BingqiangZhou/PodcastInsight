import 'dart:async';
import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/constants/cache_constants.dart';
import 'package:personal_ai_assistant/core/services/download_provider.dart';
import 'package:personal_ai_assistant/core/storage/local_storage_service.dart';
import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;
import 'package:personal_ai_assistant/core/utils/time_formatter.dart';
import 'package:personal_ai_assistant/features/auth/presentation/providers/auth_provider.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/audio_player_state_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_playback_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_queue_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/repositories/podcast_repository.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/audio_handler.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_core_providers.dart';
import 'package:personal_ai_assistant/shared/constants/storage_keys.dart';
import 'package:riverpod/riverpod.dart';

part 'audio_persistence_notifier.dart';
part 'audio_playback_rate_notifier.dart';
part 'audio_server_sync_notifier.dart';
part 'audio_sleep_timer_notifier.dart';
part 'podcast_playback_helpers.dart';
part 'podcast_playback_queue_controller.dart';

final audioPlayerProvider =
    NotifierProvider<AudioPlayerNotifier, AudioPlayerState>(
      AudioPlayerNotifier.new,
    );

typedef PlaybackRateSelectionSnapshot = ({
  double speed,
  bool applyToSubscription,
});

/// Manages Timer lifecycle with automatic cleanup.
/// Ensures all timers are cancelled and nullified properly.
class _TimerManager {
  /// Exposed for testing purposes only
  @visibleForTesting
  final Map<String, Timer> timers = {};

  /// Creates a new one-shot timer with the given key.
  /// If a timer with the same key exists, it will be cancelled first.
  Timer create(String key, Duration duration, VoidCallback callback) {
    cancel(key);
    final timer = Timer(duration, () {
      timers.remove(key);
      if (!_isDisposed) callback();
    });
    timers[key] = timer;
    return timer;
  }

  /// Creates a new periodic timer with the given key.
  /// If a timer with the same key exists, it will be cancelled first.
  Timer createPeriodic(
    String key,
    Duration duration,
    void Function(Timer) callback,
  ) {
    cancel(key);
    final timer = Timer.periodic(duration, (timer) {
      if (!_isDisposed) callback(timer);
    });
    timers[key] = timer;
    return timer;
  }

  /// Cancels and removes the timer with the given key.
  void cancel(String key) {
    final timer = timers.remove(key);
    timer?.cancel();
  }

  /// Checks if a timer with the given key is active.
  bool isActive(String key) {
    final timer = timers[key];
    return timer?.isActive ?? false;
  }

  /// Cancels all timers and clears the manager.
  void dispose() {
    for (final timer in timers.values) {
      timer.cancel();
    }
    timers.clear();
    _isDisposed = true;
  }

  bool _isDisposed = false;
}

class AudioPlayerNotifier extends Notifier<AudioPlayerState> {
  PodcastRepository get _repository => ref.read(podcastRepositoryProvider);
  bool _isDisposed = false;
  bool _isPlayingEpisode = false;
  bool _isRestoringLastPlayed = false;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  bool? _lastPlayingState; // Track last playing state to reduce log spam
  ProcessingState? _lastProcessingState;
  bool _isHandlingQueueCompletion = false;
  DateTime? _lastPlaybackSyncAt;
  bool _isSyncingPlaybackState = false; // Prevent concurrent sync requests
  static const Duration _syncInterval = Duration(seconds: 15);
  static const Duration _lastPlaybackSnapshotDebounce = Duration(seconds: 2);
  _PlaybackRateSelectionCache? _playbackRateSelectionCache;

  // Position debounce fields
  int? _pendingPositionMs;
  // Dynamic debounce intervals based on playback state
  static const Duration _positionDebounceIntervalPlaying = Duration(milliseconds: 500);
  static const Duration _positionDebounceIntervalPaused = Duration(milliseconds: 100);

  // Timer manager for centralized timer lifecycle management
  late final _TimerManager _timers = _TimerManager();

  // Timer keys
  static const String _kSyncThrottleTimer = 'syncThrottle';
  static const String _kSleepTimerTick = 'sleepTimerTick';
  static const String _kSnapshotPersist = 'snapshotPersist';
  static const String _kPositionDebounce = 'positionDebounce';

  PodcastAudioHandler get _audioHandler => ref.read(audioHandlerProvider);

  PodcastAudioHandler? _audioHandlerOrNull() {
    try {
      return ref.read(audioHandlerProvider);
    } catch (e) {
      logger.AppLogger.debug('[Playback] Audio handler not available: $e');
      return null;
    }
  }

  @visibleForTesting
  Future<void> setAudioEpisode({
    required String id,
    required String url,
    required String title,
    required String artist,
    required String? artUri,
    required bool autoPlay,
  }) {
    return _audioHandler.setEpisode(
      id: id,
      url: url,
      title: title,
      artist: artist,
      artUri: artUri,
      autoPlay: autoPlay,
    );
  }

  @visibleForTesting
  Future<void> seekAudio(Duration position) {
    return _audioHandler.seek(position);
  }

  @visibleForTesting
  Future<void> setAudioSpeed(double rate) {
    return _audioHandler.setSpeed(rate);
  }

  @visibleForTesting
  Future<void> pauseAudio() {
    return _audioHandler.pause();
  }

  @visibleForTesting
  Future<void> playAudio() {
    return _audioHandler.play();
  }

  @visibleForTesting
  Future<void> stopAudio() {
    return _audioHandler.stop();
  }

  void _cancelManagedSubscriptions() {
    _playerStateSubscription?.cancel();
    _playerStateSubscription = null;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _durationSubscription?.cancel();
    _durationSubscription = null;
  }

  void _cancelManagedTimers() {
    _timers.dispose();
    _pendingPositionMs = null;
  }

  void _disposeManagedResources() {
    _cancelManagedSubscriptions();
    _cancelManagedTimers();
  }

  @visibleForTesting
  void debugReplaceManagedResources({
    StreamSubscription? playerStateSubscription,
    StreamSubscription? positionSubscription,
    StreamSubscription? durationSubscription,
    Timer? syncThrottleTimer,
    Timer? sleepTimerTickTimer,
    Timer? snapshotPersistTimer,
  }) {
    _disposeManagedResources();
    _playerStateSubscription = playerStateSubscription;
    _positionSubscription = positionSubscription;
    _durationSubscription = durationSubscription;
    // For testing purposes, replace the timer manager with mock timers
    if (syncThrottleTimer != null) {
      _timers.timers[_kSyncThrottleTimer] = syncThrottleTimer;
    }
    if (sleepTimerTickTimer != null) {
      _timers.timers[_kSleepTimerTick] = sleepTimerTickTimer;
    }
    if (snapshotPersistTimer != null) {
      _timers.timers[_kSnapshotPersist] = snapshotPersistTimer;
    }
  }

  @override
  AudioPlayerState build() {
    _isDisposed = false;
    _playbackRateSelectionCache = null;
    _disposeManagedResources();

    final handler = _audioHandlerOrNull();
    if (handler != null) {
      _setupListeners(handler);
    } else {
      logger.AppLogger.warning(
        '[Playback] Audio handler is not initialized; running in degraded mode.',
      );
    }

    ref.onDispose(() {
      _isDisposed = true;
      _disposeManagedResources();
    });

    return const AudioPlayerState();
  }

  String? _currentUserId() {
    final authState = ref.read(authProvider);
    if (!authState.isAuthenticated) {
      return null;
    }

    final userId = authState.user?.id;
    if (userId == null || userId.isEmpty) {
      return null;
    }

    return userId;
  }

  // Persistence methods → audio_persistence_notifier.dart
  // Playback rate methods → audio_playback_rate_notifier.dart

  void _setupListeners(PodcastAudioHandler audioHandler) {
    if (_isDisposed) return;
    _cancelManagedSubscriptions();

    _playerStateSubscription = audioHandler.playbackState.listen((
      playbackState,
    ) {
      if (_isDisposed || !ref.mounted) return;

      final processingState = _mapProcessingState(
        playbackState.processingState,
      );
      final completedJustNow =
          _lastProcessingState != ProcessingState.completed &&
          processingState == ProcessingState.completed;
      _lastProcessingState = processingState;

      // Only log when state actually changes
      if (kDebugMode && _lastPlayingState != playbackState.playing) {
        final lastStateStr = switch (_lastPlayingState) {
          null => 'initial',
          true => 'playing',
          false => 'paused',
        };
        logger.AppLogger.debug(
          '[Playback] Playback state changed: $lastStateStr -> ${playbackState.playing ? "playing" : "paused"}',
        );
        _lastPlayingState = playbackState.playing;
      }

      if (state.isPlaying != playbackState.playing ||
          state.isLoading ||
          state.processingState != processingState) {
        state = state.copyWith(
          isPlaying: playbackState.playing,
          isLoading: false,
          processingState: processingState,
          clearError: true,
        );
      }
      _schedulePersistLastPlaybackSnapshot(immediate: !playbackState.playing);

      if (completedJustNow) {
        unawaited(_handleTrackCompleted());
      }
    });

    // CRITICAL: Use _audioHandler.positionStream instead of AudioService.position
    // AudioService is NOT available on desktop platforms (Windows, macOS, Linux)
    // _audioHandler.positionStream works on both mobile and desktop
    _positionSubscription = audioHandler.positionStream.listen((position) {
      if (_isDisposed || !ref.mounted) return;

      final positionMs = position.inMilliseconds;

      // OPTIMIZATION: Debounce position updates to reduce state changes
      // Only update state immediately if position changed significantly (>1 second)
      final positionDelta = (state.position - positionMs).abs();
      final shouldUpdateImmediately = positionDelta > 1000;

      if (shouldUpdateImmediately) {
        // Immediate update for significant position changes (seek operations)
        _timers.cancel(_kPositionDebounce);
        _pendingPositionMs = null;
        if (state.position != positionMs) {
          state = state.copyWith(position: positionMs);
        }
      } else if (state.position != positionMs) {
        // Debounce small position changes
        // Use longer interval when playing to reduce UI updates
        final debounceInterval = state.isPlaying
            ? _positionDebounceIntervalPlaying
            : _positionDebounceIntervalPaused;
        _pendingPositionMs = positionMs;
        _timers.create(_kPositionDebounce, debounceInterval, () {
          if (_isDisposed || !ref.mounted) return;
          final pending = _pendingPositionMs;
          _pendingPositionMs = null;
          if (pending != null && state.position != pending) {
            state = state.copyWith(position: pending);
          }
        });
      }

      if (state.currentEpisode != null) {
        _schedulePersistLastPlaybackSnapshot();
      }
      if (state.isPlaying) {
        unawaited(_updatePlaybackStateOnServer());
      }
    });

    _durationSubscription = audioHandler.mediaItem.listen((mediaItem) {
      if (_isDisposed || !ref.mounted) return;

      // Duration listener as supplementary update (backend duration is used first)
      // Only update if audio stream provides a different or more accurate duration
      if (mediaItem != null) {
        final newDuration = mediaItem.duration?.inMilliseconds ?? 0;

        // Only update if:
        // 1. Current duration is 0 (no backend duration available)
        // 2. New duration is significantly different (>5% difference) and non-zero
        final currentDuration = state.duration;
        final shouldUpdate =
            currentDuration == 0 ||
            (newDuration > 0 &&
                (newDuration - currentDuration).abs() > currentDuration * 0.05);

        if (shouldUpdate && newDuration != currentDuration) {
          if (kDebugMode) {
            logger.AppLogger.debug(
              '[DURATION UPDATE] ${currentDuration}ms -> ${newDuration}ms (from audio stream)',
            );
          }
          state = state.copyWith(duration: newDuration);
        }
      }
    });

    if (kDebugMode) {
      logger.AppLogger.debug('[OK] Audio listeners set up successfully');
    }
  }

  ProcessingState _mapProcessingState(AudioProcessingState state) {
    switch (state) {
      case AudioProcessingState.idle:
        return ProcessingState.idle;
      case AudioProcessingState.loading:
        return ProcessingState.loading;
      case AudioProcessingState.buffering:
        return ProcessingState.buffering;
      case AudioProcessingState.ready:
        return ProcessingState.ready;
      case AudioProcessingState.completed:
        return ProcessingState.completed;
      default:
        return ProcessingState.idle;
    }
  }

  Future<void> _handleTrackCompleted() async {
    if (_isDisposed || !ref.mounted) {
      return;
    }

    final completedEpisode = state.currentEpisode;
    final completedPositionMs = resolveCompletedPositionMs(
      state.position,
      state.duration,
    );
    state = state.copyWith(isPlaying: false, position: completedPositionMs);
    if (completedEpisode != null &&
        shouldSyncPlaybackToServer(completedEpisode)) {
      unawaited(
        _syncImmediatePlaybackSnapshot(
          episode: completedEpisode,
          positionMs: completedPositionMs,
          isPlaying: false,
        ),
      );
    }

    // If sleep timer is set to "after episode", stop here
    if (state.sleepTimerAfterEpisode) {
      logger.AppLogger.debug(
        '[Sleep Timer] Sleep timer: stop after episode triggered',
      );
      cancelSleepTimer();
      return;
    }

    if (!shouldAdvanceQueueOnCompletion(state) || _isHandlingQueueCompletion) {
      return;
    }

    _isHandlingQueueCompletion = true;
    try {
      final queue = await ref
          .read(podcastQueueControllerProvider.notifier)
          .onQueueTrackCompleted();

      final next = queue.currentItem;
      if (next == null) {
        state = state.copyWith(
          clearCurrentEpisode: true,
          isPlaying: false,
          position: 0,
          playSource: PlaySource.direct,
          clearCurrentQueueEpisodeId: true,
        );
        return;
      }

      await playEpisode(
        next.toEpisodeModel(),
        source: PlaySource.queue,
        queueEpisodeId: next.episodeId,
      );
    } catch (error) {
      logger.AppLogger.debug(
        '[Error] Failed to advance queue on completion: $error',
      );
    } finally {
      _isHandlingQueueCompletion = false;
    }
  }

  void syncQueueState(PodcastQueueModel queue) {
    if (_isDisposed || !ref.mounted) {
      return;
    }
    if (state.queue == queue &&
        state.currentQueueEpisodeId == queue.currentEpisodeId) {
      return;
    }
    state = state.copyWith(
      queue: queue,
      currentQueueEpisodeId: queue.currentEpisodeId,
      clearCurrentQueueEpisodeId:
          queue.currentEpisodeId == null && queue.items.isEmpty,
    );
  }

  void setQueueSyncing(bool syncing) {
    if (_isDisposed || !ref.mounted) {
      return;
    }
    if (state.queueSyncing == syncing) {
      return;
    }
    state = state.copyWith(queueSyncing: syncing);
  }

  Future<void> restoreLastPlayedEpisodeIfNeeded() async {
    if (_isDisposed || !ref.mounted) {
      return;
    }
    if (_isRestoringLastPlayed) {
      logger.AppLogger.debug(
        '[PlaybackRestore] Skip restore: restoration already in progress',
      );
      return;
    }
    if (_isPlayingEpisode || state.currentEpisode != null) {
      logger.AppLogger.debug(
        '[PlaybackRestore] Skip restore: player already has active state',
      );
      return;
    }
    if (!ref.read(authProvider).isAuthenticated) {
      logger.AppLogger.debug(
        '[PlaybackRestore] Skip restore: user is not authenticated',
      );
      return;
    }

    _isRestoringLastPlayed = true;
    try {
      final restoredFromLocal = await _restoreLastPlaybackSnapshotIfPossible();
      final expectedEpisodeId = state.currentEpisode?.id;
      if (restoredFromLocal) {
        // Preload the audio source so tapping play can use the fast-resume path.
        // Without this, _player.resume() is called on an empty player and does nothing.
        final ep = state.currentEpisode;
        if (ep != null) {
          try {
            await setAudioEpisode(
              id: ep.id.toString(),
              url: ep.audioUrl,
              title: ep.title,
              artist: ep.subscriptionTitle ?? 'Unknown Podcast',
              artUri: ep.imageUrl ?? ep.subscriptionImageUrl,
              autoPlay: false,
            );
            if (state.position > 0) {
              await seekAudio(Duration(milliseconds: state.position));
            }
            await setAudioSpeed(state.playbackRate);
          } catch (e) {
            logger.AppLogger.debug(
              '[PlaybackRestore] Failed to preload audio source: $e',
            );
          }
        }
        // Skip server restore if the local snapshot is recent (<5 min).
        // The server fetch is mainly useful for cross-device sync; if the
        // snapshot was just persisted, the data is likely still accurate.
        final restoredEp = state.currentEpisode;
        final lastPlayed = restoredEp?.lastPlayedAt;
        if (lastPlayed != null &&
            DateTime.now().difference(lastPlayed) <
                CacheConstants.defaultListCacheDuration) {
          logger.AppLogger.debug(
            '[PlaybackRestore] Local snapshot is fresh (<5 min), '
            'skipping server restore',
          );
          return;
        }
        unawaited(_restoreLastPlayedEpisodeFromServer(expectedEpisodeId));
        return;
      }
      logger.AppLogger.debug(
        '[PlaybackRestore] Restoring last played episode for mini player',
      );
      final response = await _repository.getPlaybackHistory(size: 20);
      if (_isDisposed || !ref.mounted) {
        return;
      }
      if (_isPlayingEpisode || state.currentEpisode != null) {
        logger.AppLogger.debug(
          '[PlaybackRestore] Skip apply: player state changed while restoring',
        );
        return;
      }
      if (response.episodes.isEmpty) {
        logger.AppLogger.debug(
          '[PlaybackRestore] Skip restore: no playback history found',
        );
        return;
      }

      final episodes = [...response.episodes]
        ..sort((a, b) {
          final aTime =
              a.lastPlayedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime =
              b.lastPlayedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });
      final latest = episodes.first;
      final resolvedPlaybackRate = await _resolveEffectivePlaybackRate(
        subscriptionId: latest.subscriptionId,
        fallbackRate: _effectiveFallbackPlaybackRate(
          currentValue: state.playbackRate,
          episodePlaybackRate: latest.playbackRate,
        ),
      );
      final resumePositionMs = normalizeResumePositionMs(
        latest.playbackPosition,
        latest.audioDuration,
      );
      final durationMs = (latest.audioDuration ?? 0) * 1000;

      logger.AppLogger.debug(
        '[PlaybackRestore] Candidate episode=${latest.id}, position=${resumePositionMs}ms',
      );

      try {
        await setAudioEpisode(
          id: latest.id.toString(),
          url: latest.audioUrl,
          title: latest.title,
          artist: latest.subscriptionTitle ?? 'Unknown Podcast',
          artUri: latest.imageUrl ?? latest.subscriptionImageUrl,
          autoPlay: false,
        );
        if (resumePositionMs > 0) {
          await seekAudio(Duration(milliseconds: resumePositionMs));
        }
        await setAudioSpeed(resolvedPlaybackRate);
      } catch (error) {
        logger.AppLogger.debug(
          '[PlaybackRestore] Failed to preload restored episode: $error',
        );
      }

      if (_isDisposed || !ref.mounted) {
        return;
      }
      if (_isPlayingEpisode || state.currentEpisode != null) {
        logger.AppLogger.debug(
          '[PlaybackRestore] Skip apply: player state changed after preloading',
        );
        return;
      }

      state = state.copyWith(
        currentEpisode: latest.copyWith(
          playbackRate: resolvedPlaybackRate,
          playbackPosition: (resumePositionMs / 1000).round(),
        ),
        isPlaying: false,
        isLoading: false,
        position: resumePositionMs,
        duration: durationMs,
        playbackRate: resolvedPlaybackRate,
        clearError: true,
      );

      logger.AppLogger.debug(
        '[PlaybackRestore] Restored episode ${latest.id} to ${state.formattedPosition}',
      );
      _schedulePersistLastPlaybackSnapshot(immediate: true);
    } catch (error) {
      logger.AppLogger.debug(
        '[PlaybackRestore] Failed to restore last played episode: $error',
      );
    } finally {
      _isRestoringLastPlayed = false;
    }
  }

  Future<void> _restoreLastPlayedEpisodeFromServer(
    int? expectedEpisodeId,
  ) async {
    if (_isDisposed || !ref.mounted) return;
    if (_isPlayingEpisode) return;
    if (!ref.read(authProvider).isAuthenticated) return;

    try {
      final response = await _repository.getPlaybackHistory(size: 20);
      if (_isDisposed || !ref.mounted) return;
      if (_isPlayingEpisode) return;
      if (expectedEpisodeId != null &&
          state.currentEpisode?.id != expectedEpisodeId) {
        return;
      }
      if (response.episodes.isEmpty) return;

      final episodes = [...response.episodes]
        ..sort((a, b) {
          final aTime =
              a.lastPlayedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime =
              b.lastPlayedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });
      final latest = episodes.first;
      final resolvedPlaybackRate = await _resolveEffectivePlaybackRate(
        subscriptionId: latest.subscriptionId,
        fallbackRate: _effectiveFallbackPlaybackRate(
          currentValue: state.playbackRate,
          episodePlaybackRate: latest.playbackRate,
        ),
      );
      final resumePositionMs = normalizeResumePositionMs(
        latest.playbackPosition,
        latest.audioDuration,
      );
      final durationMs = (latest.audioDuration ?? 0) * 1000;

      if (expectedEpisodeId != null &&
          state.currentEpisode?.id != expectedEpisodeId) {
        return;
      }

      state = state.copyWith(
        currentEpisode: latest.copyWith(
          playbackRate: resolvedPlaybackRate,
          playbackPosition: (resumePositionMs / 1000).round(),
        ),
        isPlaying: false,
        isLoading: false,
        position: resumePositionMs,
        duration: durationMs,
        playbackRate: resolvedPlaybackRate,
        clearError: true,
      );
      try {
        await setAudioSpeed(resolvedPlaybackRate);
      } catch (error) {
        logger.AppLogger.debug(
          '[PlaybackRestore] Failed to apply updated server playback rate: $error',
        );
      }
      _schedulePersistLastPlaybackSnapshot(immediate: true);
    } catch (e) {
      logger.AppLogger.debug('[PlaybackRestore] Failed to restore from server: $e');
    }
  }

  Future<PodcastEpisodeModel> _resolveEpisodeForPlayback(
    PodcastEpisodeModel episode,
  ) async {
    if (_isDisposed || !ref.mounted) {
      return episode;
    }

    logger.AppLogger.debug(
      '[PlaybackRestore] Fetch latest playback state before play: episode=${episode.id}',
    );
    final resolved = await resolveEpisodeForPlayback(episode, () async {
      return _repository.getEpisode(episode.id);
    });

    if (identical(resolved, episode)) {
      logger.AppLogger.debug(
        '[PlaybackRestore] Fallback to local episode data: episode=${episode.id}',
      );
    } else {
      logger.AppLogger.debug(
        '[PlaybackRestore] Using server playback state: episode=${resolved.id}, position=${resolved.playbackPosition ?? 0}s',
      );
    }

    return resolved;
  }

  Future<void> playManagedEpisode(PodcastEpisodeModel episode) async {
    if (isDiscoverPreviewEpisode(episode)) {
      await playEpisode(episode);
      return;
    }

    final preparedQueue = await _prepareManualPlayQueue(episode.id);
    final currentQueueItem = preparedQueue?.currentItem;
    if (currentQueueItem != null) {
      await playEpisode(
        currentQueueItem.toEpisodeModel(),
        source: PlaySource.queue,
        queueEpisodeId: currentQueueItem.episodeId,
      );
      return;
    }

    await playEpisode(episode);
  }

  Future<void> playEpisode(
    PodcastEpisodeModel episode, {
    PlaySource source = PlaySource.direct,
    int? queueEpisodeId,
  }) async {
    if (_isPlayingEpisode) {
      logger.AppLogger.debug(
        '[Playback] playEpisode already in progress, ignoring duplicate call',
      );
      return;
    }

    final isSameEpisode = state.currentEpisode?.id == episode.id;
    final isCompleted = state.processingState == ProcessingState.completed;
    if (isSameEpisode && !isCompleted) {
      state = state.copyWith(
        playSource: source,
        currentQueueEpisodeId: source == PlaySource.queue
            ? (queueEpisodeId ?? episode.id)
            : null,
        clearCurrentQueueEpisodeId: source != PlaySource.queue,
      );
      if (state.isPlaying) {
        logger.AppLogger.debug(
          '[Warn] Same episode already playing, skip reloading source',
        );
        return;
      }
      logger.AppLogger.debug(
        '[Playback] Same episode paused, fast resume without reloading source',
      );
      await resume();
      return;
    }

    _isPlayingEpisode = true;
    var episodeForPlayback = episode;
    final skipServerSync = isDiscoverPreviewEpisode(episode);

    try {
      if (!skipServerSync) {
        episodeForPlayback = await _resolveEpisodeForPlayback(episode);
      }
      if (!ref.mounted || _isDisposed) {
        _isPlayingEpisode = false;
        return;
      }

      logger.AppLogger.debug('[Playback] ===== playEpisode called =====');
      logger.AppLogger.debug('[Playback] Episode ID: ${episodeForPlayback.id}');
      logger.AppLogger.debug(
        '[Playback] Episode Title: ${episodeForPlayback.title}',
      );
      logger.AppLogger.debug(
        '[Playback] Audio URL: ${episodeForPlayback.audioUrl}',
      );
      logger.AppLogger.debug(
        '[Playback] Subscription ID: ${episodeForPlayback.subscriptionId}',
      );

      if (!ref.mounted || _isDisposed) {
        _isPlayingEpisode = false;
        return;
      }

      final queueSnapshot = state.queue;
      final queueSyncing = state.queueSyncing;
      final targetPlaybackRate = await _resolveEffectivePlaybackRate(
        subscriptionId: episodeForPlayback.subscriptionId,
        fallbackRate: _effectiveFallbackPlaybackRate(
          currentValue: state.playbackRate,
          episodePlaybackRate: episodeForPlayback.playbackRate,
        ),
      );

      // ===== STEP 1: Pause current playback instead of stop =====
      // Using pause() instead of stop() to avoid clearing the audio source
      // This maintains the media session state better
      logger.AppLogger.debug('[Playback] Step 1: Pausing current playback');
      try {
        await pauseAudio();
        logger.AppLogger.debug('[OK] Paused');
      } catch (e) {
        logger.AppLogger.debug('[Error] Pause error (ignorable): $e');
      }

      state = const AudioPlayerState().copyWith(
        playbackRate: targetPlaybackRate,
        queue: queueSnapshot,
        queueSyncing: queueSyncing,
        playSource: source,
        currentQueueEpisodeId: source == PlaySource.queue
            ? (queueEpisodeId ?? episodeForPlayback.id)
            : null,
        clearError: true,
      );

      if (!ref.mounted || _isDisposed) {
        _isPlayingEpisode = false;
        return;
      }

      // ===== STEP 2: Set new episode info with duration from backend =====
      logger.AppLogger.debug('[Playback] Step 2: Setting new episode info');
      // CRITICAL: Backend audioDuration is in SECONDS, convert to MILLISECONDS
      final durationMs = (episodeForPlayback.audioDuration ?? 0) * 1000;
      final resumePositionMs = normalizeResumePositionMs(
        episodeForPlayback.playbackPosition,
        episodeForPlayback.audioDuration,
      );
      logger.AppLogger.debug(
        '[Playback] Using backend duration: ${episodeForPlayback.audioDuration}s = ${durationMs}ms',
      );
      state = state.copyWith(
        currentEpisode: episodeForPlayback,
        isLoading: true,
        isPlaying: false, // Keep false until actually playing
        duration: durationMs, // Convert seconds to milliseconds
        clearError: true,
      );
      _schedulePersistLastPlaybackSnapshot(immediate: true);

      // ===== STEP 3: Set new episode with metadata =====
      // CRITICAL: Use setEpisode() to properly set MediaItem, validate artUri, and load audio
      // artUri validation is built into setEpisode() - only http/https URLs are accepted
      logger.AppLogger.debug(
        '[Playback] Step 3: Setting new episode with metadata',
      );
      logger.AppLogger.debug(
        '[Playback] Backend duration already set: ${state.duration}ms',
      );
      logger.AppLogger.debug(
        '[Playback] Image URL: ${episodeForPlayback.imageUrl ?? "NULL"}',
      );

      try {
        // Check for local offline download before using CDN URL
        final downloadService = ref.read(downloadManagerProvider);
        final localPath = await downloadService.getLocalPath(
          episodeForPlayback.id,
        );
        final audioUrl = localPath != null ? 'file://$localPath' : episodeForPlayback.audioUrl;

        if (localPath != null) {
          logger.AppLogger.debug(
            '[Playback] Using offline download: $localPath',
          );
        }

        await setAudioEpisode(
          id: episodeForPlayback.id.toString(),
          url: audioUrl,
          title: episodeForPlayback.title,
          artist: episodeForPlayback.subscriptionTitle ?? 'Unknown Podcast',
          artUri:
              episodeForPlayback.imageUrl ??
              episodeForPlayback.subscriptionImageUrl,
          autoPlay:
              false, // We'll manually start playback after restoring position/speed
        );
        logger.AppLogger.debug('[OK] Episode loaded successfully');
      } catch (loadError) {
        logger.AppLogger.debug('[Error] Failed to load episode: $loadError');
        throw Exception('Failed to load audio: $loadError');
      }

      if (!ref.mounted || _isDisposed) {
        _isPlayingEpisode = false;
        return;
      }

      // ===== STEP 4: Restore playback position =====
      if (resumePositionMs > 0) {
        logger.AppLogger.debug(
          '[Playback] Step 4: Seeking to saved position: ${resumePositionMs}ms',
        );
        try {
          await seekAudio(Duration(milliseconds: resumePositionMs));
          logger.AppLogger.debug('[OK] Seek completed');
        } catch (e) {
          logger.AppLogger.debug('[Error] Seek error: $e');
        }
      }

      if (!ref.mounted || _isDisposed) {
        _isPlayingEpisode = false;
        return;
      }

      // ===== STEP 5: Restore playback rate =====
      logger.AppLogger.debug(
        'Step 5: Applying effective playback rate ${targetPlaybackRate}x',
      );
      try {
        await setAudioSpeed(targetPlaybackRate);
      } catch (e) {
        logger.AppLogger.debug('Failed to apply playback rate: $e');
      }

      // ===== STEP 6: Start playback =====
      logger.AppLogger.debug('[Playback] Step 6: Starting playback');
      try {
        await playAudio();
        logger.AppLogger.debug('[OK] Playback started');

        if (ref.mounted && !_isDisposed) {
          state = state.copyWith(
            isPlaying: true,
            isLoading: false,
            position: resumePositionMs,
            playbackRate: targetPlaybackRate,
            clearError: true,
          );
          _schedulePersistLastPlaybackSnapshot(immediate: true);
        }
      } catch (playError) {
        logger.AppLogger.debug('[Error] Failed to start playback: $playError');
        _isPlayingEpisode = false;
        throw Exception('Failed to start playback: $playError');
      }

      logger.AppLogger.debug('[Playback] ===== playEpisode completed =====');

      // Update playback state on server (non-blocking)
      if (ref.mounted && !_isDisposed) {
        _updatePlaybackStateOnServer().catchError((error) {
          logger.AppLogger.debug('[Error] Server update failed: $error');
        });
      }

      // Release the lock
      _isPlayingEpisode = false;
    } catch (error) {
      logger.AppLogger.debug('[Error] ===== Failed to play episode =====');
      logger.AppLogger.debug('[Playback] Episode ID: ${episodeForPlayback.id}');
      logger.AppLogger.debug(
        '[Playback] Audio URL: ${episodeForPlayback.audioUrl}',
      );
      logger.AppLogger.debug('[Error] Error: $error');

      // Release the lock on error
      _isPlayingEpisode = false;

      // Update error state
      if (ref.mounted && !_isDisposed) {
        state = state.copyWith(
          isLoading: false,
          isPlaying: false, // Ensure playing is false on error
          error: 'Failed to play audio: $error',
        );
      }
    }
  }

  Future<PodcastQueueModel?> _prepareManualPlayQueue(int episodeId) async {
    if (_isDisposed || !ref.mounted) {
      return null;
    }

    try {
      final queueController = ref.read(podcastQueueControllerProvider.notifier);
      return await queueController.activateEpisode(episodeId);
    } catch (error) {
      logger.AppLogger.debug('Failed to prepare manual play queue: $error');
      return null;
    }
  }

  bool _isCurrentEpisodeAtQueueHead(int episodeId) {
    final queue = state.queue;
    if (queue.currentEpisodeId != episodeId || queue.items.isEmpty) {
      return false;
    }
    return queue.items.first.episodeId == episodeId;
  }

  Future<void> pause() async {
    if (_isDisposed) return;

    try {
      logger.AppLogger.debug(
        '[Playback] pause() called, current isPlaying: ${state.isPlaying}',
      );

      // IMPORTANT: Don't manually update state here - let the playbackState listener handle it
      // The listener will update the state when playbackState.playing changes
      // This avoids race conditions where manual state gets overwritten

      await pauseAudio();
      logger.AppLogger.debug(
        '[Playback] AudioHandler.pause() completed, waiting for playbackState listener to update UI',
      );

      if (ref.mounted && !_isDisposed) {
        final episode = state.currentEpisode;
        if (episode != null && shouldSyncPlaybackToServer(episode)) {
          await _syncImmediatePlaybackSnapshot(
            episode: episode,
            positionMs: state.position,
            isPlaying: false,
          );
        }
      }
    } catch (error) {
      logger.AppLogger.debug('[Error] pause() error: $error');
      if (ref.mounted && !_isDisposed) {
        state = state.copyWith(error: error.toString());
      }
    }
  }

  Future<void> resume() async {
    if (_isDisposed) return;

    try {
      logger.AppLogger.debug(
        '[Playback] resume() called, current isPlaying: ${state.isPlaying}',
      );

      // IMPORTANT: Don't manually update state here - let the playbackState listener handle it
      // The listener will update the state when playbackState.playing changes
      // This avoids race conditions where manual state gets overwritten

      final currentEpisode = state.currentEpisode;
      final resolvedPlaybackRate = await _resolveEffectivePlaybackRate(
        subscriptionId: currentEpisode?.subscriptionId,
        fallbackRate: _effectiveFallbackPlaybackRate(
          currentValue: state.playbackRate,
          episodePlaybackRate: currentEpisode?.playbackRate,
        ),
      );
      await setAudioSpeed(resolvedPlaybackRate);
      if (ref.mounted &&
          !_isDisposed &&
          state.playbackRate != resolvedPlaybackRate) {
        state = state.copyWith(
          playbackRate: resolvedPlaybackRate,
          currentEpisode: currentEpisode?.copyWith(
            playbackRate: resolvedPlaybackRate,
          ),
        );
      }

      await playAudio();
      logger.AppLogger.debug(
        '[Playback] AudioHandler.play() completed, waiting for playbackState listener to update UI',
      );

      if (ref.mounted && !_isDisposed) {
        unawaited(
          _updatePlaybackStateOnServer().catchError((error) {
            logger.AppLogger.debug(
              '[Error] Server update failed after resume: $error',
            );
          }),
        );

        // Ensure the currently playing episode is at the top of the queue.
        // Skip no-op activation if queue already reflects the invariant.
        final currentEpisode = state.currentEpisode;
        if (currentEpisode != null &&
            !isDiscoverPreviewEpisode(currentEpisode) &&
            !_isCurrentEpisodeAtQueueHead(currentEpisode.id)) {
          unawaited(
            _prepareManualPlayQueue(currentEpisode.id).catchError((error) {
              logger.AppLogger.debug(
                '[Error] Queue activation failed after resume: $error',
              );
              return null;
            }),
          );
        }
      }
    } catch (error) {
      logger.AppLogger.debug('[Error] resume() error: $error');
      if (ref.mounted && !_isDisposed) {
        state = state.copyWith(isPlaying: false, error: error.toString());
      }
    }
  }

  Future<void> seekTo(int position) async {
    if (_isDisposed) return;

    try {
      await seekAudio(Duration(milliseconds: position));
      if (ref.mounted && !_isDisposed) {
        state = state.copyWith(position: position);
        final episode = state.currentEpisode;
        if (episode != null && shouldSyncPlaybackToServer(episode)) {
          await _syncImmediatePlaybackSnapshot(
            episode: episode,
            positionMs: position,
            isPlaying: state.isPlaying,
          );
        }
      }
    } catch (error) {
      if (ref.mounted && !_isDisposed) {
        state = state.copyWith(error: error.toString());
      }
    }
  }

  Future<void> stop() async {
    if (_isDisposed) return;

    try {
      final episode = state.currentEpisode;
      if (ref.mounted &&
          !_isDisposed &&
          episode != null &&
          shouldSyncPlaybackToServer(episode)) {
        await _syncImmediatePlaybackSnapshot(
          episode: episode,
          positionMs: state.position,
          isPlaying: false,
        );
      }
      await stopAudio();
      if (ref.mounted && !_isDisposed) {
        state = state.copyWith(
          clearCurrentEpisode: true,
          isPlaying: false,
          position: 0,
          playSource: PlaySource.direct,
          clearCurrentQueueEpisodeId: true,
        );
      }
    } catch (error) {
      if (ref.mounted && !_isDisposed) {
        state = state.copyWith(error: error.toString());
      }
    }
  }

  // Playback rate snapshot methods defined on the class (not extension) so
  // that test mocks can override them.  They delegate to the extension helpers
  // defined in audio_playback_rate_notifier.dart.

  PlaybackRateSelectionSnapshot getPlaybackRateSelectionSnapshot() {
    final currentEpisode = state.currentEpisode;
    final fallbackRate = _effectiveFallbackPlaybackRate(
      currentValue: state.playbackRate,
      episodePlaybackRate: currentEpisode?.playbackRate,
    );
    final fallbackSelection = _fallbackPlaybackRateSelection(
      subscriptionId: currentEpisode?.subscriptionId,
      fallbackRate: fallbackRate,
    );
    final cachedSelection = _playbackRateSelectionCache;
    if (cachedSelection == null) {
      return fallbackSelection;
    }
    if (!cachedSelection.applyToSubscription) {
      return (speed: cachedSelection.speed, applyToSubscription: false);
    }
    if (currentEpisode != null &&
        cachedSelection.subscriptionId == currentEpisode.subscriptionId) {
      return (speed: cachedSelection.speed, applyToSubscription: true);
    }
    return fallbackSelection;
  }

  Future<PlaybackRateSelectionSnapshot>
  resolvePlaybackRateSelectionForCurrentContext() async {
    final currentEpisode = state.currentEpisode;
    final fallbackRate = _effectiveFallbackPlaybackRate(
      currentValue: state.playbackRate,
      episodePlaybackRate: currentEpisode?.playbackRate,
    );
    final fallbackSelection = _fallbackPlaybackRateSelection(
      subscriptionId: currentEpisode?.subscriptionId,
      fallbackRate: fallbackRate,
    );
    final effective = await _fetchEffectivePlaybackRatePreference(
      subscriptionId: currentEpisode?.subscriptionId,
    );
    final resolvedSelection = (
      speed: effective?.effectivePlaybackRate ?? fallbackSelection.speed,
      applyToSubscription: currentEpisode != null && (effective?.source == 'subscription' ||
            (effective == null && fallbackSelection.applyToSubscription)),
    );
    _cachePlaybackRateSelection(
      speed: resolvedSelection.speed,
      applyToSubscription: resolvedSelection.applyToSubscription,
      subscriptionId: currentEpisode?.subscriptionId,
    );
    return resolvedSelection;
  }

}
