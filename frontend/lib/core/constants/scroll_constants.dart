/// Scrolling view unified configuration constants.
///
/// Centralizing scroll-related values ensures consistency across
/// the application and makes it easy to adjust scroll behavior globally.
class ScrollConstants {
  ScrollConstants._();

  // ==================== Cache Extent ====================

  /// Default cache area size (pixels).
  /// Suitable for most list views with standard item heights.
  static const double defaultCacheExtent = 500;

  /// Large list cache area size.
  /// Used for lists with many items or complex layouts.
  static const double largeListCacheExtent = 1000;

  /// Small list cache area size.
  /// Used for short lists or views with simple items.
  static const double smallListCacheExtent = 250;

  // ==================== Item Extent ====================

  /// Default item height estimate.
  /// Standard height for most list items (e.g., episode cards).
  static const double defaultItemExtent = 88;

  /// Compact item height estimate.
  /// Used for dense layouts or smaller list items.
  static const double compactItemExtent = 72;

  /// Queue item height estimate.
  /// Height for podcast queue items with cover and metadata.
  static const double queueItemExtent = 88;

  // ==================== Load More Threshold ====================

  /// Load more trigger threshold (pixels from bottom).
  /// When scroll position reaches this distance from bottom,
  /// load more data should be triggered.
  static const double loadMoreThreshold = 320;
}
