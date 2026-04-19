import 'dart:async';

import 'package:flutter/material.dart';

import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_ai_assistant/core/constants/app_radius.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/utils/time_formatter.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/core/widgets/custom_adaptive_navigation.dart';
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive.dart';
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive_sliver_app_bar.dart';
import 'package:personal_ai_assistant/core/widgets/top_floating_notice.dart';
import 'package:personal_ai_assistant/features/auth/presentation/providers/auth_provider.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_daily_report_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/calendar_panel_dialog.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/shared/episode_card_utils.dart';
import 'package:personal_ai_assistant/shared/widgets/loading_widget.dart';

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
    try {
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
    } catch (error) {
      if (mounted) {
        showTopFloatingNotice(
          context,
          message: context.l10n.podcast_daily_report_error_hint,
          isError: true,
        );
      }
    }
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
          avoidTopSafeArea: true,
          alignment: Alignment.topCenter,
          child: Scrollbar(
            controller: _reportItemsScrollController,
            child: CustomScrollView(
              controller: _reportItemsScrollController,
              slivers: [
                AdaptiveSliverAppBar(
                  title: l10n.podcast_daily_report_title,
                  actions: [_buildCalendarButton(context)],
                ),
                SliverToBoxAdapter(
                    child: SizedBox(height: context.spacing.smMd)),
                ..._buildDailyReportSlivers(context),
              ],
            ),
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

  List<Widget> _buildDailyReportSlivers(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tokens = appThemeOf(context);
    final reportAsync = ref.watch(dailyReportProvider);
    final selectedDate = ref.watch(selectedDailyReportDateProvider);
    final report = reportAsync.value;
    final headerDate =
        report?.reportDate ?? selectedDate ?? _focusedCalendarDay;

    if (reportAsync.isLoading && report == null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _buildBarePanelState(
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
          ),
        ),
      ];
    }

    if (reportAsync.hasError && report == null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _buildPanelScaffold(
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
          ),
        ),
      ];
    }

    final currentReport = report;
    if (currentReport == null || !currentReport.available) {
      final targetDate = currentReport?.reportDate ?? headerDate;
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _buildPanelScaffold(
            context,
            title: EpisodeCardUtils.formatDate(targetDate),
            subtitle: l10n.podcast_daily_report_empty,
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: AppRadius.xxlCardRadius,
                border: Border.all(
                    color: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.15)),
              ),
              padding: EdgeInsets.all(context.spacing.md),
              child: Text(
                l10n.podcast_daily_report_empty,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ];
    }

    // Data state: flat slivers for the panel header, items, and bottom cap.
    final headerTitle =
        EpisodeCardUtils.formatDate(currentReport.reportDate ?? headerDate);
    final headerSubtitle =
        '${l10n.podcast_daily_report_items(currentReport.totalItems)} | ${l10n.podcast_daily_report_generated_prefix} ${currentReport.generatedAt != null ? TimeFormatter.formatTime(currentReport.generatedAt) : '--:--'}';

    return [
      // Panel header top with rounded top corners
      SliverToBoxAdapter(
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(tokens.cardRadius),
              topRight: Radius.circular(tokens.cardRadius),
            ),
            border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.15),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(context.spacing.mdLg,
                    context.spacing.md, context.spacing.mdLg, context.spacing.smMd),
                child: AppSectionHeader(
                  title: headerTitle,
                  subtitle: headerSubtitle,
                  trailing: _buildRegenerateButton(
                    currentReport.reportDate ?? headerDate,
                  ),
                ),
              ),
              Divider(
                height: 1,
                color: theme.colorScheme.outlineVariant
                    .withValues(alpha: 0.45),
              ),
            ],
          ),
        ),
      ),
      // Items list or empty text
      if (currentReport.items.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(context.spacing.mdLg),
            child: Text(
              l10n.podcast_daily_report_empty,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        )
      else
        SliverList.builder(
          itemCount: currentReport.items.length,
          itemBuilder: (itemContext, index) {
            final item = currentReport.items[index];
            return _buildReportItemCard(itemContext, item);
          },
        ),
      // Panel bottom cap with rounded bottom corners
      SliverToBoxAdapter(
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(tokens.cardRadius),
              bottomRight: Radius.circular(tokens.cardRadius),
            ),
            border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.15),
            ),
          ),
          height: context.spacing.smMd,
        ),
      ),
      // Bottom buffer
      SliverPadding(
        padding: EdgeInsets.only(bottom: context.spacing.xl),
      ),
    ];
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
            padding: EdgeInsets.fromLTRB(context.spacing.mdLg, context.spacing.md, context.spacing.mdLg, context.spacing.smMd),
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
          padding: EdgeInsets.fromLTRB(context.spacing.mdLg, context.spacing.md, context.spacing.mdLg, context.spacing.smMd),
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
      child: AdaptiveInkWell(
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
          padding: EdgeInsets.fromLTRB(context.spacing.md, context.spacing.md, context.spacing.md, context.spacing.smMd),
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
    final l10n = context.l10n;
    final reportDatesAsync = ref.read(dailyReportDatesProvider);
    final selectedDate = ref.read(selectedDailyReportDateProvider);
    final reportDateKeys = <String>{
      for (final item
          in reportDatesAsync.value?.dates ??
              const <PodcastDailyReportDateItem>[])
        EpisodeCardUtils.formatDate(item.reportDate),
    };

    await showCalendarPanelDialog(
      context: context,
      titleText: l10n.podcast_daily_report_dates,
      dateKeys: reportDateKeys,
      selectedDate: selectedDate,
      focusedDay: _focusedCalendarDay,
      calendarKey: 'daily_report_calendar',
      isLoadingDates: reportDatesAsync.isLoading && reportDatesAsync.value == null,
      loadingText: l10n.podcast_daily_report_loading,
      onDaySelected: (pickedDay, focusedDay) {
        unawaited(
          _handleCalendarDaySelected(
            pickedDay: pickedDay,
            focusedDay: focusedDay,
          ),
        );
      },
      onPageChanged: (focusedDay) {
        setState(() {
          _focusedCalendarDay = focusedDay;
        });
        unawaited(
          ref
              .read(dailyReportDatesProvider.notifier)
              .ensureMonthCoverage(focusedDay),
        );
      },
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
