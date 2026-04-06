part of 'podcast_playback_providers.dart';

/// Playback rate management extension for AudioPlayerNotifier.
///
/// Handles setting, resolving, and caching playback speed preferences
/// for both global and per-subscription contexts.
extension AudioPlaybackRateNotifier on AudioPlayerNotifier {
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

      await setAudioSpeed(rate);
      final applied = await _repository.applyPlaybackRatePreference(
        playbackRate: rate,
        applyToSubscription: applyToSubscription,
        subscriptionId: currentEpisode?.subscriptionId,
      );

      if (ref.mounted && !_isDisposed) {
        state = state.copyWith(
          playbackRate: applied.effectivePlaybackRate,
          currentEpisode: currentEpisode?.copyWith(
            playbackRate: applied.effectivePlaybackRate,
          ),
        );
        _cachePlaybackRateSelection(
          speed: applied.effectivePlaybackRate,
          applyToSubscription:
              currentEpisode != null && applied.source == 'subscription',
          subscriptionId: currentEpisode?.subscriptionId,
        );
        if (currentEpisode != null &&
            shouldSyncPlaybackToServer(currentEpisode)) {
          await _syncImmediatePlaybackSnapshot(
            episode: currentEpisode.copyWith(
              playbackRate: applied.effectivePlaybackRate,
            ),
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

  Future<PlaybackRateEffectiveResponse?> _fetchEffectivePlaybackRatePreference({
    int? subscriptionId,
  }) async {
    try {
      return await _repository.getEffectivePlaybackRate(
        subscriptionId: subscriptionId,
      );
    } catch (error) {
      logger.AppLogger.debug(
        'Failed to resolve effective playback rate, using fallback value: $error',
      );
      return null;
    }
  }

  Future<double> _resolveEffectivePlaybackRate({
    required double fallbackRate, int? subscriptionId,
  }) async {
    final effective = await _fetchEffectivePlaybackRatePreference(
      subscriptionId: subscriptionId,
    );
    final fallbackSelection = _fallbackPlaybackRateSelection(
      subscriptionId: subscriptionId,
      fallbackRate: fallbackRate,
    );
    final resolvedPlaybackRate =
        effective?.effectivePlaybackRate ?? fallbackRate;
    _cachePlaybackRateSelection(
      speed: resolvedPlaybackRate,
      applyToSubscription: subscriptionId != null && (effective?.source == 'subscription' ||
                (effective == null && fallbackSelection.applyToSubscription)),
      subscriptionId: subscriptionId,
    );
    return resolvedPlaybackRate;
  }

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

  PlaybackRateSelectionSnapshot _fallbackPlaybackRateSelection({
    required int? subscriptionId,
    required double fallbackRate,
  }) {
    final cachedSelection = _playbackRateSelectionCache;
    if (cachedSelection == null) {
      return (speed: fallbackRate, applyToSubscription: false);
    }
    if (!cachedSelection.applyToSubscription) {
      return (speed: fallbackRate, applyToSubscription: false);
    }
    if (subscriptionId != null &&
        cachedSelection.subscriptionId == subscriptionId) {
      return (speed: fallbackRate, applyToSubscription: true);
    }
    return (speed: fallbackRate, applyToSubscription: false);
  }

  void _cachePlaybackRateSelection({
    required double speed,
    required bool applyToSubscription,
    int? subscriptionId,
  }) {
    _playbackRateSelectionCache = _PlaybackRateSelectionCache(
      speed: speed,
      applyToSubscription: applyToSubscription && subscriptionId != null,
      subscriptionId: applyToSubscription ? subscriptionId : null,
    );
  }
}

class _PlaybackRateSelectionCache {
  const _PlaybackRateSelectionCache({
    required this.speed,
    required this.applyToSubscription,
    required this.subscriptionId,
  });

  final double speed;
  final bool applyToSubscription;
  final int? subscriptionId;
}
