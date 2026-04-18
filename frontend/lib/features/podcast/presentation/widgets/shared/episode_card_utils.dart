import 'package:flutter/material.dart';

import 'package:personal_ai_assistant/core/theme/app_theme.dart';
import 'package:personal_ai_assistant/core/utils/time_formatter.dart';

/// Shared utilities for episode card widgets.
///
/// Provides common formatting and styling to reduce code duplication
/// across different episode card implementations.
class EpisodeCardUtils {
  EpisodeCardUtils._();

  /// Formats a DateTime to 'YYYY-MM-DD' format using local time.
  ///
  /// Delegates to [TimeFormatter.formatDate] for consistency across the app.
  static String formatDate(DateTime date) => TimeFormatter.formatDate(date);

  /// Creates a compact icon button style suitable for episode action buttons.
  ///
  /// This style is optimized for dense layouts with:
  /// - Fixed 28x28 size
  /// - Shrinkwrap tap target
  /// - Compact visual density
  /// - Zero padding
  static ButtonStyle compactIconButtonStyle(ThemeData theme, {bool isMobile = false}) {
    const size = 16.0;
    return IconButton.styleFrom(
      minimumSize: Size(size, size),
      maximumSize: Size(size, size),
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
          style: AppTheme.metaSmall(
            theme.colorScheme.onSurfaceVariant,
          ).copyWith(fontWeight: FontWeight.w400),
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
          style: AppTheme.metaSmall(
            theme.colorScheme.onSurfaceVariant,
          ).copyWith(fontWeight: FontWeight.w400),
        ),
      ],
    );
  }
}
