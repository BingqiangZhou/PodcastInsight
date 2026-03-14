import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/breakpoints.dart';
import '../../data/models/podcast_episode_model.dart';
import '../../core/utils/episode_description_helper.dart';
import '../../../../core/localization/app_localizations.dart';
import 'shared/episode_card_utils.dart';

/// Simplified episode card without podcast image and name (for episodes list page)
class SimplifiedEpisodeCard extends ConsumerWidget {
  final PodcastEpisodeModel episode;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final VoidCallback? onAddToQueue;
  final bool isAddingToQueue;

  const SimplifiedEpisodeCard({
    super.key,
    required this.episode,
    this.onTap,
    this.onPlay,
    this.onAddToQueue,
    this.isAddingToQueue = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isMobile =
        MediaQuery.of(context).size.width < AppBreakpoints.medium;
    final titleTextStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      fontSize: 13,
    );
    final titleLineHeight =
        (titleTextStyle?.fontSize ?? 13) * (titleTextStyle?.height ?? 1.25);
    final titleSlotHeight = titleLineHeight * 2;

    final displayDescription = EpisodeDescriptionHelper.getDisplayDescription(
      aiSummary: episode.aiSummary,
      description: episode.description,
    );

    return Card(
      margin: isMobile
          ? const EdgeInsets.symmetric(horizontal: 4, vertical: 6)
          : EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                key: const Key('simplified_episode_header_row'),
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: SizedBox(
                      height: titleSlotHeight,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          episode.title,
                          style: titleTextStyle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    key: const Key('simplified_episode_play'),
                    tooltip: l10n.podcast_play,
                    onPressed: onPlay,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(28, 28),
                      maximumSize: const Size(28, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      foregroundColor: theme.colorScheme.onSurfaceVariant,
                    ),
                    icon: const Icon(Icons.play_circle_outline, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (displayDescription.isNotEmpty) ...[
                Text(
                  key: const Key('simplified_episode_description'),
                  displayDescription,
                  style: isMobile
                      ? theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        )
                      : theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                  maxLines: isMobile ? 2 : 4,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
              ] else ...[
                const SizedBox(height: 4),
              ],
              Row(
                key: const Key('simplified_episode_meta_action_row'),
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          key: const Key('simplified_episode_metadata'),
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            EpisodeCardUtils.buildDateMetadata(
                              date: episode.publishedAt,
                              theme: theme,
                            ),
                            const SizedBox(width: 8),
                            EpisodeCardUtils.buildDurationMetadata(
                              formattedDuration: episode.formattedDuration,
                              theme: theme,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    key: const Key('simplified_episode_add_to_queue'),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
