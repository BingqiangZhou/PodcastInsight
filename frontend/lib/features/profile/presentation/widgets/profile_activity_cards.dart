import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/app_shells.dart';
import '../../../podcast/presentation/navigation/podcast_navigation.dart';
import '../../../podcast/presentation/providers/podcast_providers.dart';

class ProfileActivityCards extends ConsumerWidget {
  const ProfileActivityCards({super.key});

  bool _isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  EdgeInsetsGeometry _cardMargin(BuildContext context) {
    if (_isMobile(context)) {
      return const EdgeInsets.symmetric(horizontal: 4);
    }
    return EdgeInsets.zero;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isMobile = _isMobile(context);
    final statsAsync = ref.watch(profileStatsProvider);

    final episodeCount = statsAsync.when(
      data: (stats) => stats?.totalEpisodes.toString() ?? '0',
      loading: () => '...',
      error: (error, stackTrace) => '0',
    );
    final summaryCount = statsAsync.when(
      data: (stats) => stats?.summariesGenerated.toString() ?? '0',
      loading: () => '...',
      error: (error, stackTrace) => '0',
    );
    final historyCount = statsAsync.when(
      data: (stats) => stats?.playedEpisodes.toString() ?? '0',
      loading: () => '...',
      error: (error, stackTrace) => '0',
    );
    final subscriptionCount = statsAsync.when(
      data: (stats) => stats?.totalSubscriptions.toString() ?? '0',
      loading: () => '...',
      error: (error, stackTrace) => '0',
    );
    final latestDailyReportDateText = statsAsync.when(
      data: (stats) {
        if (stats?.latestDailyReportDate == null) {
          return '--';
        }
        try {
          final date = DateTime.parse(stats!.latestDailyReportDate!);
          return _formatDateOnly(date);
        } catch (_) {
          return '--';
        }
      },
      loading: () => '--',
      error: (error, stackTrace) => '--',
    );

    if (isMobile) {
      return Column(
        children: [
          _buildActivityCard(
            context,
            icon: Icons.subscriptions_outlined,
            label: l10n.profile_subscriptions,
            value: subscriptionCount,
            color: Theme.of(context).colorScheme.primary,
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
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          _buildActivityCard(
            context,
            icon: Icons.auto_awesome,
            label: l10n.profile_ai_summary,
            value: summaryCount,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          _buildActivityCard(
            context,
            icon: Icons.history,
            label: l10n.profile_viewed_title,
            value: historyCount,
            color: Theme.of(context).colorScheme.secondary,
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
            color: Theme.of(context).colorScheme.primary,
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
            color: Theme.of(context).colorScheme.primary,
            onTap: () => context.push('/profile/subscriptions'),
            showChevron: true,
            cardKey: const Key('profile_subscriptions_card'),
          ),
          _buildActivityCard(
            context,
            icon: Icons.podcasts,
            label: l10n.podcast_episodes,
            value: episodeCount,
            color: Theme.of(context).colorScheme.primary,
          ),
          _buildActivityCard(
            context,
            icon: Icons.auto_awesome,
            label: l10n.profile_ai_summary,
            value: summaryCount,
            color: Theme.of(context).colorScheme.primary,
          ),
          _buildActivityCard(
            context,
            icon: Icons.history,
            label: l10n.profile_viewed_title,
            value: historyCount,
            color: Theme.of(context).colorScheme.secondary,
            onTap: () => context.push('/profile/history'),
            showChevron: true,
            chevronKey: const Key('profile_viewed_card_chevron'),
          ),
          _buildActivityCard(
            context,
            icon: Icons.summarize_outlined,
            label: l10n.podcast_daily_report_title,
            value: latestDailyReportDateText,
            color: Theme.of(context).colorScheme.primary,
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
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              if (showChevron)
                Icon(
                  Icons.chevron_right,
                  key: chevronKey,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _resolveActivityIconColor(BuildContext context) {
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  String _formatDateOnly(DateTime value) {
    final local = value.isUtc ? value.toLocal() : value;
    return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}
