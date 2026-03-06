import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/theme/app_theme.dart';
import 'package:personal_ai_assistant/features/auth/presentation/providers/auth_provider.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_daily_report_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_state_models.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/pages/podcast_daily_report_page.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/pages/podcast_feed_page.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';

void main() {
  group('PodcastFeedPage daily report entry', () {
    testWidgets('shows library entry and navigates to daily report route', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const PodcastFeedPage(),
          ),
          GoRoute(
            path: '/reports/daily',
            name: 'dailyReport',
            builder: (context, state) =>
                const Scaffold(body: Text('daily-route')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            podcastFeedProvider.overrideWith(
              () => _TestPodcastFeedNotifier(_feedState()),
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

      final entryFinder = find.byKey(
        const Key('library_daily_report_entry_tile'),
      );
      expect(entryFinder, findsOneWidget);

      await tester.tap(entryFinder);
      await tester.pumpAndSettle();
      expect(find.text('daily-route'), findsOneWidget);
    });

    testWidgets('uses menu icon color for daily report icon in dark mode', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            podcastFeedProvider.overrideWith(
              () => _TestPodcastFeedNotifier(_feedState()),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData.light(useMaterial3: true),
            darkTheme: ThemeData.dark(useMaterial3: true),
            themeMode: ThemeMode.dark,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PodcastFeedPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final entryFinder = find.byKey(
        const Key('library_daily_report_entry_tile'),
      );
      expect(entryFinder, findsOneWidget);

      final icon = tester.widget<Icon>(
        find.descendant(
          of: entryFinder,
          matching: find.byIcon(Icons.summarize_outlined),
        ),
      );
      final context = tester.element(entryFinder);
      expect(
        icon.color,
        equals(Theme.of(context).colorScheme.onSurfaceVariant),
      );
    });

    testWidgets('uses menu icon color for daily report icon in light mode', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            podcastFeedProvider.overrideWith(
              () => _TestPodcastFeedNotifier(_feedState()),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData.light(useMaterial3: true),
            darkTheme: ThemeData.dark(useMaterial3: true),
            themeMode: ThemeMode.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PodcastFeedPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final entryFinder = find.byKey(
        const Key('library_daily_report_entry_tile'),
      );
      expect(entryFinder, findsOneWidget);

      final icon = tester.widget<Icon>(
        find.descendant(
          of: entryFinder,
          matching: find.byIcon(Icons.summarize_outlined),
        ),
      );
      final context = tester.element(entryFinder);
      expect(
        icon.color,
        equals(Theme.of(context).colorScheme.onSurfaceVariant),
      );
    });
  });

  group('PodcastDailyReportPage', () {
    testWidgets('renders glass loading state while initial report is pending', (
      tester,
    ) async {
      final previousDay = _dateOnlyNowMinus(1);
      await tester.pumpWidget(
        _buildReportApp(
          dailyReportNotifier: _LoadingDailyReportNotifier(),
          datesNotifier: _StaticDailyReportDatesNotifier(_dates([previousDay])),
          selectedDateNotifier: _FixedSelectedDailyReportDateNotifier(
            previousDay,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Daily Report'), findsOneWidget);
      expect(find.text('Loading daily report...'), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('renders retry action when initial report load fails', (
      tester,
    ) async {
      final previousDay = _dateOnlyNowMinus(1);
      await tester.pumpWidget(
        _buildReportApp(
          dailyReportNotifier: _ErrorDailyReportNotifier(),
          datesNotifier: _StaticDailyReportDatesNotifier(_dates([previousDay])),
          selectedDateNotifier: _FixedSelectedDailyReportDateNotifier(
            previousDay,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Failed to load feed'), findsWidgets);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('renders daily report page with calendar action and items', (
      tester,
    ) async {
      final previousDay = _dateOnlyNowMinus(1);
      await tester.pumpWidget(
        _buildReportApp(
          dailyReportNotifier: _StaticDailyReportNotifier(
            _reportForDate(previousDay),
          ),
          datesNotifier: _StaticDailyReportDatesNotifier(
            _dates([previousDay, _dateOnlyNowMinus(2)]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('daily_report_page')), findsOneWidget);
      expect(
        find.byKey(const Key('daily_report_calendar_menu_button')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('daily_report_calendar')), findsNothing);
      expect(find.text('Daily Report'), findsOneWidget);
      expect(find.text(_dateKey(previousDay)), findsWidgets);
      expect(find.text('Report summary ${previousDay.day}'), findsOneWidget);
    });

    testWidgets('shows marker dot for date with available report', (
      tester,
    ) async {
      final previousDay = _dateOnlyNowMinus(1);
      await tester.pumpWidget(
        _buildReportApp(
          dailyReportNotifier: _StaticDailyReportNotifier(
            _reportForDate(previousDay),
          ),
          datesNotifier: _StaticDailyReportDatesNotifier(
            _dates([previousDay, _dateOnlyNowMinus(2)]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _openCalendarPanel(tester);
      expect(find.byKey(_calendarMarkerKey(previousDay)), findsOneWidget);
    });

    testWidgets('summary is always expanded without toggle button', (
      tester,
    ) async {
      final previousDay = _dateOnlyNowMinus(1);
      const rawSummary =
          'This is a long report summary line one. This is line two. This is line three. ---';
      const expectedSummary =
          'This is a long report summary line one. This is line two. This is line three.';
      await tester.pumpWidget(
        _buildReportApp(
          dailyReportNotifier: _StaticDailyReportNotifier(
            _reportForDate(previousDay, summary: rawSummary),
          ),
          datesNotifier: _StaticDailyReportDatesNotifier(
            _dates([previousDay, _dateOnlyNowMinus(2)]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(Key('daily_report_item_toggle_${previousDay.day}')),
        findsNothing,
      );
      expect(find.text('Expand'), findsNothing);
      expect(find.text('Collapse'), findsNothing);
      expect(find.text(rawSummary), findsNothing);
      expect(find.text(expectedSummary), findsOneWidget);
    });

    testWidgets('tapping report item navigates to episode detail', (
      tester,
    ) async {
      final previousDay = _dateOnlyNowMinus(1);
      await tester.pumpWidget(
        _buildReportApp(
          dailyReportNotifier: _StaticDailyReportNotifier(
            _reportForDate(previousDay),
          ),
          datesNotifier: _StaticDailyReportDatesNotifier(
            _dates([previousDay, _dateOnlyNowMinus(2)]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(Key('daily_report_item_${previousDay.day}')));
      await tester.pumpAndSettle();

      expect(find.text('detail:${previousDay.day}'), findsOneWidget);
    });

    testWidgets(
      'switching historical date from calendar updates report content',
      (tester) async {
        final previousDay = _dateOnlyNowMinus(1);
        final twoDaysAgo = _dateOnlyNowMinus(2);
        await tester.pumpWidget(
          _buildReportApp(
            dailyReportNotifier: _SwitchingDailyReportNotifier({
              _dateKey(previousDay): _reportForDate(previousDay),
              _dateKey(twoDaysAgo): _reportForDate(twoDaysAgo),
            }),
            datesNotifier: _StaticDailyReportDatesNotifier(
              _dates([previousDay, twoDaysAgo]),
            ),
            selectedDateNotifier: _FixedSelectedDailyReportDateNotifier(
              previousDay,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Report summary ${previousDay.day}'), findsOneWidget);
        await _openCalendarPanel(tester);
        await tester.tap(find.byKey(_calendarDayKey(twoDaysAgo)));
        await tester.pumpAndSettle();

        expect(find.text('Report summary ${twoDaysAgo.day}'), findsOneWidget);
      },
    );

    testWidgets('clicking date without report shows empty state and refresh', (
      tester,
    ) async {
      final previousDay = _dateOnlyNowMinus(1);
      final twoDaysAgo = _dateOnlyNowMinus(2);
      await tester.pumpWidget(
        _buildReportApp(
          dailyReportNotifier: _SwitchingDailyReportNotifier({
            _dateKey(previousDay): _reportForDate(previousDay),
          }),
          datesNotifier: _StaticDailyReportDatesNotifier(_dates([previousDay])),
          selectedDateNotifier: _FixedSelectedDailyReportDateNotifier(
            previousDay,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _openCalendarPanel(tester);
      await tester.tap(find.byKey(_calendarDayKey(twoDaysAgo)));
      await tester.pumpAndSettle();

      expect(find.text('No daily report available yet'), findsWidgets);
      expect(find.text(_dateKey(twoDaysAgo)), findsWidgets);
      expect(
        find.byKey(const Key('daily_report_regenerate_button')),
        findsOneWidget,
      );
    });

    testWidgets('swiping month triggers progressive date coverage loading', (
      tester,
    ) async {
      final previousDay = _dateOnlyNowMinus(1);
      final datesNotifier = _TrackingDailyReportDatesNotifier(
        _dates([previousDay, _dateOnlyNowMinus(2)]),
      );
      await tester.pumpWidget(
        _buildReportApp(
          dailyReportNotifier: _StaticDailyReportNotifier(
            _reportForDate(previousDay),
          ),
          datesNotifier: datesNotifier,
          selectedDateNotifier: _FixedSelectedDailyReportDateNotifier(
            previousDay,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _openCalendarPanel(tester);
      final baselineCalls = datesNotifier.ensureCoverageCalls.length;
      await tester.drag(
        find.byKey(const Key('daily_report_calendar')),
        const Offset(420, 0),
      );
      await tester.pumpAndSettle();

      expect(
        datesNotifier.ensureCoverageCalls.length,
        greaterThan(baselineCalls),
      );
    });

    testWidgets(
      'selecting date closes calendar panel and updates report content',
      (tester) async {
        final previousDay = _dateOnlyNowMinus(1);
        final twoDaysAgo = _dateOnlyNowMinus(2);
        await tester.pumpWidget(
          _buildReportApp(
            dailyReportNotifier: _SwitchingDailyReportNotifier({
              _dateKey(previousDay): _reportForDate(previousDay),
              _dateKey(twoDaysAgo): _reportForDate(twoDaysAgo),
            }),
            datesNotifier: _StaticDailyReportDatesNotifier(
              _dates([previousDay, twoDaysAgo]),
            ),
            selectedDateNotifier: _FixedSelectedDailyReportDateNotifier(
              previousDay,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('daily_report_calendar_panel')),
          findsNothing,
        );
        await _openCalendarPanel(tester);
        expect(
          find.byKey(const Key('daily_report_calendar_panel')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(_calendarDayKey(twoDaysAgo)));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('daily_report_calendar_panel')),
          findsNothing,
        );
        expect(find.text('Report summary ${twoDaysAgo.day}'), findsOneWidget);
      },
    );

    testWidgets('shows empty state when report is unavailable', (tester) async {
      final previousDay = _dateOnlyNowMinus(1);
      await tester.pumpWidget(
        _buildReportApp(
          dailyReportNotifier: _StaticDailyReportNotifier(
            const PodcastDailyReportResponse(
              available: false,
              timezone: 'Asia/Shanghai',
              scheduleTimeLocal: '03:30',
              totalItems: 0,
              items: [],
            ),
          ),
          datesNotifier: _StaticDailyReportDatesNotifier(
            _dates([previousDay, _dateOnlyNowMinus(2)]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No daily report available yet'), findsWidgets);
    });

    testWidgets('shows refresh button and generates report', (tester) async {
      final twoDaysAgo = _dateOnlyNowMinus(2);
      final notifier = _GeneratingDailyReportNotifier(
        initialReport: _unavailableReportForDate(twoDaysAgo),
        generatedReport: _reportForDate(twoDaysAgo),
      );
      await tester.pumpWidget(
        _buildReportApp(
          dailyReportNotifier: notifier,
          datesNotifier: _StaticDailyReportDatesNotifier(_dates([twoDaysAgo])),
          selectedDateNotifier: _FixedSelectedDailyReportDateNotifier(
            twoDaysAgo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final buttonFinder = find.byKey(
        const Key('daily_report_regenerate_button'),
      );
      expect(buttonFinder, findsOneWidget);

      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      expect(notifier.generateCalls, 1);
      expect(notifier.lastRebuild, true);
      expect(find.text('Report summary ${twoDaysAgo.day}'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });

    testWidgets('shows regenerate button and triggers rebuild', (tester) async {
      final previousDay = _dateOnlyNowMinus(1);
      final notifier = _GeneratingDailyReportNotifier(
        initialReport: _reportForDate(previousDay),
        generatedReport: _reportForDate(previousDay),
      );

      await tester.pumpWidget(
        _buildReportApp(
          dailyReportNotifier: notifier,
          datesNotifier: _StaticDailyReportDatesNotifier(_dates([previousDay])),
          selectedDateNotifier: _FixedSelectedDailyReportDateNotifier(
            previousDay,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final buttonFinder = find.byKey(
        const Key('daily_report_regenerate_button'),
      );
      expect(buttonFinder, findsOneWidget);

      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      expect(notifier.generateCalls, 1);
      expect(notifier.lastRebuild, true);
      expect(_dateKey(notifier.lastGenerateDate), _dateKey(previousDay));
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });

    testWidgets('defaults to yesterday when no date is provided', (
      tester,
    ) async {
      final yesterday = _dateOnlyNowMinus(1);
      final notifier = _TrackingDailyReportNotifier({
        _dateKey(yesterday): _reportForDate(yesterday),
      });

      await tester.pumpWidget(
        _buildReportApp(
          dailyReportNotifier: notifier,
          datesNotifier: _StaticDailyReportDatesNotifier(_dates([yesterday])),
          selectedDateNotifier: _FixedSelectedDailyReportDateNotifier(null),
        ),
      );
      await tester.pumpAndSettle();

      expect(_dateKey(notifier.lastLoadDate), _dateKey(yesterday));
    });
  });
}

Widget _buildReportApp({
  required DailyReportNotifier dailyReportNotifier,
  required DailyReportDatesNotifier datesNotifier,
  SelectedDailyReportDateNotifier? selectedDateNotifier,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const PodcastDailyReportPage(),
      ),
      GoRoute(
        path: '/podcast/episode/detail/:episodeId',
        builder: (context, state) {
          return Scaffold(
            body: Text('detail:${state.pathParameters['episodeId']}'),
          );
        },
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      authProvider.overrideWith(_AuthenticatedAuthNotifier.new),
      podcastFeedProvider.overrideWith(
        () => _TestPodcastFeedNotifier(_feedState()),
      ),
      dailyReportProvider.overrideWith(() => dailyReportNotifier),
      dailyReportDatesProvider.overrideWith(() => datesNotifier),
      if (selectedDateNotifier != null)
        selectedDailyReportDateProvider.overrideWith(
          () => selectedDateNotifier,
        ),
    ],
    child: MaterialApp.router(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

class _AuthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(isAuthenticated: true);
}

class _TestPodcastFeedNotifier extends PodcastFeedNotifier {
  _TestPodcastFeedNotifier(this._state);

  final PodcastFeedState _state;

  @override
  PodcastFeedState build() => _state;

  @override
  Future<void> loadInitialFeed({
    bool forceRefresh = false,
    bool background = false,
  }) async {}

  @override
  Future<void> loadMoreFeed() async {}
}

class _StaticDailyReportNotifier extends DailyReportNotifier {
  _StaticDailyReportNotifier(this._report);

  final PodcastDailyReportResponse _report;

  @override
  FutureOr<PodcastDailyReportResponse?> build() => _report;

  @override
  Future<PodcastDailyReportResponse?> load({
    DateTime? date,
    bool forceRefresh = false,
  }) async {
    state = AsyncValue.data(_report);
    return _report;
  }
}

class _SwitchingDailyReportNotifier extends DailyReportNotifier {
  _SwitchingDailyReportNotifier(this._reportsByDate);

  final Map<String, PodcastDailyReportResponse> _reportsByDate;

  @override
  FutureOr<PodcastDailyReportResponse?> build() {
    return _reportsByDate.values.first;
  }

  @override
  Future<PodcastDailyReportResponse?> load({
    DateTime? date,
    bool forceRefresh = false,
  }) async {
    final requestedDate = date ?? DateTime.now();
    final selected =
        _reportsByDate[_dateKey(date)] ??
        _unavailableReportForDate(requestedDate);
    state = AsyncValue.data(selected);
    return selected;
  }
}

class _TrackingDailyReportNotifier extends DailyReportNotifier {
  _TrackingDailyReportNotifier(this._reportsByDate);

  final Map<String, PodcastDailyReportResponse> _reportsByDate;
  DateTime? lastLoadDate;

  @override
  FutureOr<PodcastDailyReportResponse?> build() {
    return _reportsByDate.values.first;
  }

  @override
  Future<PodcastDailyReportResponse?> load({
    DateTime? date,
    bool forceRefresh = false,
  }) async {
    lastLoadDate = date;
    final selected =
        _reportsByDate[_dateKey(date)] ?? _reportsByDate.values.first;
    state = AsyncValue.data(selected);
    return selected;
  }
}

class _StaticDailyReportDatesNotifier extends DailyReportDatesNotifier {
  _StaticDailyReportDatesNotifier(this._response);

  final PodcastDailyReportDatesResponse _response;

  @override
  FutureOr<PodcastDailyReportDatesResponse?> build() => _response;

  @override
  Future<PodcastDailyReportDatesResponse?> load({
    int page = 1,
    int size = 100,
    bool forceRefresh = false,
  }) async {
    state = AsyncValue.data(_response);
    return _response;
  }

  @override
  Future<PodcastDailyReportDatesResponse?> ensureMonthCoverage(
    DateTime focusedMonth,
  ) async {
    return state.value;
  }
}

class _TrackingDailyReportDatesNotifier
    extends _StaticDailyReportDatesNotifier {
  _TrackingDailyReportDatesNotifier(super.response);

  final List<DateTime> ensureCoverageCalls = <DateTime>[];

  @override
  Future<PodcastDailyReportDatesResponse?> ensureMonthCoverage(
    DateTime focusedMonth,
  ) async {
    ensureCoverageCalls.add(focusedMonth);
    return state.value;
  }
}

class _FixedSelectedDailyReportDateNotifier
    extends SelectedDailyReportDateNotifier {
  _FixedSelectedDailyReportDateNotifier(this._initial);

  final DateTime? _initial;

  @override
  DateTime? build() => _initial;
}

class _GeneratingDailyReportNotifier extends DailyReportNotifier {
  _GeneratingDailyReportNotifier({
    required this.initialReport,
    required this.generatedReport,
  });

  final PodcastDailyReportResponse initialReport;
  final PodcastDailyReportResponse generatedReport;
  int generateCalls = 0;
  bool? lastRebuild;
  DateTime? lastGenerateDate;

  @override
  FutureOr<PodcastDailyReportResponse?> build() => initialReport;

  @override
  Future<PodcastDailyReportResponse?> load({
    DateTime? date,
    bool forceRefresh = false,
  }) async {
    return state.value;
  }

  @override
  Future<PodcastDailyReportResponse?> generate({
    DateTime? date,
    bool rebuild = false,
  }) async {
    generateCalls += 1;
    lastRebuild = rebuild;
    lastGenerateDate = date;
    state = AsyncValue.data(generatedReport);
    return generatedReport;
  }
}

class _LoadingDailyReportNotifier extends DailyReportNotifier {
  @override
  FutureOr<PodcastDailyReportResponse?> build() => null;

  @override
  Future<PodcastDailyReportResponse?> load({
    DateTime? date,
    bool forceRefresh = false,
  }) async {
    state = const AsyncValue.loading();
    return null;
  }
}

class _ErrorDailyReportNotifier extends DailyReportNotifier {
  @override
  FutureOr<PodcastDailyReportResponse?> build() => null;

  @override
  Future<PodcastDailyReportResponse?> load({
    DateTime? date,
    bool forceRefresh = false,
  }) async {
    state = AsyncValue.error(StateError('load failed'), StackTrace.empty);
    return null;
  }
}

PodcastFeedState _feedState() {
  final now = DateTime(2026, 2, 20, 10);
  return PodcastFeedState(
    episodes: [
      PodcastEpisodeModel(
        id: 1,
        subscriptionId: 1,
        title: 'Episode in feed',
        audioUrl: 'https://example.com/1.mp3',
        publishedAt: now,
        createdAt: now,
      ),
    ],
    hasMore: false,
    total: 1,
  );
}

PodcastDailyReportResponse _reportForDate(DateTime date, {String? summary}) {
  return PodcastDailyReportResponse(
    available: true,
    reportDate: date,
    timezone: 'Asia/Shanghai',
    scheduleTimeLocal: '03:30',
    generatedAt: DateTime(date.year, date.month, date.day, 3, 30),
    totalItems: 1,
    items: [
      PodcastDailyReportItem(
        episodeId: date.day,
        subscriptionId: 1,
        episodeTitle: 'Episode ${date.day}',
        subscriptionTitle: 'Podcast A',
        oneLineSummary: summary ?? 'Report summary ${date.day}',
        isCarryover: false,
        episodeCreatedAt: DateTime(date.year, date.month, date.day, 10),
      ),
    ],
  );
}

PodcastDailyReportDatesResponse _dates(List<DateTime> dates) {
  return PodcastDailyReportDatesResponse(
    dates: dates
        .map(
          (item) => PodcastDailyReportDateItem(reportDate: item, totalItems: 1),
        )
        .toList(),
    total: dates.length,
    page: 1,
    size: 100,
    pages: 1,
  );
}

PodcastDailyReportResponse _unavailableReportForDate(DateTime date) {
  return PodcastDailyReportResponse(
    available: false,
    reportDate: date,
    timezone: 'Asia/Shanghai',
    scheduleTimeLocal: '03:30',
    totalItems: 0,
    items: const [],
  );
}

DateTime _dateOnlyNowMinus(int days) {
  final now = DateTime.now();
  final dateOnly = DateTime(now.year, now.month, now.day);
  return dateOnly.subtract(Duration(days: days));
}

String _dateKey(DateTime? value) {
  if (value == null) {
    return '';
  }
  return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

Key _calendarDayKey(DateTime date) {
  return Key('daily_report_calendar_day_${_dateKey(date)}');
}

Key _calendarMarkerKey(DateTime date) {
  return Key('daily_report_calendar_marker_${_dateKey(date)}');
}

Future<void> _openCalendarPanel(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('daily_report_calendar_menu_button')));
  await tester.pumpAndSettle();
}
