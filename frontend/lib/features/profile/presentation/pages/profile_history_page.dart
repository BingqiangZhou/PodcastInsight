import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_ai_assistant/core/constants/app_radius.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/theme/app_theme.dart';
import 'package:personal_ai_assistant/core/utils/time_formatter.dart';
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive_sliver_app_bar.dart';
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/core/widgets/custom_adaptive_navigation.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/playback_history_lite_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/constants/podcast_ui_constants.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/podcast_image_widget.dart';
import 'package:personal_ai_assistant/shared/widgets/loading_widget.dart';

class ProfileHistoryPage extends ConsumerStatefulWidget {
  const ProfileHistoryPage({super.key});

  @override
  ConsumerState<ProfileHistoryPage> createState() => _ProfileHistoryPageState();
}

class _ProfileHistoryPageState extends ConsumerState<ProfileHistoryPage> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final historyAsync = ref.watch(playbackHistoryLiteProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Material(
        color: Colors.transparent,
        child: ResponsiveContainer(
          maxWidth: 1480,
          alignment: Alignment.topCenter,
          child: CustomScrollView(
            slivers: [
              AdaptiveSliverAppBar(
                title: l10n.profile_viewed_title,
              ),
              SliverToBoxAdapter(
                child: SizedBox(height: context.spacing.smMd),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: AdaptiveRefreshIndicator(
                  onRefresh: () => ref
                      .read(playbackHistoryLiteProvider.notifier)
                      .load(forceRefresh: true),
                  child: historyAsync.when(
                    data: (response) {
                      final episodes =
                          response?.episodes ??
                          const <PlaybackHistoryLiteItem>[];

                      if (episodes.isEmpty) {
                        return _buildPanelScaffold(
                          context,
                          title: l10n.profile_viewed_title,
                          subtitle: l10n.profile_history_subtitle,
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(context.spacing.lg),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.history,
                                    size: 56,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                  SizedBox(height: context.spacing.lg),
                                  Text(
                                    l10n.server_history_empty,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      return SurfacePanel(
                        padding: EdgeInsets.zero,
                        showBorder: false,
                        borderRadius: appThemeOf(
                          context,
                        ).cardRadius,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                context.spacing.mdLg,
                                context.spacing.mdLg,
                                context.spacing.mdLg,
                                context.spacing.smMd,
                              ),
                              child: AppSectionHeader(
                                title: l10n.profile_viewed_title,
                                subtitle:
                                    l10n.profile_history_episode_count(episodes.length),
                                hideTitle: true,
                              ),
                            ),
                            Divider(
                              height: 1,
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant
                                  .withValues(alpha: 0.45),
                            ),
                            Expanded(
                              child: ListView.builder(
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.zero,
                                itemCount: episodes.length,
                                itemBuilder: (context, index) {
                                  final episode = episodes[index];
                                  return _buildHistoryCard(
                                    context,
                                    episode,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    loading: () => _buildPanelScaffold(
                      context,
                      title: l10n.profile_viewed_title,
                      subtitle: l10n.profile_history_subtitle,
                      child: LoadingStatusContent(
                        key: const Key('profile_history_loading_content'),
                        title: l10n.loading,
                        spinnerSize: 28,
                        gapAfterSpinner: 12,
                      ),
                      bare: true,
                    ),
                    error: (error, _) => _buildPanelScaffold(
                      context,
                      title: l10n.profile_viewed_title,
                      subtitle: l10n.profile_history_subtitle,
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(context.spacing.lg),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 56,
                                color: Theme.of(
                                  context,
                                ).colorScheme.error,
                              ),
                              SizedBox(height: context.spacing.lg),
                              Text(
                                error.toString(),
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
      );
  }

  Widget _buildPanelScaffold(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Widget child,
    bool bare = false,
  }) {
    if (bare) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(context.spacing.mdLg, context.spacing.mdLg, context.spacing.mdLg, context.spacing.smMd),
            child: AppSectionHeader(title: title, subtitle: subtitle),
          ),
          Expanded(child: Center(child: child)),
        ],
      );
    }

    return SurfacePanel(
      padding: EdgeInsets.zero,
      showBorder: false,
      borderRadius: appThemeOf(context).cardRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(context.spacing.mdLg, context.spacing.mdLg, context.spacing.mdLg, context.spacing.smMd),
            child: AppSectionHeader(title: title, subtitle: subtitle),
          ),
          Divider(
            height: 1,
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(
    BuildContext context,
    PlaybackHistoryLiteItem episode,
  ) {
    return RepaintBoundary(
      key: ValueKey('history_card_${episode.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.itemValue),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.15)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.push('/podcast/episode/detail/${episode.id}'),
            borderRadius: BorderRadius.circular(AppRadius.itemValue),
            child: SizedBox(
              key: ValueKey('profile_history_card_content_${episode.id}'),
              height: kPodcastRowCardTargetHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: kPodcastRowCardHorizontalPadding,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(
                        AppRadius.itemValue,
                      ),
                      child: PodcastImageWidget(
                        imageUrl: episode.imageUrl,
                        fallbackImageUrl: episode.subscriptionImageUrl,
                        width: kPodcastRowCardImageSize,
                        height: kPodcastRowCardImageSize,
                        iconSize: context.spacing.lg,
                        iconColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: kPodcastRowCardHorizontalGap),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            key: ValueKey(
                              'profile_history_title_box_${episode.id}',
                            ),
                            height: context.spacing.mdLg + context.spacing.md + context.spacing.xs,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                key: ValueKey(
                                  'profile_history_title_${episode.id}',
                                ),
                                episode.title,
                                style: AppTheme.caption(
                                      Theme.of(context).colorScheme.onSurface,
                                    ).copyWith(
                                      fontWeight: FontWeight.w700,
                                      height: 1.15,
                                    ),
                                strutStyle: StrutStyle(
                                  fontSize: Theme.of(context).textTheme.bodySmall?.fontSize ?? 13,
                                  height: 1.15,
                                  forceStrutHeight: true,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          SizedBox(
                            key: const Key('profile_history_meta_row'),
                            height: context.spacing.mdLg,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 110,
                                      ),
                                      child: Container(
                                        key: const Key(
                                          'profile_history_meta_podcast',
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: context.spacing.sm,
                                          vertical: context.spacing.xs,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          borderRadius: AppRadius.mdRadius,
                                        ),
                                        child: Text(
                                          episode.subscriptionTitle ??
                                              AppLocalizations.of(
                                                context,
                                              )!.podcast_default_podcast,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTheme.navLabel(
                                                Theme.of(context)
                                                    .colorScheme
                                                    .onPrimary,
                                                weight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: context.spacing.sm),
                                    Icon(
                                      Icons.calendar_today_outlined,
                                      size: 13,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                    SizedBox(width: context.spacing.xs),
                                    Text(
                                      _formatPlayedAt(episode.lastPlayedAt),
                                      style: AppTheme.metaSmall(
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                    SizedBox(width: context.spacing.sm),
                                    Icon(
                                      Icons.schedule,
                                      size: 13,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                    SizedBox(width: context.spacing.xs),
                                    Text(
                                      _buildProgressText(context, episode),
                                      style: AppTheme.metaSmall(
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatPlayedAt(DateTime? lastPlayedAt) => lastPlayedAt == null
      ? '--'
      : TimeFormatter.formatFullDateTime(lastPlayedAt);

  String _buildProgressText(
    BuildContext context,
    PlaybackHistoryLiteItem episode,
  ) {
    final position = episode.playbackPosition ?? 0;
    final totalDuration = episode.audioDuration != null
        ? episode.formattedDuration
        : '--:--';
    return '${_formatPlaybackPosition(context, position)} / $totalDuration';
  }

  String _formatPlaybackPosition(BuildContext context, int seconds) {
    final l10n = context.l10n;
    final duration = Duration(seconds: seconds);
    final minutes = duration.inMinutes.remainder(60);
    final remainingSeconds = duration.inSeconds.remainder(60);

    if (duration.inHours > 0 || remainingSeconds > 0) {
      return TimeFormatter.formatDuration(duration);
    }

    return l10n.player_minutes(minutes);
  }
}
