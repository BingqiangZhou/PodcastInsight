import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/constants/app_radius.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/theme/app_theme.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_highlight_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/highlight_score_indicator.dart';

/// Card widget for displaying a podcast highlight.
///
/// Shows the original quote, overall score badge, three-dimensional scores,
/// episode source, topic tags, and favorite button.
class HighlightCard extends ConsumerWidget {
  const HighlightCard({
    required this.highlight, super.key,
    this.onFavoriteToggle,
    this.onTap,
    this.isCompact = false,
  });

  final HighlightResponse highlight;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onTap;
  final bool isCompact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15),
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            isCompact ? 14 : 16,
            isCompact ? 14 : 16,
            isCompact ? 12 : 16,
            isCompact ? 12 : 14,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 原文放在最上面
              if (!isCompact) ...[
                _buildOriginalQuote(context, theme),
              ] else ...[
                _buildCompactQuote(context, theme),
              ],
              // 分数和收藏按钮放在原文下面
              const SizedBox(height: 10),
              _buildHeader(context, theme),
              const SizedBox(height: 10),
              _buildScoresSection(context, theme),
              const SizedBox(height: 10),
              _buildMetadataSection(context, theme),
              if (highlight.topicTags.isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildTopicTags(context, theme),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Row(
      children: [
        _buildOverallScoreBadge(context, theme),
        const Spacer(),
        if (highlight.isUserFavorited || _canFavorite())
          _buildFavoriteButton(context, theme),
      ],
    );
  }

  Widget _buildOverallScoreBadge(BuildContext context, ThemeData theme) {
    final score = highlight.overallScore;
    final scoreText = score.toStringAsFixed(1);
    final scoreColor = _getScoreColor(context, score);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scoreColor.withValues(alpha: 0.12),
        borderRadius: AppRadius.pillRadius,
        border: Border.all(color: scoreColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            size: 14,
            color: scoreColor,
          ),
          const SizedBox(width: 4),
          Text(
            scoreText,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scoreColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteButton(BuildContext context, ThemeData theme) {
    final isFavorited = highlight.isUserFavorited;
    final l10n = context.l10n;

    return Tooltip(
      message: isFavorited ? l10n.podcast_highlights_unfavorite : l10n.podcast_highlights_favorite,
      child: IconButton(
        onPressed: _canFavorite() ? onFavoriteToggle : null,
        icon: Icon(
          isFavorited ? Icons.bookmark : Icons.bookmark_border_rounded,
          size: isCompact ? 18 : 20,
        ),
        style: IconButton.styleFrom(
          minimumSize: const Size(32, 32),
          maximumSize: const Size(32, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: EdgeInsets.zero,
          foregroundColor: isFavorited
              ? AppColors.sunRay
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildOriginalQuote(BuildContext context, ThemeData theme) {
    final l10n = context.l10n;
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
          borderRadius: AppRadius.lgRadius,
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.format_quote_rounded,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.podcast_highlights_original_quote,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              highlight.originalText,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactQuote(BuildContext context, ThemeData theme) {
    return Text(
      highlight.originalText,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurface,
        height: 1.45,
        fontStyle: FontStyle.italic,
      ),
    );
  }

  Widget _buildScoresSection(BuildContext context, ThemeData theme) {
    return HighlightScoreIndicator(
      insightScore: highlight.insightScore,
      noveltyScore: highlight.noveltyScore,
      actionabilityScore: highlight.actionabilityScore,
      isDense: isCompact,
    );
  }

  Widget _buildMetadataSection(BuildContext context, ThemeData theme) {
    return Row(
      children: [
        Icon(
          Icons.podcasts_rounded,
          size: 13,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            highlight.episodeTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopicTags(BuildContext context, ThemeData theme) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: highlight.topicTags.take(4).map((tag) {
        return Chip(
          label: Text(
            tag,
            style: AppTheme.navLabel(
              null,
              weight: FontWeight.w600,
            ),
          ),
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: theme.colorScheme.secondaryContainer.withValues(
            alpha: 0.4,
          ),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.pillRadius,
          ),
        );
      }).toList(),
    );
  }

  Color _getScoreColor(BuildContext context, double score) {
    if (score >= 8.5) {
      return AppColors.tertiary;
    } else if (score >= 7.0) {
      return AppColors.primary;
    } else if (score >= 5.5) {
      return AppColors.sunGlow;
    }
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  bool _canFavorite() {
    return true;
  }
}
