import 'package:flutter/material.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive.dart';

import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_discover_chart_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/podcast_image_widget.dart';

/// Chart row widget for displaying a single discover item with rank and actions.
///
/// Uses card-style container matching [BaseEpisodeCard] visual pattern:
/// `surfaceContainerLow` background, outline border, corner radius,
/// and optional identity gradient bar for top-3 ranked items.
class DiscoverChartRow extends StatelessWidget {
  const DiscoverChartRow({
    required this.rank,
    required this.item,
    required this.onTap,
    required this.onSubscribe,
    required this.onPlay,
    super.key,
    this.isSubscribing = false,
    this.isSubscribed = false,
    this.isDense = false,
    this.cardMargin,
  });

  final int rank;
  final PodcastDiscoverItem item;
  final VoidCallback onTap;
  final VoidCallback onSubscribe;
  final VoidCallback onPlay;
  final bool isSubscribing;
  final bool isSubscribed;
  final bool isDense;
  final EdgeInsetsGeometry? cardMargin;

  static const double _identityBarWidth = 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extension = appThemeOf(context);
    final showSubscribe = item.isPodcastShow;
    final rankLabel = '$rank';
    final rankSlotWidth = isDense ? 36.0 : 48.0;
    final actionSlotWidth = isDense ? 32.0 : 48.0;
    final innerPadding = isDense ? context.spacing.sm : context.spacing.md;
    final imageSize = isDense ? 48.0 : 62.0;
    final titleStyle =
        (isDense ? theme.textTheme.titleSmall : theme.textTheme.titleMedium)
            ?.copyWith(fontWeight: FontWeight.w700);
    final subtitleStyle =
        (isDense ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium)
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant);

    final isTop3 = rank <= 3;
    final List<Color> identityColors = switch (rank) {
      1 => AppColors.goldColors,
      2 => AppColors.coralColors,
      3 => AppColors.violetColors,
      _ => const [],
    };
    final rankColor = rank <= 3
        ? identityColors.first
        : theme.colorScheme.onSurfaceVariant;

    final cardContent = Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(extension.cardRadius),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: AdaptiveInkWell(
          borderRadius: BorderRadius.circular(extension.cardRadius),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: isDense ? context.spacing.sm : context.spacing.md,
              horizontal: innerPadding,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: rankSlotWidth,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        key: Key(
                          'podcast_discover_chart_rank_text_${item.itemId}',
                        ),
                        rankLabel,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: rankColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: isDense ? context.spacing.xs - 1 : context.spacing.smMd,
                ),
                RepaintBoundary(
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(extension.buttonRadius),
                    child: PodcastImageWidget(
                      imageUrl: item.artworkUrl,
                      width: imageSize,
                      height: imageSize,
                      iconSize: 20,
                    ),
                  ),
                ),
                SizedBox(
                  width: isDense ? context.spacing.xs : context.spacing.md,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: isDense ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                      SizedBox(
                        height: context.spacing.xxs,
                      ),
                      Text(
                        item.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: subtitleStyle,
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: isDense ? context.spacing.xs : context.spacing.sm,
                ),
                if (showSubscribe)
                  SizedBox(
                    width: actionSlotWidth,
                    child: Center(
                      child: SizedBox(
                        width: isDense ? 32 : 36,
                        height: isDense ? 32 : 36,
                        child: isSubscribing
                            ? Padding(
                                padding: EdgeInsets.all(context.spacing.sm),
                                child: CircularProgressIndicator.adaptive(
                                  strokeWidth: 2,
                                ),
                              )
                            : IconButton(
                                key: Key(
                                  'podcast_discover_subscribe_${item.itemId}',
                                ),
                                onPressed: isSubscribed ? null : onSubscribe,
                                tooltip: context.l10n.podcast_subscribe,
                                style: IconButton.styleFrom(
                                  minimumSize: Size(isDense ? 32 : 36, isDense ? 32 : 36),
                                  maximumSize: Size(isDense ? 32 : 36, isDense ? 32 : 36),
                                  tapTargetSize:
                                      MaterialTapTargetSize.padded,
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
                        width: isDense ? 32 : 36,
                        height: isDense ? 32 : 36,
                        child: IconButton(
                          key: Key(
                            'podcast_discover_play_${item.itemId}',
                          ),
                          onPressed: onPlay,
                          tooltip: context.l10n.podcast_play,
                          style: IconButton.styleFrom(
                            minimumSize: Size(isDense ? 32 : 36, isDense ? 32 : 36),
                            maximumSize: Size(isDense ? 32 : 36, isDense ? 32 : 36),
                            tapTargetSize: MaterialTapTargetSize.padded,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            foregroundColor:
                                theme.colorScheme.onSurfaceVariant,
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

    final wrappedCard = isTop3
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIdentityBar(extension.cardRadius, identityColors),
              Expanded(child: cardContent),
            ],
          )
        : cardContent;

    return Padding(
      key: Key('podcast_discover_chart_row_${item.itemId}'),
      padding: cardMargin ??
          EdgeInsets.symmetric(vertical: isDense ? context.spacing.xxs : context.spacing.sm),
      child: wrappedCard,
    );
  }

  Widget _buildIdentityBar(double cornerRadius, List<Color> colors) {
    return Container(
      width: _identityBarWidth,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(cornerRadius),
          bottomLeft: Radius.circular(cornerRadius),
        ),
      ),
    );
  }
}
