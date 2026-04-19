import 'dart:async';

import 'package:flutter/material.dart';

import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_ai_assistant/core/constants/app_radius.dart';
import 'package:personal_ai_assistant/core/constants/breakpoints.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/theme/app_theme.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/utils/time_formatter.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/core/widgets/custom_adaptive_navigation.dart';
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive_sliver_app_bar.dart';
import 'package:personal_ai_assistant/core/widgets/top_floating_notice.dart';
import 'package:personal_ai_assistant/features/auth/presentation/providers/auth_provider.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_daily_report_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/calendar_panel_helper.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/shared/episode_card_utils.dart';
import 'package:personal_ai_assistant/shared/widgets/loading_widget.dart';
import 'package:table_calendar/table_calendar.dart';

class PodcastDailyReportPage extends ConsumerStatefulWidget {
  const PodcastDailyReportPage({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  ConsumerState<PodcastDailyReportPage> createState() =>
      _PodcastDailyReportPageState();
}

class _PodcastDailyReportPageState
    extends ConsumerState<PodcastDailyReportPage> {
  bool _isGeneratingDailyReport = false;
  final ScrollController _reportItemsScrollController = ScrollController();
  static final RegExp _summaryTrailingDividerRegExp = RegExp(
    r'(?:\s*---\s*)+$',
  );
  late DateTime _focusedCalendarDay;

  @override
  void initState() {
    super.initState();
    final targetDate = _resolveInitialDate(widget.initialDate);
    _focusedCalendarDay = targetDate;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(selectedDailyReportDateProvider.notifier).setDate(targetDate);

      final isAuthenticated = ref.read(authProvider).isAuthenticated;
      if (!isAuthenticated) {
        return;
      }

      unawaited(_loadInitialDailyReportData(targetDate));
    });
  }

  Future<void> _loadInitialDailyReportData(DateTime targetDate) async {
    await Future.wait([
      ref
          .read(dailyReportProvider.notifier)
          .load(date: targetDate, forceRefresh: true),
      ref.read(dailyReportDatesProvider.notifier).load(forceRefresh: true),
    ]);
    if (!mounted) {
      return;
    }
    await ref
        .read(dailyReportDatesProvider.notifier)
        .ensureMonthCoverage(targetDate);
  }

  @override
  void dispose() {
    _reportItemsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      key: const Key('daily_report_page'),
      backgroundColor: Colors.transparent,
      body: Material(
        color: Colors.transparent,
        child: ResponsiveContainer(
          maxWidth: 1480,
          alignment: Alignment.topCenter,
          child: CustomScrollView(
            slivers: [
              AdaptiveSliverAppBar(
                title: l10n.podcast_daily_report_title,
                actions: [_buildCalendarButton(context)],
              ),
              SliverToBoxAdapter(child: SizedBox(height: context.spacing.smMd)),
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildDailyReportPanel(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarButton(BuildContext context) {
    final l10n = context.l10n;
    return HeaderCapsuleActionButton(
      key: const Key('daily_report_calendar_menu_button'),
      tooltip: l10n.podcast_daily_report_dates,
      onPressed: () {
        unawaited(_showCalendarPanel());
      },
      icon: Icons.calendar_month_outlined,
      circular: true,
    );
  }

  Widget _buildRegenerateButton(DateTime? targetDate) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tokens = appThemeOf(context);
    return FilledButton.tonalIcon(
      key: const Key('daily_report_regenerate_button'),
      onPressed: _isGeneratingDailyReport || targetDate == null
          ? null
          : () =>
                _generateDailyReportForSelectedDate(targetDate, rebuild: true),
      icon: _isGeneratingDailyReport
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator.adaptive(strokeWidth: 2),
            )
          : const Icon(Icons.refresh_rounded, size: 18),
      label: Text(
        _isGeneratingDailyReport
            ? l10n.podcast_daily_report_loading
            : l10n.refresh,
      ),
      style: FilledButton.styleFrom(
        backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.6 : 0.86,
        ),
        foregroundColor: theme.colorScheme.onSurface,
        disabledBackgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.32,
        ),
        disabledForegroundColor: theme.colorScheme.onSurfaceVariant.withValues(
          alpha: 0.7,
        ),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
        shape: AppRadius.pillShape,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.symmetric(horizontal: context.spacing.md, vertical: context.spacing.smMd),
        textStyle: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildDailyReportPanel(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tokens = appThemeOf(context);
    final reportAsync = ref.watch(dailyReportProvider);
    final selectedDate = ref.watch(selectedDailyReportDateProvider);
    final report = reportAsync.value;
    final headerDate =
        report?.reportDate ?? selectedDate ?? _focusedCalendarDay;

    if (reportAsync.isLoading && report == null) {
      return _buildBarePanelState(
        context,
        title: EpisodeCardUtils.formatDate(headerDate),
        subtitle: l10n.podcast_daily_report_loading,
        child: LoadingStatusContent(
          key: const Key('daily_report_loading_content'),
          title: l10n.podcast_daily_report_loading,
          spinnerSize: 28,
          spinnerColor: theme.colorScheme.primary,
          gapAfterSpinner: 12,
        ),
      );
    }

    if (reportAsync.hasError && report == null) {
      return _buildPanelScaffold(
        context,
        title: EpisodeCardUtils.formatDate(headerDate),
        subtitle: l10n.podcast_failed_to_load_feed,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.podcast_daily_report_error_hint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            SizedBox(height: context.spacing.md),
            FilledButton.tonal(
              onPressed: () {
                ref
                    .read(dailyReportProvider.notifier)
                    .load(date: selectedDate, forceRefresh: true);
                ref
                    .read(dailyReportDatesProvider.notifier)
                    .load(forceRefresh: true);
              },
              child: Text(l10n.podcast_retry),
            ),
          ],
        ),
      );
    }

    final currentReport = report;
    if (currentReport == null || !currentReport.available) {
      final targetDate = currentReport?.reportDate ?? headerDate;
      return _buildPanelScaffold(
        context,
        title: EpisodeCardUtils.formatDate(targetDate),
        subtitle: l10n.podcast_daily_report_empty,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: AppRadius.xxlCardRadius,
            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15)),
          ),
          padding: EdgeInsets.all(context.spacing.md),
          child: Text(
            l10n.podcast_daily_report_empty,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return SurfacePanel(
      padding: EdgeInsets.zero,
      showBorder: false,
      borderRadius: tokens.cardRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(context.spacing.mdLg, 18, context.spacing.mdLg, 14),
            child: AppSectionHeader(
              title: EpisodeCardUtils.formatDate(currentReport.reportDate ?? headerDate),
              subtitle:
                  '${l10n.podcast_daily_report_items(currentReport.totalItems)} | ${l10n.podcast_daily_report_generated_prefix} ${currentReport.generatedAt != null ? TimeFormatter.formatTime(currentReport.generatedAt) : '--:--'}',
              trailing: _buildRegenerateButton(
                currentReport.reportDate ?? headerDate,
              ),
            ),
          ),
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
          Expanded(
            child: currentReport.items.isEmpty
                ? Padding(
                    padding: EdgeInsets.all(context.spacing.mdLg),
                    child: Text(
                      l10n.podcast_daily_report_empty,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : Scrollbar(
                    controller: _reportItemsScrollController,
                    thumbVisibility: currentReport.items.length > 4,
                    child: ListView.separated(
                      controller: _reportItemsScrollController,
                      key: const Key('daily_report_items_scroll'),
                      padding: EdgeInsets.zero,
                      itemCount: currentReport.items.length,
                      separatorBuilder: (_, separatorIndex) =>
                          const SizedBox.shrink(),
                      itemBuilder: (itemContext, index) {
                        final item = currentReport.items[index];
                        return _buildReportItemCard(itemContext, item);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelScaffold(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final tokens = appThemeOf(context);
    final theme = Theme.of(context);

    return SurfacePanel(
      padding: EdgeInsets.zero,
      showBorder: false,
      borderRadius: tokens.cardRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(context.spacing.mdLg, 18, context.spacing.mdLg, 14),
            child: AppSectionHeader(
              title: title,
              subtitle: subtitle,
              trailing: _buildRegenerateButton(
                ref.watch(selectedDailyReportDateProvider) ??
                    _focusedCalendarDay,
              ),
            ),
          ),
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(context.spacing.mdLg),
              child: Align(alignment: Alignment.topLeft, child: child),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarePanelState(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(context.spacing.mdLg, 18, context.spacing.mdLg, 14),
          child: AppSectionHeader(
            title: title,
            subtitle: subtitle,
            trailing: _buildRegenerateButton(
              ref.watch(selectedDailyReportDateProvider) ?? _focusedCalendarDay,
            ),
          ),
        ),
        SizedBox(height: context.spacing.mdLg),
        Expanded(child: Center(child: child)),
      ],
    );
  }

  Widget _buildReportItemCard(
    BuildContext context,
    PodcastDailyReportItem item,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final metaLine =
        '${item.episodeTitle} | ${item.subscriptionTitle ?? l10n.podcast_default_podcast}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('daily_report_item_${item.episodeId}'),
        onTap: () {
          context.push('/podcast/episode/detail/${item.episodeId}');
        },
        borderRadius: AppRadius.xxlCardRadius,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: AppRadius.xxlCardRadius,
            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15)),
          ),
          padding: EdgeInsets.fromLTRB(context.spacing.md, context.spacing.md, context.spacing.md, 14),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _sanitizeOneLineSummary(item.oneLineSummary),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                          height: 1.45,
                        ),
                      ),
                    ),
                    if (item.isCarryover) ...[
                      SizedBox(width: context.spacing.smMd),
                      Icon(
                        Icons.history_toggle_off_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ],
                ),
                SizedBox(height: context.spacing.smMd),
                Text(
                  metaLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }

  Future<void> _showCalendarPanel() async {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding =
        screenWidth < Breakpoints.medium ? 12.0 : 16.0;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.12),
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final maxPanelWidth = (screenWidth - horizontalPadding * 2)
            .clamp(0.0, 400.0)
            ;
        return SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: EdgeInsets.only(
                top: 84,
                left: horizontalPadding,
                right: horizontalPadding,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxPanelWidth),
                child: Material(
                  color: Colors.transparent,
                  child: SurfacePanel(
                    key: const Key('daily_report_calendar_panel'),
                    padding: EdgeInsets.all(context.spacing.md),
                    borderRadius: 26,
                    child: Consumer(
                      builder: (panelContext, panelRef, _) {
                        return _buildCalendarPanelContent(
                          panelContext,
                          panelRef,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final curvedValue = Curves.easeOutCubic.transform(animation.value);
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

  Widget _buildCalendarPanelContent(BuildContext context, WidgetRef panelRef) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final reportDatesAsync = panelRef.watch(dailyReportDatesProvider);
    final selectedDate = panelRef.watch(selectedDailyReportDateProvider);
    final reportDateKeys = <String>{
      for (final item
          in reportDatesAsync.value?.dates ??
              const <PodcastDailyReportDateItem>[])
        EpisodeCardUtils.formatDate(item.reportDate),
    };
    final now = _toDateOnly(DateTime.now());
    final displayFocusedDay = _focusedCalendarDay.isAfter(now)
        ? now
        : _focusedCalendarDay;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.podcast_daily_report_dates,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: context.spacing.smMd),
        SizedBox(
          key: const Key('daily_report_calendar'),
          height: 348,
          child: TableCalendar<bool>(
            firstDay: DateTime(2000),
            lastDay: now,
            focusedDay: displayFocusedDay,
            availableCalendarFormats: {CalendarFormat.month: context.l10n.calendar_month_format},
            rowHeight: 42,
            daysOfWeekHeight: 22,
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
                  AppTheme.metaSmall().copyWith(fontWeight: FontWeight.w700),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle:
                  theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ) ??
                  AppTheme.metaSmall(theme.colorScheme.onSurfaceVariant),
              weekendStyle:
                  theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ) ??
                  AppTheme.metaSmall(theme.colorScheme.onSurfaceVariant),
            ),
            selectedDayPredicate: (day) => _isSameDate(day, selectedDate),
            enabledDayPredicate: (day) {
              final normalizedDay = _toDateOnly(day);
              return !normalizedDay.isAfter(now);
            },
            eventLoader: (day) {
              final hasReport = reportDateKeys.contains(EpisodeCardUtils.formatDate(day));
              return hasReport ? const [true] : const [];
            },
            onDaySelected: (pickedDay, focusedDay) {
              unawaited(
                _handleCalendarDaySelectedFromPanel(
                  panelContext: context,
                  pickedDay: pickedDay,
                  focusedDay: focusedDay,
                ),
              );
            },
            onPageChanged: (focusedDay) {
              final normalizedFocused = _toDateOnly(focusedDay);
              setState(() {
                _focusedCalendarDay = normalizedFocused;
              });
              unawaited(
                panelRef
                    .read(dailyReportDatesProvider.notifier)
                    .ensureMonthCoverage(normalizedFocused),
              );
            },
            calendarBuilders: CalendarBuilders<bool>(
              defaultBuilder: (context, day, _) => _buildCalendarDayCell(
                context,
                day,
                selectedDate: selectedDate,
              ),
              outsideBuilder: (context, day, _) => _buildCalendarDayCell(
                context,
                day,
                selectedDate: selectedDate,
                isOutside: true,
              ),
              disabledBuilder: (context, day, _) => _buildCalendarDayCell(
                context,
                day,
                selectedDate: selectedDate,
                isDisabled: true,
              ),
              todayBuilder: (context, day, _) => _buildCalendarDayCell(
                context,
                day,
                selectedDate: selectedDate,
                isToday: true,
              ),
              selectedBuilder: (context, day, _) => _buildCalendarDayCell(
                context,
                day,
                selectedDate: selectedDate,
                isSelected: true,
              ),
              markerBuilder: (context, day, events) {
                if (events.isEmpty) {
                  return null;
                }
                final isSelected = _isSameDate(day, selectedDate);
                final markerColor = isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.primary;
                return Positioned(
                  key: Key('daily_report_calendar_marker_${EpisodeCardUtils.formatDate(day)}'),
                  bottom: 5,
                  child: Container(
                    width: 6,
                    height: 6,
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
        if (reportDatesAsync.isLoading && reportDatesAsync.value == null) ...[
          SizedBox(height: context.spacing.smMd),
          Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
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
                  l10n.podcast_daily_report_loading,
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

  Future<void> _handleCalendarDaySelectedFromPanel({
    required BuildContext panelContext,
    required DateTime pickedDay,
    required DateTime focusedDay,
  }) async {
    await _handleCalendarDaySelected(
      pickedDay: pickedDay,
      focusedDay: focusedDay,
    );
    if (!panelContext.mounted) {
      return;
    }
    final navigator = Navigator.of(panelContext);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  Widget _buildCalendarDayCell(
    BuildContext context,
    DateTime day, {
    required DateTime? selectedDate,
    bool isSelected = false,
    bool isToday = false,
    bool isOutside = false,
    bool isDisabled = false,
  }) {
    return CalendarPanelHelper.buildCalendarDayCell(
      context,
      day,
      selectedDate: selectedDate,
      keyPrefix: 'daily_report_calendar_day',
      isSelected: isSelected,
      isToday: isToday,
      isOutside: isOutside,
      isDisabled: isDisabled,
    );
  }

  Future<void> _handleCalendarDaySelected({
    required DateTime pickedDay,
    required DateTime focusedDay,
  }) async {
    final normalizedSelected = _toDateOnly(pickedDay);
    final normalizedFocused = _toDateOnly(focusedDay);
    if (mounted) {
      setState(() {
        _focusedCalendarDay = normalizedFocused;
      });
    }
    ref
        .read(selectedDailyReportDateProvider.notifier)
        .setDate(normalizedSelected);
    await ref
        .read(dailyReportProvider.notifier)
        .load(date: normalizedSelected, forceRefresh: true);
  }

  Future<void> _generateDailyReportForSelectedDate(
    DateTime? selectedDate, {
    bool rebuild = false,
  }) async {
    if (selectedDate == null) {
      return;
    }
    setState(() {
      _isGeneratingDailyReport = true;
    });

    try {
      final generated = await ref
          .read(dailyReportProvider.notifier)
          .generate(date: selectedDate, rebuild: rebuild);
      if (!mounted) {
        return;
      }

      if (generated != null && generated.available) {
        final l10n = context.l10n;
        showTopFloatingNotice(
          context,
          message: l10n.podcast_daily_report_generate_success,
          extraTopOffset: 64,
        );
      } else {
        final l10n = context.l10n;
        showTopFloatingNotice(
          context,
          message: l10n.podcast_daily_report_generate_failed,
          isError: true,
          extraTopOffset: 64,
        );
      }
    } catch (error) {
      if (mounted) {
        final l10n = context.l10n;
        final errorMessage = error.toString().trim();
        showTopFloatingNotice(
          context,
          message: errorMessage.isEmpty
              ? l10n.podcast_daily_report_generate_failed
              : '${l10n.podcast_daily_report_generate_failed}: $errorMessage',
          isError: true,
          extraTopOffset: 64,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingDailyReport = false;
        });
      }
    }
  }

  bool _isSameDate(DateTime? left, DateTime? right) {
    if (left == null || right == null) {
      return false;
    }
    final l = _toDateOnly(left);
    final r = _toDateOnly(right);
    return l.year == r.year && l.month == r.month && l.day == r.day;
  }

  DateTime _resolveInitialDate(DateTime? rawValue) {
    final now = _toDateOnly(DateTime.now());
    final minimum = DateTime(2000);
    final fallback = now.subtract(const Duration(days: 1));
    if (rawValue == null) {
      return fallback;
    }

    final normalized = _toDateOnly(rawValue);
    if (normalized.isAfter(now)) {
      return now;
    }
    if (normalized.isBefore(minimum)) {
      return minimum;
    }
    return normalized;
  }

  DateTime _toDateOnly(DateTime value) {
    final local = value.isUtc ? value.toLocal() : value;
    return DateTime(local.year, local.month, local.day);
  }

  String _sanitizeOneLineSummary(String rawSummary) {
    final normalized = rawSummary.trim();
    if (normalized.isEmpty) {
      return normalized;
    }
    return normalized.replaceAll(_summaryTrailingDividerRegExp, '').trim();
  }
}
