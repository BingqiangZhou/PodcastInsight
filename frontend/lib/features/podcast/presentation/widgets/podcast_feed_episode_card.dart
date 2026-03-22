import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/app_localizations_extension.dart';
import '../../data/models/podcast_episode_model.dart';
import 'podcast_image_widget.dart';
import 'shared/episode_card_utils.dart';

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
    final compact = this.compact;
    final subscriptionBadgeBackgroundColor = theme.colorScheme.onSurfaceVariant;
    final subscriptionBadgeTextColor = theme.colorScheme.surface;
    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: 13,
    );
    final titleFontSize = titleStyle?.fontSize ?? 13;
    final titleLineHeightFactor = titleStyle?.height ?? 1.0;
    final coverSize = 2 * (titleFontSize * titleLineHeightFactor);
    final coverIconSize = (coverSize * 0.58).clamp(14.0, 28.0).toDouble();

    return Card(
      margin: compact
          ? const EdgeInsets.symmetric(horizontal: 4, vertical: 6)
          : null,
      shape: compact
          ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
          : null,
      child: InkWell(
        onTap: onOpenDetail,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderRow(l10n, theme, titleStyle, coverSize, coverIconSize),
              if (displayDescription.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  key: Key(
                    compact
                        ? 'podcast_feed_mobile_description'
                        : 'podcast_feed_desktop_description',
                  ),
                  displayDescription,
                  style:
                      (compact
                              ? theme.textTheme.bodyMedium
                              : theme.textTheme.bodySmall)
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  maxLines: compact ? 2 : 4,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
              ] else ...[
                const SizedBox(height: 4),
              ],
              _buildMetaActionRow(
                context,
                l10n,
                theme,
                subscriptionBadgeBackgroundColor,
                subscriptionBadgeTextColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderRow(
    AppLocalizations l10n,
    ThemeData theme,
    TextStyle? titleStyle,
    double coverSize,
    double coverIconSize,
  ) {
    final rowKey = compact
        ? const Key('podcast_feed_mobile_header_row')
        : const Key('podcast_feed_desktop_header_row');
    final playKey = compact
        ? const Key('podcast_feed_mobile_play')
        : const Key('podcast_feed_desktop_play');
    return Row(
      key: rowKey,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        compact
            ? Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onPlayAndOpenDetail,
                  borderRadius: BorderRadius.circular(8),
                  child: _buildCoverWidget(
                    theme,
                    coverSize,
                    coverIconSize,
                    key: const Key('podcast_feed_mobile_cover'),
                  ),
                ),
              )
            : _buildCoverWidget(theme, coverSize, coverIconSize),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: coverSize,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                episode.title,
                style: titleStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          key: playKey,
          tooltip: l10n.podcast_play,
          onPressed: onPlayAndOpenDetail,
          style: IconButton.styleFrom(
            minimumSize: const Size(28, 28),
            maximumSize: const Size(28, 28),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            foregroundColor: theme.colorScheme.onSurfaceVariant,
            shape: compact ? null : const CircleBorder(),
            side: compact
                ? null
                : BorderSide(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.65,
                    ),
                    width: 1,
                  ),
          ),
          icon: compact
              ? const Icon(Icons.play_circle_outline, size: 22)
              : const Icon(Icons.play_arrow, size: 18),
        ),
      ],
    );
  }

  Widget _buildCoverWidget(
    ThemeData theme,
    double coverSize,
    double coverIconSize, {
    Key? key,
  }) {
    return Container(
      key: key,
      width: coverSize,
      height: coverSize,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: PodcastImageWidget(
            imageUrl: episode.imageUrl ?? episode.subscriptionImageUrl,
            width: coverSize,
            height: coverSize,
            iconSize: coverIconSize,
            iconColor: theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }

  Widget _buildMetaActionRow(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    Color subscriptionBadgeBackgroundColor,
    Color subscriptionBadgeTextColor,
  ) {
    final rowKey = compact
        ? const Key('podcast_feed_mobile_meta_action_row')
        : const Key('podcast_feed_desktop_meta_action_row');
    final metadataKey = compact
        ? const Key('podcast_feed_mobile_metadata')
        : const Key('podcast_feed_desktop_metadata');
    final badgeKey = compact
        ? const Key('podcast_feed_mobile_subscription_badge')
        : const Key('podcast_feed_desktop_subscription_badge');
    final addQueueKey = compact
        ? const Key('podcast_feed_mobile_add_to_queue')
        : const Key('podcast_feed_desktop_add_to_queue');

    return Row(
      key: rowKey,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                key: metadataKey,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: compact ? 140 : 170),
                    child: Container(
                      key: badgeKey,
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 8 : 10,
                        vertical: compact ? 2 : 3,
                      ),
                      decoration: BoxDecoration(
                        color: subscriptionBadgeBackgroundColor,
                        borderRadius: BorderRadius.circular(compact ? 10 : 12),
                      ),
                      child: Text(
                        episode.subscriptionTitle ??
                            l10n.podcast_default_podcast,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: subscriptionBadgeTextColor,
                          fontWeight: FontWeight.bold,
                          fontSize: compact ? 10 : 11,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  EpisodeCardUtils.buildDateMetadata(
                    date: episode.publishedAt,
                    theme: theme,
                    spacing: compact ? 3 : 2,
                  ),
                  const SizedBox(width: 8),
                  EpisodeCardUtils.buildDurationMetadata(
                    formattedDuration: episode.formattedDuration,
                    theme: theme,
                    spacing: compact ? 3 : 2,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          key: addQueueKey,
          tooltip: isAddingToQueue
              ? l10n.podcast_adding
              : l10n.podcast_add_to_queue,
          onPressed: isAddingToQueue ? null : onAddToQueue,
          style: IconButton.styleFrom(
            minimumSize: const Size(28, 28),
            maximumSize: const Size(28, 28),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            foregroundColor: theme.colorScheme.onSurfaceVariant,
          ),
          icon: isAddingToQueue
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.playlist_add, size: 18),
        ),
      ],
    );
  }
}
