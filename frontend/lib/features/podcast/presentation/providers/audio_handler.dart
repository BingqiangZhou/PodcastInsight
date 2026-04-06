import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:personal_ai_assistant/core/services/app_cache_service.dart';
import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;

/// AudioHandler for podcast playback with system media controls
///
/// Migrated from just_audio to audioplayers 6.5.1
/// Optimized for Android 15 + Vivo OriginOS with proper state synchronization
///
/// ## Lifecycle Management
///
/// This handler is a global singleton that lives for the app's lifetime.
/// Proper cleanup is important to prevent memory leaks:
///
/// ```dart
/// // Create the handler (usually done once at app startup)
/// final handler = PodcastAudioHandler();
///
/// // Use it throughout the app
/// await handler.setEpisode(id: '1', url: '...', title: 'Episode 1');
/// await handler.play();
///
/// // When the app is shutting down OR when switching to a different
/// // audio context (like playing a different podcast), call stopService():
/// await handler.stopService();
///
/// // For complete cleanup (app shutdown):
/// await handler.dispose();
/// ```
///
/// ## Memory Leak Prevention
///
/// - All stream subscriptions are tracked in `_subs` list
/// - Subscriptions are cancelled in both `stopService()` and `dispose()`
/// - `_isDisposed` flag prevents operations after disposal
/// - Both methods check the disposal flag before proceeding
///
/// ## Platform Compatibility
///
/// - **Android/OriginOS**: Full lock screen controls with artUri support (http/https only)
/// - **iOS**: Background playback with lock screen controls
/// - **Desktop**: Basic playback controls (no lock screen)
class PodcastAudioHandler extends BaseAudioHandler with SeekHandler {

  PodcastAudioHandler() : _player = AudioPlayer() {
    // Setup player event listeners
    _listenPlayerEvents();

    // Initialize with default MediaItem
    mediaItem.add(
      const MediaItem(
        id: 'default',
        title: 'No media',
        artist: 'Unknown',
      ),
    );

    // Initialize playback state
    playbackState.add(
      PlaybackState(
        controls: [MediaControl.play],
        androidCompactActionIndices: const [0],
        systemActions: const {
          MediaAction.play,
          MediaAction.pause,
          MediaAction.stop,
          MediaAction.seek,
          MediaAction.rewind,
          MediaAction.fastForward,
        },
      ),
    );

    if (kDebugMode) {
      logger.AppLogger.debug('🎵 PodcastAudioHandler initialized (audioplayers)');
    }
  }

  /// Test-only constructor that skips AudioPlayer creation.
  @visibleForTesting
  PodcastAudioHandler.testOnly() : _player = null;

  final AudioPlayer? _player;
  Duration _currentPosition = Duration.zero;
  Duration? _currentDuration;

  // Position broadcast throttling fields
  DateTime _lastPosEmit = DateTime.fromMillisecondsSinceEpoch(0);
  Duration _lastPos = Duration.zero;

  bool _isDisposed = false;

  // All stream subscriptions to be cancelled on disposal
  final List<StreamSubscription> _subs = [];

  /// Validate and sanitize artUri for Vivo/OriginOS lock screen compatibility
  /// Only returns http/https URLs, returns null for invalid protocols
  static Uri? _validateArtUri(String? urlString) {
    if (urlString == null || urlString.isEmpty) return null;

    final uri = Uri.tryParse(urlString);
    if (uri == null) return null;

    // Vivo/OriginOS lock screen ONLY supports http/https protocols
    // Reject asset://, file://, content://, and other schemes
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      if (kDebugMode) {
        logger.AppLogger.debug(
          '⚠️ [ART_URI] Invalid scheme: ${uri.scheme} (only http/https allowed)',
        );
      }
      return null;
    }

    return uri;
  }

  void _listenPlayerEvents() {
    final player = _player!;
    // Listen to player state changes
    _subs.add(player.onPlayerStateChanged.listen((state) {
      if (_isDisposed) return;
      if (kDebugMode) {
        logger.AppLogger.debug('🎧 PlayerState: $state');
      }
      _broadcastState();
    }));

    // Listen to player complete events
    _subs.add(player.onPlayerComplete.listen((_) {
      if (_isDisposed) return;
      if (kDebugMode) {
        logger.AppLogger.debug('🎧 Player completed');
      }
      // Reset to beginning when complete
      _currentPosition = Duration.zero;
      _broadcastState();
    }));

    // Listen to position changes with throttling
    _subs.add(player.onPositionChanged.listen((position) {
      if (_isDisposed) return;
      final now = DateTime.now();
      final dt = now.difference(_lastPosEmit).inMilliseconds;
      final dp = (position - _lastPos).abs().inMilliseconds;

      // Throttle: 500ms OR position change >= 1000ms
      if (dt < 500 && dp < 1000) return;

      _lastPosEmit = now;
      _lastPos = position;
      _currentPosition = position;
      _broadcastPosition(position: position);
    }));

    // Listen to duration changes
    _subs.add(player.onDurationChanged.listen((duration) {
      if (_isDisposed) return;
      if (kDebugMode) {
        logger.AppLogger.debug('⏱️ [DURATION] Duration changed: ${duration.inMilliseconds}ms');
      }

      final mi = mediaItem.value;
      if (mi != null) {
        _currentDuration = duration;
        // Update MediaItem with new duration
        if (mi.duration != duration) {
          mediaItem.add(mi.copyWith(duration: duration));
          if (kDebugMode) {
            logger.AppLogger.debug('✅ [DURATION] Updated MediaItem duration: ${duration.inMilliseconds}ms');
          }
        }
      }
    }));
  }

  /// Lightweight position-only broadcast
  void _broadcastPosition({Duration? position}) {
    if (_isDisposed) return;
    final pos = position ?? _currentPosition;

    final currentState = playbackState.value;
    playbackState.add(
      currentState.copyWith(
        updatePosition: pos,
        bufferedPosition: pos,
        speed: _player?.playbackRate ?? 1.0,
      ),
    );
  }

  /// Full state broadcast (controls, playing, processingState)
  void _broadcastState() {
    if (_isDisposed) return;
    if (_player == null) return;

    final playing = _player!.state == PlayerState.playing;
    final processingState = _mapProcessingState(_player!.state);
    final updateTime = DateTime.now();

    // Build controls list based on current state
    final hasContent =
        processingState != AudioProcessingState.idle &&
        processingState != AudioProcessingState.loading;

    final controls = hasContent
        ? [
            MediaControl.rewind,
            if (playing) MediaControl.pause else MediaControl.play,
            MediaControl.fastForward,
          ]
        : [MediaControl.play];

    // Set compact action indices based on available controls
    final androidCompactActionIndices = hasContent
        ? const [0, 1, 2] // Show all 3 buttons in compact view
        : const [0]; // Show only play button

    if (kDebugMode) {
      logger.AppLogger.debug(
        '🎵 [BROADCAST STATE] ========================================',
      );
      logger.AppLogger.debug('  playing: $playing');
      logger.AppLogger.debug('  processingState: $processingState');
      logger.AppLogger.debug('  position: ${_currentPosition.inMilliseconds}ms');
      logger.AppLogger.debug('  duration: ${_currentDuration?.inMilliseconds ?? 0}ms');
      logger.AppLogger.debug('  speed: ${_player!.playbackRate}x');
      logger.AppLogger.debug('  updateTime: $updateTime');
      logger.AppLogger.debug(
        '🎵 [BROADCAST STATE] ========================================',
      );
    }

    playbackState.add(
      PlaybackState(
        controls: controls,
        androidCompactActionIndices: androidCompactActionIndices,
        playing: playing,
        processingState: processingState,
        updatePosition: _currentPosition,
        bufferedPosition: _currentPosition,
        speed: _player?.playbackRate ?? 1.0,
        updateTime: updateTime,
        systemActions: const {
          MediaAction.play,
          MediaAction.pause,
          MediaAction.stop,
          MediaAction.seek,
          MediaAction.rewind,
          MediaAction.fastForward,
        },
      ),
    );
  }

  AudioProcessingState _mapProcessingState(PlayerState state) {
    switch (state) {
      case PlayerState.stopped:
        return AudioProcessingState.idle;
      case PlayerState.disposed:
        return AudioProcessingState.idle;
      case PlayerState.playing:
      case PlayerState.paused:
        return AudioProcessingState.ready;
      case PlayerState.completed:
        return AudioProcessingState.completed;
    }
  }

  Future<void> _setAudioSourceWithCache(String url) async {
    if (_player == null) return;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      await _player!.setSourceUrl(url);
      return;
    }

    try {
      final cached = await AppMediaCacheManager.instance.getFileFromCache(url);
      final file = cached?.file;
      if (file != null && await file.exists()) {
        await _player!.setSource(DeviceFileSource(file.path));
        return;
      }
    } catch (e) {
      // Cache miss or error - fall back to direct URL
      if (kDebugMode) {
        logger.AppLogger.debug('⚠️ Cache lookup failed for $url: $e');
      }
    }

    // Download in background for future use
    Future(() async {
      try {
        await AppMediaCacheManager.instance.downloadFile(url);
      } catch (e) {
        // Background download failed - not critical, audio will still play
        if (kDebugMode) {
          logger.AppLogger.debug('⚠️ Background cache download failed: $e');
        }
      }
    });

    await _player!.setSourceUrl(url);
  }

  /// Set episode with full metadata support
  Future<void> setEpisode({
    required String id,
    required String url,
    required String title,
    String? artist,
    String? album,
    String? artUri,
    Duration? durationHint,
    Map<String, dynamic>? extras,
    bool autoPlay = false,
  }) async {
    // CRITICAL: Validate artUri - ONLY http/https URLs allowed for Vivo/OriginOS
    final validArtUri = artUri != null ? _validateArtUri(artUri) : null;

    if (artUri != null && validArtUri == null && kDebugMode) {
      logger.AppLogger.debug(
        '⚠️ [SET_EPISODE] Invalid artUri format: "$artUri" (must be http/https)',
      );
    }

    // 1) Push MediaItem FIRST
    final newMediaItem = MediaItem(
      id: id,
      title: title,
      artist: artist ?? 'Unknown',
      album: album,
      artUri: validArtUri,
      duration: durationHint,
      extras: <String, dynamic>{
        'url': url,
        ...?extras,
      },
    );

    mediaItem.add(newMediaItem);

    if (kDebugMode) {
      logger.AppLogger.debug('📋 [MediaItem] Set:');
      logger.AppLogger.debug('  id: ${newMediaItem.id}');
      logger.AppLogger.debug('  title: ${newMediaItem.title}');
      logger.AppLogger.debug('  artist: ${newMediaItem.artist}');
      logger.AppLogger.debug('  artUri: ${newMediaItem.artUri ?? "NULL"}');
      logger.AppLogger.debug('  duration: ${newMediaItem.duration?.inMilliseconds ?? "NULL"}ms');
      logger.AppLogger.debug('  url: $url');
    }

    // 2) Set source URL
    try {
      await _setAudioSourceWithCache(url);
      if (kDebugMode) {
        logger.AppLogger.debug('✅ Audio source set: $url${validArtUri != null ? ' with cover' : ' (no cover)'}');
      }
    } catch (e) {
      if (kDebugMode) {
        logger.AppLogger.debug('❌ Failed to set audio source: $e');
      }
      rethrow;
    }

    // 3) Broadcast state immediately
    _broadcastState();

    if (autoPlay) {
      await play();
    }
  }

  /// Legacy method for backward compatibility
  @Deprecated(
    'Use setEpisode() with full metadata for proper lock screen display',
  )
  Future<void> setAudioSource(String url) async {
    mediaItem.add(
      MediaItem(
        id: url,
        title: 'Audio Playback',
        artist: 'Unknown',
        extras: <String, dynamic>{'url': url},
      ),
    );

    try {
      await _setAudioSourceWithCache(url);
      _broadcastState();

      if (kDebugMode) {
        logger.AppLogger.debug('✅ Audio source set: $url');
      }
    } catch (e) {
      if (kDebugMode) {
        logger.AppLogger.debug('❌ Failed to set audio source: $e');
      }
      rethrow;
    }
  }

  @override
  Future<void> play() async {
    if (_isDisposed) {
      if (kDebugMode) {
        logger.AppLogger.debug('⚠️ play() called after disposal, ignoring');
      }
      return;
    }

    try {
      await _player?.resume();
      if (kDebugMode) {
        logger.AppLogger.debug('▶️ Playback started');
      }
      _broadcastState();
    } catch (e) {
      if (kDebugMode) {
        logger.AppLogger.debug('❌ Failed to start playback: $e');
      }
      rethrow;
    }
  }

  @override
  Future<void> pause() async {
    if (_isDisposed) {
      if (kDebugMode) {
        logger.AppLogger.debug('⚠️ pause() called after disposal, ignoring');
      }
      return;
    }

    await _player?.pause();

    if (kDebugMode) {
      logger.AppLogger.debug('⏸️ Playback paused');
    }

    _broadcastState();
  }

  @override
  Future<void> stop() async {
    if (_isDisposed) {
      if (kDebugMode) {
        logger.AppLogger.debug('⚠️ stop() called after disposal, ignoring');
      }
      return;
    }

    if (kDebugMode) {
      logger.AppLogger.debug('⏹️ stop() called - stopping playback');
    }

    await _player?.stop();
    _currentPosition = Duration.zero;

    if (kDebugMode) {
      logger.AppLogger.debug('✅ stop() completed');
    }
  }

  /// Complete stop - stops playback AND stops the AudioService
  Future<void> stopService() async {
    if (_isDisposed) return;
    _isDisposed = true;

    if (kDebugMode) {
      logger.AppLogger.debug('🛑 stopService() called - stopping audio playback');
    }

    // Cancel all subscriptions FIRST
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();

    // Stop and dispose player
    try {
      await _player?.stop();
      await _player?.dispose();
    } catch (e) {
      if (kDebugMode) {
        logger.AppLogger.debug('⚠️ Error disposing player: $e');
      }
    }

    // Stop the AudioService foreground service (mobile only)
    try {
      await super.stop();
      if (kDebugMode) {
        logger.AppLogger.debug('✅ AudioService stopped (mobile)');
      }
    } catch (e) {
      if (kDebugMode) {
        logger.AppLogger.debug('ℹ️ AudioService stop skipped (desktop or already stopped): $e');
      }
    }

    // Clear MediaSession state
    try {
      playbackState.add(
        PlaybackState(
          controls: [],
        ),
      );
      mediaItem.add(null);
    } catch (e) {
      if (kDebugMode) {
        logger.AppLogger.debug('ℹ️ State clearing after stop (expected): $e');
      }
    }

    if (kDebugMode) {
      logger.AppLogger.debug('✅ stopService() completed');
    }
  }

  @override
  Future<void> seek(Duration position) async {
    await _player?.seek(position);
    _currentPosition = position;
    _broadcastPosition(position: position);
  }

  @override
  Future<void> rewind() async {
    final newPosition = _currentPosition - const Duration(seconds: 15);
    final clampedPosition = newPosition < Duration.zero
        ? Duration.zero
        : newPosition;
    await _player?.seek(clampedPosition);
    _currentPosition = clampedPosition;
    _broadcastPosition(position: clampedPosition);
  }

  @override
  Future<void> fastForward() async {
    final duration = _currentDuration ?? Duration.zero;
    final newPosition = _currentPosition + const Duration(seconds: 30);
    final clampedPosition = newPosition > duration ? duration : newPosition;
    await _player?.seek(clampedPosition);
    _currentPosition = clampedPosition;
    _broadcastPosition(position: clampedPosition);
  }

  @override
  Future<void> setSpeed(double speed) async {
    await _player?.setPlaybackRate(speed);
    _broadcastPosition();
  }

  // Volume control (desktop-oriented; mobile typically uses hardware keys).
  double _volume = 1;

  /// Get current volume level (0.0 to 1.0).
  double get volume => _volume;

  /// Set volume to [level] (clamped to 0.0-1.0).
  Future<void> setVolume(double level) async {
    if (_isDisposed) return;
    final clamped = level.clamp(0.0, 1.0);
    await _player?.setVolume(clamped);
    _volume = clamped;
  }

  /// Increase volume by [step] (default 0.1). Clamped at 1.0.
  Future<void> volumeUp({double step = 0.1}) async {
    await setVolume(_volume + step);
  }

  /// Decrease volume by [step] (default 0.1). Clamped at 0.0.
  Future<void> volumeDown({double step = 0.1}) async {
    await setVolume(_volume - step);
  }

  /// Get current position
  Duration get position => _currentPosition;

  /// Get duration
  Duration? get duration => _currentDuration;

  /// Get playing state
  bool get playing => _player?.state == PlayerState.playing;

  /// Get player state stream
  Stream<PlayerState> get playerStateStream =>
      _player?.onPlayerStateChanged ?? const Stream.empty();

  /// Get position stream
  Stream<Duration> get positionStream =>
      _player?.onPositionChanged ?? const Stream.empty();

  /// Get duration stream
  Stream<Duration?> get durationStream =>
      _player?.onDurationChanged ?? const Stream.empty();

  @override
  Future<void> onTaskRemoved() async {
    if (kDebugMode) {
      logger.AppLogger.debug('🗑️ Task removed - stopping service and cleaning up');
    }
    await stopService();
  }

  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }

    _isDisposed = true;

    if (kDebugMode) {
      logger.AppLogger.debug('🗑️ Disposing AudioHandler...');
    }

    // Cancel all stream subscriptions
    final subCount = _subs.length;
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();

    if (kDebugMode) {
      logger.AppLogger.debug('   - $subCount subscriptions cancelled');
    }

    // Release AudioPlayer
    try {
      await _player?.dispose();
      if (kDebugMode) {
        logger.AppLogger.debug('   - Audio player disposed');
      }
    } catch (e) {
      if (kDebugMode) {
        logger.AppLogger.debug('   - Error disposing player: $e');
      }
    }

    if (kDebugMode) {
      logger.AppLogger.debug('✅ AudioHandler disposed');
    }
  }
}
