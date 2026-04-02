import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/exceptions/network_exceptions.dart';
import '../../../../core/constants/cache_constants.dart';
import '../../../../core/utils/app_logger.dart' as logger;
import '../../../../core/utils/time_formatter.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/podcast_daily_report_model.dart';
import '../../data/repositories/podcast_repository.dart';
import 'podcast_core_providers.dart';

final selectedDailyReportDateProvider =
    NotifierProvider<SelectedDailyReportDateNotifier, DateTime?>(
      SelectedDailyReportDateNotifier.new,
    );
final dailyReportProvider =
    AsyncNotifierProvider<DailyReportNotifier, PodcastDailyReportResponse?>(
      DailyReportNotifier.new,
    );

final dailyReportDatesProvider =
    AsyncNotifierProvider<
      DailyReportDatesNotifier,
      PodcastDailyReportDatesResponse?
    >(DailyReportDatesNotifier.new);

class SelectedDailyReportDateNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void setDate(DateTime? value) {
    state = value;
  }
}

class DailyReportNotifier extends AsyncNotifier<PodcastDailyReportResponse?> {
  PodcastRepository get _repository => ref.read(podcastRepositoryProvider);
  DateTime? _lastLoadedAt;
  DateTime? _lastDate;
  Future<PodcastDailyReportResponse?>? _inFlightRequest;
  Future<PodcastDailyReportResponse?>? _inFlightGenerateRequest;

  @override
  FutureOr<PodcastDailyReportResponse?> build() {
    return null;
  }

  bool _isFresh() {
    final loadedAt = _lastLoadedAt;
    if (loadedAt == null) {
      return false;
    }
    final cacheDuration = CacheConstants.defaultListCacheDuration;
    return DateTime.now().difference(loadedAt) < cacheDuration;
  }

  Future<PodcastDailyReportResponse?> load({
    DateTime? date,
    bool forceRefresh = false,
  }) async {
    final previousData = state.value;
    if (!forceRefresh &&
        previousData != null &&
        TimeFormatter.sameDate(_lastDate, date) &&
        _isFresh()) {
      return previousData;
    }

    final inFlight = _inFlightRequest;
    if (inFlight != null && TimeFormatter.sameDate(_lastDate, date)) {
      return inFlight;
    }

    if (previousData == null) {
      state = const AsyncValue.loading();
    }

    final request = () async {
      try {
        final data = await _repository.getDailyReport(date: date);
        _lastLoadedAt = DateTime.now();
        _lastDate = date;
        state = AsyncValue.data(data);
        return data;
      } catch (error, stackTrace) {
        logger.AppLogger.debug('Failed to load daily report: $error');
        if (previousData == null) {
          state = AsyncValue.error(error, stackTrace);
        } else {
          state = AsyncValue.data(previousData);
        }
        return previousData;
      } finally {
        _inFlightRequest = null;
      }
    }();

    _inFlightRequest = request;
    return request;
  }

  Future<PodcastDailyReportResponse?> generate({
    DateTime? date,
    bool rebuild = false,
  }) async {
    final previousData = state.value;
    final inFlight = _inFlightGenerateRequest;
    if (inFlight != null && TimeFormatter.sameDate(_lastDate, date)) {
      return inFlight;
    }

    final request = () async {
      try {
        final data = await _repository.generateDailyReport(
          date: date,
          rebuild: rebuild,
        );
        _lastLoadedAt = DateTime.now();
        _lastDate = date;
        state = AsyncValue.data(data);
        await ref
            .read(dailyReportDatesProvider.notifier)
            .load(forceRefresh: true);
        return data;
      } catch (error, stackTrace) {
        logger.AppLogger.debug('Failed to generate daily report: $error');
        if (error is AuthenticationException) {
          ref.read(authProvider.notifier).checkAuthStatus();
        }
        if (previousData == null) {
          state = AsyncValue.error(error, stackTrace);
        } else {
          state = AsyncValue.data(previousData);
        }
        rethrow;
      } finally {
        _inFlightGenerateRequest = null;
      }
    }();

    _inFlightGenerateRequest = request;
    return request;
  }
}

class DailyReportDatesNotifier
    extends AsyncNotifier<PodcastDailyReportDatesResponse?> {
  PodcastRepository get _repository => ref.read(podcastRepositoryProvider);
  DateTime? _lastLoadedAt;
  int _lastSize = _defaultPageSize;
  int _nextPage = 1;
  int _totalPages = 0;
  int _total = 0;
  final Map<String, PodcastDailyReportDateItem> _datesByKey =
      <String, PodcastDailyReportDateItem>{};
  Future<PodcastDailyReportDatesResponse?>? _inFlightRequest;
  Future<PodcastDailyReportDatesResponse?>? _inFlightCoverageRequest;

  static const int _defaultPageSize = 100;

  @override
  FutureOr<PodcastDailyReportDatesResponse?> build() {
    return null;
  }

  bool _isFresh() {
    final loadedAt = _lastLoadedAt;
    if (loadedAt == null) {
      return false;
    }
    final cacheDuration = CacheConstants.defaultListCacheDuration;
    return DateTime.now().difference(loadedAt) < cacheDuration;
  }

  DateTime _toDateOnly(DateTime value) {
    final local = value.isUtc ? value.toLocal() : value;
    return DateTime(local.year, local.month, local.day);
  }

  String _dateKey(DateTime value) {
    final normalized = _toDateOnly(value);
    return '${normalized.year.toString().padLeft(4, '0')}-${normalized.month.toString().padLeft(2, '0')}-${normalized.day.toString().padLeft(2, '0')}';
  }

  DateTime? _earliestLoadedDate() {
    DateTime? earliest;
    for (final item in _datesByKey.values) {
      final date = _toDateOnly(item.reportDate);
      if (earliest == null || date.isBefore(earliest)) {
        earliest = date;
      }
    }
    return earliest;
  }

  bool _canLoadNextPage() {
    if (_totalPages <= 0) {
      return false;
    }
    return _nextPage <= _totalPages;
  }

  bool _isMonthCovered(DateTime focusedMonth) {
    final monthStart = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final earliest = _earliestLoadedDate();
    if (earliest == null) {
      return false;
    }
    return !earliest.isAfter(monthStart);
  }

  void _resetAggregation() {
    _datesByKey.clear();
    _nextPage = 1;
    _totalPages = 0;
    _total = 0;
  }

  PodcastDailyReportDatesResponse _buildAggregatedResponse() {
    final merged = _datesByKey.values.toList()
      ..sort((left, right) => right.reportDate.compareTo(left.reportDate));
    return PodcastDailyReportDatesResponse(
      dates: merged,
      total: _total,
      page: 1,
      size: _lastSize,
      pages: _totalPages,
    );
  }

  Future<PodcastDailyReportDatesResponse?> _fetchAndMerge({
    required int page,
    required int size,
  }) async {
    final payload = await _repository.getDailyReportDates(
      page: page,
      size: size,
    );
    for (final item in payload.dates) {
      final normalizedDate = _toDateOnly(item.reportDate);
      _datesByKey[_dateKey(normalizedDate)] = PodcastDailyReportDateItem(
        reportDate: normalizedDate,
        totalItems: item.totalItems,
        generatedAt: item.generatedAt,
      );
    }

    _total = payload.total;
    _totalPages = payload.pages;
    _nextPage = page + 1;
    _lastSize = size;
    _lastLoadedAt = DateTime.now();

    final merged = _buildAggregatedResponse();
    state = AsyncValue.data(merged);
    return merged;
  }

  Future<PodcastDailyReportDatesResponse?> load({
    int page = 1,
    int size = _defaultPageSize,
    bool forceRefresh = false,
  }) async {
    final previousData = state.value;
    final isFirstPageQuery = page == 1;
    if (!forceRefresh &&
        previousData != null &&
        isFirstPageQuery &&
        _isFresh()) {
      return previousData;
    }

    final inFlight = _inFlightRequest;
    if (inFlight != null && isFirstPageQuery) {
      return inFlight;
    }

    if (previousData == null) {
      state = const AsyncValue.loading();
    }

    final request = () async {
      try {
        if (forceRefresh || isFirstPageQuery) {
          _resetAggregation();
        }
        return await _fetchAndMerge(page: page, size: size);
      } catch (error, stackTrace) {
        logger.AppLogger.debug('Failed to load daily report dates: $error');
        if (previousData == null) {
          state = AsyncValue.error(error, stackTrace);
        } else {
          state = AsyncValue.data(previousData);
        }
        return previousData;
      } finally {
        _inFlightRequest = null;
      }
    }();

    _inFlightRequest = request;
    return request;
  }

  Future<PodcastDailyReportDatesResponse?> ensureMonthCoverage(
    DateTime focusedMonth,
  ) async {
    final normalizedMonth = DateTime(focusedMonth.year, focusedMonth.month, 1);
    if (_datesByKey.isEmpty) {
      await load(forceRefresh: false);
    }
    if (_isMonthCovered(normalizedMonth) || !_canLoadNextPage()) {
      return state.value;
    }

    final inFlightCoverage = _inFlightCoverageRequest;
    if (inFlightCoverage != null) {
      return inFlightCoverage;
    }

    final request = () async {
      try {
        while (!_isMonthCovered(normalizedMonth) && _canLoadNextPage()) {
          await _fetchAndMerge(page: _nextPage, size: _lastSize);
        }
      } catch (error) {
        logger.AppLogger.debug(
          'Failed to ensure daily report date coverage for month=$normalizedMonth error=$error',
        );
      } finally {
        _inFlightCoverageRequest = null;
      }
      return state.value;
    }();

    _inFlightCoverageRequest = request;
    return request;
  }
}
