/// Unified cache and pagination constants for the application.
///
/// Centralizing these values ensures consistency across providers
/// and makes it easy to adjust cache behavior globally.
class CacheConstants {
  CacheConstants._();

  // ==================== Cache Durations ====================

  /// Cache duration for the podcast feed (episodes from all subscriptions).
  /// Short duration since new episodes can appear frequently.
  static const Duration feedCacheDuration = Duration(seconds: 30);

  /// Default cache duration for list data that doesn't change often.
  static const Duration defaultListCacheDuration = Duration(minutes: 5);

  /// Cache duration for discover/chart data.
  /// Charts don't update very frequently.
  static const Duration discoverCacheDuration = Duration(minutes: 5);

  // ==================== Pagination Sizes ====================

  /// Default page size for paginated API requests.
  static const int defaultPageSize = 20;

  /// Page size for subscription lists (smaller for faster initial load).
  static const int subscriptionsPageSize = 10;

  /// Initial fetch limit for discover charts.
  static const int discoverInitialFetchLimit = 25;

  /// Maximum number of items to load for discover charts.
  static const int discoverTopChartMaxLimit = 100;

  /// Step size for loading more discover items.
  static const int discoverHydrationStep = 25;
}
