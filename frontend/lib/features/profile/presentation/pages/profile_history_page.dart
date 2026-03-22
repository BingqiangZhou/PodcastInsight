import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_ai_assistant/core/constants/breakpoints.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/utils/time_formatter.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/core/widgets/custom_adaptive_navigation.dart';
import 'package:personal_ai_assistant/shared/widgets/loading_widget.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/playback_history_lite_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/constants/podcast_ui_constants.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/podcast_image_widget.dart';

class ProfileHistoryPage extends ConsumerStatefulWidget {
  const ProfileHistoryPage({super.key});

  @override
  ConsumerState<ProfileHistoryPage> createState() => _ProfileHistoryPageState();
}

class _ProfileHistoryPageState extends ConsumerState<ProfileHistoryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(playbackHistoryLiteProvider.notifier).load(forceRefresh: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final historyAsync = ref.watch(playbackHistoryLiteProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Material(
        color: Colors.transparent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const AppPageBackdrop(),
            SafeArea(
              bottom: false,
              child: ResponsiveContainer(
                maxWidth: 1480,
                alignment: Alignment.topCenter,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderPanel(context, l10n),
                    const SizedBox(height: 12),
                    Expanded(
                      child: RefreshIndicator(
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
                                subtitle:
                                    'Resume episodes and review recently played content.',
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
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
                                        const SizedBox(height: 16),
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
                              borderRadius: appThemeOf(
                                context,
                              ).panelRadius,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      18,
                                      20,
                                      14,
                                    ),
                                    child: AppSectionHeader(
                                      title: l10n.profile_viewed_title,
                                      subtitle:
                                          '${episodes.length} recently played episodes',
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
                            subtitle:
                                'Resume episodes and review recently played content.',
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
                            subtitle:
                                'Resume episodes and review recently played content.',
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
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
                                    const SizedBox(height: 16),
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
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderPanel(BuildContext context, AppLocalizations l10n) {
    final isMobile = context.isMobile;
    return CompactHeaderPanel(
      title: l10n.profile_viewed_title,
      trailing: isMobile
          ? null
          : HeaderCapsuleActionButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: Icons.arrow_back_rounded,
              onPressed: () => context.pop(),
              circular: true,
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
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: AppSectionHeader(title: title, subtitle: subtitle),
          ),
          Expanded(child: Center(child: child)),
        ],
      );
    }

    return SurfacePanel(
      padding: EdgeInsets.zero,
      borderRadius: appThemeOf(context).panelRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
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
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kPodcastRowCardCornerRadius),
        side: BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/podcast/episode/detail/${episode.id}'),
        borderRadius: BorderRadius.circular(kPodcastRowCardCornerRadius),
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
                    kPodcastRowCardImageRadius,
                  ),
                  child: PodcastImageWidget(
                    imageUrl: episode.imageUrl,
                    fallbackImageUrl: episode.subscriptionImageUrl,
                    width: kPodcastRowCardImageSize,
                    height: kPodcastRowCardImageSize,
                    iconSize: 24,
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
                        height: 38,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            key: ValueKey(
                              'profile_history_title_${episode.id}',
                            ),
                            episode.title,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  height: 1.15,
                                ),
                            strutStyle: const StrutStyle(
                              fontSize: 13,
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
                        height: 18,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 110,
                                  ),
                                  child: Container(
                                    key: const Key(
                                      'profile_history_meta_podcast',
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      episode.subscriptionTitle ??
                                          AppLocalizations.of(
                                            context,
                                          )!.podcast_default_podcast,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: 13,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  _formatPlayedAt(episode.lastPlayedAt),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                        fontSize: 11,
                                      ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.schedule,
                                  size: 13,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  _buildProgressText(context, episode),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                        fontSize: 11,
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
    final l10n = AppLocalizations.of(context)!;
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final remainingSeconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return TimeFormatter.formatDuration(duration);
    }

    if (remainingSeconds > 0) {
      return TimeFormatter.formatDuration(duration);
    }

    return l10n.player_minutes(minutes);
  }
}
