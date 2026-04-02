import 'package:flutter/material.dart';

import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/shared/base_episode_card.dart';

class PodcastFeedEpisodeCard extends StatelessWidget {
  const PodcastFeedEpisodeCard({
    super.key,
    required this.episode,
    required this.compact,
    required this.isAddingToQueue,
    required this.displayDescription,
    required this.onOpenDetail,
    required this.onPlayAndOpenDetail,
    required this.onAddToQueue,
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
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: 13,
    );
    final titleFontSize = titleStyle?.fontSize ?? 13;
    final titleLineHeightFactor = titleStyle?.height ?? 1.0;
    final coverSize = 2 * (titleFontSize * titleLineHeightFactor);
    final coverIconSize = (coverSize * 0.58).clamp(14.0, 28.0).toDouble();

    return BaseEpisodeCard(
      config: EpisodeCardConfig(
        showImage: true,
        imageUrl: episode.imageUrl ?? episode.subscriptionImageUrl,
        imageSize: coverSize,
        imageIconSize: coverIconSize,
        dense: compact,
        cardMargin: compact
            ? const EdgeInsets.symmetric(horizontal: 4, vertical: 6)
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
        showPlayButton: true,
        showQueueButton: true,
        isAddingToQueue: isAddingToQueue,
        showDownloadButton: true,
        episodeId: episode.id,
        audioUrl: episode.audioUrl,
        heroTag: 'episode_cover_${episode.id}',
      ),
      title: episode.title,
      onTap: onOpenDetail,
      onPlay: onPlayAndOpenDetail,
      onAddToQueue: onAddToQueue,
    );
  }
}
