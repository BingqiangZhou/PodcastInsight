import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/network/dio_client.dart';
import 'package:personal_ai_assistant/core/providers/core_providers.dart';
import 'package:personal_ai_assistant/core/services/app_cache_service.dart';
import 'package:personal_ai_assistant/features/profile/presentation/pages/profile_cache_management_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockDioClient extends Mock implements DioClient {
  @override
  Future<void> clearCache() =>
      super.noSuchMethod(
            Invocation.method(#clearCache, []),
            returnValue: Future<void>.value(),
            returnValueForMissingStub: Future<void>.value(),
          )
          as Future<void>;

  @override
  void clearETagCache() => super.noSuchMethod(
        Invocation.method(#clearETagCache, []),
        returnValueForMissingStub: null,
      );
}

class _MockAppCacheService extends Mock implements AppCacheService {
  @override
  CacheManager get mediaCacheManager => AppMediaCacheManager.instance;

  @override
  Future<void> clearMediaCache() => Future<void>.value();

  @override
  Future<void> clearMemoryImageCache() => Future<void>.value();

  @override
  Future<void> clearAll() =>
      super.noSuchMethod(
            Invocation.method(#clearAll, []),
            returnValue: Future<void>.value(),
            returnValueForMissingStub: Future<void>.value(),
          )
          as Future<void>;

  @override
  Future<void> warmUp(String url) => Future<void>.value();

  @override
  Future<Map<String, dynamic>> getCacheStats() =>
      Future<Map<String, dynamic>>.value({});
}

const MethodChannel _pathProviderChannel =
    MethodChannel('plugins.flutter.io/path_provider');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, (methodCall) async {
      final base = Directory.systemTemp.path;
      return base;
    });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ProfileCacheManagementPage Widget Tests', () {
    testWidgets('renders without crashing', (tester) async {
      final cacheService = _MockAppCacheService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appCacheServiceProvider.overrideWithValue(cacheService),
            dioClientProvider.overrideWithValue(_MockDioClient()),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ProfileCacheManagementPage()),
          ),
        ),
      );

      // Allow the async _loadStats to complete
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byType(ProfileCacheManagementPage), findsOneWidget);
    });

    testWidgets('shows overview section with total usage after loading',
        (tester) async {
      final cacheService = _MockAppCacheService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appCacheServiceProvider.overrideWithValue(cacheService),
            dioClientProvider.overrideWithValue(_MockDioClient()),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ProfileCacheManagementPage()),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // With empty cache (mocked), it should show 0.00 MB
      expect(find.text('0.00'), findsOneWidget);
      expect(find.text('MB'), findsOneWidget);

      // Should show the overview section
      expect(
          find.byKey(const Key('cache_manage_overview_section')),
          findsOneWidget);
    });

    testWidgets('shows cache detail rows for images, audio, and other',
        (tester) async {
      final cacheService = _MockAppCacheService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appCacheServiceProvider.overrideWithValue(cacheService),
            dioClientProvider.overrideWithValue(_MockDioClient()),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ProfileCacheManagementPage()),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      final context = tester.element(find.byType(ProfileCacheManagementPage));
      final l10n = AppLocalizations.of(context)!;

      // Should show category labels (appear in both legend and detail rows)
      expect(find.text(l10n.profile_cache_manage_images), findsAtLeast(1));
      expect(find.text(l10n.profile_cache_manage_audio), findsAtLeast(1));
      expect(find.text(l10n.profile_cache_manage_other), findsAtLeast(1));

      // Should show clean buttons for each category
      expect(
          find.byKey(const Key('cache_manage_clean_images')), findsOneWidget);
      expect(
          find.byKey(const Key('cache_manage_clean_audio')), findsOneWidget);
      expect(
          find.byKey(const Key('cache_manage_clean_other')), findsOneWidget);
    });

    testWidgets('shows deep clean all button and refresh action',
        (tester) async {
      final cacheService = _MockAppCacheService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appCacheServiceProvider.overrideWithValue(cacheService),
            dioClientProvider.overrideWithValue(_MockDioClient()),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ProfileCacheManagementPage()),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Should show the deep clean all button
      expect(
          find.byKey(const Key('cache_manage_deep_clean_all')),
          findsOneWidget);

      // Should show the refresh action button
      expect(
          find.byKey(const Key('cache_manage_refresh_action')),
          findsOneWidget);
    });

    testWidgets('shows info notice box', (tester) async {
      final cacheService = _MockAppCacheService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appCacheServiceProvider.overrideWithValue(cacheService),
            dioClientProvider.overrideWithValue(_MockDioClient()),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ProfileCacheManagementPage()),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Should show the notice box with info icon
      expect(
          find.byKey(const Key('cache_manage_notice_box')), findsOneWidget);
      expect(
          find.byKey(const Key('cache_manage_notice_icon')), findsOneWidget);
    });
  });
}
