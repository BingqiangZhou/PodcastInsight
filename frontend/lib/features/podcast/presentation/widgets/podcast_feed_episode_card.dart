import 'package:flutter/material.dart';

import 'package:personal_ai_assistant/core/constants/app_spacing.dart';

import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/shared/base_episode_card.dart';

class PodcastFeedEpisodeCard extends StatelessWidget {
  const PodcastFeedEpisodeCard({
    required this.episode, required this.compact, required this.isAddingToQueue, required this.displayDescription, required this.onOpenDetail, required this.onPlayAndOpenDetail, required this.onAddToQueue, super.key,
  });

  final PodcastEpisodeModel episode;
  final bool compact;
  final bool isAddingToQueue;
  final String displayDescription;
  final VoidCallback onOpenDetail;
  final VoidCallback onPlayAndOpenDetail;
  final VoidCallback onAddToQueue;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final titleFontSize = titleStyle?.fontSize ?? 13;
    final titleLineHeightFactor = titleStyle?.height ?? 1.0;
    final coverSize = 2 * (titleFontSize * titleLineHeightFactor);
    final coverIconSize = (coverSize * 0.58).clamp(14.0, 28.0);

    // Identity gradient colors (all gradients are now monochrome gray)
    final identityGradientColors = AppColors.podcastGradientColors.first;

    return BaseEpisodeCard(
      config: EpisodeCardConfig(
        imageUrl: episode.imageUrl ?? episode.subscriptionImageUrl,
        imageSize: coverSize,
        imageIconSize: coverIconSize,
        dense: compact,
        cardMargin: compact
            ? const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.sm)
            : null,
        showSubscriptionBadge: true,
        subscriptionBadgeText:
            episode.subscriptionTitle ?? l10n.podcast_default_podcast,
        showDate: true,
        date: episode.publishedAt,
        showDuration: true,
        formattedDuration: episode.formattedDuration,
        showDescription: displayDescription.isNotEmpty,
        description: displayDescription.isNotEmpty ? displayDescription : null,
        descriptionMaxLines: compact ? 2 : 4,
        showQueueButton: true,
        isAddingToQueue: isAddingToQueue,
        showDownloadButton: true,
        episodeId: episode.id,
        audioUrl: episode.audioUrl,
        episodeTitle: episode.title,
        subscriptionTitle: episode.subscriptionTitle,
        subscriptionImageUrl: episode.subscriptionImageUrl,
        subscriptionId: episode.subscriptionId,
        audioDuration: episode.audioDuration,
        publishedAt: episode.publishedAt,
        heroTag: 'episode_cover_${episode.id}',
        useGradientIdentityBar: true,
        identityGradientColors: identityGradientColors,
      ),
      title: episode.title,
      onTap: onOpenDetail,
      onPlay: onPlayAndOpenDetail,
      onAddToQueue: onAddToQueue,
      additionalMetadata: episode.aiSummary != null
          ? [
              Tooltip(
                message: l10n.ai_summary_available,
                child: Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
              ),
            ]
          : null,
    );
  }
}
