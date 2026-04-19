import 'package:flutter/material.dart';

import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/shared/episode_card_utils.dart';

/// Shared calendar day cell builder for daily report and highlights pages.
class CalendarPanelHelper {
  CalendarPanelHelper._();

  /// Normalizes a [DateTime] to a date-only value (no time component).
  static DateTime toDateOnly(DateTime value) {
    final local = value.isUtc ? value.toLocal() : value;
    return DateTime(local.year, local.month, local.day);
  }

  /// Returns `true` if [left] and [right] represent the same calendar date.
  static bool isSameDate(DateTime? left, DateTime? right) {
    if (left == null || right == null) return false;
    final l = toDateOnly(left);
    final r = toDateOnly(right);
    return l.year == r.year && l.month == r.month && l.day == r.day;
  }

  /// Builds a styled calendar day cell for TableCalendar builders.
  ///
  /// [context] - Build context for theme access.
  /// [day] - The day to render.
  /// [selectedDate] - The currently selected date (may be null).
  /// [keyPrefix] - Prefix for widget keys (e.g. 'daily_report_calendar_day').
  /// [isSelected] - Whether TableCalendar marked this day as selected.
  /// [isToday] - Whether this day is today.
  /// [isOutside] - Whether this day falls outside the current month.
  /// [isDisabled] - Whether this day is disabled.
  static Widget buildCalendarDayCell(
    BuildContext context,
    DateTime day, {
    required DateTime? selectedDate,
    required String keyPrefix,
    bool isSelected = false,
    bool isToday = false,
    bool isOutside = false,
    bool isDisabled = false,
  }) {
    final theme = Theme.of(context);
    final normalizedDay = toDateOnly(day);
    final selected = isSelected || isSameDate(normalizedDay, selectedDate);
    var textColor = theme.colorScheme.onSurface;
    if (selected) {
      textColor = theme.colorScheme.onPrimary;
    } else if (isOutside || isDisabled) {
      textColor = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6);
    } else if (isToday) {
      textColor = theme.colorScheme.primary;
    }

    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        key: Key('${keyPrefix}_${EpisodeCardUtils.formatDate(normalizedDay)}'),
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: isOutside || isDisabled ? 0.18 : 0.22,
                ),
          borderRadius: BorderRadius.circular(appThemeOf(context).cardRadius),
          border: Border.all(
            color: isToday && !selected
                ? theme.colorScheme.primary.withValues(alpha: 0.75)
                : theme.colorScheme.outlineVariant.withValues(
                    alpha: selected ? 0 : 0.35,
                  ),
          ),
        ),
        child: Text(
          '${normalizedDay.day}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: textColor,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
