import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/adaptive_sheet_helper.dart';
import '../../data/models/podcast_highlight_model.dart';
import 'highlight_score_indicator.dart';

/// Shows highlight details in an adaptive bottom sheet/dialog
Future<void> showHighlightDetailSheet({
  required BuildContext context,
  required HighlightResponse highlight,
  VoidCallback? onFavoriteToggle,
}) async {
  await showAdaptiveSheet(
    context: context,
    builder: (context) => _HighlightDetailContent(
      highlight: highlight,
      onFavoriteToggle: onFavoriteToggle,
    ),
  );
}

/// Shows multiple highlights in an adaptive bottom sheet/dialog
Future<void> showMultipleHighlightsSheet({
  required BuildContext context,
  required List<HighlightResponse> highlights,
  VoidCallback? onFavoriteToggle,
}) async {
  await showAdaptiveSheet(
    context: context,
    builder: (context) => _MultipleHighlightsContent(
      highlights: highlights,
      onFavoriteToggle: onFavoriteToggle,
    ),
  );
}

class _HighlightDetailContent extends StatelessWidget {
  const _HighlightDetailContent({
    required this.highlight,
    this.onFavoriteToggle,
  });

  final HighlightResponse highlight;
  final VoidCallback? onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quote section
            _buildQuoteSection(context),
            const SizedBox(height: 20),

            // Overall score badge
            _buildOverallScoreBadge(context),
            const SizedBox(height: 20),

            // Three-dimensional scores
            HighlightScoreIndicator(
              insightScore: highlight.insightScore,
              noveltyScore: highlight.noveltyScore,
              actionabilityScore: highlight.actionabilityScore,
            ),
            const SizedBox(height: 20),

            // Topic tags
            if (highlight.topicTags.isNotEmpty) ...[
              _buildTopicTags(context),
              const SizedBox(height: 20),
            ],

            // Episode source
            if (highlight.episodeTitle.isNotEmpty) ...[
              _buildEpisodeSource(context),
              const SizedBox(height: 20),
            ],

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onFavoriteToggle,
                  icon: Icon(
                    highlight.isUserFavorited
                        ? Icons.favorite
                        : Icons.favorite_border,
                    size: 18,
                    color: highlight.isUserFavorited
                        ? Colors.red
                        : scheme.onSurfaceVariant,
                  ),
                  label: Text(
                    highlight.isUserFavorited
                        ? l10n.podcast_highlights_favorited
                        : l10n.podcast_highlights_favorite,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuoteSection(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.format_quote,
            size: 20,
            color: scheme.primary.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              highlight.originalText,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontSize: 15,
                height: 1.6,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallScoreBadge(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;

    // Determine score color
    Color scoreColor;
    if (highlight.overallScore >= 8.0) {
      scoreColor = AppColors.leaf;
    } else if (highlight.overallScore >= 6.0) {
      scoreColor = AppColors.sunRay;
    } else {
      scoreColor = scheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: scoreColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: scoreColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star,
            size: 18,
            color: scoreColor,
          ),
          const SizedBox(width: 8),
          Text(
            l10n.podcast_highlights_overall_score(highlight.overallScore),
            style: theme.textTheme.titleMedium?.copyWith(
              color: scoreColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicTags(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.podcast_highlights_topic_tags,
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: highlight.topicTags.map((tag) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                tag,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildEpisodeSource(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.podcasts_outlined,
            size: 16,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (highlight.subscriptionTitle != null) ...[
                  Text(
                    highlight.subscriptionTitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  highlight.episodeTitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MultipleHighlightsContent extends StatelessWidget {
  const _MultipleHighlightsContent({
    required this.highlights,
    this.onFavoriteToggle,
  });

  final List<HighlightResponse> highlights;
  final VoidCallback? onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Text(
              l10n.podcast_highlights_multiple_count(highlights.length),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: highlights.length,
              itemBuilder: (context, index) {
                final highlight = highlights[index];
                return RepaintBoundary(
                  key: ValueKey('highlight_list_item_$index'),
                  child: _HighlightListItem(
                    highlight: highlight,
                    onTap: () {
                      Navigator.of(context).pop();
                      showHighlightDetailSheet(
                        context: context,
                        highlight: highlight,
                        onFavoriteToggle: onFavoriteToggle,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightListItem extends StatelessWidget {
  const _HighlightListItem({
    required this.highlight,
    required this.onTap,
  });

  final HighlightResponse highlight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Determine score color
    Color scoreColor;
    if (highlight.overallScore >= 8.0) {
      scoreColor = AppColors.leaf;
    } else if (highlight.overallScore >= 6.0) {
      scoreColor = AppColors.sunRay;
    } else {
      scoreColor = scheme.onSurfaceVariant;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: scheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, size: 12, color: scoreColor),
                        const SizedBox(width: 4),
                        Text(
                          highlight.overallScore.toStringAsFixed(1),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scoreColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (highlight.isUserFavorited)
                    Icon(
                      Icons.favorite,
                      size: 14,
                      color: Colors.red,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                highlight.originalText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
