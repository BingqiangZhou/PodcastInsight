import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../app/config/app_config.dart';
import '../network/dio_client.dart';
import '../services/app_cache_service.dart';
import '../storage/local_storage_service.dart';

// Dio Client Provider
final dioClientProvider = Provider<DioClient>((ref) {
  return DioClient();
});

final appCacheServiceProvider = Provider<AppCacheService>((ref) {
  return AppCacheServiceImpl();
});

// Current Date/Time Provider
final dateTimeProvider = Provider<DateTime>((ref) {
  return DateTime.now();
});

// App Loading State Provider
final appLoadingProvider = NotifierProvider<AppLoadingNotifier, bool>(AppLoadingNotifier.new);

class AppLoadingNotifier extends Notifier<bool> {
  @override
  bool build() {
    return false;
  }

  void setLoading(bool loading) {
    state = loading;
  }
}

// Connection Status Provider
final connectionStatusProvider = NotifierProvider<ConnectionStatusNotifier, bool>(ConnectionStatusNotifier.new);

class ConnectionStatusNotifier extends Notifier<bool> {
  @override
  bool build() {
    return true;
  }

  void setStatus(bool status) {
    state = status;
  }
}

// Error State Provider
final errorProvider = NotifierProvider<ErrorNotifier, String?>(ErrorNotifier.new);

class ErrorNotifier extends Notifier<String?> {
  @override
  String? build() {
    return null;
  }

  void setError(String? error) {
    state = error;
  }

  void clearError() {
    state = null;
  }
}

// ETag Configuration Provider
final etagEnabledProvider = Provider<bool>((ref) => true);

// Server Config Provider - Manages backend server address configuration
class ServerConfigState {
  final String serverUrl;
  final bool isLoading;
  final String? error;
  final bool testSuccess;

  const ServerConfigState({
    required this.serverUrl,
    this.isLoading = false,
    this.error,
    this.testSuccess = false,
  });

  ServerConfigState copyWith({
    String? serverUrl,
    bool? isLoading,
    String? error,
    bool? testSuccess,
  }) {
    return ServerConfigState(
      serverUrl: serverUrl ?? this.serverUrl,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      testSuccess: testSuccess ?? this.testSuccess,
    );
  }
}

class ServerConfigNotifier extends Notifier<ServerConfigState> {
  LocalStorageService? _storageService;

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
      await _storageService!.saveServerBaseUrl(normalizedUrl);

      // Update AppConfig
      AppConfig.setServerBaseUrl(normalizedUrl);

      // Update DioClient
      final dioClient = ref.read(dioClientProvider);
      dioClient.updateBaseUrl('$normalizedUrl/api/v1');
      dioClient.clearETagCache();

      // No additional providers need explicit refresh here.
      state = state.copyWith(
        serverUrl: normalizedUrl,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to update server URL: $e',
      );
    }
  }

  /// Test connection to the server
  Future<bool> testConnection(String testUrl) async {
    state = state.copyWith(isLoading: true, error: null, testSuccess: false);

    try {
      // Normalize URL for testing (server base URL without /api/v1)
      var normalizedUrl = testUrl.trim();
      while (normalizedUrl.endsWith('/')) {
        normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1);
      }
      // Remove /api/v1 suffix if present for health check
      if (normalizedUrl.endsWith('/api/v1')) {
        normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 7);
      }

      // Create temporary Dio instance for testing
      final testDio = Dio(BaseOptions(
        baseUrl: normalizedUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ));

      final response = await testDio.get('/api/v1/health');

      final success = response.statusCode == 200;

      state = state.copyWith(
        isLoading: false,
        testSuccess: success,
        error: success ? null : 'Server returned status ${response.statusCode}',
      );

      return success;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        testSuccess: false,
        error: 'Connection failed: ${e.toString()}',
      );
      return false;
    }
  }

  /// Load saved server URL from storage
  Future<void> loadSavedUrl() async {
    try {
      final savedUrl = await _storageService!.getServerBaseUrl();
      if (savedUrl != null && savedUrl.isNotEmpty) {
        state = state.copyWith(serverUrl: savedUrl);
      }
    } catch (e) {
      // Keep default URL on error
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  void clearTestSuccess() {
    state = state.copyWith(testSuccess: false);
  }
}

final serverConfigProvider = NotifierProvider<ServerConfigNotifier, ServerConfigState>(ServerConfigNotifier.new);



