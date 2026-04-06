import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/app/config/app_config.dart';
import 'package:personal_ai_assistant/core/events/server_config_events.dart';
import 'package:personal_ai_assistant/core/network/dio_client.dart';
import 'package:personal_ai_assistant/core/network/server_health_service.dart';
import 'package:personal_ai_assistant/core/services/app_cache_service.dart';
import 'package:personal_ai_assistant/core/storage/local_storage_service.dart';

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
  ///
  /// Feature-layer providers listen to [serverConfigVersionProvider] and
  /// perform their own cleanup (e.g. auth clears tokens, podcast clears
  /// caches).  This method does NOT import any feature modules directly,
  /// preserving the core -> feature dependency boundary.
  Future<void> _clearAllServerData() async {
    final dioClient = ref.read(dioClientProvider);

    // 1. Cancel any in-flight requests
    dioClient.cancelAllRequests();

    // 2. Clear network cache
    await dioClient.clearCache();
    dioClient.clearETagCache();

    // 3. Clear media cache
    await ref.read(appCacheServiceProvider).clearAll();

    // 4. Bump the server-config version so that feature-layer listeners
    //    invalidate their own caches and state.
    ref.read(serverConfigVersionProvider.notifier).bump();
  }

  /// Update server base URL and apply to DioClient
  /// If [clearData] is true and URL changes, all server data will be cleared
  Future<void> updateServerUrl(String newUrl, {bool clearData = true}) async {
    final oldUrl = state.serverUrl;
    state = state.copyWith(isLoading: true);

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
