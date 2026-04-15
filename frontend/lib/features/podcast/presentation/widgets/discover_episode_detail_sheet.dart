import 'package:flutter/material.dart';

import 'package:personal_ai_assistant/core/constants/app_spacing.dart';

import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/utils/time_formatter.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/itunes_episode_lookup_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/podcast_image_widget.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/shared/episode_card_utils.dart';

class DiscoverEpisodeDetailSheet extends StatelessWidget {
  const DiscoverEpisodeDetailSheet({
    required this.episode, required this.onPlay, super.key,
  });

  final ITunesPodcastEpisodeResult episode;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final description = episode.description?.trim().isNotEmpty == true
        ? episode.description!
        : (episode.shortDescription ?? '');

    return SafeArea(
      child: SingleChildScrollView(
        key: const Key('discover_episode_detail_sheet'),
        padding: const EdgeInsets.fromLTRB(AppSpacing.smMd, AppSpacing.smMd, AppSpacing.smMd, AppSpacing.smMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RepaintBoundary(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(appThemeOf(context).itemRadius),
                    child: PodcastImageWidget(
                      imageUrl: episode.artworkUrl600 ?? episode.artworkUrl100,
                      width: 64,
                      height: 64,
                      iconSize: 26,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.smMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        episode.trackName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  episode.collectionName,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    height: 1.15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _buildMetaText(episode),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    height: 1.15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Align(
                            child: IconButton(
                              key: const Key('discover_episode_detail_play_button'),
                              tooltip: l10n.podcast_play,
                              onPressed: onPlay,
                              style: IconButton.styleFrom(
                                minimumSize: const Size(36, 36),
                                maximumSize: const Size(36, 36),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                foregroundColor: theme.colorScheme.onSurfaceVariant,
                              ),
                              icon: const Icon(Icons.play_circle_outline, size: 32),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.smMd),
              Text(description, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }

  String _buildMetaText(ITunesPodcastEpisodeResult episode) {
    final parts = <String>[];
    if (episode.releaseDate != null) {
      parts.add(EpisodeCardUtils.formatDate(episode.releaseDate!));
    }
    if (episode.trackTimeMillis != null && episode.trackTimeMillis! > 0) {
      parts.add(
        TimeFormatter.formatDuration(
          Duration(milliseconds: episode.trackTimeMillis!),
        ),
      );
    }
    return parts.join(' · ');
  }
}
