import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/mockito.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/network/dio_client.dart';
import 'package:personal_ai_assistant/core/providers/core_providers.dart';
import 'package:personal_ai_assistant/core/services/app_cache_service.dart';
import 'package:personal_ai_assistant/core/storage/local_storage_service.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/features/auth/domain/models/user.dart';
import 'package:personal_ai_assistant/features/auth/presentation/providers/auth_provider.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_daily_report_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/profile_stats_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/services/apple_podcast_rss_service.dart';
import 'package:personal_ai_assistant/features/podcast/data/services/itunes_search_service.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_state_models.dart';
import 'package:personal_ai_assistant/features/podcast/data/repositories/podcast_repository.dart';
import 'package:personal_ai_assistant/features/podcast/data/services/podcast_api_service.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_discover_provider.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_search_provider.dart'
    as search;
import 'package:personal_ai_assistant/features/profile/presentation/pages/profile_cache_management_page.dart';
import 'package:personal_ai_assistant/features/profile/presentation/pages/profile_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return AuthState(
      isAuthenticated: true,
      user: User(
        id: '1',
        email: 'test@example.com',
        username: 'tester',
        fullName: 'Test User',
        isVerified: true,
        isActive: true,
      ),
    );
  }
}

const _defaultProfileStats = ProfileStatsModel(
  totalSubscriptions: 1,
  totalEpisodes: 23,
  summariesGenerated: 12,
  pendingSummaries: 11,
  playedEpisodes: 8,
);

const _profileStatsWithDailyReport = ProfileStatsModel(
  totalSubscriptions: 1,
  totalEpisodes: 23,
  summariesGenerated: 12,
  pendingSummaries: 11,
  playedEpisodes: 8,
  latestDailyReportDate: '2026-02-20',
);

class _FixedProfileStatsNotifier extends ProfileStatsNotifier {
  _FixedProfileStatsNotifier(this._value);

  final ProfileStatsModel? _value;

  @override
  FutureOr<ProfileStatsModel?> build() => _value;

  @override
  Future<ProfileStatsModel?> load({bool forceRefresh = false}) async {
    state = AsyncValue.data(_value);
    return _value;
  }
}

class _PendingProfileStatsNotifier extends ProfileStatsNotifier {
  _PendingProfileStatsNotifier(this._pending);

  final Completer<ProfileStatsModel?> _pending;

  @override
  FutureOr<ProfileStatsModel?> build() => _pending.future;

  @override
  Future<ProfileStatsModel?> load({bool forceRefresh = false}) =>
      _pending.future;
}

class _FixedDailyReportDatesNotifier extends DailyReportDatesNotifier {
  _FixedDailyReportDatesNotifier(this._value);

  final PodcastDailyReportDatesResponse? _value;

  @override
  FutureOr<PodcastDailyReportDatesResponse?> build() => _value;

  @override
  Future<PodcastDailyReportDatesResponse?> load({
    int page = 1,
    int size = 30,
    bool forceRefresh = false,
  }) async {
    state = AsyncValue.data(_value);
    return _value;
  }
}

class _ThrowingPodcastApiService extends Mock implements PodcastApiService {}

class _ThrowingPodcastRepository extends PodcastRepository {
  _ThrowingPodcastRepository() : super(_ThrowingPodcastApiService());

  @override
  Future<ProfileStatsModel> getProfileStats() async {
    throw Exception('profile stats failed');
  }
}

class _TestPodcastSubscriptionNotifier extends PodcastSubscriptionNotifier {
  @override
  PodcastSubscriptionState build() {
    return const PodcastSubscriptionState(total: 5);
  }

  @override
  Future<void> loadSubscriptions({
    int page = 1,
    int size = 10,
    int? categoryId,
    String? status,
    bool forceRefresh = false,
  }) async {}

  @override
  Future<void> loadMoreSubscriptions({int? categoryId, String? status}) async {}

  @override
  Future<void> refreshSubscriptions({int? categoryId, String? status}) async {}
}

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
  Future<FileInfo?> getCachedFileInfo(String url) => Future<FileInfo?>.value();

  @override
  Future<void> warmUp(String url) => Future<void>.value();
}

class _MockITunesSearchService extends Mock implements ITunesSearchService {
  @override
  void clearCache() => super.noSuchMethod(
    Invocation.method(#clearCache, []),
    returnValueForMissingStub: null,
  );
}

class _TrackingApplePodcastRssService extends ApplePodcastRssService {
  int clearCacheCalls = 0;

  @override
  void clearCache() {
    clearCacheCalls += 1;
    super.clearCache();
  }
}

PodcastDailyReportDatesResponse _buildDailyReportDatesResponse(
  List<DateTime> dates,
) {
  return PodcastDailyReportDatesResponse(
    dates: dates
        .map(
          (item) => PodcastDailyReportDateItem(reportDate: item, totalItems: 1),
        )
        .toList(),
    total: dates.length,
    page: 1,
    size: 30,
    pages: dates.isEmpty ? 0 : 1,
  );
}

const MethodChannel _packageInfoChannel = MethodChannel(
  'dev.fluttercommunity.plus/package_info',
);
const MethodChannel _pathProviderChannel = MethodChannel(
  'plugins.flutter.io/path_provider',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_packageInfoChannel, (methodCall) async {
          if (methodCall.method == 'getAll') {
            return <String, dynamic>{
              'appName': 'Personal AI Assistant',
              'packageName': 'com.example.personal_ai_assistant',
              'version': '1.2.3',
              'buildNumber': '123',
              'buildSignature': '',
              'installerStore': null,
            };
          }
          return null;
        });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, (methodCall) async {
          final base = Directory.systemTemp.path;
          switch (methodCall.method) {
            case 'getTemporaryDirectory':
              return base;
            case 'getApplicationSupportDirectory':
              return base;
            case 'getApplicationDocumentsDirectory':
              return base;
            case 'getDownloadsDirectory':
              return base;
            default:
              return base;
          }
        });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_packageInfoChannel, null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'renders lightweight stats with viewed count from playedEpisodes',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(_TestAuthNotifier.new),
            profileStatsProvider.overrideWith(
              () => _FixedProfileStatsNotifier(_profileStatsWithDailyReport),
            ),
            podcastSubscriptionProvider.overrideWith(
              _TestPodcastSubscriptionNotifier.new,
            ),
            dailyReportDatesProvider.overrideWith(
              () => _FixedDailyReportDatesNotifier(
                _buildDailyReportDatesResponse(const []),
              ),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: ProfilePage()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('23'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(
        find.byKey(const Key('profile_viewed_card_chevron')),
        findsOneWidget,
      );
    },
  );

  testWidgets('daily report activity card navigates to daily report route', (
    WidgetTester tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: ProfilePage()),
        ),
        GoRoute(
          path: '/reports/daily',
          name: 'dailyReport',
          builder: (context, state) =>
              const Scaffold(body: Text('daily-report')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_TestAuthNotifier.new),
          profileStatsProvider.overrideWith(
            () => _FixedProfileStatsNotifier(_profileStatsWithDailyReport),
          ),
          podcastSubscriptionProvider.overrideWith(
            _TestPodcastSubscriptionNotifier.new,
          ),
          dailyReportDatesProvider.overrideWith(
            () => _FixedDailyReportDatesNotifier(
              _buildDailyReportDatesResponse([DateTime(2026, 2, 20)]),
            ),
          ),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );

    await tester.pumpAndSettle();

    final dailyReportCard = find.byKey(const Key('profile_daily_report_card'));
    expect(dailyReportCard, findsOneWidget);

    await tester.tap(dailyReportCard);
    await tester.pumpAndSettle();

    expect(find.text('daily-report'), findsOneWidget);
  });

  testWidgets(
    'daily report card shows latest report date and icon color matches other cards',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(_TestAuthNotifier.new),
            profileStatsProvider.overrideWith(
              () => _FixedProfileStatsNotifier(_profileStatsWithDailyReport),
            ),
            podcastSubscriptionProvider.overrideWith(
              _TestPodcastSubscriptionNotifier.new,
            ),
            dailyReportDatesProvider.overrideWith(
              () => _FixedDailyReportDatesNotifier(
                _buildDailyReportDatesResponse([DateTime(2026, 2, 20)]),
              ),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: ProfilePage()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final dailyReportCard = find.byKey(
        const Key('profile_daily_report_card'),
      );
      expect(dailyReportCard, findsOneWidget);
      expect(
        find.descendant(of: dailyReportCard, matching: find.text('2026-02-20')),
        findsOneWidget,
      );

      final dailyReportIcon = tester.widget<Icon>(
        find.descendant(
          of: dailyReportCard,
          matching: find.byIcon(Icons.summarize_outlined),
        ),
      );
      final subscriptionsIcon = tester.widget<Icon>(
        find.byIcon(Icons.subscriptions_outlined).first,
      );
      expect(dailyReportIcon.color, equals(subscriptionsIcon.color));
    },
  );

  testWidgets(
    'uses menu icon color tokens for profile icons, avatar, and switch in dark mode',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(_TestAuthNotifier.new),
            profileStatsProvider.overrideWith(
              () => _FixedProfileStatsNotifier(_profileStatsWithDailyReport),
            ),
            podcastSubscriptionProvider.overrideWith(
              _TestPodcastSubscriptionNotifier.new,
            ),
            dailyReportDatesProvider.overrideWith(
              () => _FixedDailyReportDatesNotifier(
                _buildDailyReportDatesResponse([DateTime(2026, 2, 20)]),
              ),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData.light(useMaterial3: true),
            darkTheme: ThemeData.dark(useMaterial3: true),
            themeMode: ThemeMode.dark,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: ProfilePage()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final context = tester.element(find.byType(ProfilePage));
      final scheme = Theme.of(context).colorScheme;

      final subscriptionsIcon = tester.widget<Icon>(
        find.byIcon(Icons.subscriptions_outlined).first,
      );
      expect(subscriptionsIcon.color, equals(scheme.onSurfaceVariant));

      final avatar = tester.widget<CircleAvatar>(
        find.descendant(
          of: find.byKey(const Key('profile_user_menu_button')),
          matching: find.byType(CircleAvatar),
        ),
      );
      expect(avatar.backgroundColor, equals(scheme.onSurfaceVariant));

      final notificationsSwitch = tester.widget<Switch>(
        find.byKey(const Key('profile_notifications_switch')),
      );
      expect(
        notificationsSwitch.activeTrackColor,
        equals(scheme.onSurfaceVariant),
      );
      expect(
        notificationsSwitch.inactiveTrackColor,
        equals(scheme.onSurfaceVariant.withValues(alpha: 0.30)),
      );
      expect(notificationsSwitch.activeThumbColor, equals(scheme.surface));
      expect(notificationsSwitch.inactiveThumbColor, equals(scheme.surface));
    },
  );

  testWidgets(
    'uses menu icon color tokens for profile icons, avatar, and switch in light mode',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(_TestAuthNotifier.new),
            profileStatsProvider.overrideWith(
              () => _FixedProfileStatsNotifier(_profileStatsWithDailyReport),
            ),
            podcastSubscriptionProvider.overrideWith(
              _TestPodcastSubscriptionNotifier.new,
            ),
            dailyReportDatesProvider.overrideWith(
              () => _FixedDailyReportDatesNotifier(
                _buildDailyReportDatesResponse([DateTime(2026, 2, 20)]),
              ),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData.light(useMaterial3: true),
            darkTheme: ThemeData.dark(useMaterial3: true),
            themeMode: ThemeMode.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: ProfilePage()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final context = tester.element(find.byType(ProfilePage));
      final scheme = Theme.of(context).colorScheme;

      final subscriptionsIcon = tester.widget<Icon>(
        find.byIcon(Icons.subscriptions_outlined).first,
      );
      expect(subscriptionsIcon.color, equals(scheme.onSurfaceVariant));

      final avatar = tester.widget<CircleAvatar>(
        find.descendant(
          of: find.byKey(const Key('profile_user_menu_button')),
          matching: find.byType(CircleAvatar),
        ),
      );
      expect(avatar.backgroundColor, equals(scheme.onSurfaceVariant));

      final notificationsSwitch = tester.widget<Switch>(
        find.byKey(const Key('profile_notifications_switch')),
      );
      expect(
        notificationsSwitch.activeTrackColor,
        equals(scheme.onSurfaceVariant),
      );
      expect(
        notificationsSwitch.inactiveTrackColor,
        equals(scheme.onSurfaceVariant.withValues(alpha: 0.30)),
      );
      expect(notificationsSwitch.activeThumbColor, equals(scheme.surface));
      expect(notificationsSwitch.inactiveThumbColor, equals(scheme.surface));
    },
  );

  testWidgets('daily report card shows -- when no report date exists', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_TestAuthNotifier.new),
          profileStatsProvider.overrideWith(
            () => _FixedProfileStatsNotifier(_defaultProfileStats),
          ),
          podcastSubscriptionProvider.overrideWith(
            _TestPodcastSubscriptionNotifier.new,
          ),
          dailyReportDatesProvider.overrideWith(
            () => _FixedDailyReportDatesNotifier(
              _buildDailyReportDatesResponse(const []),
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: ProfilePage()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final dailyReportCard = find.byKey(const Key('profile_daily_report_card'));
    expect(dailyReportCard, findsOneWidget);
    expect(
      find.descendant(of: dailyReportCard, matching: find.text('--')),
      findsOneWidget,
    );
  });

  testWidgets('shows loading placeholders when profile stats is loading', (
    WidgetTester tester,
  ) async {
    final pending = Completer<ProfileStatsModel?>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_TestAuthNotifier.new),
          profileStatsProvider.overrideWith(
            () => _PendingProfileStatsNotifier(pending),
          ),
          podcastSubscriptionProvider.overrideWith(
            _TestPodcastSubscriptionNotifier.new,
          ),
          dailyReportDatesProvider.overrideWith(
            () => _FixedDailyReportDatesNotifier(
              _buildDailyReportDatesResponse(const []),
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: ProfilePage()),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('...'), findsNWidgets(4));
    expect(find.text('--'), findsOneWidget);
  });

  testWidgets('falls back to 0 when profile stats provider returns null', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_TestAuthNotifier.new),
          profileStatsProvider.overrideWith(
            () => _FixedProfileStatsNotifier(null),
          ),
          podcastSubscriptionProvider.overrideWith(
            _TestPodcastSubscriptionNotifier.new,
          ),
          dailyReportDatesProvider.overrideWith(
            () => _FixedDailyReportDatesNotifier(
              _buildDailyReportDatesResponse(const []),
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: ProfilePage()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('0'), findsNWidgets(4));
    expect(find.text('5'), findsNothing);
  });

  testWidgets('falls back to 0 when repository throws in provider chain', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_TestAuthNotifier.new),
          podcastRepositoryProvider.overrideWithValue(
            _ThrowingPodcastRepository(),
          ),
          podcastSubscriptionProvider.overrideWith(
            _TestPodcastSubscriptionNotifier.new,
          ),
          dailyReportDatesProvider.overrideWith(
            () => _FixedDailyReportDatesNotifier(
              _buildDailyReportDatesResponse(const []),
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: ProfilePage()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('0'), findsNWidgets(4));
    expect(find.text('5'), findsNothing);
  });

  testWidgets('clear cache entry triggers cache clear flow', (
    WidgetTester tester,
  ) async {
    final dioClient = _MockDioClient();
    final cacheService = _MockAppCacheService();
    final searchService = _MockITunesSearchService();
    final discoverService = _TrackingApplePodcastRssService();
    final prefs = await SharedPreferences.getInstance();

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: ProfilePage()),
        ),
        GoRoute(
          path: '/profile/cache',
          builder: (context, state) => const ProfileCacheManagementPage(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_TestAuthNotifier.new),
          profileStatsProvider.overrideWith(
            () => _FixedProfileStatsNotifier(_defaultProfileStats),
          ),
          podcastSubscriptionProvider.overrideWith(
            _TestPodcastSubscriptionNotifier.new,
          ),
          dailyReportDatesProvider.overrideWith(
            () => _FixedDailyReportDatesNotifier(
              _buildDailyReportDatesResponse(const []),
            ),
          ),
          dioClientProvider.overrideWithValue(dioClient),
          appCacheServiceProvider.overrideWithValue(cacheService),
          localStorageServiceProvider.overrideWithValue(
            LocalStorageServiceImpl(prefs),
          ),
          search.iTunesSearchServiceProvider.overrideWithValue(searchService),
          applePodcastRssServiceProvider.overrideWithValue(discoverService),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );

    await tester.pumpAndSettle();

    final clearCacheItem = find.byKey(const Key('profile_clear_cache_item'));
    await tester.scrollUntilVisible(
      clearCacheItem,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(clearCacheItem);
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(ProfileCacheManagementPage).evaluate().isNotEmpty) {
        break;
      }
    }
    expect(find.byType(ProfileCacheManagementPage), findsOneWidget);

    final deepCleanFinder = find.byKey(
      const Key('cache_manage_deep_clean_all'),
    );
    final cachePageScrollable = find.descendant(
      of: find.byType(ProfileCacheManagementPage),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      deepCleanFinder,
      200,
      scrollable: cachePageScrollable.first,
    );
    expect(deepCleanFinder, findsOneWidget);
    await tester.ensureVisible(deepCleanFinder);
    await tester.tap(deepCleanFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    verify(dioClient.clearCache()).called(1);
    verify(dioClient.clearETagCache()).called(1);
    verify(cacheService.clearAll()).called(1);
    verify(searchService.clearCache()).called(1);
    expect(discoverService.clearCacheCalls, 1);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('removes settings entries and updates action buttons', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_TestAuthNotifier.new),
          profileStatsProvider.overrideWith(
            () => _FixedProfileStatsNotifier(_defaultProfileStats),
          ),
          podcastSubscriptionProvider.overrideWith(
            _TestPodcastSubscriptionNotifier.new,
          ),
          dailyReportDatesProvider.overrideWith(
            () => _FixedDailyReportDatesNotifier(
              _buildDailyReportDatesResponse(const []),
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: ProfilePage()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final context = tester.element(find.byType(ProfilePage));
    final l10n = AppLocalizations.of(context)!;

    expect(find.text(l10n.profile_edit_profile), findsNothing);
    expect(find.text(l10n.profile_auto_sync), findsNothing);

    expect(find.byKey(const Key('profile_user_menu_button')), findsOneWidget);
  });

  testWidgets('top logout and user edit buttons open expected dialogs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_TestAuthNotifier.new),
          profileStatsProvider.overrideWith(
            () => _FixedProfileStatsNotifier(_defaultProfileStats),
          ),
          podcastSubscriptionProvider.overrideWith(
            _TestPodcastSubscriptionNotifier.new,
          ),
          dailyReportDatesProvider.overrideWith(
            () => _FixedDailyReportDatesNotifier(
              _buildDailyReportDatesResponse(const []),
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: ProfilePage()),
        ),
      ),
    );

    await tester.pumpAndSettle();
    final context = tester.element(find.byType(ProfilePage));
    final l10n = AppLocalizations.of(context)!;

    await tester.tap(find.byKey(const Key('profile_user_menu_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile_user_menu_item_logout')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.profile_logout_message), findsOneWidget);

    await tester.tap(find.text(l10n.cancel));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('profile_user_menu_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile_user_menu_item_edit')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.profile_edit_profile), findsOneWidget);
  });

  testWidgets('uses updated icons and consistent dialog widths on mobile', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_TestAuthNotifier.new),
          profileStatsProvider.overrideWith(
            () => _FixedProfileStatsNotifier(_defaultProfileStats),
          ),
          podcastSubscriptionProvider.overrideWith(
            _TestPodcastSubscriptionNotifier.new,
          ),
          dailyReportDatesProvider.overrideWith(
            () => _FixedDailyReportDatesNotifier(
              _buildDailyReportDatesResponse(const []),
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: ProfilePage()),
        ),
      ),
    );

    await tester.pumpAndSettle();
    final context = tester.element(find.byType(ProfilePage));
    final l10n = AppLocalizations.of(context)!;
    final expectedDialogActionColor = Theme.of(
      context,
    ).colorScheme.onSurfaceVariant;

    final securityTile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, l10n.profile_security),
    );

    expect((securityTile.leading as Icon).icon, Icons.shield);

    await tester.tap(find.byKey(const Key('profile_user_menu_button')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('profile_user_menu_item_logout')),
        matching: find.byIcon(Icons.logout),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('profile_user_menu_item_edit')),
        matching: find.byIcon(Icons.edit_note),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('profile_user_menu_item_edit')));
    await tester.pumpAndSettle();
    final editDialogWidth = tester.getSize(find.byType(AlertDialog)).width;
    await tester.tap(find.text(l10n.cancel));
    await tester.pumpAndSettle();

    final languageTile = find.widgetWithText(ListTile, l10n.language);
    await tester.ensureVisible(languageTile);
    await tester.tap(languageTile);
    await tester.pumpAndSettle();
    final languageDialogWidth = tester.getSize(find.byType(AlertDialog)).width;
    final dynamic languageSegmented = tester.widget(
      find.byKey(const Key('profile_language_segmented_button')),
    );
    final languageStyle = languageSegmented.style as ButtonStyle?;
    final languageSelectedColor = languageStyle?.foregroundColor?.resolve(
      <WidgetState>{WidgetState.selected},
    );
    expect(languageSelectedColor, expectedDialogActionColor);
    final languageCloseButton = tester.widget<TextButton>(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, l10n.close),
      ),
    );
    final languageCloseColor = languageCloseButton.style?.foregroundColor
        ?.resolve(<WidgetState>{});
    expect(languageCloseColor, expectedDialogActionColor);
    await tester.tap(find.text(l10n.close));
    await tester.pumpAndSettle();

    final themeModeTile = find.widgetWithText(ListTile, l10n.theme_mode);
    await tester.ensureVisible(themeModeTile);
    await tester.tap(themeModeTile);
    await tester.pumpAndSettle();
    final themeDialogWidth = tester.getSize(find.byType(AlertDialog)).width;
    final dynamic themeSegmented = tester.widget(
      find.byKey(const Key('profile_theme_segmented_button')),
    );
    final themeStyle = themeSegmented.style as ButtonStyle?;
    final themeSelectedColor = themeStyle?.foregroundColor?.resolve(
      <WidgetState>{WidgetState.selected},
    );
    expect(themeSelectedColor, expectedDialogActionColor);
    final themeCloseButton = tester.widget<TextButton>(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, l10n.close),
      ),
    );
    final themeCloseColor = themeCloseButton.style?.foregroundColor?.resolve(
      <WidgetState>{},
    );
    expect(themeCloseColor, expectedDialogActionColor);
    await tester.tap(find.text(l10n.close));
    await tester.pumpAndSettle();

    final securityTileFinder = find.widgetWithText(
      ListTile,
      l10n.profile_security,
    );
    await tester.ensureVisible(securityTileFinder);
    await tester.tap(securityTileFinder);
    await tester.pumpAndSettle();
    final securityDialogWidth = tester.getSize(find.byType(AlertDialog)).width;
    final securityCloseButton = tester.widget<TextButton>(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, l10n.close),
      ),
    );
    final securityCloseColor = securityCloseButton.style?.foregroundColor
        ?.resolve(<WidgetState>{});
    expect(securityCloseColor, expectedDialogActionColor);
    await tester.tap(find.text(l10n.close));
    await tester.pumpAndSettle();

    final helpTile = find.widgetWithText(ListTile, l10n.profile_help_center);
    await tester.ensureVisible(helpTile);
    await tester.tap(helpTile);
    await tester.pumpAndSettle();
    final helpDialogWidth = tester.getSize(find.byType(AlertDialog)).width;
    final helpCloseButton = tester.widget<TextButton>(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, l10n.close),
      ),
    );
    final helpCloseColor = helpCloseButton.style?.foregroundColor?.resolve(
      <WidgetState>{},
    );
    expect(helpCloseColor, expectedDialogActionColor);
    await tester.tap(find.text(l10n.close));
    await tester.pumpAndSettle();

    final versionTile = find.byKey(const Key('profile_version_item'));
    await tester.ensureVisible(versionTile);
    await tester.tap(versionTile);
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();
    final aboutDialogWidth = tester.getSize(find.byType(AlertDialog)).width;
    final aboutOkButton = tester.widget<TextButton>(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(TextButton, l10n.ok),
      ),
    );
    final aboutOkColor = aboutOkButton.style?.foregroundColor?.resolve(
      <WidgetState>{},
    );
    expect(aboutOkColor, expectedDialogActionColor);
    await tester.tap(find.text(l10n.ok));
    await tester.pumpAndSettle();

    expect(editDialogWidth, closeTo(languageDialogWidth, 0.01));
    expect(themeDialogWidth, closeTo(languageDialogWidth, 0.01));
    expect(securityDialogWidth, closeTo(languageDialogWidth, 0.01));
    expect(helpDialogWidth, closeTo(languageDialogWidth, 0.01));
    expect(aboutDialogWidth, closeTo(languageDialogWidth, 0.01));
  });

  testWidgets('single tap version opens about and 5 taps opens server config', (
    WidgetTester tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_TestAuthNotifier.new),
          profileStatsProvider.overrideWith(
            () => _FixedProfileStatsNotifier(_defaultProfileStats),
          ),
          localStorageServiceProvider.overrideWithValue(
            LocalStorageServiceImpl(prefs),
          ),
          podcastSubscriptionProvider.overrideWith(
            _TestPodcastSubscriptionNotifier.new,
          ),
          dailyReportDatesProvider.overrideWith(
            () => _FixedDailyReportDatesNotifier(
              _buildDailyReportDatesResponse(const []),
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: ProfilePage()),
        ),
      ),
    );

    await tester.pumpAndSettle();
    final context = tester.element(find.byType(ProfilePage));
    final l10n = AppLocalizations.of(context)!;
    final versionFinder = find.byKey(const Key('profile_version_item'));

    await tester.ensureVisible(versionFinder);
    await tester.tap(versionFinder);
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();
    expect(find.text(l10n.appTitle), findsOneWidget);

    await tester.tap(find.text(l10n.ok));
    await tester.pumpAndSettle();

    await tester.ensureVisible(versionFinder);
    for (var i = 0; i < 5; i++) {
      await tester.tap(versionFinder);
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    expect(find.text(l10n.backend_api_server_config), findsOneWidget);
  });

  testWidgets('two taps on version does not trigger dialogs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_TestAuthNotifier.new),
          profileStatsProvider.overrideWith(
            () => _FixedProfileStatsNotifier(_defaultProfileStats),
          ),
          podcastSubscriptionProvider.overrideWith(
            _TestPodcastSubscriptionNotifier.new,
          ),
          dailyReportDatesProvider.overrideWith(
            () => _FixedDailyReportDatesNotifier(
              _buildDailyReportDatesResponse(const []),
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: ProfilePage()),
        ),
      ),
    );

    await tester.pumpAndSettle();
    final context = tester.element(find.byType(ProfilePage));
    final l10n = AppLocalizations.of(context)!;
    final versionFinder = find.byKey(const Key('profile_version_item'));

    await tester.ensureVisible(versionFinder);
    await tester.tap(versionFinder);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(versionFinder);
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();

    expect(find.text(l10n.appTitle), findsNothing);
    expect(find.text(l10n.backend_api_server_config), findsNothing);
  });

  testWidgets('uses feed-style card shape and width on mobile profile cards', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_TestAuthNotifier.new),
          profileStatsProvider.overrideWith(
            () => _FixedProfileStatsNotifier(_defaultProfileStats),
          ),
          podcastSubscriptionProvider.overrideWith(
            _TestPodcastSubscriptionNotifier.new,
          ),
          dailyReportDatesProvider.overrideWith(
            () => _FixedDailyReportDatesNotifier(
              _buildDailyReportDatesResponse(const []),
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: ProfilePage()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final cards = tester.widgetList<Card>(find.byType(Card)).toList();
    expect(cards, isNotEmpty);

    for (final card in cards) {
      expect(card.margin, const EdgeInsets.symmetric(horizontal: 4));
      expect(card.shape, isA<RoundedRectangleBorder>());

      final shape = card.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(12));
      expect(shape.side.style, BorderStyle.none);
      expect(shape.side.width, 0);
    }
  });

  testWidgets('mobile profile header stays above subscriptions card', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_TestAuthNotifier.new),
          profileStatsProvider.overrideWith(
            () => _FixedProfileStatsNotifier(_defaultProfileStats),
          ),
          podcastSubscriptionProvider.overrideWith(
            _TestPodcastSubscriptionNotifier.new,
          ),
          dailyReportDatesProvider.overrideWith(
            () => _FixedDailyReportDatesNotifier(
              _buildDailyReportDatesResponse(const []),
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: ProfilePage()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final headerRect = tester.getRect(
      find.byKey(const Key('profile_hero_header')).last,
    );
    final subscriptionsRect = tester.getRect(
      find.byKey(const Key('profile_subscriptions_card')),
    );

    expect(headerRect.bottom, lessThanOrEqualTo(subscriptionsRect.top));
  });

  testWidgets('short profile screens keep shared shell header and backdrop', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_TestAuthNotifier.new),
          profileStatsProvider.overrideWith(
            () => _FixedProfileStatsNotifier(_defaultProfileStats),
          ),
          podcastSubscriptionProvider.overrideWith(
            _TestPodcastSubscriptionNotifier.new,
          ),
          dailyReportDatesProvider.overrideWith(
            () => _FixedDailyReportDatesNotifier(
              _buildDailyReportDatesResponse(const []),
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: ProfilePage()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(AppPageBackdrop), findsOneWidget);
    expect(find.byKey(const Key('profile_hero_header')).last, findsOneWidget);
    expect(find.byKey(const Key('profile_user_menu_button')), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsWidgets);
    final viewportClip = tester.widget<ClipRRect>(
      find.byKey(const Key('profile_shell_viewport_clip')),
    );
    expect(viewportClip.borderRadius, BorderRadius.circular(28));
  });

  testWidgets('keeps desktop profile cards unchanged', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_TestAuthNotifier.new),
          profileStatsProvider.overrideWith(
            () => _FixedProfileStatsNotifier(_defaultProfileStats),
          ),
          podcastSubscriptionProvider.overrideWith(
            _TestPodcastSubscriptionNotifier.new,
          ),
          dailyReportDatesProvider.overrideWith(
            () => _FixedDailyReportDatesNotifier(
              _buildDailyReportDatesResponse(const []),
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: ProfilePage()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('profile_viewed_card_chevron')),
      findsOneWidget,
    );

    final cards = tester.widgetList<Card>(find.byType(Card)).toList();
    expect(cards, isNotEmpty);

    for (final card in cards) {
      expect(card.margin, EdgeInsets.zero);
      expect(card.shape, isNull);
    }
  });
}
