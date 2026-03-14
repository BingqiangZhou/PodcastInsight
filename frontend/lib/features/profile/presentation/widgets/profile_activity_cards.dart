import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/breakpoints.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/app_shells.dart';
import '../../../podcast/presentation/navigation/podcast_navigation.dart';
import '../../../podcast/presentation/providers/podcast_providers.dart';

class ProfileActivityCards extends ConsumerWidget {
  const ProfileActivityCards({super.key});

  EdgeInsetsGeometry _cardMargin(BuildContext context) {
    if (context.isMobile) {
      return const EdgeInsets.symmetric(horizontal: 4);
    }
    return EdgeInsets.zero;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
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

    if (isMobile) {
      return Column(
        children: [
          _buildActivityCard(
            context,
            icon: Icons.subscriptions_outlined,
            label: l10n.profile_subscriptions,
            value: subscriptionCount,
            color: scheme.primary,
            onTap: () => context.push('/profile/subscriptions'),
            showChevron: true,
            cardKey: const Key('profile_subscriptions_card'),
          ),
          const SizedBox(height: 12),
          _buildActivityCard(
            context,
            icon: Icons.podcasts,
            label: l10n.podcast_episodes,
            value: episodeCount,
            color: scheme.primary,
          ),
          const SizedBox(height: 12),
          _buildActivityCard(
            context,
            icon: Icons.auto_awesome,
            label: l10n.profile_ai_summary,
            value: summaryCount,
            color: scheme.primary,
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),
          _buildActivityCard(
            context,
            icon: Icons.summarize_outlined,
            label: l10n.podcast_daily_report_title,
            value: latestDailyReportDateText,
            color: scheme.primary,
            onTap: () =>
                PodcastNavigation.goToDailyReport(context, source: 'profile'),
            showChevron: true,
            cardKey: const Key('profile_daily_report_card'),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final columns = maxWidth >= 1000 ? 4 : 2;
        final cardWidth = (maxWidth - (columns - 1) * 16) / columns;

        final cards = <Widget>[
          _buildActivityCard(
            context,
            icon: Icons.subscriptions_outlined,
            label: l10n.profile_subscriptions,
            value: subscriptionCount,
            color: scheme.primary,
            onTap: () => context.push('/profile/subscriptions'),
            showChevron: true,
            cardKey: const Key('profile_subscriptions_card'),
          ),
          _buildActivityCard(
            context,
            icon: Icons.podcasts,
            label: l10n.podcast_episodes,
            value: episodeCount,
            color: scheme.primary,
          ),
          _buildActivityCard(
            context,
            icon: Icons.auto_awesome,
            label: l10n.profile_ai_summary,
            value: summaryCount,
            color: scheme.primary,
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
            color: scheme.primary,
            onTap: () =>
                PodcastNavigation.goToDailyReport(context, source: 'profile'),
            showChevron: true,
            cardKey: const Key('profile_daily_report_card'),
          ),
        ];

        return Wrap(
          spacing: 16,
          runSpacing: 16,
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
    final effectiveIconColor = _resolveActivityIconColor(context);
    return Padding(
      key: cardKey,
      padding: _cardMargin(context),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: GlassPanel(
          borderRadius: 20,
          showHighlight: false,
          child: Row(
            children: [
              Icon(icon, color: effectiveIconColor, size: 24),
              const SizedBox(width: 12),
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
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
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
      return _formatDateOnly(DateTime.parse(latestDailyReportDate));
    } catch (_) {
      return '--';
    }
  }

  Color _resolveActivityIconColor(BuildContext context) {
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  String _formatDateOnly(DateTime value) {
    final local = value.isUtc ? value.toLocal() : value;
    return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}
