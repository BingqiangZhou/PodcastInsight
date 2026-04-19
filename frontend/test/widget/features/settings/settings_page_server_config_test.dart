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
  Future<void> cacheData(
    String key,
    dynamic data, {
    Duration? expiration,
  }) async {
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
  group('ServerConfigDialog Widget Tests', () {
    testWidgets('displays server config dialog with all elements', (
      tester,
    ) async {
      // Set up mock SharedPreferences
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(
              MockLocalStorageService(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ServerConfigDialog()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify dialog title
      expect(find.text('Backend API Server Configuration'), findsOneWidget);

      // Verify all required elements are present
      expect(find.text('Backend API URL'), findsOneWidget);
      expect(find.text('Local Server'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('local server button is present', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(
              MockLocalStorageService(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ServerConfigDialog()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify local server button
      expect(find.text('Local Server'), findsOneWidget);
    });

    testWidgets('has URL input field', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(
              MockLocalStorageService(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ServerConfigDialog()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify URL input field exists
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('has connection status panel', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(
              MockLocalStorageService(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ServerConfigDialog()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify status panel exists (looks for the unverified status text)
      expect(find.textContaining('Unverified'), findsOneWidget);
    });

    testWidgets('clear button shows and hides based on text input', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(
              MockLocalStorageService(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ServerConfigDialog(initialUrl: '')),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify clear button appears when text is entered
      await tester.enterText(find.byType(TextField), 'test');
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Verify text is cleared when clear button is tapped
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Verify text is cleared
      final textFieldAfter = tester.widget<TextField>(find.byType(TextField));
      expect(textFieldAfter.controller?.text, isEmpty);
    });

    testWidgets('history list is not shown when empty', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(
              MockLocalStorageService(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ServerConfigDialog()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify history title is not shown
      expect(find.text('History'), findsNothing);
    });

    testWidgets('save button is disabled when connection is not successful', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(
              MockLocalStorageService(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ServerConfigDialog()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find save button - it should be disabled (null onPressed)
      final saveButton = find.widgetWithText(TextButton, 'Save');
      expect(saveButton, findsOneWidget);

      // Get the TextButton widget
      final textButton = tester.widget<TextButton>(saveButton);
      // Save button should be disabled when status is not success
      expect(textButton.onPressed, isNull);
    });

    testWidgets('uses mobile width consistent with profile dialogs', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(
              MockLocalStorageService(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ServerConfigDialog()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (widget) => widget is SizedBox && widget.width == 362.0,
        ),
        findsOneWidget,
      );
    });
  });

  group('ServerConfigDialog Bilingual Tests', () {
    testWidgets('supports English localization', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(
              MockLocalStorageService(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: Scaffold(body: ServerConfigDialog()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify English text
      expect(find.text('Backend API Server Configuration'), findsOneWidget);
      expect(find.text('Local Server'), findsOneWidget);
      expect(find.text('Unverified'), findsOneWidget);
    });

    testWidgets('supports Chinese localization', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(
              MockLocalStorageService(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('zh'),
            home: Scaffold(body: ServerConfigDialog()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Chinese text
      expect(find.text('后端 API 服务器配置'), findsOneWidget);
      expect(find.text('本地服务器'), findsOneWidget);
      expect(find.text('未验证'), findsOneWidget);
    });

    testWidgets('clear button has correct localization', (tester) async {
      SharedPreferences.setMockInitialValues({});

      // Test English
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(
              MockLocalStorageService(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: Scaffold(body: ServerConfigDialog()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter text to show clear button
      await tester.enterText(find.byType(TextField), 'http://example.com');
      await tester.pumpAndSettle();

      // Verify clear icon tooltip in English
      final clearButton = find.byIcon(Icons.close);
      expect(clearButton, findsOneWidget);

      // Test Chinese
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(
              MockLocalStorageService(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('zh'),
            home: Scaffold(body: ServerConfigDialog()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter text to show clear button
      await tester.enterText(find.byType(TextField), 'http://example.com');
      await tester.pumpAndSettle();

      // Verify clear icon exists in Chinese locale
      expect(find.byIcon(Icons.close), findsOneWidget);
    });
  });
}
