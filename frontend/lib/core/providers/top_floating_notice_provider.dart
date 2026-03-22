import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Internal state for top floating notice
class TopFloatingNoticeState {
  final OverlayEntry? entry;
  final Timer? timer;

  const TopFloatingNoticeState({this.entry, this.timer});

  TopFloatingNoticeState copyWith({OverlayEntry? entry, Timer? timer}) {
    return TopFloatingNoticeState(
      entry: entry ?? this.entry,
      timer: timer ?? this.timer,
    );
  }
}

/// Provider for managing top floating notice state
///
/// This replaces the global variables `_activeTopNoticeEntry` and
/// `_activeTopNoticeTimer` with proper state management.
final topFloatingNoticeProvider =
    NotifierProvider<TopFloatingNoticeNotifier, TopFloatingNoticeState>(
  TopFloatingNoticeNotifier.new,
);

/// Notifier for managing top floating notice lifecycle
class TopFloatingNoticeNotifier extends Notifier<TopFloatingNoticeState> {
  OverlayEntry? _cachedEntry;
  Timer? _cachedTimer;

  @override
  TopFloatingNoticeState build() {
    ref.onDispose(() {
      // Clean up resources when provider is disposed
      _cachedEntry?.remove();
      _cachedTimer?.cancel();
    });
    return const TopFloatingNoticeState();
  }

  /// Show a new top floating notice, replacing any existing one
  void showNotice({
    required OverlayEntry entry,
    required Duration duration,
  }) {
    // Remove existing notice
    _removeCurrentNotice();

    // Create and schedule removal timer
    final timer = Timer(duration, _removeCurrentNotice);

    _cachedEntry = entry;
    _cachedTimer = timer;
    state = state.copyWith(entry: entry, timer: timer);
  }

  /// Remove the current notice and clean up resources
  void _removeCurrentNotice() {
    _cachedTimer?.cancel();
    _cachedEntry?.remove();
    _cachedTimer = null;
    _cachedEntry = null;
    state = const TopFloatingNoticeState();
  }

  /// Programmatically hide the current notice
  void hideNotice() {
    _removeCurrentNotice();
  }

  /// Check if a notice is currently visible
  bool get isVisible => _cachedEntry != null;
}
