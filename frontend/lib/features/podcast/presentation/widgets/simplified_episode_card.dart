import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/constants/breakpoints.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/features/podcast/core/utils/episode_description_helper.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/shared/base_episode_card.dart';

/// Simplified episode card without podcast image and name (for episodes list page)
class SimplifiedEpisodeCard extends ConsumerWidget {

  const SimplifiedEpisodeCard({
    required this.episode, super.key,
    this.onTap,
    this.onPlay,
    this.onAddToQueue,
    this.isAddingToQueue = false,
  });
  final PodcastEpisodeModel episode;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final VoidCallback? onAddToQueue;
  final bool isAddingToQueue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile =
        MediaQuery.sizeOf(context).width < Breakpoints.medium;

    final displayDescription = EpisodeDescriptionHelper.getDisplayDescription(
      aiSummary: episode.aiSummary,
      description: episode.description,
    );

    return RepaintBoundary(
      key: ValueKey('simplified_episode_card_${episode.id}'),
      child: BaseEpisodeCard(
        config: EpisodeCardConfig(
          showImage: false,
          dense: isMobile,
          cardMargin: isMobile
              ? const EdgeInsets.symmetric(horizontal: 4, vertical: 6)
              : EdgeInsets.zero,
          showDate: true,
          date: episode.publishedAt,
          showDuration: true,
          formattedDuration: episode.formattedDuration,
          showDescription: displayDescription.isNotEmpty,
          description: displayDescription.isNotEmpty ? displayDescription : null,
          descriptionMaxLines: isMobile ? 2 : 4,
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
        ),
        title: episode.title,
        onTap: onTap,
        onPlay: onPlay,
        onAddToQueue: onAddToQueue,
        additionalMetadata: episode.aiSummary != null
            ? [
                Tooltip(
                  message: context.l10n.ai_summary_available,
                  child: Icon(
                    Icons.auto_awesome,
                    size: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ]
            : null,
      ),
    );
  }
}
