import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Provides keyboard shortcuts for media playback on desktop platforms.
///
/// Wrap the main content area with this widget to enable:
/// - Space: Toggle play/pause
/// - Left arrow: Seek back 10 seconds
/// - Right arrow: Seek forward 30 seconds
/// - J / K: Seek back / forward 10 seconds
/// - Up arrow: Volume up
/// - Down arrow: Volume down
/// - N / MediaTrackNext: Next episode
/// - P / MediaTrackPrevious: Previous episode
///
/// Only active when [enabled] is true (typically when a text field is NOT focused).
class PlaybackShortcuts extends StatelessWidget {
  const PlaybackShortcuts({
    required this.child, required this.onTogglePlayPause, required this.onSeekBackward, required this.onSeekForward, super.key,
    this.onVolumeUp,
    this.onVolumeDown,
    this.onNextEpisode,
    this.onPreviousEpisode,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onSeekBackward;
  final VoidCallback onSeekForward;
  final VoidCallback? onVolumeUp;
  final VoidCallback? onVolumeDown;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onPreviousEpisode;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.space):
            const _TogglePlayPauseIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft):
            const _SeekBackwardIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowRight):
            const _SeekForwardIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyJ):
            const _SeekBackwardIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyK):
            const _SeekForwardIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowUp): const _VolumeUpIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowDown): const _VolumeDownIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyN): const _NextEpisodeIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyP): const _PreviousEpisodeIntent(),
        LogicalKeySet(LogicalKeyboardKey.mediaTrackNext):
            const _NextEpisodeIntent(),
        LogicalKeySet(LogicalKeyboardKey.mediaTrackPrevious):
            const _PreviousEpisodeIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _TogglePlayPauseIntent: _CallbackAction(onTogglePlayPause),
          _SeekBackwardIntent: _CallbackAction(onSeekBackward),
          _SeekForwardIntent: _CallbackAction(onSeekForward),
          if (onVolumeUp != null)
            _VolumeUpIntent: _CallbackAction(onVolumeUp!),
          if (onVolumeDown != null)
            _VolumeDownIntent: _CallbackAction(onVolumeDown!),
          if (onNextEpisode != null)
            _NextEpisodeIntent: _CallbackAction(onNextEpisode!),
          if (onPreviousEpisode != null)
            _PreviousEpisodeIntent: _CallbackAction(onPreviousEpisode!),
        },
        child: child,
      ),
    );
  }
}

class _TogglePlayPauseIntent extends Intent {
  const _TogglePlayPauseIntent();
}

class _SeekBackwardIntent extends Intent {
  const _SeekBackwardIntent();
}

class _SeekForwardIntent extends Intent {
  const _SeekForwardIntent();
}

class _VolumeUpIntent extends Intent {
  const _VolumeUpIntent();
}

class _VolumeDownIntent extends Intent {
  const _VolumeDownIntent();
}

class _NextEpisodeIntent extends Intent {
  const _NextEpisodeIntent();
}

class _PreviousEpisodeIntent extends Intent {
  const _PreviousEpisodeIntent();
}

class _CallbackAction extends Action<Intent> {
  _CallbackAction(this.callback);

  final VoidCallback callback;

  @override
  Object? invoke(Intent intent) {
    callback();
    return null;
  }
}
