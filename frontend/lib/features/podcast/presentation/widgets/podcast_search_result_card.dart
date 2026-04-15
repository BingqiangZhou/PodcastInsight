import 'package:flutter/material.dart';

import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_search_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/constants/podcast_ui_constants.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/shared/base_episode_card.dart';

class PodcastSearchResultCard extends StatelessWidget {
  const PodcastSearchResultCard({
    required this.result, super.key,
    this.onSubscribe,
    this.isSubscribed = false,
    this.isSubscribing = false,
    this.searchCountry = PodcastCountry.china,
    this.dense = false,
  });

  final PodcastSearchResult result;
  final ValueChanged<PodcastSearchResult>? onSubscribe;
  final bool isSubscribed;
  final bool isSubscribing;
  final PodcastCountry searchCountry;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    if (result.collectionName == null || result.feedUrl == null) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cardHorizontalPadding =
        dense ? 8.0 : kPodcastRowCardHorizontalPadding;
    final cardVerticalPadding = dense ? 6.0 : kPodcastRowCardVerticalPadding;
    final cardVerticalMargin = dense ? 1.0 : kPodcastRowCardVerticalMargin;
    final imageSize = dense ? 52.0 : kPodcastRowCardImageSize;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        );
      },
      child: BaseEpisodeCard(
        key: ValueKey('podcast_search_result_${result.feedUrl}'),
        config: EpisodeCardConfig(
          imageUrl: result.artworkUrl100,
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
          showPlayButton: false,
          showSubscribeAction: true,
          isSubscribed: isSubscribed,
          isSubscribing: isSubscribing,
        ),
        title: result.collectionName!,
        subtitle: result.artistName ?? l10n.podcast_unknown_author,
        onTap: () => onSubscribe?.call(result),
        onSubscribe: () => onSubscribe?.call(result),
        additionalMetadata: _buildGenreMetadata(l10n, theme),
      ),
    );
  }

  List<Widget> _buildGenreMetadata(AppLocalizations l10n, ThemeData theme) {
    final widgets = <Widget>[];
    if (result.primaryGenreName != null) {
      widgets.addAll([
        const SizedBox(width: AppSpacing.sm),
        Icon(
          Icons.category,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            result.primaryGenreName!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]);
    }
    widgets.addAll([
      const SizedBox(width: AppSpacing.sm),
      Icon(
        Icons.podcasts,
        size: 14,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: AppSpacing.xs),
      Text(
        '${result.trackCount ?? 0} ${l10n.podcast_episodes}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ]);
    return widgets;
  }
}
