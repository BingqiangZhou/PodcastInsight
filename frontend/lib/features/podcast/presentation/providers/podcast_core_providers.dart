import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_ai_assistant/core/events/server_config_events.dart';
import 'package:personal_ai_assistant/core/providers/core_providers.dart';
import 'package:personal_ai_assistant/features/podcast/data/repositories/podcast_repository.dart';
import 'package:personal_ai_assistant/features/podcast/data/services/podcast_api_service.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/audio_handler.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_daily_report_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_discover_provider.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_episodes_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_feed_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_highlights_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_search_provider.dart' as search;
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_stats_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_subscription_providers.dart';

final podcastApiServiceProvider = Provider<PodcastApiService>((ref) {
  final dio = ref.read(dioClientProvider).dio;
  return PodcastApiService(dio);
});

final podcastRepositoryProvider = Provider<PodcastRepository>((ref) {
  final apiService = ref.read(podcastApiServiceProvider);
  return PodcastRepository(apiService);
});

/// Provides the singleton [PodcastAudioHandler] managed by Riverpod.
///
/// The handler is created once and shared across all features that need
/// audio playback. It is disposed when the provider scope is disposed.
final audioHandlerProvider = Provider<PodcastAudioHandler>((ref) {
  final handler = PodcastAudioHandler();
  ref.onDispose(handler.stopService);
  return handler;
});

// ---------------------------------------------------------------------------
// Server config listener (moved from podcast_server_config_listener.dart)
// ---------------------------------------------------------------------------

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
    ref.invalidate(podcastStatsProvider);
    ref.invalidate(dailyReportProvider);
    ref.invalidate(dailyReportDatesProvider);
    ref.invalidate(highlightsProvider);
    ref.invalidate(highlightDatesProvider);
    ref.invalidate(search.podcastSearchProvider);
  });
});
