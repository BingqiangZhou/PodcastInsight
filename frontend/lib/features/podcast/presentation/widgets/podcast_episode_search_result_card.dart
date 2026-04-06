import 'package:flutter/material.dart';
import 'package:personal_ai_assistant/core/utils/time_formatter.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/itunes_episode_lookup_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/constants/podcast_ui_constants.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/shared/base_episode_card.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/shared/episode_card_utils.dart';

class PodcastEpisodeSearchResultCard extends StatelessWidget {
  const PodcastEpisodeSearchResultCard({
    required this.episode, super.key,
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
    final cardHorizontalPadding =
        dense ? 8.0 : kPodcastRowCardHorizontalPadding;
    final cardVerticalPadding = dense ? 6.0 : kPodcastRowCardVerticalPadding;
    final cardVerticalMargin = dense ? 1.0 : kPodcastRowCardVerticalMargin;
    final imageSize = dense ? 52.0 : kPodcastRowCardImageSize;

    return BaseEpisodeCard(
      config: EpisodeCardConfig(
        imageUrl: episode.artworkUrl100 ?? episode.artworkUrl600,
        imageSize: imageSize,
        dense: dense,
        cardMargin: EdgeInsets.symmetric(
          horizontal: kPodcastRowCardHorizontalMargin,
          vertical: cardVerticalMargin,
        ),
        cardPadding: EdgeInsets.symmetric(
          horizontal: cardHorizontalPadding,
          vertical: cardVerticalPadding,
        ),
        cornerRadius: kPodcastRowCardCornerRadius,
        titleMaxLines: 1,
        showPlayButton: onPlay != null,
      ),
      title: episode.trackName,
      subtitle: episode.collectionName,
      subtitle2: _buildMetaText(episode),
      onTap: onTap,
      onPlay: onPlay,
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
    return parts.join(' \u00b7 ');
  }
}
