import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_ai_assistant/core/events/server_config_events.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_discover_provider.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_episodes_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_feed_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_search_provider.dart' as search;
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_stats_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_subscription_providers.dart';

/// Keeps the podcast feature layer in sync with server-config changes.
///
/// When the user switches backend servers, [serverConfigVersionProvider] is
/// bumped by the core layer.  This provider listens for that change and
/// performs all podcast-specific cleanup (clearing caches, resetting state,
/// invalidating providers).
///
/// This provider MUST be loaded early (e.g. in the app shell or main widget)
/// so that it starts listening before any server switch can happen.
final podcastServerConfigListenerProvider = Provider<void>((ref) {
  ref.listen<int>(serverConfigVersionProvider, (previous, next) {
    if (previous == null || previous == next) return;

    // --- Clear runtime caches ---
    ref.read(podcastDiscoverProvider.notifier).clearRuntimeCache();
    ref.read(search.iTunesSearchServiceProvider).clearCache();

    // --- Reset notifier states before invalidating ---
    ref.read(profileStatsProvider.notifier).reset();
    ref.read(playbackHistoryLiteProvider.notifier).reset();

    // --- Invalidate all server-related podcast providers ---
    ref.invalidate(podcastFeedProvider);
    ref.invalidate(podcastDiscoverProvider);
    ref.invalidate(podcastSubscriptionProvider);
    ref.invalidate(podcastEpisodesProvider);
    ref.invalidate(profileStatsProvider);
    ref.invalidate(playbackHistoryLiteProvider);
    ref.invalidate(search.podcastSearchProvider);
  });
});
