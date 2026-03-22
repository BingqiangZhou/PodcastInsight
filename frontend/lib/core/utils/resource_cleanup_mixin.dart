import 'dart:async';
import 'package:flutter/widgets.dart';

/// Mixin for managing and cleaning up disposable resources like
/// StreamSubscription and Timer in StatefulWidget State classes.
///
/// Usage:
/// ```dart
/// class MyWidgetState extends ConsumerState<MyWidget>
///     with ResourceCleanupMixin {
///
///   @override
///   void initState() {
///     super.initState();
///     final subscription = someStream.listen(_onData);
///     registerSubscription(subscription);
///
///     final timer = Timer(const Duration(seconds: 5), _onTimeout);
///     registerTimer(timer);
///   }
/// }
/// ```
mixin ResourceCleanupMixin<T extends StatefulWidget> on State<T> {
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final List<Timer> _timers = [];

  /// Register a StreamSubscription to be automatically canceled on dispose.
  ///
  /// Call this when creating a new StreamSubscription to ensure it will be
  /// properly cleaned up when the widget is disposed.
  void registerSubscription(StreamSubscription<dynamic> sub) {
    _subscriptions.add(sub);
  }

  /// Register a Timer to be automatically canceled on dispose.
  ///
  /// Call this when creating a new Timer to ensure it will be properly
  /// cleaned up when the widget is disposed.
  void registerTimer(Timer timer) {
    _timers.add(timer);
  }

  @override
  void dispose() {
    // Cancel all registered subscriptions
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

    // Cancel all registered timers
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();

    super.dispose();
  }
}
