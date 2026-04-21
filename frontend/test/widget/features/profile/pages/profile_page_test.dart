import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/core/network/dio_client.dart';
import 'package:personal_ai_assistant/core/providers/core_providers.dart';
import 'package:personal_ai_assistant/core/services/app_cache_service.dart';
import 'package:personal_ai_assistant/core/storage/local_storage_service.dart';
import 'package:personal_ai_assistant/features/auth/domain/models/user.dart';
import 'package:personal_ai_assistant/features/auth/presentation/providers/auth_provider.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_daily_report_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_state_models.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/profile_stats_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/repositories/podcast_repository.dart';
import 'package:personal_ai_assistant/features/podcast/data/services/apple_podcast_rss_service.dart';
import 'package:personal_ai_assistant/features/podcast/data/services/itunes_search_service.dart';
import 'package:personal_ai_assistant/features/podcast/data/services/podcast_api_service.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_daily_report_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_search_provider.dart';
import 'package:personal_ai_assistant/features/profile/presentation/pages/profile_cache_management_page.dart';
import 'package:personal_ai_assistant/features/profile/presentation/pages/profile_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../helpers/podcast_list_page_helper.dart';

class _TestAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return const AuthState(
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

class _ThrowingPodcastApiService extends Mock implements PodcastApiService {
  @override
  Future<ProfileStatsModel> getProfileStats() async {
    throw Exception('profile stats failed');
  }
}

class _ThrowingPodcastRepository extends PodcastRepository {
  _ThrowingPodcastRepository() : super(_ThrowingPodcastApiService());

  @override
  Future<ProfileStatsModel> getProfileStats() async {
    throw Exception('profile stats failed');
  }
}

class _MockDioClient extends Mock implements DioClient {}

class _MockAppCacheService extends Mock implements AppCacheService {
  @override
  CacheManager get mediaCacheManager => AppMediaCacheManager.instance;
}

class _MockITunesSearchService extends Mock implements ITunesSearchService {}

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
              'packageName': 'com.opc.stella',
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
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(_TestAuthNotifier.new),
            profileStatsProvider.overrideWith(
              () => _FixedProfileStatsNotifier(_profileStatsWithDailyReport),
            ),
            podcastSubscriptionProvider.overrideWith(
              () => TestPodcastSubscriptionNotifier(const PodcastSubscriptionState(total: 5)),
            ),
            dailyReportDatesProvider.overrideWith(
              () => _FixedDailyReportDatesNotifier(
                _buildDailyReportDatesResponse(const []),
              ),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ProfilePage()),
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
    tester,
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
            () => TestPodcastSubscriptionNotifier(const PodcastSubscriptionState(total: 5)),
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
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(_TestAuthNotifier.new),
            profileStatsProvider.overrideWith(
              () => _FixedProfileStatsNotifier(_profileStatsWithDailyReport),
            ),
            podcastSubscriptionProvider.overrideWith(
              () => TestPodcastSubscriptionNotifier(const PodcastSubscriptionState(total: 5)),
            ),
            dailyReportDatesProvider.overrideWith(
              () => _FixedDailyReportDatesNotifier(
                _buildDailyReportDatesResponse([DateTime(2026, 2, 20)]),
              ),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ProfilePage()),
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
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(_TestAuthNotifier.new),
            profileStatsProvider.overrideWith(
              () => _FixedProfileStatsNotifier(_profileStatsWithDailyReport),
            ),
            podcastSubscriptionProvider.overrideWith(
              () => TestPodcastSubscriptionNotifier(const PodcastSubscriptionState(total: 5)),
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
      expect(subscriptionsIcon.color, equals(scheme.secondary));

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
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(_TestAuthNotifier.new),
            profileStatsProvider.overrideWith(
              () => _FixedProfileStatsNotifier(_profileStatsWithDailyReport),
            ),
            podcastSubscriptionProvider.overrideWith(
              () => TestPodcastSubscriptionNotifier(const PodcastSubscriptionState(total: 5)),
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
      expect(subscriptionsIcon.color, equals(scheme.secondary));

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
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_TestAuthNotifier.new),
          profileStatsProvider.overrideWith(
            () => _FixedProfileStatsNotifier(_defaultProfileStats),
          ),
          podcastSubscriptionProvider.overrideWith(
            () => TestPodcastSubscriptionNotifier(const PodcastSubscriptionState(total: 5)),
          ),
          dailyReportDatesProvider.overrideWith(
            () => _FixedDailyReportDatesNotifier(
              _buildDailyReportDatesResponse(const []),
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ProfilePage()),
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
    tester,
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
            () => TestPodcastSubscriptionNotifier(const PodcastSubscriptionState(total: 5)),
          ),
          dailyReportDatesProvider.overrideWith(
            () => _FixedDailyReportDatesNotifier(
              _buildDailyReportDatesResponse(const []),
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ProfilePage()),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('...'), findsNWidgets(5));
    expect(find.text('--'), findsOneWidget);
  });

  testWidgets('falls back to 0 when profile stats provider returns null', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_TestAuthNotifier.new),
          profileStatsProvider.overrideWith(
            () => _FixedProfileStatsNotifier(null),
          ),
          podcastSubscriptionProvider.overrideWith(
            () => TestPodcastSubscriptionNotifier(const PodcastSubscriptionState(total: 5)),
          ),
          dailyReportDatesProvider.overrideWith(
            () => _FixedDailyReportDatesNotifier(
              _buildDailyReportDatesResponse(const []),
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ProfilePage()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('0'), findsNWidgets(5));
    expect(find.text('5'), findsNothing);
  });

  testWidgets('falls back to 0 when repository throws in provider chain', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_TestAuthNotifier.new),
          podcastRepositoryProvider.overrideWithValue(
            _ThrowingPodcastRepository(),
          ),
          podcastSubscriptionProvider.overrideWith(
            () => TestPodcastSubscriptionNotifier(const PodcastSubscriptionState(total: 5)),
          ),
          dailyReportDatesProvider.overrideWith(
            () => _FixedDailyReportDatesNotifier(
              _buildDailyReportDatesResponse(const []),
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ProfilePage()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('0'), findsNWidgets(5));
    expect(find.text('5'), findsNothing);
  });

  testWidgets('clear cache entry triggers cache clear flow', (
    tester,
  ) async {
    final dioClient = _MockDioClient();
    final cacheService = _MockAppCacheService();
    final searchService = _MockITunesSearchService();
    final discoverService = _TrackingApplePodcastRssService();
    final prefs = await SharedPreferences.getInstance();

    when(() => dioClient.clearCache()).thenAnswer((_) async {});
    when(() => dioClient.clearETagCache()).thenReturn(null);
    when(() => cacheService.clearAll()).thenAnswer((_) async {});
    when(() => cacheService.clearMediaCache()).thenAnswer((_) async {});
    when(() => cacheService.clearMemoryImageCache()).thenAnswer((_) async {});
    when(() => cacheService.warmUp(any())).thenAnswer((_) async {});
    when(() => cacheService.getCacheStats()).thenAnswer((_) async => {});
    when(() => cacheService.getCachedFileInfo(any())).thenAnswer((_) async => null);
    when(() => searchService.clearCache()).thenReturn(null);

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
            () => TestPodcastSubscriptionNotifier(const PodcastSubscriptionState(total: 5)),
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
          iTunesSearchServiceProvider.overrideWithValue(searchService),
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
    await tester.ensureVisible(clearCacheItem);
    await tester.pumpAndSettle();
    await tester.tap(clearCacheItem);
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(ProfileCacheManagementPage).evaluate().isNotEmpty) {
        break;
      }
    }
    expect(find.byType(ProfileCacheManagementPage), findsOneWidget);
    await tester.pumpAndSettle();

    final deepCleanFinder = find.byKey(
      const Key('cache_manage_deep_clean_all'),
    );
    await tester.ensureVisible(deepCleanFinder);
    await tester.pumpAndSettle();
    expect(deepCleanFinder, findsOneWidget);
    await tester.ensureVisible(deepCleanFinder);
    await tester.tap(deepCleanFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.widgetWithText(TextButton, 'Clear'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    verify(() => dioClient.clearCache()).called(1);
    verify(() => dioClient.clearETagCache()).called(1);
    verify(() => cacheService.clearAll()).called(1);
    verify(() => searchService.clearCache()).called(1);
    expect(discoverService.clearCacheCalls, 1);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('removes settings entries and updates action buttons', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_TestAuthNotifier.new),
          profileStatsProvider.overrideWith(
            () => _FixedProfileStatsNotifier(_defaultProfileStats),
          ),
          podcastSubscriptionProvider.overrideWith(
            () => TestPodcastSubscriptionNotifier(const PodcastSubscriptionState(total: 5)),
          ),
          dailyReportDatesProvider.overrideWith(
            () => _FixedDailyReportDatesNotifier(
              _buildDailyReportDatesResponse(const []),
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ProfilePage()),
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
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_TestAuthNotifier.new),
          profileStatsProvider.overrideWith(
            () => _FixedProfileStatsNotifier(_defaultProfileStats),
          ),
          podcastSubscriptionProvider.overrideWith(
            () => TestPodcastSubscriptionNotifier(const PodcastSubscriptionState(total: 5)),
          ),
          dailyReportDatesProvider.overrideWith(
            () => _FixedDailyReportDatesNotifier(
              _buildDailyReportDatesResponse(const []),
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ProfilePage()),
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
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_TestAuthNotifier.new),
          localStorageServiceProvider.overrideWithValue(
            LocalStorageServiceImpl(prefs),
          ),
          profileStatsProvider.overrideWith(
            () => _FixedProfileStatsNotifier(_defaultProfileStats),
          ),
          podcastSubscriptionProvider.overrideWith(
            () => TestPodcastSubscriptionNotifier(const PodcastSubscriptionState(total: 5)),
          ),
          dailyReportDatesProvider.overrideWith(
            () => _FixedDailyReportDatesNotifier(
              _buildDailyReportDatesResponse(const []),
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ProfilePage()),
        ),
      ),
    );

    await tester.pumpAndSettle();
    final context = tester.element(find.byType(ProfilePage));
    final l10n = AppLocalizations.of(context)!;

    final securityTile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, l10n.profile_security),
    );

    expect((securityTile.leading! as Icon).icon, Icons.shield);
    final serverConfigSupportTile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, l10n.backend_api_server_config),
    );
    expect((serverConfigSupportTile.leading! as Icon).icon, Icons.dns);

    await tester.tap(find.byKey(const Key('profile_user_menu_button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('profile_user_menu_item_logout')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('profile_user_menu_item_edit')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('profile_user_menu_item_edit')));
    await tester.pumpAndSettle();
    final editDialogWidth = tester.getSize(find.byType(Dialog)).width;
    await tester.tap(find.text(l10n.ok));
    await tester.pumpAndSettle();

    final languageTile = find.widgetWithText(ListTile, l10n.language);
    await tester.ensureVisible(languageTile);
    await tester.tap(languageTile);
    await tester.pumpAndSettle();
    final languageDialogWidth = tester.getSize(find.byType(Dialog)).width;
    final languageSegmentedButton = tester.widget<SegmentedButton<String>>(
      find.descendant(
        of: find.byKey(const Key('profile_language_segmented_button')),
        matching: find.byType(SegmentedButton<String>),
      ),
    );
    expect(languageSegmentedButton.selected, isNotEmpty);
    final languageCloseButton = tester.widget<TextButton>(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.widgetWithText(TextButton, l10n.close),
      ),
    );
    expect(languageCloseButton.onPressed, isNotNull);
    await tester.tap(find.text(l10n.close));
    await tester.pumpAndSettle();

    // Appearance tile replaces the old Theme Mode dialog;
    // it navigates to /settings/appearance instead of opening a dialog.
    final appearanceTile = find.widgetWithText(ListTile, l10n.appearance_title);
    expect(appearanceTile, findsOneWidget);

    final securityTileFinder = find.widgetWithText(
      ListTile,
      l10n.profile_security,
    );
    await tester.ensureVisible(securityTileFinder);
    await tester.tap(securityTileFinder);
    await tester.pumpAndSettle();
    final securityDialogWidth = tester.getSize(find.byType(Dialog)).width;
    final securityCloseButton = tester.widget<TextButton>(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.widgetWithText(TextButton, l10n.close),
      ),
    );
    expect(securityCloseButton.onPressed, isNotNull);
    await tester.tap(find.text(l10n.close));
    await tester.pumpAndSettle();

    final serverConfigTile = find.widgetWithText(
      ListTile,
      l10n.backend_api_server_config,
    );
    await tester.ensureVisible(serverConfigTile);
    await tester.tap(serverConfigTile);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text(l10n.backend_api_server_config),
      ),
      findsOneWidget,
    );
    final serverConfigCancelButton = tester.widget<TextButton>(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.widgetWithText(TextButton, l10n.cancel),
      ),
    );
    expect(serverConfigCancelButton.onPressed, isNotNull);
    await tester.tap(find.text(l10n.cancel));
    await tester.pumpAndSettle();

    final versionTile = find.byKey(const Key('profile_version_item'));
    await tester.ensureVisible(versionTile);
    await tester.tap(versionTile);
    await tester.pumpAndSettle();
    final aboutDialogWidth = tester.getSize(find.byType(Dialog)).width;
    final aboutOkButton = tester.widget<TextButton>(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.widgetWithText(TextButton, l10n.ok),
      ),
    );
    expect(aboutOkButton.onPressed, isNotNull);
    await tester.tap(find.text(l10n.ok));
    await tester.pumpAndSettle();

    expect(editDialogWidth, closeTo(languageDialogWidth, 0.01));
    expect(securityDialogWidth, closeTo(languageDialogWidth, 0.01));
    expect(aboutDialogWidth, closeTo(languageDialogWidth, 0.01));
  });

  testWidgets('single tap version opens about dialog', (
    tester,
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
            () => TestPodcastSubscriptionNotifier(const PodcastSubscriptionState(total: 5)),
          ),
          dailyReportDatesProvider.overrideWith(
            () => _FixedDailyReportDatesNotifier(
              _buildDailyReportDatesResponse(const []),
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ProfilePage()),
        ),
      ),
    );

    await tester.pumpAndSettle();
    final context = tester.element(find.byType(ProfilePage));
    final l10n = AppLocalizations.of(context)!;
    final versionFinder = find.byKey(const Key('profile_version_item'));

    await tester.ensureVisible(versionFinder);
    await tester.tap(versionFinder);
    await tester.pumpAndSettle();
    expect(find.text(l10n.appTitle), findsOneWidget);

    await tester.tap(find.text(l10n.ok));
    await tester.pumpAndSettle();
  });

  testWidgets('uses feed-style card shape and width on mobile profile cards', (
    tester,
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
            () => TestPodcastSubscriptionNotifier(const PodcastSubscriptionState(total: 5)),
          ),
          dailyReportDatesProvider.overrideWith(
            () => _FixedDailyReportDatesNotifier(
              _buildDailyReportDatesResponse(const []),
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ProfilePage()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final cards = tester.widgetList<SurfacePanel>(
      find.byType(SurfacePanel),
    ).toList();
    expect(cards, isNotEmpty);

    for (final card in cards) {
      expect(card.borderRadius, 14);
    }
  });

  testWidgets('mobile profile header stays above subscriptions card', (
    tester,
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
            () => TestPodcastSubscriptionNotifier(const PodcastSubscriptionState(total: 5)),
          ),
          dailyReportDatesProvider.overrideWith(
            () => _FixedDailyReportDatesNotifier(
              _buildDailyReportDatesResponse(const []),
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ProfilePage()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final headerRect = tester.getRect(
      find.byKey(const Key('profile_user_menu_button')),
    );
    final subscriptionsRect = tester.getRect(
      find.byKey(const Key('profile_subscriptions_card')),
    );

    expect(headerRect.bottom, lessThanOrEqualTo(subscriptionsRect.top));
  });

  testWidgets('short profile screens keep shared shell header and backdrop', (
    tester,
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
            () => TestPodcastSubscriptionNotifier(const PodcastSubscriptionState(total: 5)),
          ),
          dailyReportDatesProvider.overrideWith(
            () => _FixedDailyReportDatesNotifier(
              _buildDailyReportDatesResponse(const []),
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ProfilePage()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(HeroHeader), findsWidgets);
    expect(find.byKey(const Key('profile_user_menu_button')), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsWidgets);
    final viewportClip = tester.widget<ClipRRect>(
      find.byKey(const Key('content_shell_viewport_clip')),
    );
    expect(viewportClip.borderRadius, BorderRadius.circular(14));
  });

  testWidgets('keeps desktop profile cards unchanged', (
    tester,
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
            () => TestPodcastSubscriptionNotifier(const PodcastSubscriptionState(total: 5)),
          ),
          dailyReportDatesProvider.overrideWith(
            () => _FixedDailyReportDatesNotifier(
              _buildDailyReportDatesResponse(const []),
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ProfilePage()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('profile_viewed_card_chevron')),
      findsOneWidget,
    );

    final cards = tester.widgetList<SurfacePanel>(
      find.byType(SurfacePanel),
    ).toList();
    expect(cards, isNotEmpty);
  });
}
