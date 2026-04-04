import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A monotonically increasing counter that is bumped every time the server
/// configuration changes (i.e. the user switches to a different backend).
///
/// Feature-layer providers can [ref.listen] on this provider to react to
/// server switches and perform their own cleanup (clearing caches,
/// invalidating state, etc.) without the core layer needing to import from
/// any feature module.
class ServerConfigVersionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  /// Increment the version counter, signalling a server-config change.
  void bump() => state++;
}

final serverConfigVersionProvider =
    NotifierProvider<ServerConfigVersionNotifier, int>(
  ServerConfigVersionNotifier.new,
);
