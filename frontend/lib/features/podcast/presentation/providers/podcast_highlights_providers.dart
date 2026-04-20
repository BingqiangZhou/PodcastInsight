import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/constants/cache_constants.dart';
import 'package:personal_ai_assistant/core/network/exceptions/network_exceptions.dart';
import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;
import 'package:personal_ai_assistant/core/utils/time_formatter.dart';
import 'package:personal_ai_assistant/features/auth/presentation/providers/auth_provider.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_highlight_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/repositories/podcast_repository.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_core_providers.dart';
import 'package:riverpod/src/providers/future_provider.dart';

/// 选中的高光日期
final selectedHighlightDateProvider =
    NotifierProvider<SelectedHighlightDateNotifier, DateTime?>(
  SelectedHighlightDateNotifier.new,
);

/// 单集高光 Provider (用于转录页面集成)
final FutureProviderFamily<HighlightsListResponse?, int> episodeHighlightsProvider =
    FutureProvider.autoDispose.family<HighlightsListResponse?, int>((ref, episodeId) async {
  final repository = ref.read(podcastRepositoryProvider);
  // Let errors propagate so AsyncValue.when() can handle them via error callback
  return repository.getHighlights(
    episodeId: episodeId,
    perPage: 100,
  );
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
  PodcastRepository get _repository => ref.read(podcastRepositoryProvider);
  DateTime? _lastLoadedAt;
  DateTime? _lastDate;
  Future<HighlightsListResponse?>? _inFlightRequest;

  static const int _defaultPageSize = 20;

  @override
  FutureOr<HighlightsListResponse?> build() {
    return null;
  }

  bool _isFresh() {
    final lastLoaded = _lastLoadedAt;
    if (lastLoaded == null) return false;
    return DateTime.now().difference(lastLoaded) < CacheConstants.defaultListCacheDuration;
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
        if (error is AuthException) {
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
          size: previousData.size,
          pages: previousData.pages,
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
          size: previousData.size,
          pages: previousData.pages,
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
        perPage: currentData.size,
      );

      final combinedItems = [...currentData.items, ...newData.items];

      state = AsyncValue.data(
        HighlightsListResponse(
          items: combinedItems,
          total: newData.total,
          page: newData.page,
          size: newData.size,
          pages: newData.pages,
        ),
      );
    } catch (error) {
      logger.AppLogger.debug('Failed to load next page: $error');
    }
  }
}

/// 高光可用日期 Notifier
class HighlightDatesNotifier extends AsyncNotifier<HighlightDatesResponse?> {
  PodcastRepository get _repository => ref.read(podcastRepositoryProvider);

  // Cache and deduplication state
  static const Duration _cacheDuration = CacheConstants.defaultListCacheDuration;
  DateTime? _lastFetchTime;
  Future<HighlightDatesResponse?>? _inFlightRequest;
  bool _isDisposed = false;
  bool _onDisposeWired = false;

  @override
  FutureOr<HighlightDatesResponse?> build() {
    return load();
  }

  /// Whether the currently held data is still within the cache window.
  bool get isFresh {
    final fetchTime = _lastFetchTime;
    if (fetchTime == null) return false;
    return clock.now().difference(fetchTime) < _cacheDuration;
  }

  /// Executes [fetcher] with cache-aware deduplication.
  Future<HighlightDatesResponse?> runWithCache({
    required Future<HighlightDatesResponse> Function() fetcher,
    bool forceRefresh = false,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    if (!_onDisposeWired) {
      _onDisposeWired = true;
      ref.onDispose(markDisposed);
    }
    final previousData = state.value;

    if (!forceRefresh && previousData != null && isFresh) {
      return previousData;
    }

    final inFlight = _inFlightRequest;
    if (inFlight != null) {
      return inFlight;
    }

    if (previousData == null) {
      state = const AsyncValue.loading();
    }

    final request = () async {
      try {
        final data = await fetcher();
        _lastFetchTime = clock.now();
        if (!_isDisposed) {
          state = AsyncValue.data(data);
        }
        return data;
      } catch (error, stackTrace) {
        if (onError != null) {
          onError(error, stackTrace);
        }
        if (previousData == null) {
          if (!_isDisposed) {
            state = AsyncValue.error(error, stackTrace);
          }
        } else {
          if (!_isDisposed) {
            state = AsyncValue.error(error, stackTrace);
          }
          Future.microtask(() {
            if (!_isDisposed) {
              state = AsyncValue.data(previousData);
            }
          });
        }
        return previousData;
      } finally {
        _inFlightRequest = null;
      }
    }();

    _inFlightRequest = request;
    return request;
  }

  /// Resets the cache state.
  void resetCache() {
    _lastFetchTime = null;
    _inFlightRequest = null;
  }

  /// Mark the notifier as disposed to prevent state updates after disposal.
  void markDisposed() {
    _isDisposed = true;
  }

  Future<HighlightDatesResponse?> load({
    bool forceRefresh = false,
  }) {
    return runWithCache(
      forceRefresh: forceRefresh,
      fetcher: () => _repository.getHighlightDates(),
      onError: (error, _) {
        logger.AppLogger.debug('Failed to load highlight dates: $error');
        if (error is AuthException) {
          ref.read(authProvider.notifier).checkAuthStatus();
        }
      },
    );
  }

  Future<void> ensureMonthCoverage(DateTime date) async {
    final currentData = state.value;
    if (currentData == null) {
      await load();
      return;
    }

    final monthStart = DateTime(date.year, date.month);
    final monthEnd = DateTime(date.year, date.month + 1)
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
class HighlightStatsNotifier extends AsyncNotifier<HighlightStatsResponse?> {
  PodcastRepository get _repository => ref.read(podcastRepositoryProvider);

  // Cache and deduplication state
  static const Duration _cacheDuration = CacheConstants.defaultListCacheDuration;
  DateTime? _lastFetchTime;
  Future<HighlightStatsResponse?>? _inFlightRequest;
  bool _isDisposed = false;
  bool _onDisposeWired = false;

  @override
  FutureOr<HighlightStatsResponse?> build() {
    return load();
  }

  /// Whether the currently held data is still within the cache window.
  bool get isFresh {
    final fetchTime = _lastFetchTime;
    if (fetchTime == null) return false;
    return clock.now().difference(fetchTime) < _cacheDuration;
  }

  /// Executes [fetcher] with cache-aware deduplication.
  Future<HighlightStatsResponse?> runWithCache({
    required Future<HighlightStatsResponse> Function() fetcher,
    bool forceRefresh = false,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    if (!_onDisposeWired) {
      _onDisposeWired = true;
      ref.onDispose(markDisposed);
    }
    final previousData = state.value;

    if (!forceRefresh && previousData != null && isFresh) {
      return previousData;
    }

    final inFlight = _inFlightRequest;
    if (inFlight != null) {
      return inFlight;
    }

    if (previousData == null) {
      state = const AsyncValue.loading();
    }

    final request = () async {
      try {
        final data = await fetcher();
        _lastFetchTime = clock.now();
        if (!_isDisposed) {
          state = AsyncValue.data(data);
        }
        return data;
      } catch (error, stackTrace) {
        if (onError != null) {
          onError(error, stackTrace);
        }
        if (previousData == null) {
          if (!_isDisposed) {
            state = AsyncValue.error(error, stackTrace);
          }
        } else {
          if (!_isDisposed) {
            state = AsyncValue.error(error, stackTrace);
          }
          Future.microtask(() {
            if (!_isDisposed) {
              state = AsyncValue.data(previousData);
            }
          });
        }
        return previousData;
      } finally {
        _inFlightRequest = null;
      }
    }();

    _inFlightRequest = request;
    return request;
  }

  /// Resets the cache state.
  void resetCache() {
    _lastFetchTime = null;
    _inFlightRequest = null;
  }

  /// Mark the notifier as disposed to prevent state updates after disposal.
  void markDisposed() {
    _isDisposed = true;
  }

  Future<HighlightStatsResponse?> load({
    bool forceRefresh = false,
  }) {
    return runWithCache(
      forceRefresh: forceRefresh,
      fetcher: () => _repository.getHighlightStats(),
      onError: (error, _) {
        logger.AppLogger.debug('Failed to load highlight stats: $error');
        if (error is AuthException) {
          ref.read(authProvider.notifier).checkAuthStatus();
        }
      },
    );
  }
}
