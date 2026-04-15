import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:personal_ai_assistant/core/constants/app_radius.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/constants/breakpoints.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/navigation/podcast_navigation.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/shared/episode_card_utils.dart';

class ProfileActivityCards extends ConsumerWidget {
  const ProfileActivityCards({super.key});

  EdgeInsetsGeometry _cardMargin(BuildContext context) {
    if (context.isMobile) {
      return const EdgeInsets.symmetric(horizontal: AppSpacing.xs);
    }
    return EdgeInsets.zero;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
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
      return Column(
        children: [
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
          const SizedBox(height: AppSpacing.md),
          _buildActivityCard(
            context,
            icon: Icons.podcasts,
            label: l10n.podcast_episodes,
            value: episodeCount,
            color: scheme.secondary,
          ),
          const SizedBox(height: AppSpacing.md),
          _buildActivityCard(
            context,
            icon: Icons.auto_awesome,
            label: l10n.profile_ai_summary,
            value: summaryCount,
            color: scheme.secondary,
          ),
          const SizedBox(height: AppSpacing.md),
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
          const SizedBox(height: AppSpacing.md),
          _buildActivityCard(
            context,
            icon: Icons.summarize_outlined,
            label: l10n.podcast_daily_report_title,
            value: latestDailyReportDateText,
            color: scheme.secondary,
            onTap: () =>
                PodcastNavigation.goToDailyReport(context, source: 'profile'),
            showChevron: true,
            cardKey: const Key('profile_daily_report_card'),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildActivityCard(
            context,
            icon: Icons.lightbulb_outline,
            label: l10n.podcast_highlights_title,
            value: highlightsCount,
            color: scheme.secondary,
            onTap: () => PodcastNavigation.goToHighlights(context, source: 'profile'),
            showChevron: true,
            cardKey: const Key('profile_highlights_card'),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final columns = maxWidth >= 1000 ? 4 : 2;
        final cardWidth = (maxWidth - (columns - 1) * AppSpacing.lg) / columns;

        final cards = <Widget>[
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
                PodcastNavigation.goToDailyReport(context, source: 'profile'),
            showChevron: true,
            cardKey: const Key('profile_daily_report_card'),
          ),
          _buildActivityCard(
            context,
            icon: Icons.lightbulb_outline,
            label: l10n.podcast_highlights_title,
            value: highlightsCount,
            color: scheme.secondary,
            onTap: () => PodcastNavigation.goToHighlights(context, source: 'profile'),
            showChevron: true,
            cardKey: const Key('profile_highlights_card'),
          ),
        ];

        return Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.lg,
          children: [
            for (final card in cards) SizedBox(width: cardWidth, child: card),
          ],
        );
      },
    );
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(extension.cardRadius),
        child: SurfacePanel(
          borderRadius: extension.cardRadius,
          showBorder: false,
          child: Row(
            children: [
              Container(
                width: AppSpacing.xl,
                height: AppSpacing.xl,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: AppRadius.mdRadius,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
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
                    const SizedBox(height: AppSpacing.sm),
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
