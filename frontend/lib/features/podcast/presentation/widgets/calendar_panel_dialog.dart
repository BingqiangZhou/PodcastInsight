import 'dart:async';

import 'package:flutter/material.dart';
import 'package:personal_ai_assistant/core/constants/app_text_styles.dart';

import 'package:personal_ai_assistant/core/constants/app_durations.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/constants/breakpoints.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/theme/app_theme.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/calendar_panel_helper.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/shared/episode_card_utils.dart';
import 'package:table_calendar/table_calendar.dart';

/// Shows a calendar panel dialog anchored to the top-right of the screen.
///
/// This replaces the duplicated `_showCalendarPanel()` methods in the
/// highlights and daily-report pages.
///
/// Parameters:
/// - [context] - Build context for showing the dialog.
/// - [titleText] - Title displayed above the calendar.
/// - [dateKeys] - Set of date strings (formatted via `EpisodeCardUtils.formatDate`)
///   that have data and should show marker dots.
/// - [selectedDate] - Currently selected date, or null.
/// - [focusedDay] - The calendar's focused day (controls which month is visible).
/// - [onDaySelected] - Callback when a day is tapped. Receives the picked day and
///   the new focused day. The dialog pops itself after invoking this.
/// - [onPageChanged] - Callback when the user swipes to a different month. Receives
///   the new focused day.
/// - [calendarKey] - Widget key prefix for the calendar and its children.
/// - [isLoadingDates] - Whether date data is still loading.
/// - [loadingText] - Text shown next to the loading spinner while dates load.
Future<void> showCalendarPanelDialog({
  required BuildContext context,
  required String titleText,
  required Set<String> dateKeys,
  required DateTime? selectedDate,
  required DateTime focusedDay,
  required void Function(DateTime pickedDay, DateTime focusedDay) onDaySelected,
  required void Function(DateTime focusedDay) onPageChanged,
  required String calendarKey,
  required bool isLoadingDates,
  String? loadingText,
}) async {
  final screenWidth = MediaQuery.sizeOf(context).width;
  final horizontalPadding =
      screenWidth < Breakpoints.medium ? 12.0 : 16.0;

  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor:
        Theme.of(context).colorScheme.scrim.withValues(alpha: 0.12),
    barrierLabel:
        MaterialLocalizations.of(context).modalBarrierDismissLabel,
    transitionDuration: AppDurations.entranceFast,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      final maxPanelWidth = (screenWidth - horizontalPadding * 2)
          .clamp(0.0, CalendarPanelHelper.maxPanelWidth);
      return SafeArea(
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: EdgeInsets.only(
              top: CalendarPanelHelper.dialogTopOffset,
              left: horizontalPadding,
              right: horizontalPadding,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxPanelWidth),
              child: Material(
                color: Colors.transparent,
                child: SurfacePanel(
                  key: Key('${calendarKey}_panel'),
                  padding: EdgeInsets.all(context.spacing.md),
                  borderRadius: CalendarPanelHelper.panelBorderRadius,
                  child: CalendarPanelContent(
                    titleText: titleText,
                    dateKeys: dateKeys,
                    selectedDate: selectedDate,
                    focusedDay: focusedDay,
                    onDaySelected: onDaySelected,
                    onPageChanged: onPageChanged,
                    calendarKey: calendarKey,
                    isLoadingDates: isLoadingDates,
                    loadingText: loadingText,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder:
        (dialogContext, animation, secondaryAnimation, child) {
      return AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final curvedValue =
              Curves.easeOutCubic.transform(animation.value);
          return Opacity(
            opacity: curvedValue,
            child: Transform.scale(
              scale: 0.96 + 0.04 * curvedValue,
              alignment: Alignment.topRight,
              child: child,
            ),
          );
        },
      );
    },
  );
}

/// A self-contained calendar panel content widget.
///
/// Renders a `TableCalendar` with marker dots for dates that have data,
/// a loading indicator, and a title. This widget replaces the duplicated
/// `_buildCalendarPanelContent()` methods in the highlights and daily-report
/// pages.
///
/// All data is passed in as parameters -- the parent is responsible for
/// watching providers and supplying the current state.
class CalendarPanelContent extends StatelessWidget {
  const CalendarPanelContent({
    required this.titleText,
    required this.dateKeys,
    required this.selectedDate,
    required this.focusedDay,
    required this.onDaySelected,
    required this.onPageChanged,
    required this.calendarKey,
    required this.isLoadingDates,
    this.loadingText,
    super.key,
  });

  /// Title displayed above the calendar.
  final String titleText;

  /// Set of formatted date strings that should show marker dots.
  final Set<String> dateKeys;

  /// Currently selected date, or null.
  final DateTime? selectedDate;

  /// The calendar's focused day (controls visible month).
  final DateTime focusedDay;

  /// Called when a day is tapped. The widget pops the enclosing dialog
  /// after invoking this callback.
  final void Function(DateTime pickedDay, DateTime focusedDay) onDaySelected;

  /// Called when the user navigates to a different month page.
  final void Function(DateTime focusedDay) onPageChanged;

  /// Widget key prefix used for keys on the calendar and its children.
  final String calendarKey;

  /// Whether date data is still loading.
  final bool isLoadingDates;

  /// Optional text shown next to the loading spinner while dates load.
  final String? loadingText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = CalendarPanelHelper.toDateOnly(DateTime.now());
    final displayFocusedDay =
        focusedDay.isAfter(now) ? now : focusedDay;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          titleText,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: context.spacing.smMd),
        SizedBox(
          key: Key(calendarKey),
          height: CalendarPanelHelper.calendarHeight,
          child: TableCalendar<bool>(
            firstDay: DateTime(2000),
            lastDay: now,
            focusedDay: displayFocusedDay,
            availableCalendarFormats: {
              CalendarFormat.month: context.l10n.calendar_month_format,
            },
            rowHeight: CalendarPanelHelper.calendarRowHeight,
            daysOfWeekHeight: CalendarPanelHelper.calendarDaysOfWeekHeight,
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              leftChevronIcon: Icon(
                Icons.chevron_left_rounded,
                color: theme.colorScheme.onSurface,
              ),
              rightChevronIcon: Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurface,
              ),
              titleTextStyle:
                  theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ) ??
                  AppTextStyles.metaSmall().copyWith(fontWeight: FontWeight.w700),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle:
                  theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ) ??
                  AppTextStyles.metaSmall(theme.colorScheme.onSurfaceVariant),
              weekendStyle:
                  theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ) ??
                  AppTextStyles.metaSmall(theme.colorScheme.onSurfaceVariant),
            ),
            selectedDayPredicate: (day) =>
                CalendarPanelHelper.isSameDate(day, selectedDate),
            enabledDayPredicate: (day) {
              final normalizedDay = CalendarPanelHelper.toDateOnly(day);
              return !normalizedDay.isAfter(now);
            },
            eventLoader: (day) {
              final hasData =
                  dateKeys.contains(EpisodeCardUtils.formatDate(day));
              return hasData ? const [true] : const [];
            },
            onDaySelected: (pickedDay, focusedDay) {
              onDaySelected(pickedDay, focusedDay);
              // Pop the dialog after selection.
              final navigator = Navigator.of(context);
              if (navigator.canPop()) {
                navigator.pop();
              }
            },
            onPageChanged: (focusedDay) {
              final normalizedFocused =
                  CalendarPanelHelper.toDateOnly(focusedDay);
              onPageChanged(normalizedFocused);
            },
            calendarBuilders: CalendarBuilders<bool>(
              defaultBuilder: (context, day, _) =>
                  CalendarPanelHelper.buildCalendarDayCell(
                context,
                day,
                selectedDate: selectedDate,
                keyPrefix: '${calendarKey}_day',
              ),
              outsideBuilder: (context, day, _) =>
                  CalendarPanelHelper.buildCalendarDayCell(
                context,
                day,
                selectedDate: selectedDate,
                keyPrefix: '${calendarKey}_day',
                isOutside: true,
              ),
              disabledBuilder: (context, day, _) =>
                  CalendarPanelHelper.buildCalendarDayCell(
                context,
                day,
                selectedDate: selectedDate,
                keyPrefix: '${calendarKey}_day',
                isDisabled: true,
              ),
              todayBuilder: (context, day, _) =>
                  CalendarPanelHelper.buildCalendarDayCell(
                context,
                day,
                selectedDate: selectedDate,
                keyPrefix: '${calendarKey}_day',
                isToday: true,
              ),
              selectedBuilder: (context, day, _) =>
                  CalendarPanelHelper.buildCalendarDayCell(
                context,
                day,
                selectedDate: selectedDate,
                keyPrefix: '${calendarKey}_day',
                isSelected: true,
              ),
              markerBuilder: (context, day, events) {
                if (events.isEmpty) return null;
                final isSelected =
                    CalendarPanelHelper.isSameDate(day, selectedDate);
                final markerColor = isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.primary;
                return Positioned(
                  key: Key(
                    '${calendarKey}_marker_${EpisodeCardUtils.formatDate(day)}',
                  ),
                  bottom: CalendarPanelHelper.markerBottomOffset,
                  child: Container(
                    width: CalendarPanelHelper.markerDotSize,
                    height: CalendarPanelHelper.markerDotSize,
                    decoration: BoxDecoration(
                      color: markerColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (isLoadingDates && loadingText != null) ...[
          SizedBox(height: context.spacing.smMd),
          Row(
            children: [
              SizedBox(
                width: CalendarPanelHelper.loadingSpinnerSize,
                height: CalendarPanelHelper.loadingSpinnerSize,
                child: Theme(
                  data: theme.copyWith(
                    colorScheme: theme.colorScheme.copyWith(
                      primary: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  child: const CircularProgressIndicator.adaptive(
                    strokeWidth: 2,
                  ),
                ),
              ),
              SizedBox(width: context.spacing.sm),
              Expanded(
                child: Text(
                  loadingText!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
