import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../data/models/itunes_episode_lookup_model.dart';
import '../../data/models/podcast_episode_model.dart';
import 'simplified_episode_card.dart';

class DiscoverShowEpisodesSheet extends StatelessWidget {
  const DiscoverShowEpisodesSheet({
    super.key,
    required this.showId,
    required this.showTitle,
    required this.episodes,
    required this.onEpisodeSelected,
    required this.onPlayEpisode,
  });

  final int showId;
  final String showTitle;
  final List<ITunesPodcastEpisodeResult> episodes;
  final void Function(ITunesPodcastEpisodeResult episode) onEpisodeSelected;
  final void Function(ITunesPodcastEpisodeResult episode) onPlayEpisode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final now = DateTime.now();

    return SafeArea(
      child: Padding(
        key: const Key('discover_show_episodes_sheet'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              showTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              '${episodes.length} ${l10n.podcast_episodes}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: episodes.isEmpty
                  ? Center(
                      child: Text(
                        l10n.podcast_no_episodes_found,
                        style: theme.textTheme.bodyMedium,
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: episodes.length,
                      itemBuilder: (context, index) {
                        final episode = episodes[index];
                        final discoverEpisode = PodcastEpisodeModel(
                          id: episode.trackId,
                          subscriptionId: 0,
                          title: episode.trackName,
                          subscriptionTitle: episode.collectionName,
                          description:
                              episode.description ??
                              episode.shortDescription ??
                              '',
                          audioUrl: episode.resolvedAudioUrl ?? '',
                          audioDuration: episode.trackTimeMillis == null
                              ? null
                              : (episode.trackTimeMillis! / 1000).round(),
                          publishedAt: episode.releaseDate ?? now,
                          imageUrl:
                              episode.artworkUrl600 ?? episode.artworkUrl100,
                          itemLink: episode.trackViewUrl,
                          metadata: {
                            'discover_preview': true,
                            'source': 'top_charts',
                            'show_id': showId,
                            'track_id': episode.trackId,
                          },
                          createdAt: now,
                        );

                        return SimplifiedEpisodeCard(
                          episode: discoverEpisode,
                          onTap: () => onEpisodeSelected(episode),
                          onPlay: () => onPlayEpisode(episode),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
