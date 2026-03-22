import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../app/config/app_config.dart';
import '../network/dio_client.dart';
import '../network/server_health_service.dart';
import '../services/app_cache_service.dart';
import '../storage/local_storage_service.dart';

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

  /// Update server base URL and apply to DioClient
  Future<void> updateServerUrl(String newUrl) async {
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

      // Save to storage
      await _storageService.saveServerBaseUrl(normalizedUrl);

      // Update AppConfig
      AppConfig.setServerBaseUrl(normalizedUrl);

      // Update DioClient
      final dioClient = ref.read(dioClientProvider);
      dioClient.updateBaseUrl('$normalizedUrl/api/v1');
      dioClient.clearETagCache();

      // No additional providers need explicit refresh here.
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
