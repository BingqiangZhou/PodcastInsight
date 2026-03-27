import 'dart:async';
import 'package:flutter/foundation.dart';

/// Authentication event type
enum AuthEventType {
  /// Token was cleared (user needs to re-login)
  tokenCleared,
  /// Token was refreshed successfully
  tokenRefreshed,
}

/// Authentication event data
class AuthEvent {
  final AuthEventType type;
  final String? message;
  final DateTime timestamp;

  AuthEvent({
    required this.type,
    this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    return 'AuthEvent{type: $type, message: $message, timestamp: $timestamp}';
  }
}

/// Global authentication event notifier
///
/// This allows different parts of the app to communicate about
/// authentication state changes without creating circular dependencies.
///
/// **Lifecycle Notes:**
/// - This is a singleton that lives for the app's lifetime
/// - The stream is a broadcast stream, so multiple listeners are supported
/// - Call dispose() only when the app is shutting down
///
/// Usage:
/// ```dart
/// // Listen to auth events
/// AuthEventNotifier.instance.authEventStream.listen((event) {
///   if (event.type == AuthEventType.tokenCleared) {
///     // Update auth state
///   }
/// });
///
/// // Broadcast auth event
/// AuthEventNotifier.instance.notify(AuthEvent(
///   type: AuthEventType.tokenCleared,
///   message: 'Token expired',
/// ));
/// ```
class AuthEventNotifier {
  AuthEventNotifier._privateConstructor();

  static final AuthEventNotifier _instance = AuthEventNotifier._privateConstructor();

  /// Global singleton instance
  static AuthEventNotifier get instance => _instance;

  final _controller = StreamController<AuthEvent>.broadcast();

  /// Stream of authentication events.
  ///
  /// This is a broadcast stream from [_controller]. It is safe to listen
  /// to this stream from multiple places simultaneously. Each call returns
  /// the same underlying broadcast stream (no new subscriptions are created
  /// by the getter itself).
  Stream<AuthEvent> get authEventStream => _controller.stream;

  /// Whether the underlying stream controller has been closed.
  bool get isClosed => _controller.isClosed;

  /// Broadcast an authentication event
  void notify(AuthEvent event) {
    if (kDebugMode) {
      debugPrint('[AuthEvent] ${event.type}: ${event.message ?? "no message"}');
    }
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  /// Dispose the stream controller.
  ///
  /// Should only be called during app shutdown.
  void dispose() {
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}
