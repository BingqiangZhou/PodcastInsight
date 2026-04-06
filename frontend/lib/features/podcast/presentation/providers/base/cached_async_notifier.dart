import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_ai_assistant/core/constants/cache_constants.dart';

/// A base class for [AsyncNotifier] subclasses that need time-based
/// cache freshness checks and in-flight request deduplication.
///
/// Subclasses get:
/// - [isFresh] -- checks whether data loaded at [_lastFetchTime] is still
///   within [cacheDuration].
/// - [runWithCache] -- deduplicates concurrent fetches via [_inFlightRequest]
///   and manages loading state transitions.
///
/// Typical usage:
/// ```dart
/// class MyNotifier extends CachedAsyncNotifier<MyData> {
///   MyNotifier() : super(cacheDuration: CacheConstants.defaultListCacheDuration);
///
///   @override
///   FutureOr<MyData?> build() => null;
///
///   Future<MyData?> load({bool forceRefresh = false}) {
///     return runWithCache(
///       forceRefresh: forceRefresh,
///       fetcher: () => repository.fetchData(),
///     );
///   }
/// }
/// ```
abstract class CachedAsyncNotifier<T> extends AsyncNotifier<T> {
  CachedAsyncNotifier({this.cacheDuration = CacheConstants.defaultListCacheDuration});

  /// How long cached data is considered fresh.
  final Duration cacheDuration;

  DateTime? _lastFetchTime;
  Future<T?>? _inFlightRequest;
  bool _isDisposed = false;

  /// Whether the currently held data is still within the cache window.
  bool get isFresh {
    final fetchTime = _lastFetchTime;
    if (fetchTime == null) return false;
    return clock.now().difference(fetchTime) < cacheDuration;
  }

  /// Executes [fetcher] with cache-aware deduplication.
  ///
  /// - If data is fresh and [forceRefresh] is false, returns current data.
  /// - If a request is already in flight, returns that future.
  /// - Otherwise, sets loading state, runs [fetcher], updates state, and
  ///   records the fetch time.
  ///
  /// The [onError] callback allows subclasses to handle specific errors
  /// (e.g., authentication errors) before the generic fallback applies.
  Future<T?> runWithCache({
    required Future<T> Function() fetcher, bool forceRefresh = false,
    void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
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
        state = AsyncValue.data(data);
        return data;
      } catch (error, stackTrace) {
        if (onError != null) {
          onError(error, stackTrace);
        }
        if (previousData == null) {
          state = AsyncValue.error(error, stackTrace);
        } else {
          // Briefly emit error so UI can react (e.g. show toast), then
          // schedule fallback to stale data on the next microtask.
          state = AsyncValue.error(error, stackTrace);
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

  /// Resets the cache state. Useful when switching servers or on logout.
  void resetCache() {
    _lastFetchTime = null;
    _inFlightRequest = null;
  }

  /// Mark the notifier as disposed to prevent state updates after disposal.
  void markDisposed() {
    _isDisposed = true;
  }
}
