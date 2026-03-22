import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations_extension.dart';
import '../../../../core/utils/time_formatter.dart';
import '../../data/models/itunes_episode_lookup_model.dart';
import 'podcast_image_widget.dart';
import 'shared/episode_card_utils.dart';

class DiscoverEpisodeDetailSheet extends StatelessWidget {
  const DiscoverEpisodeDetailSheet({
    super.key,
    required this.episode,
    required this.onPlay,
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
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: PodcastImageWidget(
                    imageUrl: episode.artworkUrl600 ?? episode.artworkUrl100,
                    width: 64,
                    height: 64,
                    iconSize: 26,
                  ),
                ),
                const SizedBox(width: 10),
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
                      const SizedBox(height: 4),
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
                          const SizedBox(width: 6),
                          Align(
                            alignment: Alignment.center,
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
              const SizedBox(height: 10),
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
