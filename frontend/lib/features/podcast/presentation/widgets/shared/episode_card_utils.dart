import 'package:flutter/material.dart';

/// Shared utilities for episode card widgets.
///
/// Provides common formatting and styling to reduce code duplication
/// across different episode card implementations.
class EpisodeCardUtils {
  EpisodeCardUtils._();

  /// Formats a DateTime to 'YYYY-MM-DD' format using local time.
  ///
  /// Handles both UTC and local DateTime objects by converting to local time first.
  static String formatDate(DateTime date) {
    final localDate = date.isUtc ? date.toLocal() : date;
    final year = localDate.year;
    final month = localDate.month.toString().padLeft(2, '0');
    final day = localDate.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Creates a compact icon button style suitable for episode action buttons.
  ///
  /// This style is optimized for dense layouts with:
  /// - Fixed 28x28 size
  /// - Shrinkwrap tap target
  /// - Compact visual density
  /// - Zero padding
  static ButtonStyle compactIconButtonStyle(ThemeData theme) {
    return IconButton.styleFrom(
      minimumSize: const Size(28, 28),
      maximumSize: const Size(28, 28),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      foregroundColor: theme.colorScheme.onSurfaceVariant,
    );
  }

  /// Builds a date metadata row widget with calendar icon.
  ///
  /// Used for displaying publication date in episode cards.
  static Widget buildDateMetadata({
    required DateTime date,
    required ThemeData theme,
    double iconSize = 13,
    double spacing = 3,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.calendar_today_outlined,
          size: iconSize,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        SizedBox(width: spacing),
        Text(
          formatDate(date),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  /// Builds a duration metadata row widget with schedule icon.
  ///
  /// Used for displaying episode duration in cards.
  static Widget buildDurationMetadata({
    required String formattedDuration,
    required ThemeData theme,
    double iconSize = 13,
    double spacing = 3,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.schedule,
          size: iconSize,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        SizedBox(width: spacing),
        Text(
          formattedDuration,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
