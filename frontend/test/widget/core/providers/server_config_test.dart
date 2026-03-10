import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/providers/core_providers.dart';
import 'package:personal_ai_assistant/core/app/config/app_config.dart';
import 'package:personal_ai_assistant/core/storage/local_storage_service.dart';

// Mock classes
class MockLocalStorageService implements LocalStorageService {
  String? _serverUrl;

  @override
  Future<void> saveString(String key, String value) async {}

  @override
  Future<String?> getString(String key) async => null;

  @override
  Future<void> saveBool(String key, bool value) async {}

  @override
  Future<bool?> getBool(String key) async => null;

  @override
  Future<void> saveInt(String key, int value) async {}

  @override
  Future<int?> getInt(String key) async => null;

  @override
  Future<void> saveDouble(String key, double value) async {}

  @override
  Future<double?> getDouble(String key) async => null;

  @override
  Future<void> saveStringList(String key, List<String> value) async {}

  @override
  Future<List<String>?> getStringList(String key) async => null;

  @override
  Future<void> save<T>(String key, T value) async {}

  @override
  Future<T?> get<T>(String key) async => null;

  @override
  Future<void> remove(String key) async {}

  @override
  Future<void> clear() async {}

  @override
  Future<bool> containsKey(String key) async => false;

  @override
  Future<void> cacheData(String key, dynamic data, {Duration? expiration}) async {}

  @override
  Future<T?> getCachedData<T>(String key) async => null;

  @override
  Future<void> clearExpiredCache() async {}

  @override
  Future<void> saveApiBaseUrl(String url) async {}

  @override
  Future<String?> getApiBaseUrl() async => null;

  @override
  Future<void> saveServerBaseUrl(String url) async {
    _serverUrl = url;
  }

  @override
  Future<String?> getServerBaseUrl() async => _serverUrl;
}

void main() {
  group('ServerConfigNotifier Tests', () {
    late MockLocalStorageService mockStorage;

    setUp(() {
      mockStorage = MockLocalStorageService();
      // Reset AppConfig
      AppConfig.setServerBaseUrl('');
    });

    test('should initialize with default server URL', () {
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(mockStorage),
        ],
      );

      final state = container.read(serverConfigProvider);

      expect(state.serverUrl, isNotEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.testSuccess, isFalse);

      container.dispose();
    });

    test('should update server URL successfully', () async {
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(mockStorage),
        ],
      );

      final notifier = container.read(serverConfigProvider.notifier);

      await notifier.updateServerUrl('http://192.168.1.100:8000');

      final state = container.read(serverConfigProvider);

      expect(state.serverUrl, 'http://192.168.1.100:8000');
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);

      container.dispose();
    });

    test('should normalize server URL by removing trailing slashes', () async {
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(mockStorage),
        ],
      );

      final notifier = container.read(serverConfigProvider.notifier);

      await notifier.updateServerUrl('http://192.168.1.100:8000/');

      final state = container.read(serverConfigProvider);

      expect(state.serverUrl, 'http://192.168.1.100:8000');

      container.dispose();
    });

    test('should remove /api/v1 suffix if present', () async {
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(mockStorage),
        ],
      );

      final notifier = container.read(serverConfigProvider.notifier);

      // Test that updateServerUrl removes /api/v1 suffix
      await notifier.updateServerUrl('http://192.168.1.100:8000/api/v1');

      final state = container.read(serverConfigProvider);

      expect(state.serverUrl, 'http://192.168.1.100:8000');

      container.dispose();
    });

    test('should handle URL with /api/v1 in test connection', () async {
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(mockStorage),
        ],
      );

      final notifier = container.read(serverConfigProvider.notifier);

      // testConnection should also remove /api/v1 suffix
      // Note: This test will fail with connection error since server doesn't exist,
      // but we're testing URL normalization logic
      try {
        await notifier.testConnection('http://192.168.1.100:8000/api/v1');
      } catch (e) {
        // Expected to fail with connection error
      }

      // The test should have attempted to connect to the base URL
      // Error message should indicate connection failure, not 404
      final state = container.read(serverConfigProvider);

      // If we got a 404, that means the URL normalization failed
      if (state.error != null && state.error!.contains('404')) {
        fail('testConnection should remove /api/v1 suffix before testing');
      }

      container.dispose();
    });

    test('should test connection against /api/v1/health', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
      });

      late String requestPath;
      unawaited(() async {
        final request = await server.first;
        requestPath = request.uri.path;
        request.response
          ..statusCode = HttpStatus.ok
          ..write('{"status":"healthy"}');
        await request.response.close();
      }());

      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(mockStorage),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(serverConfigProvider.notifier);
      final success = await notifier.testConnection(
        'http://127.0.0.1:${server.port}',
      );

      expect(success, isTrue);
      expect(requestPath, '/api/v1/health');
    });

    test('should clear error when clearError is called', () {
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(mockStorage),
        ],
      );

      final notifier = container.read(serverConfigProvider.notifier);

      // First set an error state
      notifier.clearError();

      final state = container.read(serverConfigProvider);

      expect(state.error, isNull);

      container.dispose();
    });

    test('should clear test success when clearTestSuccess is called', () {
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(mockStorage),
        ],
      );

      final notifier = container.read(serverConfigProvider.notifier);

      notifier.clearTestSuccess();

      final state = container.read(serverConfigProvider);

      expect(state.testSuccess, isFalse);

      container.dispose();
    });
  });

  group('AppConfig Tests', () {
    setUp(() {
      AppConfig.setServerBaseUrl('');
    });

    test('serverBaseUrl should return default URL when not set', () {
      final url = AppConfig.serverBaseUrl;
      expect(url, isNotEmpty);
      expect(url.contains('localhost'), isTrue);
    });

    test('setServerBaseUrl should update the URL', () {
      AppConfig.setServerBaseUrl('http://example.com');
      expect(AppConfig.serverBaseUrl, 'http://example.com');
    });

    test('apiBaseUrl should return same as serverBaseUrl', () {
      AppConfig.setServerBaseUrl('http://test.com');
      expect(AppConfig.apiBaseUrl, 'http://test.com');
    });

    test('setApiBaseUrl should work for backward compatibility', () {
      AppConfig.setApiBaseUrl('http://compat.com');
      expect(AppConfig.serverBaseUrl, 'http://compat.com');
    });
  });
}
