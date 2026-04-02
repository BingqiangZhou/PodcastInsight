import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Provides keyboard shortcuts for media playback on desktop platforms.
///
/// Wrap the main content area with this widget to enable:
/// - Space: Toggle play/pause
/// - Left arrow: Seek back 10 seconds
/// - Right arrow: Seek forward 30 seconds
/// - J / K: Seek back / forward 10 seconds
///
/// Only active when [enabled] is true (typically when a text field is NOT focused).
class PlaybackShortcuts extends StatelessWidget {
  const PlaybackShortcuts({
    super.key,
    required this.child,
    required this.onTogglePlayPause,
    required this.onSeekBackward,
    required this.onSeekForward,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onSeekBackward;
  final VoidCallback onSeekForward;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.space): const _TogglePlayPauseIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft): const _SeekBackwardIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowRight): const _SeekForwardIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyJ): const _SeekBackwardIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyK): const _SeekForwardIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _TogglePlayPauseIntent: _CallbackAction(onTogglePlayPause),
          _SeekBackwardIntent: _CallbackAction(onSeekBackward),
          _SeekForwardIntent: _CallbackAction(onSeekForward),
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

class _CallbackAction extends Action<Intent> {
  _CallbackAction(this.callback);

  final VoidCallback callback;

  @override
  Object? invoke(Intent intent) {
    callback();
    return null;
  }
}
