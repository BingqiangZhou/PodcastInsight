import 'package:flutter/material.dart';

import '../../data/models/itunes_episode_lookup_model.dart';
import '../../../../core/utils/time_formatter.dart';
import '../constants/podcast_ui_constants.dart';
import 'podcast_image_widget.dart';
import 'shared/episode_card_utils.dart';

class PodcastEpisodeSearchResultCard extends StatelessWidget {
  const PodcastEpisodeSearchResultCard({
    super.key,
    required this.episode,
    this.onTap,
    this.onPlay,
    this.dense = false,
  });

  final ITunesPodcastEpisodeResult episode;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardHorizontalPadding =
        dense ? 8.0 : kPodcastRowCardHorizontalPadding;
    final cardVerticalPadding = dense ? 6.0 : kPodcastRowCardVerticalPadding;
    final cardVerticalMargin = dense ? 1.0 : kPodcastRowCardVerticalMargin;
    final imageSize = dense ? 52.0 : kPodcastRowCardImageSize;
    final horizontalGap = dense ? 10.0 : kPodcastRowCardHorizontalGap;

    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: kPodcastRowCardHorizontalMargin,
        vertical: cardVerticalMargin,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kPodcastRowCardCornerRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kPodcastRowCardCornerRadius),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: cardHorizontalPadding,
            vertical: cardVerticalPadding,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: imageSize),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(kPodcastRowCardImageRadius),
                  child: SizedBox(
                    key: const Key('podcast_episode_search_result_card_artwork'),
                    width: imageSize,
                    height: imageSize,
                    child: PodcastImageWidget(
                      imageUrl: episode.artworkUrl100 ?? episode.artworkUrl600,
                      width: imageSize,
                      height: imageSize,
                      iconSize: 24,
                      iconColor: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                SizedBox(width: horizontalGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        episode.trackName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        episode.collectionName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _buildMetaText(episode),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                if (onPlay != null)
                  IconButton(
                    onPressed: onPlay,
                    icon: const Icon(Icons.play_circle_outline),
                    iconSize: 26,
                    color: theme.colorScheme.onSurfaceVariant,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
              ],
            ),
          ),
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
