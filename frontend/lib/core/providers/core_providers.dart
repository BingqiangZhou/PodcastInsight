import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../app/config/app_config.dart';
import '../network/dio_client.dart';
import '../network/server_health_service.dart';
import '../services/app_cache_service.dart';
import '../storage/local_storage_service.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/podcast/presentation/providers/podcast_discover_provider.dart';
import '../../features/podcast/presentation/providers/podcast_providers.dart';
import '../../features/podcast/presentation/providers/podcast_search_provider.dart' as search;

// Dio Client Provider
final dioClientProvider = Provider<DioClient>((ref) {
  return DioClient();
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
  final String serverUrl;
  final bool isLoading;
  final String? error;

  const ServerConfigState({
    required this.serverUrl,
    this.isLoading = false,
    this.error,
  });

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
  late final LocalStorageService _storageService;

  @override
  ServerConfigState build() {
    // Get initial server URL from AppConfig
    _storageService = ref.read(localStorageServiceProvider);
    final initialUrl = AppConfig.serverBaseUrl;
    return ServerConfigState(serverUrl: initialUrl);
  }

  /// Clear all server-related data when switching servers
  Future<void> _clearAllServerData() async {
    final dioClient = ref.read(dioClientProvider);

    // 1. Cancel any in-flight requests
    dioClient.cancelAllRequests();

    // 2. Clear network cache
    await dioClient.clearCache();
    dioClient.clearETagCache();

    // 3. Clear media cache
    await ref.read(appCacheServiceProvider).clearAll();

    // 4. Clear Provider runtime cache
    ref.read(podcastDiscoverProvider.notifier).clearRuntimeCache();
    ref.read(search.iTunesSearchServiceProvider).clearCache();

    // 5. Invalidate all server-related Providers
    ref.invalidate(podcastFeedProvider);
    ref.invalidate(podcastDiscoverProvider);
    ref.invalidate(podcastSubscriptionProvider);
    ref.invalidate(podcastEpisodesProvider);

    // Reset notifier states before invalidating
    ref.read(profileStatsProvider.notifier).reset();
    ref.read(playbackHistoryLiteProvider.notifier).reset();

    ref.invalidate(profileStatsProvider);
    ref.invalidate(playbackHistoryLiteProvider);
    ref.invalidate(search.podcastSearchProvider);

    // 6. Clear auth tokens and reset auth state (triggers router redirect)
    await ref.read(authProvider.notifier).clearLocalAuthState();
  }

  /// Update server base URL and apply to DioClient
  /// If [clearData] is true and URL changes, all server data will be cleared
  Future<void> updateServerUrl(String newUrl, {bool clearData = true}) async {
    final oldUrl = state.serverUrl;
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Normalize URL
      var normalizedUrl = newUrl.trim();
      while (normalizedUrl.endsWith('/')) {
        normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1);
      }

      // Remove /api/v1 suffix if present (7 characters)
      if (normalizedUrl.endsWith('/api/v1')) {
        normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 7);
      }

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
