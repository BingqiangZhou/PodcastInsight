import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../utils/app_logger.dart' as logger;

part 'connectivity_provider.g.dart';

/// Connectivity state representing network status
class ConnectivityState {
  const ConnectivityState({
    required this.isOnline,
    required this.connectionType,
    this.lastChangedAt,
  });

  final bool isOnline;
  final List<ConnectivityResult> connectionType;
  final DateTime? lastChangedAt;

  ConnectivityState copyWith({
    bool? isOnline,
    List<ConnectivityResult>? connectionType,
    DateTime? lastChangedAt,
  }) {
    return ConnectivityState(
      isOnline: isOnline ?? this.isOnline,
      connectionType: connectionType ?? this.connectionType,
      lastChangedAt: lastChangedAt ?? this.lastChangedAt,
    );
  }

  @override
  String toString() =>
      'ConnectivityState(isOnline: $isOnline, type: $connectionType)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConnectivityState &&
          runtimeType == other.runtimeType &&
          isOnline == other.isOnline;

  @override
  int get hashCode => isOnline.hashCode;
}

/// Provider for network connectivity monitoring
@riverpod
class ConnectivityNotifier extends _$ConnectivityNotifier {
  Connectivity get _connectivity => Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  ConnectivityState build() {

    // Start listening to connectivity changes
    _startMonitoring();

    ref.onDispose(() {
      _connectivitySubscription?.cancel();
    });

    // Return initial state - assume online until we know otherwise
    return const ConnectivityState(
      isOnline: true,
      connectionType: [],
      lastChangedAt: null,
    );
  }

  void _startMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        final isOnline = _isOnline(results);
        logger.AppLogger.debug(
          'Connectivity changed: ${isOnline ? "online" : "offline"} ($results)',
          tag: 'Connectivity',
        );
        state = state.copyWith(
          isOnline: isOnline,
          connectionType: results,
          lastChangedAt: DateTime.now(),
        );
      },
      onError: (error) {
        // Treat errors as offline for safety
        logger.AppLogger.error(
          'Connectivity error: $error',
          tag: 'Connectivity',
        );
        state = state.copyWith(
          isOnline: false,
          connectionType: [ConnectivityResult.none],
          lastChangedAt: DateTime.now(),
        );
      },
    );
  }

  bool _isOnline(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((result) =>
        result != ConnectivityResult.none &&
        result != ConnectivityResult.other);
  }

  /// Manually refresh connectivity status
  Future<void> refresh() async {
    final results = await _connectivity.checkConnectivity();
    final isOnline = _isOnline(results);
    state = state.copyWith(
      isOnline: isOnline,
      connectionType: results,
      lastChangedAt: DateTime.now(),
    );
  }
}

/// Simple boolean provider for online status
@riverpod
bool isOnline(Ref ref) {
  return ref.watch(connectivityProvider).isOnline;
}

/// Simple boolean provider for offline status
@riverpod
bool isOffline(Ref ref) {
  return !ref.watch(connectivityProvider).isOnline;
}
