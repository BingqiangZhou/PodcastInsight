import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';

/// Widget for displaying the three-dimensional score of a highlight.
///
/// Shows insight, novelty, and actionability scores as progress bars
/// with distinct colors for each dimension.
class HighlightScoreIndicator extends StatelessWidget {
  const HighlightScoreIndicator({
    super.key,
    required this.insightScore,
    required this.noveltyScore,
    required this.actionabilityScore,
    this.isDense = false,
  });

  final double insightScore;
  final double noveltyScore;
  final double actionabilityScore;
  final bool isDense;

  static const double _defaultBarHeight = 5.0;
  static const double _denseBarHeight = 4.0;
  static const double _defaultLabelWidth = 48.0;
  static const double _denseLabelWidth = 42.0;
  static const double _defaultScoreWidth = 28.0;
  static const double _denseScoreWidth = 24.0;

  Color _getInsightColor(BuildContext context) {
    return AppColors.indigo;
  }

  Color _getNoveltyColor(BuildContext context) {
    return AppColors.leaf;
  }

  Color _getActionabilityColor(BuildContext context) {
    return AppColors.sunRay;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final barHeight = isDense ? _denseBarHeight : _defaultBarHeight;
    final labelWidth = isDense ? _denseLabelWidth : _defaultLabelWidth;
    final scoreWidth = isDense ? _denseScoreWidth : _defaultScoreWidth;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ScoreRow(
          label: l10n.podcast_highlights_insight,
          score: insightScore,
          color: _getInsightColor(context),
          barHeight: barHeight,
          labelWidth: labelWidth,
          scoreWidth: scoreWidth,
          theme: theme,
        ),
        SizedBox(height: isDense ? 4 : 6),
        _ScoreRow(
          label: l10n.podcast_highlights_novelty,
          score: noveltyScore,
          color: _getNoveltyColor(context),
          barHeight: barHeight,
          labelWidth: labelWidth,
          scoreWidth: scoreWidth,
          theme: theme,
        ),
        SizedBox(height: isDense ? 4 : 6),
        _ScoreRow(
          label: l10n.podcast_highlights_actionability,
          score: actionabilityScore,
          color: _getActionabilityColor(context),
          barHeight: barHeight,
          labelWidth: labelWidth,
          scoreWidth: scoreWidth,
          theme: theme,
        ),
      ],
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.label,
    required this.score,
    required this.color,
    required this.barHeight,
    required this.labelWidth,
    required this.scoreWidth,
    required this.theme,
  });

  final String label;
  final double score;
  final Color color;
  final double barHeight;
  final double labelWidth;
  final double scoreWidth;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final clampedScore = score.clamp(0.0, 10.0);
    final scoreText = clampedScore.toStringAsFixed(1);

    return Row(
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: LinearProgressIndicator(
            value: clampedScore / 10.0,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(
              color.withValues(alpha: 0.85),
            ),
            minHeight: barHeight,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: scoreWidth,
          child: Text(
            scoreText,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
