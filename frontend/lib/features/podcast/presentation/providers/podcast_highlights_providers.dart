import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/exceptions/network_exceptions.dart';
import '../../../../core/constants/cache_constants.dart';
import '../../../../core/utils/app_logger.dart' as logger;
import '../../../../core/utils/time_formatter.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/podcast_highlight_model.dart';
import '../../data/repositories/podcast_repository.dart';
import 'base/cached_async_notifier.dart';
import 'podcast_core_providers.dart';

/// 选中的高光日期
final selectedHighlightDateProvider =
    NotifierProvider<SelectedHighlightDateNotifier, DateTime?>(
  SelectedHighlightDateNotifier.new,
);

/// 单集高光 Provider (用于转录页面集成)
final episodeHighlightsProvider =
    FutureProvider.autoDispose.family<HighlightsListResponse?, int>((ref, episodeId) async {
  final repository = ref.read(podcastRepositoryProvider);
  try {
    return repository.getHighlights(
      episodeId: episodeId,
      perPage: 100,
    );
  } catch (error) {
    logger.AppLogger.debug('Failed to load episode highlights: $error');
    return null;
  }
});

/// 触发单集高光提取
Future<HighlightExtractResponse?> extractEpisodeHighlights(
  WidgetRef ref,
  int episodeId,
) async {
  final repository = ref.read(podcastRepositoryProvider);
  try {
    final response = await repository.extractEpisodeHighlights(episodeId);
    // Refresh the episode highlights provider
    ref.invalidate(episodeHighlightsProvider(episodeId));
    return response;
  } catch (error) {
    logger.AppLogger.debug('Failed to extract episode highlights: $error');
    return null;
  }
}

/// 高光列表 Provider
final highlightsProvider =
    AsyncNotifierProvider<HighlightsNotifier, HighlightsListResponse?>(
  HighlightsNotifier.new,
);

/// 高光可用日期 Provider
final highlightDatesProvider =
    AsyncNotifierProvider<HighlightDatesNotifier, HighlightDatesResponse?>(
  HighlightDatesNotifier.new,
);

/// 高光统计 Provider
final highlightStatsProvider =
    AsyncNotifierProvider<HighlightStatsNotifier, HighlightStatsResponse?>(
  HighlightStatsNotifier.new,
);

/// 选中的高光日期 Notifier
class SelectedHighlightDateNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void setDate(DateTime? value) {
    state = value;
  }
}

/// 高光列表 Notifier
class HighlightsNotifier extends AsyncNotifier<HighlightsListResponse?> {
  late PodcastRepository _repository;
  DateTime? _lastLoadedAt;
  DateTime? _lastDate;
  Future<HighlightsListResponse?>? _inFlightRequest;

  static const int _defaultPageSize = 20;

  @override
  FutureOr<HighlightsListResponse?> build() {
    _repository = ref.read(podcastRepositoryProvider);
    return null;
  }

  bool _isFresh() {
    if (_lastLoadedAt == null) {
      return false;
    }
    return DateTime.now().difference(_lastLoadedAt!) < CacheConstants.defaultListCacheDuration;
  }

  Future<HighlightsListResponse?> load({
    DateTime? date,
    int page = 1,
    int? perPage,
    bool forceRefresh = false,
  }) async {
    final previousData = state.value;
    if (!forceRefresh &&
        previousData != null &&
        TimeFormatter.sameDate(_lastDate, date) &&
        _isFresh() &&
        page == 1) {
      return previousData;
    }

    final inFlight = _inFlightRequest;
    if (inFlight != null && TimeFormatter.sameDate(_lastDate, date) && page == 1) {
      return inFlight;
    }

    if (previousData == null) {
      state = const AsyncValue.loading();
    }

    final request = () async {
      try {
        final data = await _repository.getHighlights(
          date: date,
          page: page,
          perPage: perPage ?? _defaultPageSize,
        );
        _lastLoadedAt = DateTime.now();
        _lastDate = date;
        state = AsyncValue.data(data);
        return data;
      } catch (error, stackTrace) {
        logger.AppLogger.debug('Failed to load highlights: $error');
        if (error is AuthenticationException) {
          ref.read(authProvider.notifier).checkAuthStatus();
        }
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

  Future<void> toggleFavorite(int highlightId) async {
    final previousData = state.value;
    if (previousData == null) {
      return;
    }

    try {
      await _repository.toggleHighlightFavorite(highlightId);

      // Update local state
      final updatedItems = previousData.items.map((item) {
        if (item.id == highlightId) {
          return item.copyWith(
            isUserFavorited: !item.isUserFavorited,
          );
        }
        return item;
      }).toList();

      state = AsyncValue.data(
        HighlightsListResponse(
          items: updatedItems,
          total: previousData.total,
          page: previousData.page,
          perPage: previousData.perPage,
          hasMore: previousData.hasMore,
        ),
      );
    } catch (error) {
      logger.AppLogger.debug('Failed to toggle favorite: $error');
      // Revert on error
      state = AsyncValue.data(previousData);
    }
  }

  Future<void> deleteHighlight(int highlightId) async {
    final previousData = state.value;
    if (previousData == null) {
      return;
    }

    try {
      await _repository.deleteHighlight(highlightId);

      // Update local state
      final updatedItems = previousData.items
          .where((item) => item.id != highlightId)
          .toList();

      state = AsyncValue.data(
        HighlightsListResponse(
          items: updatedItems,
          total: previousData.total - 1,
          page: previousData.page,
          perPage: previousData.perPage,
          hasMore: previousData.hasMore,
        ),
      );

      // Refresh stats
      ref.read(highlightStatsProvider.notifier).load(forceRefresh: true);
    } catch (error) {
      logger.AppLogger.debug('Failed to delete highlight: $error');
      // Revert on error
      state = AsyncValue.data(previousData);
    }
  }

  Future<void> loadNextPage({DateTime? date}) async {
    final currentData = state.value;
    if (currentData == null || !currentData.hasMore) {
      return;
    }

    final targetDate = date ?? _lastDate;
    final nextPage = currentData.page + 1;

    try {
      final newData = await _repository.getHighlights(
        date: targetDate,
        page: nextPage,
        perPage: currentData.perPage,
      );

      final combinedItems = [...currentData.items, ...newData.items];

      state = AsyncValue.data(
        HighlightsListResponse(
          items: combinedItems,
          total: newData.total,
          page: newData.page,
          perPage: newData.perPage,
          hasMore: newData.hasMore,
        ),
      );
    } catch (error) {
      logger.AppLogger.debug('Failed to load next page: $error');
    }
  }
}

/// 高光可用日期 Notifier
class HighlightDatesNotifier
    extends CachedAsyncNotifier<HighlightDatesResponse?> {
  late PodcastRepository _repository;

  @override
  FutureOr<HighlightDatesResponse?> build() {
    _repository = ref.read(podcastRepositoryProvider);
    return null;
  }

  Future<HighlightDatesResponse?> load({
    bool forceRefresh = false,
  }) {
    return runWithCache(
      forceRefresh: forceRefresh,
      fetcher: () => _repository.getHighlightDates(),
      onError: (error, _) {
        logger.AppLogger.debug('Failed to load highlight dates: $error');
        if (error is AuthenticationException) {
          ref.read(authProvider.notifier).checkAuthStatus();
        }
      },
    );
  }

  Future<void> ensureMonthCoverage(DateTime date) async {
    final currentData = state.value;
    if (currentData == null) {
      await load(forceRefresh: false);
      return;
    }

    final monthStart = DateTime(date.year, date.month, 1);
    final monthEnd = DateTime(date.year, date.month + 1, 1)
        .subtract(const Duration(days: 1));

    final hasCoverage = currentData.dates.any((d) =>
        d.isAtSameMomentAs(monthStart) ||
        (d.isAfter(monthStart) && d.isBefore(monthEnd)) ||
        d.isAtSameMomentAs(monthEnd));

    if (!hasCoverage) {
      await load(forceRefresh: true);
    }
  }
}

/// 高光统计 Notifier
class HighlightStatsNotifier
    extends CachedAsyncNotifier<HighlightStatsResponse?> {
  late PodcastRepository _repository;

  @override
  FutureOr<HighlightStatsResponse?> build() {
    _repository = ref.read(podcastRepositoryProvider);
    return null;
  }

  Future<HighlightStatsResponse?> load({
    bool forceRefresh = false,
  }) {
    return runWithCache(
      forceRefresh: forceRefresh,
      fetcher: () => _repository.getHighlightStats(),
      onError: (error, _) {
        logger.AppLogger.debug('Failed to load highlight stats: $error');
        if (error is AuthenticationException) {
          ref.read(authProvider.notifier).checkAuthStatus();
        }
      },
    );
  }
}
