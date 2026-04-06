import 'package:flutter/material.dart';

import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/theme/app_theme.dart';

/// Widget for displaying the three-dimensional score of a highlight.
///
/// Shows insight, novelty, and actionability scores as progress bars
/// with distinct colors for each dimension.
class HighlightScoreIndicator extends StatelessWidget {
  const HighlightScoreIndicator({
    required this.insightScore, required this.noveltyScore, required this.actionabilityScore, super.key,
    this.isDense = false,
  });

  final double insightScore;
  final double noveltyScore;
  final double actionabilityScore;
  final bool isDense;

  static const double _defaultBarHeight = 5;
  static const double _denseBarHeight = 4;
  static const double _defaultLabelWidth = 48;
  static const double _denseLabelWidth = 42;
  static const double _defaultScoreWidth = 28;
  static const double _denseScoreWidth = 24;

  Color _getInsightColor(BuildContext context) {
    return AppColors.primary;
  }

  Color _getNoveltyColor(BuildContext context) {
    return AppColors.accentWarm;
  }

  Color _getActionabilityColor(BuildContext context) {
    return AppColors.accentCoral;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
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
            style: AppTheme.metaSmall(
              theme.colorScheme.onSurfaceVariant,
            ).copyWith(fontWeight: FontWeight.w400),
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
            style: AppTheme.metaSmall(color).copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
