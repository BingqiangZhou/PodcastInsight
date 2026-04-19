part of 'podcast_playback_providers.dart';

/// Sleep timer extension for AudioPlayerNotifier.
///
/// Sleep timer is intentionally session-local and must not sync to backend.
extension AudioSleepTimerNotifier on AudioPlayerNotifier {
  void setSleepTimer(Duration duration) {
    if (_isDisposed || !ref.mounted) return;
    if (duration <= Duration.zero) {
      cancelSleepTimer();
      return;
    }

    _timers.cancel(AudioPlayerNotifier._kSleepTimerTick);

    final endTime = DateTime.now().add(duration);
    state = state.copyWith(
      sleepTimerEndTime: endTime,
      sleepTimerAfterEpisode: false,
      sleepTimerRemainingLabel: _formatRemainingTime(duration),
    );

    logger.AppLogger.debug(
      '[Sleep Timer] Sleep timer set: ${duration.inMinutes} minutes',
    );

    _timers.createPeriodic(
      AudioPlayerNotifier._kSleepTimerTick,
      const Duration(seconds: 1),
      (_) => _onSleepTimerTick(),
    );
  }

  void setSleepTimerAfterEpisode() {
    if (_isDisposed || !ref.mounted) return;

    _timers.cancel(AudioPlayerNotifier._kSleepTimerTick);

    if (state.sleepTimerAfterEpisode && state.sleepTimerEndTime == null) {
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
    if (!state.isSleepTimerActive && !_timers.isActive(AudioPlayerNotifier._kSleepTimerTick)) {
      return;
    }

    _timers.cancel(AudioPlayerNotifier._kSleepTimerTick);

    state = state.copyWith(clearSleepTimer: true);

    logger.AppLogger.debug('[Sleep Timer] Sleep timer cancelled');
  }

  void _onSleepTimerTick() {
    if (_isDisposed || !ref.mounted) return;

    final endTime = state.sleepTimerEndTime;
    if (endTime == null) {
      _timers.cancel(AudioPlayerNotifier._kSleepTimerTick);
      return;
    }

    final remaining = endTime.difference(DateTime.now());
    if (remaining.isNegative || remaining.inSeconds <= 0) {
      logger.AppLogger.debug(
        '[Sleep Timer] Sleep timer expired, pausing playback',
      );
      _timers.cancel(AudioPlayerNotifier._kSleepTimerTick);
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
    return TimeFormatter.formatDuration(d, padHours: false);
  }
}
