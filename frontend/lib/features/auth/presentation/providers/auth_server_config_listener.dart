import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_ai_assistant/core/events/server_config_events.dart';
import 'package:personal_ai_assistant/features/auth/presentation/providers/auth_provider.dart';

/// Keeps the auth feature layer in sync with server-config changes.
///
/// When the user switches backend servers, [serverConfigVersionProvider] is
/// bumped by the core layer.  This provider listens for that change and
/// clears local auth state (tokens, session) so the user is redirected to
/// the login screen for the new server.
///
/// This removes the need for [core_providers] to import the auth feature,
/// preserving the core -> feature dependency boundary.
///
/// This provider MUST be loaded early (e.g. in the app shell or main widget)
/// so that it starts listening before any server switch can happen.
final authServerConfigListenerProvider = Provider<void>((ref) {
  ref.listen<int>(serverConfigVersionProvider, (previous, next) {
    if (previous == null || previous == next) return;

    ref.read(authProvider.notifier).clearLocalAuthState();
  });
});
