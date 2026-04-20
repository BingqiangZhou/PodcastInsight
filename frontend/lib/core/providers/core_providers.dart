import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/app/config/app_config.dart';
import 'package:personal_ai_assistant/core/network/dio_client.dart';
import 'package:personal_ai_assistant/core/utils/url_normalizer.dart';
import 'package:personal_ai_assistant/core/network/server_health_service.dart';
import 'package:personal_ai_assistant/core/services/app_cache_service.dart';
import 'package:personal_ai_assistant/core/storage/local_storage_service.dart';
import 'package:personal_ai_assistant/features/auth/presentation/providers/auth_provider.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_daily_report_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_discover_provider.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_episodes_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_feed_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_highlights_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_search_provider.dart' as search;
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_stats_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_subscription_providers.dart';

// Dio Client Provider
final dioClientProvider = Provider<DioClient>((ref) {
  final client = DioClient();
  ref.onDispose(client.dispose);
  return client;
});

final appCacheServiceProvider = Provider<AppCacheService>((ref) {
  // Initialize cache service with optimized memory settings
  AppCacheServiceImpl.initialize();

  return AppCacheServiceImpl();
});

typedef ServerHealthServiceFactory = ServerHealthService Function();

final serverHealthServiceFactoryProvider = Provider<ServerHealthServiceFactory>(
  (ref) {
    return () => ServerHealthService(Dio());
  },
);

// Server Config Provider - Manages backend server address configuration
class ServerConfigState {

  const ServerConfigState({
    required this.serverUrl,
    this.isLoading = false,
    this.error,
  });
  final String serverUrl;
  final bool isLoading;
  final String? error;

  ServerConfigState copyWith({
    String? serverUrl,
    bool? isLoading,
    String? error,
  }) {
    return ServerConfigState(
      serverUrl: serverUrl ?? this.serverUrl,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ServerConfigNotifier extends Notifier<ServerConfigState> {
  LocalStorageService get _storageService => ref.read(localStorageServiceProvider);

  @override
  ServerConfigState build() {
    // Get initial server URL from AppConfig
    final initialUrl = AppConfig.serverBaseUrl;
    return ServerConfigState(serverUrl: initialUrl);
  }

  /// Clear all server-related data when switching servers.
  Future<void> _clearAllServerData() async {
    final dioClient = ref.read(dioClientProvider);

    // 1. Cancel any in-flight requests
    dioClient.cancelAllRequests();

    // 2. Clear network cache
    await dioClient.clearCache();
    dioClient.clearETagCache();

    // 3. Clear media cache
    await ref.read(appCacheServiceProvider).clearAll();

    // 4. Clear auth state (was authServerConfigListenerProvider)
    ref.read(authProvider.notifier).clearLocalAuthState();

    // 5. Clear podcast caches (was podcastServerConfigListenerProvider)
    ref.read(podcastDiscoverProvider.notifier).clearRuntimeCache();
    ref.read(search.iTunesSearchServiceProvider).clearCache();
    ref.read(profileStatsProvider.notifier).reset();
    ref.read(playbackHistoryLiteProvider.notifier).reset();
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
  }

  /// Update server base URL and apply to DioClient
  /// If [clearData] is true and URL changes, all server data will be cleared
  Future<void> updateServerUrl(String newUrl, {bool clearData = true}) async {
    final oldUrl = state.serverUrl;
    state = state.copyWith(isLoading: true);

    try {
      // Normalize URL
      final normalizedUrl = UrlNormalizer.normalize(newUrl);

      // Clear all server data if URL changed and clearData is true
      if (clearData && oldUrl != normalizedUrl) {
        await _clearAllServerData();
      }

      // Save to storage
      await _storageService.saveServerBaseUrl(normalizedUrl);

      // Update AppConfig
      AppConfig.setServerBaseUrl(normalizedUrl);

      // Update DioClient
      final dioClient = ref.read(dioClientProvider);
      dioClient.updateBaseUrl('$normalizedUrl/api/v1');

      state = state.copyWith(serverUrl: normalizedUrl, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to update server URL: $e',
      );
    }
  }
}

final serverConfigProvider =
    NotifierProvider<ServerConfigNotifier, ServerConfigState>(
      ServerConfigNotifier.new,
    );
