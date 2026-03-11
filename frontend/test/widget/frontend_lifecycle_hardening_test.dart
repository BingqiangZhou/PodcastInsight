import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_ai_assistant/core/app/config/app_config.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/storage/local_storage_service.dart';
import 'package:personal_ai_assistant/features/auth/presentation/pages/login_page.dart';
import 'package:personal_ai_assistant/features/auth/presentation/providers/auth_provider.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_playback_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/conversation_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/summary_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/bulk_import_dialog.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/conversation_chat_widget.dart';
import 'package:personal_ai_assistant/shared/widgets/server_config_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

const MethodChannel _secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);
const MethodChannel _sharedPreferencesChannel = MethodChannel(
  'plugins.flutter.io/shared_preferences',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugBulkImportRssUrlValidator = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_sharedPreferencesChannel, null);
    SharedPreferences.resetStatic();
  });

  testWidgets(
    'LoginPage ignores delayed secure storage completion after dispose',
    (tester) async {
      final usernameCompleter = Completer<String?>();
      final passwordCompleter = Completer<String?>();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_secureStorageChannel, (call) async {
            if (call.method != 'read') {
              return null;
            }

            final arguments = Map<String, Object?>.from(
              call.arguments! as Map<Object?, Object?>,
            );
            switch (arguments['key']) {
              case AppConstants.savedUsernameKey:
                return usernameCompleter.future;
              case AppConstants.savedPasswordKey:
                return passwordCompleter.future;
            }

            return null;
          });

      await tester.pumpWidget(
        _buildTestApp(
          const LoginPage(),
          overrides: [authProvider.overrideWith(_IdleAuthNotifier.new)],
        ),
      );
      await tester.pump();

      await tester.pumpWidget(const SizedBox.shrink());

      usernameCompleter.complete('tester@example.com');
      await tester.pump();
      passwordCompleter.complete('secret123');
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ServerConfigDialog ignores delayed shared preferences load after dispose',
    (tester) async {
      SharedPreferences.resetStatic();
      final prefsCompleter = Completer<Map<String, Object>>();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_sharedPreferencesChannel, (call) async {
            if (call.method == 'getAll') {
              return prefsCompleter.future;
            }
            return null;
          });

      await tester.pumpWidget(
        _buildTestApp(
          const Scaffold(body: ServerConfigDialog()),
          overrides: [
            localStorageServiceProvider.overrideWithValue(
              _FakeLocalStorageService(),
            ),
          ],
        ),
      );
      await tester.pump();

      await tester.pumpWidget(const SizedBox.shrink());

      prefsCompleter.complete(<String, Object>{
        'flutter.server_history_list': <String>['http://localhost:8000'],
      });
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('BulkImportDialog ignores validation completion after dispose', (
    tester,
  ) async {
    final validationCompleter = Completer<bool>();
    debugBulkImportRssUrlValidator = (_) => validationCompleter.future;

    await tester.pumpWidget(
      _buildTestApp(Scaffold(body: BulkImportDialog(onImport: (_) async {}))),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).first,
      'https://example.com/feed.xml',
    );
    await tester.tap(find.byIcon(Icons.auto_awesome));
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    validationCompleter.complete(true);
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('ConversationChatWidget cancels delayed auto-scroll on dispose', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        const Scaffold(
          body: ConversationChatWidget(
            episodeId: 1,
            episodeTitle: 'Episode',
            aiSummary: 'Summary',
          ),
        ),
        overrides: [
          getConversationProvider(
            1,
          ).overrideWith(() => _ReadyConversationNotifier()),
          availableModelsProvider.overrideWith(
            (ref) async => const <SummaryModelInfo>[],
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField).first);
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
  });
}

Widget _buildTestApp(Widget home, {List overrides = const []}) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => home),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(body: Text('Home')),
      ),
    ],
  );

  return ProviderScope(
    overrides: overrides.cast(),
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

class _IdleAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState();
}

class _ReadyConversationNotifier extends ConversationNotifier {
  _ReadyConversationNotifier() : super(1);

  @override
  ConversationState build() => const ConversationState(messages: []);
}

class _FakeLocalStorageService implements LocalStorageService {
  final Map<String, Object?> _values = <String, Object?>{};

  @override
  Future<void> cacheData(String key, data, {Duration? expiration}) async {
    _values[key] = data;
  }

  @override
  Future<void> clear() async {
    _values.clear();
  }

  @override
  Future<void> clearExpiredCache() async {}

  @override
  Future<bool> containsKey(String key) async => _values.containsKey(key);

  @override
  Future<T?> get<T>(String key) async => _values[key] as T?;

  @override
  Future<String?> getApiBaseUrl() async => _values['api_base_url'] as String?;

  @override
  Future<bool?> getBool(String key) async => _values[key] as bool?;

  @override
  Future<T?> getCachedData<T>(String key) async => _values[key] as T?;

  @override
  Future<double?> getDouble(String key) async => _values[key] as double?;

  @override
  Future<int?> getInt(String key) async => _values[key] as int?;

  @override
  Future<String?> getServerBaseUrl() async =>
      _values['server_base_url'] as String?;

  @override
  Future<String?> getString(String key) async => _values[key] as String?;

  @override
  Future<List<String>?> getStringList(String key) async =>
      _values[key] as List<String>?;

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
  }

  @override
  Future<void> save<T>(String key, T value) async {
    _values[key] = value;
  }

  @override
  Future<void> saveApiBaseUrl(String url) async {
    _values['api_base_url'] = url;
  }

  @override
  Future<void> saveBool(String key, bool value) async {
    _values[key] = value;
  }

  @override
  Future<void> saveDouble(String key, double value) async {
    _values[key] = value;
  }

  @override
  Future<void> saveInt(String key, int value) async {
    _values[key] = value;
  }

  @override
  Future<void> saveServerBaseUrl(String url) async {
    _values['server_base_url'] = url;
  }

  @override
  Future<void> saveString(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> saveStringList(String key, List<String> value) async {
    _values[key] = value;
  }
}
