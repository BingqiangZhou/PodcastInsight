import 'dart:async';

import 'package:flutter/material.dart';

import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_ai_assistant/core/constants/breakpoints.dart';
import 'package:personal_ai_assistant/core/constants/scroll_constants.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/core/widgets/custom_adaptive_navigation.dart';
import 'package:personal_ai_assistant/features/auth/presentation/providers/auth_provider.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_highlight_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/highlight_card.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/shared/episode_card_utils.dart';
import 'package:personal_ai_assistant/shared/widgets/loading_widget.dart';
import 'package:table_calendar/table_calendar.dart';

/// Page for displaying podcast highlights.
///
/// Shows a list of highlight cards with filtering by date and source.
/// Features a calendar popup for date selection and responsive layout.
class PodcastHighlightsPage extends ConsumerStatefulWidget {
  const PodcastHighlightsPage({super.key, this.initialDate, this.source});

  final DateTime? initialDate;
  final String? source;

  @override
  ConsumerState<PodcastHighlightsPage> createState() =>
      _PodcastHighlightsPageState();
}

class _PodcastHighlightsPageState extends ConsumerState<PodcastHighlightsPage> {
  final ScrollController _scrollController = ScrollController();
  late DateTime _focusedCalendarDay;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    final targetDate = _resolveInitialDate(widget.initialDate);
    _focusedCalendarDay = targetDate;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(selectedHighlightDateProvider.notifier).setDate(targetDate);

      final isAuthenticated = ref.read(authProvider).isAuthenticated;
      if (!isAuthenticated) return;

      unawaited(_loadInitialHighlightsData(targetDate));
    });

    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore) return;

    final highlightsAsync = ref.read(highlightsProvider);
    final hasMore = highlightsAsync.value?.hasMore ?? false;

    if (!hasMore) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    const delta = 200.0;

    if (maxScroll - currentScroll < delta) {
      _loadMoreHighlights();
    }
  }

  Future<void> _loadInitialHighlightsData(DateTime targetDate) async {
    await Future.wait([
      ref
          .read(highlightsProvider.notifier)
          .load(date: targetDate, forceRefresh: true),
      ref.read(highlightDatesProvider.notifier).load(forceRefresh: true),
    ]);

    if (!mounted) return;
    await ref
        .read(highlightDatesProvider.notifier)
        .ensureMonthCoverage(targetDate);
  }

  Future<void> _loadMoreHighlights() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final selectedDate = ref.read(selectedHighlightDateProvider);
      await ref.read(highlightsProvider.notifier).loadNextPage(date: selectedDate);
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('highlights_page'),
      backgroundColor: Colors.transparent,
      body: Material(
        color: Colors.transparent,
        child: SafeArea(
          bottom: false,
          child: ResponsiveContainer(
            maxWidth: 1480,
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderPanel(context),
                const SizedBox(height: AppSpacing.smMd),
                Expanded(child: _buildHighlightsPanel(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderPanel(BuildContext context) {
    final isMobile =
        MediaQuery.sizeOf(context).width < Breakpoints.medium;
    final l10n = context.l10n;

    return CompactHeaderPanel(
      title: l10n.podcast_highlights_title,
      trailing: isMobile
          ? _buildCalendarButton(context)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCalendarButton(context),
                const SizedBox(width: AppSpacing.sm),
                _buildBackButton(context),
              ],
            ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return HeaderCapsuleActionButton(
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      icon: Icons.arrow_back_rounded,
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
      },
      circular: true,
    );
  }

  Widget _buildCalendarButton(BuildContext context) {
    final l10n = context.l10n;
    return HeaderCapsuleActionButton(
      key: const Key('highlights_calendar_menu_button'),
      tooltip: l10n.podcast_highlights_dates,
      onPressed: () {
        unawaited(_showCalendarPanel());
      },
      icon: Icons.calendar_month_outlined,
      circular: true,
    );
  }

  Widget _buildHighlightsPanel(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = appThemeOf(context);
    final l10n = context.l10n;
    final highlightsAsync = ref.watch(highlightsProvider);
    final selectedDate = ref.watch(selectedHighlightDateProvider);
    final headerDate = selectedDate ?? _focusedCalendarDay;

    if (highlightsAsync.isLoading && highlightsAsync.value == null) {
      return _buildLoadingState(context, headerDate);
    }

    if (highlightsAsync.hasError && highlightsAsync.value == null) {
      return _buildErrorState(context, headerDate);
    }

    final highlightsResponse = highlightsAsync.value;
    final highlights = highlightsResponse?.items ?? [];

    if (highlights.isEmpty) {
      return _buildEmptyState(context, headerDate);
    }

    return SurfacePanel(
      padding: EdgeInsets.zero,
      showBorder: false,
      borderRadius: tokens.cardRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.mdLg, 18, AppSpacing.mdLg, 14),
            child: AppSectionHeader(
              title: EpisodeCardUtils.formatDate(headerDate),
              subtitle: l10n.podcast_highlights_items(highlightsResponse?.total ?? 0),
            ),
          ),
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: highlights.length > 4,
              child: ListView.separated(
                controller: _scrollController,
                key: const Key('highlights_scroll'),
                padding: EdgeInsets.zero,
                cacheExtent: ScrollConstants.defaultCacheExtent,
                itemCount: highlights.length + (_isLoadingMore ? 1 : 0),
                separatorBuilder: (_, index) => const SizedBox.shrink(),
                itemBuilder: (itemContext, index) {
                  if (index >= highlights.length) {
                    return _buildLoadingMoreIndicator(itemContext);
                  }
                  final highlight = highlights[index];
                  return _buildHighlightCard(itemContext, highlight);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightCard(
    BuildContext context,
    HighlightResponse highlight,
  ) {
    return HighlightCard(
      key: Key('highlight_${highlight.id}'),
      highlight: highlight,
      onTap: () {
        context.push('/podcast/episode/detail/${highlight.episodeId}');
      },
      onFavoriteToggle: () {
        ref
            .read(highlightsProvider.notifier)
            .toggleFavorite(highlight.id);
      },
    );
  }

  Widget _buildLoadingMoreIndicator(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: SizedBox(
          width: 24,
          height: 24,
          child: Theme(
            data: theme.copyWith(
              colorScheme: theme.colorScheme.copyWith(
                primary: theme.colorScheme.primary,
              ),
            ),
            child: const CircularProgressIndicator.adaptive(
              strokeWidth: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context, DateTime headerDate) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.mdLg, 18, AppSpacing.mdLg, 14),
          child: AppSectionHeader(
            title: EpisodeCardUtils.formatDate(headerDate),
            subtitle: l10n.podcast_highlights_loading,
          ),
        ),
        const SizedBox(height: AppSpacing.mdLg),
        Expanded(
          child: Center(
            child: LoadingStatusContent(
              key: const Key('highlights_loading_content'),
              title: l10n.podcast_highlights_loading_highlights,
              spinnerSize: 28,
              spinnerColor: theme.colorScheme.primary,
              gapAfterSpinner: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context, DateTime headerDate) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return SurfacePanel(
      padding: EdgeInsets.zero,
      showBorder: false,
      borderRadius: appThemeOf(context).cardRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.mdLg, 18, AppSpacing.mdLg, 14),
            child: AppSectionHeader(
              title: EpisodeCardUtils.formatDate(headerDate),
              subtitle: l10n.podcast_highlights_load_failed,
            ),
          ),
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.mdLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.podcast_highlights_cannot_load,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.tonal(
                    onPressed: () {
                      final selectedDate =
                          ref.read(selectedHighlightDateProvider);
                      ref
                          .read(highlightsProvider.notifier)
                          .load(date: selectedDate, forceRefresh: true);
                      ref
                          .read(highlightDatesProvider.notifier)
                          .load(forceRefresh: true);
                    },
                    child: Text(l10n.podcast_highlights_retry),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, DateTime headerDate) {
    final theme = Theme.of(context);
    final tokens = appThemeOf(context);
    final l10n = context.l10n;

    return SurfacePanel(
      padding: EdgeInsets.zero,
      showBorder: false,
      borderRadius: tokens.cardRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.mdLg, 18, AppSpacing.mdLg, 14),
            child: AppSectionHeader(
              title: EpisodeCardUtils.formatDate(headerDate),
              subtitle: l10n.podcast_highlights_no_highs,
            ),
          ),
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.mdLg),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15)),
                ),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  l10n.podcast_highlights_empty,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
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
      barrierColor: Colors.black.withValues(alpha: 0.12),
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
                    key: const Key('highlights_calendar_panel'),
                    padding: const EdgeInsets.all(AppSpacing.md),
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
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            alignment: Alignment.topRight,
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildCalendarPanelContent(BuildContext context, WidgetRef panelRef) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final datesAsync = panelRef.watch(highlightDatesProvider);
    final selectedDate = panelRef.watch(selectedHighlightDateProvider);
    final highlightDateKeys = <String>{
      for (final item in datesAsync.value?.dates ?? const <DateTime>[])
        EpisodeCardUtils.formatDate(item),
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
          l10n.podcast_highlights_dates,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.smMd),
        SizedBox(
          key: const Key('highlights_calendar'),
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
                  const TextStyle(fontWeight: FontWeight.w700),
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle:
                  theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ) ??
                  const TextStyle(),
              weekendStyle:
                  theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ) ??
                  const TextStyle(),
            ),
            selectedDayPredicate: (day) => _isSameDate(day, selectedDate),
            enabledDayPredicate: (day) {
              final normalizedDay = _toDateOnly(day);
              return !normalizedDay.isAfter(now);
            },
            eventLoader: (day) {
              final hasHighlights =
                  highlightDateKeys.contains(EpisodeCardUtils.formatDate(day));
              return hasHighlights ? const [true] : const [];
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
                    .read(highlightDatesProvider.notifier)
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
                if (events.isEmpty) return null;
                final isSelected = _isSameDate(day, selectedDate);
                final markerColor = isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.primary;
                return Positioned(
                  key: Key(
                      'highlights_calendar_marker_${EpisodeCardUtils.formatDate(day)}'),
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
        if (datesAsync.isLoading && datesAsync.value == null) ...[
          const SizedBox(height: AppSpacing.smMd),
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
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.podcast_highlights_loading,
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
    if (!panelContext.mounted) return;
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
    final theme = Theme.of(context);
    final normalizedDay = _toDateOnly(day);
    final selected = isSelected || _isSameDate(normalizedDay, selectedDate);
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
        key: Key(
            'highlights_calendar_day_${EpisodeCardUtils.formatDate(normalizedDay)}'),
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
        .read(selectedHighlightDateProvider.notifier)
        .setDate(normalizedSelected);
    await ref
        .read(highlightsProvider.notifier)
        .load(date: normalizedSelected, forceRefresh: true);
  }

  bool _isSameDate(DateTime? left, DateTime? right) {
    if (left == null || right == null) return false;
    final l = _toDateOnly(left);
    final r = _toDateOnly(right);
    return l.year == r.year && l.month == r.month && l.day == r.day;
  }

  DateTime _resolveInitialDate(DateTime? rawValue) {
    final now = _toDateOnly(DateTime.now());
    final minimum = DateTime(2000);
    final fallback = now.subtract(const Duration(days: 1));
    if (rawValue == null) return fallback;

    final normalized = _toDateOnly(rawValue);
    if (normalized.isAfter(now)) return now;
    if (normalized.isBefore(minimum)) return minimum;
    return normalized;
  }

  DateTime _toDateOnly(DateTime value) {
    final local = value.isUtc ? value.toLocal() : value;
    return DateTime(local.year, local.month, local.day);
  }
}
