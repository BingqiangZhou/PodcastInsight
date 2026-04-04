import 'package:equatable/equatable.dart';

import 'package:personal_ai_assistant/core/constants/cache_constants.dart';

/// Generic paginated list UI state.
///
/// Encapsulates the common fields shared by every paginated list screen:
/// the current items, pagination cursors, loading/error flags, and a
/// cache-validity timestamp. Feature-specific subclasses add their own
/// extra fields while inheriting all of this boilerplate.
///
/// Subclasses should provide their own [copyWith] with domain-specific
/// parameter names (e.g. `episodes`, `subscriptions`) that forward to
/// the [items] field internally.
///
/// Usage:
/// ```dart
/// class PodcastFeedState extends PaginatedState<PodcastEpisodeModel> {
///   final String? nextCursor;
///   ...
/// }
/// ```
class PaginatedState<T> extends Equatable {
  /// The currently loaded items.
  final List<T> items;

  /// Whether more pages exist on the server.
  final bool hasMore;

  /// The next page number to request (null if no more pages).
  final int? nextPage;

  /// The current page number (1-based).
  final int currentPage;

  /// Total item count reported by the server.
  final int total;

  /// Whether an initial/page-1 load is in progress.
  final bool isLoading;

  /// Whether a "load more" request is in progress.
  final bool isLoadingMore;

  /// Human-readable error message (null when no error).
  final String? error;

  /// Timestamp of the last successful refresh.
  final DateTime? lastRefreshTime;

  const PaginatedState({
    this.items = const [],
    this.hasMore = true,
    this.nextPage,
    this.currentPage = 1,
    this.total = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.lastRefreshTime,
  });

  /// Whether the data is still considered fresh within [cacheDuration].
  bool isDataFresh({
    Duration cacheDuration = CacheConstants.defaultListCacheDuration,
  }) {
    final refreshTime = lastRefreshTime;
    if (refreshTime == null) return false;
    return DateTime.now().difference(refreshTime) < cacheDuration;
  }

  @override
  List<Object?> get props => [
    items,
    hasMore,
    nextPage,
    currentPage,
    total,
    isLoading,
    isLoadingMore,
    error,
    lastRefreshTime,
  ];
}
