import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/network/exceptions/network_exceptions.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_daily_report_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/repositories/podcast_repository.dart';
import 'package:personal_ai_assistant/features/podcast/data/services/podcast_api_service.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';

void main() {
  group('DailyReport providers', () {
    test('loads daily report and reuses fresh cache', () async {
      final repository = _FakePodcastRepository();
      final container = ProviderContainer(
        overrides: [podcastRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(dailyReportProvider.notifier);
      await notifier.load();
      await notifier.load();

      expect(repository.dailyReportCalls, 1);
      expect(container.read(dailyReportProvider).value?.available, isTrue);
    });

    test('switching selected date loads historical daily report', () async {
      final repository = _FakePodcastRepository();
      final container = ProviderContainer(
        overrides: [podcastRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(dailyReportProvider.notifier);
      await notifier.load();
      container
          .read(selectedDailyReportDateProvider.notifier)
          .setDate(DateTime(2026, 2, 19));
      await notifier.load(date: DateTime(2026, 2, 19), forceRefresh: true);

      final switched = container.read(dailyReportProvider).value;

      expect(switched?.reportDate, DateTime(2026, 2, 19));
      expect(repository.lastDailyReportDate, DateTime(2026, 2, 19));
    });

    test('force refresh bypasses cache for daily report', () async {
      final repository = _FakePodcastRepository();
      final container = ProviderContainer(
        overrides: [podcastRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(dailyReportProvider.notifier);
      await notifier.load();
      await notifier.load(forceRefresh: true);

      expect(repository.dailyReportCalls, 2);
    });

    test(
      'daily report dates provider loads and caches with size 100',
      () async {
        final repository = _FakePodcastRepository();
        final container = ProviderContainer(
          overrides: [podcastRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);

        final notifier = container.read(dailyReportDatesProvider.notifier);
        await notifier.load();
        await notifier.load();

        expect(repository.dailyReportDatesCalls, 1);
        expect(repository.requestedDatePages, [1]);
        expect(repository.requestedDateSizes, [100]);
        expect(container.read(dailyReportDatesProvider).value?.dates.length, 2);
      },
    );

    test(
      'ensureMonthCoverage loads more pages until month is covered',
      () async {
        final repository = _FakePodcastRepository(
          datesByPage: {
            1: _datesPage(
              dates: [DateTime(2026, 2, 20), DateTime(2026, 2, 19)],
              total: 4,
              page: 1,
              pages: 2,
            ),
            2: _datesPage(
              dates: [DateTime(2026, 1, 10), DateTime(2026)],
              total: 4,
              page: 2,
              pages: 2,
            ),
          },
        );
        final container = ProviderContainer(
          overrides: [podcastRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);

        final notifier = container.read(dailyReportDatesProvider.notifier);
        await notifier.load();
        await notifier.ensureMonthCoverage(DateTime(2026, 1, 15));

        final merged = container.read(dailyReportDatesProvider).value!;
        expect(repository.requestedDatePages, [1, 2]);
        expect(merged.dates.map((item) => _dateKey(item.reportDate)), [
          '2026-02-20',
          '2026-02-19',
          '2026-01-10',
          '2026-01-01',
        ]);
      },
    );

    test('ensureMonthCoverage deduplicates dates across pages', () async {
      final repository = _FakePodcastRepository(
        datesByPage: {
          1: _datesPage(
            dates: [DateTime(2026, 2, 20), DateTime(2026, 2, 19)],
            total: 4,
            page: 1,
            pages: 2,
          ),
          2: _datesPage(
            dates: [DateTime(2026, 2, 19), DateTime(2026, 2, 18)],
            total: 4,
            page: 2,
            pages: 2,
          ),
        },
      );
      final container = ProviderContainer(
        overrides: [podcastRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(dailyReportDatesProvider.notifier);
      await notifier.load();
      await notifier.ensureMonthCoverage(DateTime(2026, 1, 15));

      final merged = container.read(dailyReportDatesProvider).value!;
      expect(repository.requestedDatePages, [1, 2]);
      expect(merged.dates.map((item) => _dateKey(item.reportDate)), [
        '2026-02-20',
        '2026-02-19',
        '2026-02-18',
      ]);
    });

    test(
      'ensureMonthCoverage stops requesting when reaching last page',
      () async {
        final repository = _FakePodcastRepository(
          datesByPage: {
            1: _datesPage(
              dates: [DateTime(2026, 2, 20), DateTime(2026, 2, 19)],
              total: 3,
              page: 1,
              pages: 2,
            ),
            2: _datesPage(
              dates: [DateTime(2026, 1, 15)],
              total: 3,
              page: 2,
              pages: 2,
            ),
          },
        );
        final container = ProviderContainer(
          overrides: [podcastRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);

        final notifier = container.read(dailyReportDatesProvider.notifier);
        await notifier.load();
        await notifier.ensureMonthCoverage(DateTime(2025, 11, 15));

        expect(repository.requestedDatePages, [1, 2]);
        expect(repository.dailyReportDatesCalls, 2);
      },
    );

    test(
      'ensureMonthCoverage uses cache when month is already covered',
      () async {
        final repository = _FakePodcastRepository();
        final container = ProviderContainer(
          overrides: [podcastRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);

        final notifier = container.read(dailyReportDatesProvider.notifier);
        await notifier.load();
        await notifier.ensureMonthCoverage(DateTime(2026, 2));
        await notifier.load();

        expect(repository.dailyReportDatesCalls, 1);
        expect(repository.requestedDatePages, [1]);
      },
    );

    test('generate daily report updates state and refreshes dates', () async {
      final repository = _FakePodcastRepository();
      final container = ProviderContainer(
        overrides: [podcastRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(dailyReportProvider.notifier);
      final targetDate = DateTime(2026, 2, 20);
      final result = await notifier.generate(date: targetDate);

      expect(result?.available, isTrue);
      expect(result?.reportDate, DateTime(2026, 2, 20));
      expect(container.read(dailyReportProvider).value?.reportDate, targetDate);
      expect(repository.generateDailyReportCalls, 1);
      expect(repository.lastGeneratedReportDate, targetDate);
      expect(repository.lastGeneratedReportRebuild, false);
      expect(repository.dailyReportDatesCalls, 1);
    });

    test('generate daily report passes rebuild flag', () async {
      final repository = _FakePodcastRepository();
      final container = ProviderContainer(
        overrides: [podcastRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(dailyReportProvider.notifier);
      await notifier.generate(date: DateTime(2026, 2, 20), rebuild: true);

      expect(repository.generateDailyReportCalls, 1);
      expect(repository.lastGeneratedReportRebuild, true);
    });

    test('generate daily report rethrows on failure', () async {
      final repository = _FailingGeneratePodcastRepository();
      final container = ProviderContainer(
        overrides: [podcastRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(dailyReportProvider.notifier);

      await expectLater(
        () => notifier.generate(date: DateTime(2026, 2, 20)),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}

class _FakePodcastRepository extends PodcastRepository {
  _FakePodcastRepository({
    Map<int, PodcastDailyReportDatesResponse>? datesByPage,
  }) : _datesByPage = datesByPage ?? _defaultDatesByPage(),
       super(PodcastApiService(Dio()));

  final Map<int, PodcastDailyReportDatesResponse> _datesByPage;

  int dailyReportCalls = 0;
  int dailyReportDatesCalls = 0;
  int generateDailyReportCalls = 0;
  DateTime? lastDailyReportDate;
  DateTime? lastGeneratedReportDate;
  bool? lastGeneratedReportRebuild;
  final List<int> requestedDatePages = <int>[];
  final List<int> requestedDateSizes = <int>[];

  @override
  Future<PodcastDailyReportResponse> getDailyReport({DateTime? date}) async {
    dailyReportCalls += 1;
    lastDailyReportDate = date;

    final reportDate = date == null
        ? DateTime(2026, 2, 20)
        : DateTime(date.year, date.month, date.day);
    return PodcastDailyReportResponse(
      available: true,
      reportDate: reportDate,
      timezone: 'Asia/Shanghai',
      scheduleTimeLocal: '03:30',
      generatedAt: DateTime(2026, 2, 21, 3, 30),
      totalItems: 1,
      items: [
        PodcastDailyReportItem(
          episodeId: reportDate.day,
          subscriptionId: 1,
          episodeTitle: 'Episode ${reportDate.day}',
          subscriptionTitle: 'Podcast',
          oneLineSummary: 'Summary ${reportDate.day}',
          isCarryover: false,
          episodeCreatedAt: DateTime(2026, 2, reportDate.day, 10),
        ),
      ],
    );
  }

  @override
  Future<PodcastDailyReportDatesResponse> getDailyReportDates({
    int page = 1,
    int size = 100,
  }) async {
    dailyReportDatesCalls += 1;
    requestedDatePages.add(page);
    requestedDateSizes.add(size);

    final payload = _datesByPage[page];
    if (payload == null) {
      return PodcastDailyReportDatesResponse(
        dates: const [],
        total: _datesByPage[1]?.total ?? 0,
        page: page,
        size: size,
        pages: _datesByPage[1]?.pages ?? 0,
      );
    }

    return PodcastDailyReportDatesResponse(
      dates: payload.dates,
      total: payload.total,
      page: page,
      size: size,
      pages: payload.pages,
    );
  }

  @override
  Future<PodcastDailyReportResponse> generateDailyReport({
    DateTime? date,
    bool rebuild = false,
  }) async {
    generateDailyReportCalls += 1;
    lastGeneratedReportDate = date;
    lastGeneratedReportRebuild = rebuild;
    final reportDate = date == null
        ? DateTime(2026, 2, 20)
        : DateTime(date.year, date.month, date.day);
    return PodcastDailyReportResponse(
      available: true,
      reportDate: reportDate,
      timezone: 'Asia/Shanghai',
      scheduleTimeLocal: '03:30',
      generatedAt: DateTime(2026, 2, 21, 4),
      totalItems: 1,
      items: [
        PodcastDailyReportItem(
          episodeId: reportDate.day,
          subscriptionId: 1,
          episodeTitle: 'Episode ${reportDate.day}',
          subscriptionTitle: 'Podcast',
          oneLineSummary: 'Generated summary ${reportDate.day}',
          isCarryover: false,
          episodeCreatedAt: DateTime(2026, 2, reportDate.day, 10),
        ),
      ],
    );
  }

  static Map<int, PodcastDailyReportDatesResponse> _defaultDatesByPage() {
    return {
      1: _datesPage(
        dates: [DateTime(2026, 2, 20), DateTime(2026, 2, 19)],
        total: 2,
        page: 1,
        pages: 1,
      ),
    };
  }
}

class _FailingGeneratePodcastRepository extends _FakePodcastRepository {
  @override
  Future<PodcastDailyReportResponse> generateDailyReport({
    DateTime? date,
    bool rebuild = false,
  }) async {
    throw const NetworkException('Server error');
  }
}

PodcastDailyReportDatesResponse _datesPage({
  required List<DateTime> dates,
  required int total,
  required int page,
  required int pages,
}) {
  return PodcastDailyReportDatesResponse(
    dates: dates
        .map(
          (item) => PodcastDailyReportDateItem(reportDate: item, totalItems: 1),
        )
        .toList(),
    total: total,
    page: page,
    size: 100,
    pages: pages,
  );
}

String _dateKey(DateTime value) {
  final local = value.isUtc ? value.toLocal() : value;
  return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
}
