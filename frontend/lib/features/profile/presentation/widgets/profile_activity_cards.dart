import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:personal_ai_assistant/core/constants/app_radius.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/constants/breakpoints.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/navigation/podcast_navigation.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/shared/episode_card_utils.dart';

class ProfileActivityCards extends ConsumerWidget {
  const ProfileActivityCards({super.key});

  EdgeInsetsGeometry _cardMargin(BuildContext context) {
    if (context.isMobile) {
      return EdgeInsets.symmetric(horizontal: context.spacing.xs);
    }
    return EdgeInsets.zero;
  }

  Widget _wrapIfTapable({
    required VoidCallback? onTap,
    required double borderRadius,
    required Widget child,
  }) {
    if (onTap == null) return child;
    return AdaptiveInkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(borderRadius),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isMobile = context.isMobile;
    final statsAsync = ref.watch(profileStatsProvider);
    final stats = statsAsync.maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );
    final isLoading = statsAsync.isLoading;

    final episodeCount = isLoading
        ? '...'
        : (stats?.totalEpisodes.toString() ?? '0');
    final summaryCount = isLoading
        ? '...'
        : (stats?.summariesGenerated.toString() ?? '0');
    final historyCount = isLoading
        ? '...'
        : (stats?.playedEpisodes.toString() ?? '0');
    final subscriptionCount = isLoading
        ? '...'
        : (stats?.totalSubscriptions.toString() ?? '0');
    final latestDailyReportDateText = _resolveLatestDailyReportDateText(
      stats?.latestDailyReportDate,
      isLoading: isLoading,
    );
    final highlightsCount = isLoading
        ? '...'
        : (stats?.totalHighlights.toString() ?? '0');

    if (isMobile) {
      final cards = _buildCardList(
        context,
        subscriptionCount: subscriptionCount,
        episodeCount: episodeCount,
        summaryCount: summaryCount,
        historyCount: historyCount,
        latestDailyReportDateText: latestDailyReportDateText,
        highlightsCount: highlightsCount,
        scheme: scheme,
      );
      return Column(
        children: cards
            .expand<Widget>(
              (card) => [card, SizedBox(height: context.spacing.smMd)],
            )
            .toList()
          ..removeLast(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final columns = maxWidth >= 1000 ? 4 : 2;
        final cardWidth = (maxWidth - (columns - 1) * context.spacing.lg) / columns;

        final cards = _buildCardList(
          context,
          subscriptionCount: subscriptionCount,
          episodeCount: episodeCount,
          summaryCount: summaryCount,
          historyCount: historyCount,
          latestDailyReportDateText: latestDailyReportDateText,
          highlightsCount: highlightsCount,
          scheme: scheme,
        );

        return Wrap(
          spacing: context.spacing.lg,
          runSpacing: context.spacing.lg,
          children: [
            for (final card in cards) SizedBox(width: cardWidth, child: card),
          ],
        );
      },
    );
  }

  List<Widget> _buildCardList(
    BuildContext context, {
    required String subscriptionCount,
    required String episodeCount,
    required String summaryCount,
    required String historyCount,
    required String latestDailyReportDateText,
    required String highlightsCount,
    required ColorScheme scheme,
  }) {
    final l10n = context.l10n;
    return [
      _buildActivityCard(
        context,
        icon: Icons.subscriptions_outlined,
        label: l10n.profile_subscriptions,
        value: subscriptionCount,
        color: scheme.secondary,
        onTap: () => context.push('/profile/subscriptions'),
        showChevron: true,
        cardKey: const Key('profile_subscriptions_card'),
      ),
      _buildActivityCard(
        context,
        icon: Icons.podcasts,
        label: l10n.podcast_episodes,
        value: episodeCount,
        color: scheme.secondary,
      ),
      _buildActivityCard(
        context,
        icon: Icons.auto_awesome,
        label: l10n.profile_ai_summary,
        value: summaryCount,
        color: scheme.secondary,
      ),
      _buildActivityCard(
        context,
        icon: Icons.history,
        label: l10n.profile_viewed_title,
        value: historyCount,
        color: scheme.secondary,
        onTap: () => context.push('/profile/history'),
        showChevron: true,
        chevronKey: const Key('profile_viewed_card_chevron'),
      ),
      _buildActivityCard(
        context,
        icon: Icons.summarize_outlined,
        label: l10n.podcast_daily_report_title,
        value: latestDailyReportDateText,
        color: scheme.secondary,
        onTap: () =>
            PodcastNavigation.goToDailyReport(context),
        showChevron: true,
        cardKey: const Key('profile_daily_report_card'),
      ),
      _buildActivityCard(
        context,
        icon: Icons.lightbulb_outline,
        label: l10n.podcast_highlights_title,
        value: highlightsCount,
        color: scheme.secondary,
        onTap: () => PodcastNavigation.goToHighlights(context),
        showChevron: true,
        cardKey: const Key('profile_highlights_card'),
      ),
    ];
  }

  Widget _buildActivityCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    VoidCallback? onTap,
    bool showChevron = false,
    Key? chevronKey,
    Key? cardKey,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final extension = appThemeOf(context);
    return Padding(
      key: cardKey,
      padding: _cardMargin(context),
      child: _wrapIfTapable(
        onTap: onTap,
        borderRadius: extension.cardRadius,
        child: SurfacePanel(
          borderRadius: extension.cardRadius,
          showBorder: false,
          child: Row(
            children: [
              Container(
                width: context.spacing.xl,
                height: context.spacing.xl,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: AppRadius.mdRadius,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              SizedBox(width: context.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: context.spacing.sm),
                    Text(
                      value,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              if (showChevron)
                Icon(
                  Icons.chevron_right,
                  key: chevronKey,
                  color: scheme.onSurfaceVariant,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _resolveLatestDailyReportDateText(
    String? latestDailyReportDate, {
    required bool isLoading,
  }) {
    if (isLoading) {
      return '--';
    }
    if (latestDailyReportDate == null || latestDailyReportDate.isEmpty) {
      return '--';
    }
    try {
      return EpisodeCardUtils.formatDate(DateTime.parse(latestDailyReportDate));
    } catch (e, stackTrace) {
      logger.AppLogger.debug(
        '[ProfileActivityCards] Failed to parse daily report date: $latestDailyReportDate, error: $e',
      );
      logger.AppLogger.debug('[ProfileActivityCards] Stack trace: $stackTrace');
      return '--';
    }
  }

}
