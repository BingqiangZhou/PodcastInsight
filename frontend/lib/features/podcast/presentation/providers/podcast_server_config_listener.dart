import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_ai_assistant/core/providers/core_providers.dart';
import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_discover_provider.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_episodes_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_feed_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_search_provider.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_stats_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_subscription_providers.dart';

/// Listener provider that watches [serverConfigChangedProvider] and
/// invalidates all podcast-related caches when the server config changes.
///
/// This decouples the core layer from the feature layer: core broadcasts a
/// signal, and each feature layer listens and handles its own cleanup.
final podcastServerConfigListenerProvider = Provider<void>((ref) {
  ref.listen<int>(serverConfigChangedProvider, (previous, next) {
    logger.AppLogger.debug(
      'Server config changed (signal $previous->$next), '
      'invalidating podcast providers',
    );

    // Clear runtime caches
    ref.read(podcastDiscoverProvider.notifier).clearRuntimeCache();
    ref.read(iTunesSearchServiceProvider).clearCache();

    // Reset stats notifiers before invalidating
    ref.read(profileStatsProvider.notifier).reset();
    ref.read(playbackHistoryLiteProvider.notifier).reset();

    // Invalidate all server-dependent podcast providers
    ref.invalidate(podcastFeedProvider);
    ref.invalidate(podcastDiscoverProvider);
    ref.invalidate(podcastSubscriptionProvider);
    ref.invalidate(podcastEpisodesProvider);
    ref.invalidate(profileStatsProvider);
    ref.invalidate(playbackHistoryLiteProvider);
    ref.invalidate(podcastSearchProvider);
  });
});
