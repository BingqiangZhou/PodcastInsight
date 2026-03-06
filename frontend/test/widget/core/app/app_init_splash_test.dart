import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/app/app.dart';
import 'package:personal_ai_assistant/core/storage/local_storage_service.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/features/auth/presentation/providers/auth_provider.dart';
import 'package:personal_ai_assistant/features/settings/presentation/providers/app_update_provider.dart';

class _TestAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState();

  @override
  Future<void> checkAuthStatus() async {}
}

class _MemoryLocalStorageService implements LocalStorageService {
  final Map<String, Object?> _storage = <String, Object?>{};

  @override
  Future<void> cacheData(
    String key,
    dynamic data, {
    Duration? expiration,
  }) async {
    _storage[key] = data;
  }

  @override
  Future<void> clear() async {
    _storage.clear();
  }

  @override
  Future<void> clearExpiredCache() async {}

  @override
  Future<bool> containsKey(String key) async => _storage.containsKey(key);

  @override
  Future<T?> get<T>(String key) async => _storage[key] as T?;

  @override
  Future<String?> getApiBaseUrl() async => _storage['api_base_url'] as String?;

  @override
  Future<bool?> getBool(String key) async => _storage[key] as bool?;

  @override
  Future<T?> getCachedData<T>(String key) async => _storage[key] as T?;

  @override
  Future<double?> getDouble(String key) async => _storage[key] as double?;

  @override
  Future<int?> getInt(String key) async => _storage[key] as int?;

  @override
  Future<String?> getServerBaseUrl() async =>
      _storage['server_base_url'] as String?;

  @override
  Future<String?> getString(String key) async => _storage[key] as String?;

  @override
  Future<List<String>?> getStringList(String key) async =>
      (_storage[key] as List<dynamic>?)?.cast<String>();

  @override
  Future<void> remove(String key) async {
    _storage.remove(key);
  }

  @override
  Future<void> save<T>(String key, T value) async {
    _storage[key] = value;
  }

  @override
  Future<void> saveApiBaseUrl(String url) async {
    _storage['api_base_url'] = url;
  }

  @override
  Future<void> saveBool(String key, bool value) async {
    _storage[key] = value;
  }

  @override
  Future<void> saveDouble(String key, double value) async {
    _storage[key] = value;
  }

  @override
  Future<void> saveInt(String key, int value) async {
    _storage[key] = value;
  }

  @override
  Future<void> saveServerBaseUrl(String url) async {
    _storage['server_base_url'] = url;
  }

  @override
  Future<void> saveString(String key, String value) async {
    _storage[key] = value;
  }

  @override
  Future<void> saveStringList(String key, List<String> value) async {
    _storage[key] = value;
  }
}

void main() {
  testWidgets('app init splash renders without GlassPanel', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => _TestAuthNotifier()),
          localStorageServiceProvider.overrideWithValue(
            _MemoryLocalStorageService(),
          ),
          autoUpdateCheckProvider.overrideWith(
            (ref) async => const AppUpdateState(),
          ),
        ],
        child: const PersonalAIAssistantApp(),
      ),
    );

    expect(find.text('Stella'), findsOneWidget);
    expect(
      find.text('Your personal assistant for everything you follow.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('app_init_loading_indicator')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(GlassPanel), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
  });
}
