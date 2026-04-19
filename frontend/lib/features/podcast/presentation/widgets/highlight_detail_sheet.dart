import 'package:flutter/material.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';

import 'package:personal_ai_assistant/core/constants/app_radius.dart';

import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/theme/app_theme.dart';
import 'package:personal_ai_assistant/core/widgets/adaptive_sheet_helper.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_highlight_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/highlight_score_indicator.dart';

/// Shows highlight details in an adaptive bottom sheet/dialog
Future<void> showHighlightDetailSheet({
  required BuildContext context,
  required HighlightResponse highlight,
  VoidCallback? onFavoriteToggle,
}) async {
  await showAdaptiveSheet<void>(
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
  await showAdaptiveSheet<void>(
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
        padding: EdgeInsets.all(context.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quote section
            _buildQuoteSection(context),
            SizedBox(height: context.spacing.md),

            // Overall score badge
            _buildOverallScoreBadge(context),
            SizedBox(height: context.spacing.md),

            // Three-dimensional scores
            HighlightScoreIndicator(
              insightScore: highlight.insightScore,
              noveltyScore: highlight.noveltyScore,
              actionabilityScore: highlight.actionabilityScore,
              isDense: true,
            ),
            SizedBox(height: context.spacing.md),

            // Topic tags
            if (highlight.topicTags.isNotEmpty) ...[
              _buildTopicTags(context),
              SizedBox(height: context.spacing.md),
            ],

            // Episode source
            if (highlight.episodeTitle.isNotEmpty) ...[
              _buildEpisodeSource(context),
              SizedBox(height: context.spacing.md),
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
                        ? theme.colorScheme.error
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
      padding: EdgeInsets.all(context.spacing.smMd),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.15),
        borderRadius: AppRadius.lgRadius,
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
            color: scheme.primary.withValues(alpha: 0.7),
          ),
          SizedBox(width: context.spacing.smMd),
          Expanded(
            child: SelectableText(
              highlight.originalText,
              style: AppTheme.transcriptBody(scheme.onSurface),
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
      scoreColor = theme.colorScheme.tertiary;
    } else if (highlight.overallScore >= 6.0) {
      scoreColor = theme.colorScheme.secondary;
    } else {
      scoreColor = scheme.onSurfaceVariant;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: context.spacing.md, vertical: context.spacing.smMd),
      decoration: BoxDecoration(
        color: scoreColor.withValues(alpha: 0.12),
        borderRadius: AppRadius.xlRadius,
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
          SizedBox(width: context.spacing.sm),
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
        SizedBox(height: context.spacing.sm),
        Wrap(
          spacing: context.spacing.sm,
          runSpacing: context.spacing.sm,
          children: highlight.topicTags.map((tag) {
            return Container(
              padding: EdgeInsets.symmetric(horizontal: context.spacing.smMd, vertical: context.spacing.sm),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(appThemeOf(context).pillRadius),
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
    final extension = appThemeOf(context);

    return Container(
      padding: EdgeInsets.all(context.spacing.smMd),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(extension.itemRadius),
      ),
      child: Row(
        children: [
          Icon(
            Icons.podcasts_outlined,
            size: 16,
            color: scheme.onSurfaceVariant,
          ),
          SizedBox(width: context.spacing.sm),
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
                  const SizedBox(height: AppSpacing.xxs),
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
            padding: EdgeInsets.fromLTRB(context.spacing.mdLg, context.spacing.mdLg, context.spacing.mdLg, 0),
            child: Text(
              l10n.podcast_highlights_multiple_count(highlights.length),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(height: context.spacing.sm),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.symmetric(horizontal: context.spacing.md),
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
      scoreColor = theme.colorScheme.tertiary;
    } else if (highlight.overallScore >= 6.0) {
      scoreColor = theme.colorScheme.secondary;
    } else {
      scoreColor = scheme.onSurfaceVariant;
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.spacing.xs),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: AppRadius.mdLgRadius,
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.15),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(context.spacing.smMd),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.spacing.sm,
                      vertical: context.spacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(appThemeOf(context).buttonRadius),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, size: 12, color: scoreColor),
                        SizedBox(width: context.spacing.xs),
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
                    const Icon(
                      Icons.favorite,
                      size: 14,
                      color: AppColors.error,
                    ),
                ],
              ),
              SizedBox(height: context.spacing.sm),
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
      ),
    );
  }
}
