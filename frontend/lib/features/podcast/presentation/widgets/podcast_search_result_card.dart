import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/app_localizations_extension.dart';
import '../../data/models/podcast_search_model.dart';
import '../constants/podcast_ui_constants.dart';
import 'podcast_image_widget.dart';

class PodcastSearchResultCard extends StatelessWidget {
  const PodcastSearchResultCard({
    super.key,
    required this.result,
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
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cardHorizontalPadding =
        dense ? 8.0 : kPodcastRowCardHorizontalPadding;
    final cardVerticalPadding = dense ? 6.0 : kPodcastRowCardVerticalPadding;
    final cardVerticalMargin = dense ? 1.0 : kPodcastRowCardVerticalMargin;
    final imageSize = dense ? 52.0 : kPodcastRowCardImageSize;
    final horizontalGap = dense ? 10.0 : kPodcastRowCardHorizontalGap;

    if (result.collectionName == null || result.feedUrl == null) {
      return const SizedBox.shrink();
    }

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
        onTap: () => onSubscribe?.call(result),
        borderRadius: BorderRadius.circular(kPodcastRowCardCornerRadius),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: cardHorizontalPadding,
            vertical: cardVerticalPadding,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: imageSize,
            ),
            child: Row(
              children: [
                RepaintBoundary(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      kPodcastRowCardImageRadius,
                    ),
                    child: SizedBox(
                      key: const Key('podcast_search_result_card_artwork'),
                      width: imageSize,
                      height: imageSize,
                      child: PodcastImageWidget(
                        imageUrl: result.artworkUrl100,
                        width: imageSize,
                        height: imageSize,
                        iconSize: 24,
                        iconColor: theme.colorScheme.onPrimaryContainer,
                      ),
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
                        result.collectionName!,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        result.artistName ?? l10n.podcast_unknown_author,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (result.primaryGenreName != null) ...[
                            Icon(
                              Icons.category,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
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
                            const SizedBox(width: 8),
                          ],
                          Icon(
                            Icons.podcasts,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${result.trackCount ?? 0} ${l10n.podcast_episodes}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: animation, child: child),
                    );
                  },
                  child: _buildSubscribeButton(context, l10n, theme),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubscribeButton(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    if (isSubscribed) {
      return Tooltip(
        key: const ValueKey('subscribed'),
        message: l10n.podcast_subscribed,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            Icons.check_circle,
            color: theme.colorScheme.primary,
            size: 24,
          ),
        ),
      );
    }

    if (isSubscribing) {
      return const SizedBox(
        key: ValueKey('subscribing'),
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return Tooltip(
      key: const ValueKey('not_subscribed'),
      message: l10n.podcast_subscribe,
      child: IconButton(
        onPressed: () => onSubscribe?.call(result),
        icon: const Icon(Icons.add_circle_outline),
        iconSize: 24,
        color: theme.colorScheme.onSurfaceVariant,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      ),
    );
  }
}
