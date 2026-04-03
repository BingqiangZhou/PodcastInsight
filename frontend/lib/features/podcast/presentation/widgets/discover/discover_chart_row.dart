import 'package:flutter/material.dart';

import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_discover_chart_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/podcast_image_widget.dart';

/// Chart row widget for displaying a single discover item with rank and actions
class DiscoverChartRow extends StatelessWidget {
  const DiscoverChartRow({
    super.key,
    required this.rank,
    required this.item,
    required this.onTap,
    required this.onSubscribe,
    required this.onPlay,
    this.isSubscribing = false,
    this.isSubscribed = false,
    this.isDense = false,
  });

  final int rank;
  final PodcastDiscoverItem item;
  final VoidCallback onTap;
  final VoidCallback onSubscribe;
  final VoidCallback onPlay;
  final bool isSubscribing;
  final bool isSubscribed;
  final bool isDense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final extension = appThemeOf(context);
    final showSubscribe = item.isPodcastShow;
    final rankLabel = '$rank';
    final rankSlotWidth = isDense ? 44.0 : 48.0;
    final actionSlotWidth = rankSlotWidth;
    final rowOuterPadding = isDense ? 3.0 : 6.0;
    final rowInnerPadding = isDense ? 4.0 : 6.0;
    final imageSize = isDense ? 56.0 : 62.0;
    final titleStyle =
        (isDense ? theme.textTheme.titleSmall : theme.textTheme.titleMedium)
            ?.copyWith(fontWeight: FontWeight.w700);
    final subtitleStyle =
        (isDense ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium)
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    return Padding(
      key: Key('podcast_discover_chart_row_${item.itemId}'),
      padding: EdgeInsets.symmetric(vertical: rowOuterPadding),
      child: InkWell(
        borderRadius: BorderRadius.circular(extension.cardRadius),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: rank <= 3
                ? scheme.primary.withValues(alpha: rank == 1 ? 0.08 : 0.04)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(extension.cardRadius),
          ),
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: rowInnerPadding),
            child: Row(
              children: [
                SizedBox(
                  width: rankSlotWidth,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        key: Key('podcast_discover_chart_rank_text_${item.itemId}'),
                        rankLabel,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: rank == 1
                              ? AppColors.accentWarm
                              : rank <= 3
                                  ? scheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: isDense ? 4 : 6),
                RepaintBoundary(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(extension.inputRadius),
                    child: PodcastImageWidget(
                      imageUrl: item.artworkUrl,
                      width: imageSize,
                      height: imageSize,
                      iconSize: 24,
                    ),
                  ),
                ),
                SizedBox(width: isDense ? 10 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: subtitleStyle,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: isDense ? 6 : 8),
                if (showSubscribe)
                  SizedBox(
                    width: actionSlotWidth,
                    child: Center(
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: isSubscribing
                            ? const Padding(
                                padding: EdgeInsets.all(8),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : IconButton(
                                key: Key('podcast_discover_subscribe_${item.itemId}'),
                                onPressed: isSubscribed ? null : onSubscribe,
                                style: IconButton.styleFrom(
                                  minimumSize: const Size(36, 36),
                                  maximumSize: const Size(36, 36),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                ),
                                icon: Icon(
                                  isSubscribed
                                      ? Icons.check_circle
                                      : Icons.add_circle_outline,
                                ),
                              ),
                      ),
                    ),
                  ),
                if (!showSubscribe)
                  SizedBox(
                    width: actionSlotWidth,
                    child: Center(
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: IconButton(
                          key: Key('podcast_discover_play_${item.itemId}'),
                          onPressed: onPlay,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(36, 36),
                            maximumSize: const Size(36, 36),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            foregroundColor: theme.colorScheme.onSurfaceVariant,
                          ),
                          icon: const Icon(Icons.play_circle_outline, size: 24),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
