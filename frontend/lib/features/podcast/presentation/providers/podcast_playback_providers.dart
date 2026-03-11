import 'dart:async';
import 'dart:convert';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/riverpod.dart';

import '../../../../main.dart' as main_app;
import 'audio_handler.dart';

import '../../../../core/storage/local_storage_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/podcast_episode_model.dart';
import '../../data/models/podcast_queue_model.dart';
import '../../data/models/audio_player_state_model.dart';
import '../../data/repositories/podcast_repository.dart';
import 'podcast_core_providers.dart';
import 'playback_progress_policy.dart';
import '../../../../core/utils/app_logger.dart' as logger;

part 'podcast_playback_helpers.dart';
part 'podcast_playback_queue_controller.dart';

final audioPlayerProvider =
    NotifierProvider<AudioPlayerNotifier, AudioPlayerState>(
      AudioPlayerNotifier.new,
    );

const String kLastPlaybackSnapshotStorageKeyPrefix =
    'podcast_last_playback_snapshot_v1';

class AudioPlayerNotifier extends Notifier<AudioPlayerState> {
  late PodcastRepository _repository;
  bool _isDisposed = false;
  bool _isPlayingEpisode = false;
  bool _isRestoringLastPlayed = false;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  bool? _lastPlayingState; // Track last playing state to reduce log spam
  ProcessingState? _lastProcessingState;
  bool _isHandlingQueueCompletion = false;
  Timer? _syncThrottleTimer;
  Timer? _sleepTimerTickTimer;
  DateTime? _lastPlaybackSyncAt;
  static const Duration _syncInterval = Duration(seconds: 2);
  static const Duration _lastPlaybackSnapshotDebounce = Duration(seconds: 2);
  Timer? _snapshotPersistTimer;

  PodcastAudioHandler get _audioHandler => main_app.audioHandler;

  PodcastAudioHandler? _audioHandlerOrNull() {
    try {
      return main_app.audioHandler;
    } catch (_) {
      return null;
    }
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
    _syncThrottleTimer?.cancel();
    _syncThrottleTimer = null;
    _sleepTimerTickTimer?.cancel();
    _sleepTimerTickTimer = null;
    _snapshotPersistTimer?.cancel();
    _snapshotPersistTimer = null;
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
    _syncThrottleTimer = syncThrottleTimer;
    _sleepTimerTickTimer = sleepTimerTickTimer;
    _snapshotPersistTimer = snapshotPersistTimer;
  }

  @override
  AudioPlayerState build() {
    _repository = ref.read(podcastRepositoryProvider);
    _isDisposed = false;
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

  String? _lastPlaybackSnapshotStorageKey() {
    final userId = _currentUserId();
    if (userId == null) {
      return null;
    }
    return playbackSnapshotStorageKeyForUser(userId);
  }

  void _schedulePersistLastPlaybackSnapshot({bool immediate = false}) {
    if (_isDisposed || !ref.mounted) return;
    if (state.currentEpisode == null) return;

    if (immediate) {
      _snapshotPersistTimer?.cancel();
      _snapshotPersistTimer = null;
      unawaited(_persistLastPlaybackSnapshot());
      return;
    }

    if (_snapshotPersistTimer != null) return;
    _snapshotPersistTimer = Timer(_lastPlaybackSnapshotDebounce, () {
      _snapshotPersistTimer = null;
      unawaited(_persistLastPlaybackSnapshot());
    });
  }

  Future<void> _persistLastPlaybackSnapshot() async {
    if (_isDisposed || !ref.mounted) return;
    final episode = state.currentEpisode;
    if (episode == null) return;
    final snapshotKey = _lastPlaybackSnapshotStorageKey();
    if (snapshotKey == null) return;

    final payload = <String, dynamic>{
      'episode': <String, dynamic>{
        'id': episode.id,
        'subscription_id': episode.subscriptionId,
        'subscription_image_url': episode.subscriptionImageUrl,
        'title': episode.title,
        'subscription_title': episode.subscriptionTitle,
        'description': null,
        'audio_url': episode.audioUrl,
        'audio_duration': episode.audioDuration,
        'audio_file_size': episode.audioFileSize,
        'published_at': episode.publishedAt.toIso8601String(),
        'image_url': episode.imageUrl,
        'item_link': episode.itemLink,
        'transcript_url': null,
        'transcript_content': null,
        'ai_summary': null,
        'summary_version': null,
        'ai_confidence_score': null,
        'play_count': episode.playCount,
        'last_played_at': episode.lastPlayedAt?.toIso8601String(),
        'season': episode.season,
        'episode_number': episode.episodeNumber,
        'explicit': episode.explicit,
        'status': episode.status,
        'metadata': episode.metadata,
        'playback_position': (state.position / 1000).round(),
        'is_playing': false,
        'playback_rate': state.playbackRate,
        'is_played': episode.isPlayed,
        'created_at': episode.createdAt.toIso8601String(),
        'updated_at': episode.updatedAt?.toIso8601String(),
      },
      'position_ms': state.position,
      'duration_ms': state.duration,
      'playback_rate': state.playbackRate,
      'saved_at': DateTime.now().toIso8601String(),
    };

    try {
      final storage = ref.read(localStorageServiceProvider);
      await storage.saveString(snapshotKey, jsonEncode(payload));
    } catch (_) {}
  }

  Future<_LastPlaybackSnapshot?> _loadLastPlaybackSnapshot() async {
    try {
      final snapshotKey = _lastPlaybackSnapshotStorageKey();
      if (snapshotKey == null) return null;
      final storage = ref.read(localStorageServiceProvider);
      final raw = await storage.getString(snapshotKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final episodeJson = decoded['episode'];
      if (episodeJson is! Map) return null;
      final episode = PodcastEpisodeModel.fromJson(
        Map<String, dynamic>.from(episodeJson),
      );
      final positionMs = (decoded['position_ms'] as num?)?.toInt() ?? 0;
      final durationMs =
          (decoded['duration_ms'] as num?)?.toInt() ??
          (episode.audioDuration ?? 0) * 1000;
      final playbackRate =
          (decoded['playback_rate'] as num?)?.toDouble() ??
          episode.playbackRate;
      final savedAtRaw = decoded['saved_at'];
      final savedAt = savedAtRaw is String
          ? DateTime.tryParse(savedAtRaw)
          : null;
      return _LastPlaybackSnapshot(
        episode: episode,
        positionMs: positionMs,
        durationMs: durationMs,
        playbackRate: playbackRate,
        savedAt: savedAt,
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> _restoreLastPlaybackSnapshotIfPossible() async {
    if (_isDisposed || !ref.mounted) return false;
    if (!ref.read(authProvider).isAuthenticated) return false;
    if (_isPlayingEpisode || state.currentEpisode != null) return false;

    final snapshot = await _loadLastPlaybackSnapshot();
    if (_isDisposed || !ref.mounted) return false;
    if (snapshot == null) return false;
    if (_isPlayingEpisode || state.currentEpisode != null) return false;

    state = state.copyWith(
      currentEpisode: snapshot.episode.copyWith(
        playbackRate: snapshot.playbackRate,
        playbackPosition: (snapshot.positionMs / 1000).round(),
      ),
      isPlaying: false,
      isLoading: false,
      position: snapshot.positionMs,
      duration: snapshot.durationMs,
      playbackRate: snapshot.playbackRate,
      error: null,
    );
    return true;
  }

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
        logger.AppLogger.debug(
          '[Playback] Playback state changed: ${_lastPlayingState == null
              ? "initial"
              : _lastPlayingState!
              ? "playing"
              : "paused"} -> ${playbackState.playing ? "playing" : "paused"}',
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
      if (state.position != positionMs) {
        state = state.copyWith(position: positionMs);
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
            await _audioHandler.setEpisode(
              id: ep.id.toString(),
              url: ep.audioUrl,
              title: ep.title,
              artist: ep.subscriptionTitle ?? 'Unknown Podcast',
              artUri: ep.imageUrl ?? ep.subscriptionImageUrl,
              autoPlay: false,
            );
            if (state.position > 0) {
              await _audioHandler.seek(Duration(milliseconds: state.position));
            }
            await _audioHandler.setSpeed(state.playbackRate);
          } catch (e) {
            logger.AppLogger.debug(
              '[PlaybackRestore] Failed to preload audio source: $e',
            );
          }
        }
        unawaited(_restoreLastPlayedEpisodeFromServer(expectedEpisodeId));
        return;
      }
      logger.AppLogger.debug(
        '[PlaybackRestore] Restoring last played episode for mini player',
      );
      final response = await _repository.getPlaybackHistory(page: 1, size: 20);
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
      final resolvedPlaybackRate = latest.playbackRate > 0
          ? latest.playbackRate
          : 1.0;
      final resumePositionMs = normalizeResumePositionMs(
        latest.playbackPosition,
        latest.audioDuration,
      );
      final durationMs = (latest.audioDuration ?? 0) * 1000;

      logger.AppLogger.debug(
        '[PlaybackRestore] Candidate episode=${latest.id}, position=${resumePositionMs}ms',
      );

      try {
        await _audioHandler.setEpisode(
          id: latest.id.toString(),
          url: latest.audioUrl,
          title: latest.title,
          artist: latest.subscriptionTitle ?? 'Unknown Podcast',
          artUri: latest.imageUrl ?? latest.subscriptionImageUrl,
          autoPlay: false,
        );
        if (resumePositionMs > 0) {
          await _audioHandler.seek(Duration(milliseconds: resumePositionMs));
        }
        await _audioHandler.setSpeed(resolvedPlaybackRate);
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
        error: null,
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
      final response = await _repository.getPlaybackHistory(page: 1, size: 20);
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
      final resolvedPlaybackRate = latest.playbackRate > 0
          ? latest.playbackRate
          : 1.0;
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
        error: null,
      );
      _schedulePersistLastPlaybackSnapshot(immediate: true);
    } catch (_) {}
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
      var targetPlaybackRate = state.playbackRate;

      try {
        final effectiveRate = await _repository.getEffectivePlaybackRate(
          subscriptionId: episodeForPlayback.subscriptionId,
        );
        targetPlaybackRate = effectiveRate.effectivePlaybackRate;
      } catch (error) {
        logger.AppLogger.debug(
          'Failed to resolve effective playback rate, using current state value: $error',
        );
      }

      // ===== STEP 1: Pause current playback instead of stop =====
      // Using pause() instead of stop() to avoid clearing the audio source
      // This maintains the media session state better
      logger.AppLogger.debug('[Playback] Step 1: Pausing current playback');
      try {
        await _audioHandler.pause();
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
        error: null,
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
        await _audioHandler.setEpisode(
          id: episodeForPlayback.id.toString(),
          url: episodeForPlayback.audioUrl,
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
          await _audioHandler.seek(Duration(milliseconds: resumePositionMs));
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
        await _audioHandler.setSpeed(targetPlaybackRate);
      } catch (e) {
        logger.AppLogger.debug('Failed to apply playback rate: $e');
      }

      // ===== STEP 6: Start playback =====
      logger.AppLogger.debug('[Playback] Step 6: Starting playback');
      try {
        await _audioHandler.play();
        logger.AppLogger.debug('[OK] Playback started');

        if (ref.mounted && !_isDisposed) {
          state = state.copyWith(
            isPlaying: true,
            isLoading: false,
            position: resumePositionMs,
            playbackRate: targetPlaybackRate,
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

      await _audioHandler.pause();
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

      await _audioHandler.play();
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
      await _audioHandler.seek(Duration(milliseconds: position));
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

  Future<void> setPlaybackRate(
    double rate, {
    bool applyToSubscription = false,
  }) async {
    if (_isDisposed) return;

    try {
      final currentEpisode = state.currentEpisode;
      if (applyToSubscription && currentEpisode == null) {
        throw StateError(
          'A current episode is required when applying to subscription',
        );
      }

      await _audioHandler.setSpeed(rate);
      final applied = await _repository.applyPlaybackRatePreference(
        playbackRate: rate,
        applyToSubscription: applyToSubscription,
        subscriptionId: currentEpisode?.subscriptionId,
      );

      if (ref.mounted && !_isDisposed) {
        state = state.copyWith(playbackRate: applied.effectivePlaybackRate);
        final episode = state.currentEpisode;
        if (episode != null && shouldSyncPlaybackToServer(episode)) {
          await _syncImmediatePlaybackSnapshot(
            episode: episode,
            positionMs: state.position,
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
      await _audioHandler.stop();
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

  // ===== Sleep Timer =====

  void setSleepTimer(Duration duration) {
    if (_isDisposed || !ref.mounted) return;
    if (duration <= Duration.zero) {
      cancelSleepTimer();
      return;
    }

    _sleepTimerTickTimer?.cancel();
    _sleepTimerTickTimer = null;

    final endTime = DateTime.now().add(duration);
    state = state.copyWith(
      sleepTimerEndTime: endTime,
      sleepTimerAfterEpisode: false,
      sleepTimerRemainingLabel: _formatRemainingTime(duration),
    );

    logger.AppLogger.debug(
      '[Sleep Timer] Sleep timer set: ${duration.inMinutes} minutes',
    );

    _sleepTimerTickTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _onSleepTimerTick(),
    );
  }

  void setSleepTimerAfterEpisode() {
    if (_isDisposed || !ref.mounted) return;

    _sleepTimerTickTimer?.cancel();
    _sleepTimerTickTimer = null;

    if (state.sleepTimerAfterEpisode &&
        state.sleepTimerEndTime == null &&
        state.sleepTimerRemainingLabel == 'After current episode') {
      return;
    }

    state = state
        .copyWith(clearSleepTimer: true)
        .copyWith(
          sleepTimerAfterEpisode: true,
          sleepTimerRemainingLabel: 'After current episode',
        );

    logger.AppLogger.debug(
      '[Sleep Timer] Sleep timer set: after current episode',
    );
  }

  void cancelSleepTimer() {
    if (_isDisposed || !ref.mounted) return;
    if (!state.isSleepTimerActive && _sleepTimerTickTimer == null) {
      return;
    }

    _sleepTimerTickTimer?.cancel();
    _sleepTimerTickTimer = null;

    state = state.copyWith(clearSleepTimer: true);

    logger.AppLogger.debug('[Sleep Timer] Sleep timer cancelled');
  }

  void _onSleepTimerTick() {
    if (_isDisposed || !ref.mounted) return;

    final endTime = state.sleepTimerEndTime;
    if (endTime == null) {
      _sleepTimerTickTimer?.cancel();
      _sleepTimerTickTimer = null;
      return;
    }

    final remaining = endTime.difference(DateTime.now());
    if (remaining.isNegative || remaining.inSeconds <= 0) {
      // Timer expired, pause playback
      logger.AppLogger.debug(
        '[Sleep Timer] Sleep timer expired, pausing playback',
      );
      _sleepTimerTickTimer?.cancel();
      _sleepTimerTickTimer = null;
      state = state.copyWith(clearSleepTimer: true);
      unawaited(pause());
      return;
    }

    final remainingLabel = _formatRemainingTime(remaining);
    if (state.sleepTimerRemainingLabel != remainingLabel) {
      state = state.copyWith(sleepTimerRemainingLabel: remainingLabel);
    }
  }

  String _formatRemainingTime(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _updatePlaybackStateOnServer({bool immediate = false}) async {
    if (_isDisposed) return;

    final episode = state.currentEpisode;
    if (episode == null) return;
    if (!shouldSyncPlaybackToServer(episode)) return;

    // If immediate (pause/seek/stop/completed), send right away
    if (immediate) {
      await _syncImmediatePlaybackSnapshot(
        episode: episode,
        positionMs: state.position,
        isPlaying: state.isPlaying,
      );
      return;
    }

    await _scheduleThrottledSync(episode);
  }

  Future<void> _syncImmediatePlaybackSnapshot({
    required PodcastEpisodeModel episode,
    required int positionMs,
    required bool isPlaying,
  }) async {
    _syncThrottleTimer?.cancel();
    _syncThrottleTimer = null;
    final success = await _sendPlaybackSnapshot(
      episode: episode,
      positionMs: positionMs,
      isPlaying: isPlaying,
    );
    if (success) {
      _lastPlaybackSyncAt = DateTime.now();
    }
  }

  Future<void> _scheduleThrottledSync(PodcastEpisodeModel episode) async {
    final now = DateTime.now();
    final lastSync = _lastPlaybackSyncAt;

    if (lastSync == null || now.difference(lastSync) >= _syncInterval) {
      final success = await _sendPlaybackUpdate(episode);
      if (success) {
        _lastPlaybackSyncAt = DateTime.now();
      }
      return;
    }

    if (_syncThrottleTimer?.isActive ?? false) {
      return;
    }

    final remaining = _syncInterval - now.difference(lastSync);
    _syncThrottleTimer = Timer(remaining, () {
      _syncThrottleTimer = null;
      if (_isDisposed) return;
      final currentEpisode = state.currentEpisode;
      if (currentEpisode == null) return;

      _sendPlaybackUpdate(currentEpisode).then((success) {
        if (success) {
          _lastPlaybackSyncAt = DateTime.now();
        }
      });
    });
  }

  Future<bool> _sendPlaybackUpdate(PodcastEpisodeModel episode) async {
    return _sendPlaybackSnapshot(
      episode: episode,
      positionMs: state.position,
      isPlaying: state.isPlaying,
    );
  }

  Future<bool> _sendPlaybackSnapshot({
    required PodcastEpisodeModel episode,
    required int positionMs,
    required bool isPlaying,
  }) async {
    if (_isDisposed) return false;
    if (!shouldSyncPlaybackToServer(episode)) return false;

    final payload = buildPersistPayload(positionMs, state.duration, isPlaying);

    try {
      await _repository.updatePlaybackProgress(
        episodeId: episode.id,
        position: payload.positionSec,
        isPlaying: payload.isPlaying,
        playbackRate: state.playbackRate,
      );
      return true;
    } catch (error) {
      // Log more detailed error for debugging
      logger.AppLogger.debug(
        '[Error] Failed to update playback state on server: $error',
      );
      logger.AppLogger.debug('[Playback] Episode ID: ${episode.id}');
      logger.AppLogger.debug(
        '[Playback] Position: ${positionMs}ms (${(positionMs / 1000).round()}s)',
      );
      logger.AppLogger.debug('[Playback] Is Playing: $isPlaying');
      logger.AppLogger.debug('[Playback] Playback Rate: ${state.playbackRate}');

      // Check if it's an authentication error
      if (error.toString().contains('401') ||
          error.toString().contains('authentication')) {
        logger.AppLogger.debug(
          '[Error] Authentication error - user may need to log in again',
        );
      }

      // Don't update the UI state for server errors - continue playback
      return false;
    }
  }
}
