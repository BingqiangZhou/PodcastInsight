import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/storage/local_storage_service.dart';
import 'package:personal_ai_assistant/shared/widgets/server_config_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Mock LocalStorageService for testing
class MockLocalStorageService implements LocalStorageService {
  final Map<String, dynamic> _storage = {};

  @override
  Future<void> saveString(String key, String value) async {
    _storage[key] = value;
  }

  @override
  Future<String?> getString(String key) async {
    return _storage[key] as String?;
  }

  @override
  Future<void> saveBool(String key, bool value) async {
    _storage[key] = value;
  }

  @override
  Future<bool?> getBool(String key) async {
    return _storage[key] as bool?;
  }

  @override
  Future<void> saveInt(String key, int value) async {
    _storage[key] = value;
  }

  @override
  Future<int?> getInt(String key) async {
    return _storage[key] as int?;
  }

  @override
  Future<void> saveDouble(String key, double value) async {
    _storage[key] = value;
  }

  @override
  Future<double?> getDouble(String key) async {
    return _storage[key] as double?;
  }

  @override
  Future<void> saveStringList(String key, List<String> value) async {
    _storage[key] = value;
  }

  @override
  Future<List<String>?> getStringList(String key) async {
    return _storage[key] as List<String>?;
  }

  @override
  Future<void> save<T>(String key, T value) async {
    _storage[key] = value;
  }

  @override
  Future<T?> get<T>(String key) async {
    return _storage[key] as T?;
  }

  @override
  Future<void> remove(String key) async {
    _storage.remove(key);
  }

  @override
  Future<void> clear() async {
    _storage.clear();
  }

  @override
  Future<bool> containsKey(String key) async {
    return _storage.containsKey(key);
  }

  @override
  Future<void> cacheData(String key, dynamic data, {Duration? expiration}) async {
    _storage[key] = data;
  }

  @override
  Future<T?> getCachedData<T>(String key) async {
    return _storage[key] as T?;
  }

  @override
  Future<void> clearExpiredCache() async {
    // No-op for mock
  }

  @override
  Future<void> saveApiBaseUrl(String url) async {
    _storage['api_base_url'] = url;
  }

  @override
  Future<String?> getApiBaseUrl() async {
    return _storage['api_base_url'] as String?;
  }

  @override
  Future<void> saveServerBaseUrl(String url) async {
    _storage['server_base_url'] = url;
  }

  @override
  Future<String?> getServerBaseUrl() async {
    return _storage['server_base_url'] as String?;
  }
}

void main() {
  group('LoginScreen ServerConfigDialog Integration Tests', () {
    testWidgets('server config dialog can be displayed', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(MockLocalStorageService()),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ServerConfigDialog(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify dialog is displayed
      expect(find.text('Backend API Server Configuration'), findsOneWidget);
    });

    testWidgets('server config dialog has all required UI elements',
        (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(MockLocalStorageService()),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ServerConfigDialog(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify all required elements
      expect(find.text('Backend API URL'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('server config dialog supports bilingual', (tester) async {
      SharedPreferences.setMockInitialValues({});

      // Test Chinese
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(MockLocalStorageService()),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('zh'),
            home: Scaffold(
              body: ServerConfigDialog(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Chinese text
      expect(find.text('后端 API 服务器配置'), findsOneWidget);
      expect(find.text('未验证'), findsOneWidget);
    });

    testWidgets('server config dialog has URL input field', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(MockLocalStorageService()),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ServerConfigDialog(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify URL input field
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('server config dialog has connection status panel',
        (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(MockLocalStorageService()),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ServerConfigDialog(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify status panel (unverified status)
      expect(find.textContaining('Unverified'), findsOneWidget);
    });
  });
}
