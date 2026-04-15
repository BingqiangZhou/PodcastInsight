import 'package:flutter/material.dart';

import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/theme/app_theme.dart';
import 'package:personal_ai_assistant/core/utils/time_formatter.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_transcription_model.dart';

/// Widget displaying the completed transcription state with stats and actions.
class CompletedStateWidget extends StatelessWidget {
  const CompletedStateWidget({
    required this.transcription,
    required this.onDelete,
    required this.onView,
    super.key,
  });

  final PodcastTranscriptionResponse transcription;
  final VoidCallback onDelete;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ext = appThemeOf(context);
    final wordCount = transcription.wordCount ?? 0;
    final duration = transcription.durationSeconds ?? 0;
    final completedAt = transcription.completedAt;

    return Container(
      decoration: BoxDecoration(
        color: scheme.tertiary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(ext.cardRadius),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.15),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Success icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: scheme.tertiary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(Icons.check_circle, size: 40, color: scheme.tertiary),
            ),

            const SizedBox(height: AppSpacing.md),

            // Title
            Text(
              context.l10n.transcription_complete_title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            // Description
            Text(
              context.l10n.transcription_complete_desc,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Stats
            Container(
              padding: const EdgeInsets.all(AppSpacing.smMd),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(ext.buttonRadius),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        context,
                        '${(wordCount / 1000).toStringAsFixed(1)}K',
                        context.l10n.transcription_stat_words,
                        Icons.text_fields,
                      ),
                      _buildStatItem(
                        context,
                        formatDuration(duration),
                        AppLocalizations.of(
                          context,
                        )!.transcription_stat_duration,
                        Icons.schedule,
                      ),
                      _buildStatItem(
                        context,
                        formatAccuracy(null),
                        AppLocalizations.of(
                          context,
                        )!.transcription_stat_accuracy,
                        Icons.speed,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (completedAt != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                AppLocalizations.of(
                  context,
                )!.transcription_completed_at(TimeFormatter.formatFullDateTime(completedAt)),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.md),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(
                      AppLocalizations.of(
                        context,
                      )!.podcast_transcription_delete,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.smMd),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ext.buttonRadius),
                      ),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.smMd),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onView,
                    icon: const Icon(Icons.visibility),
                    label: Text(
                      context.l10n.transcription_view_button,
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.smMd),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ext.buttonRadius),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget displaying the failed transcription state with retry option.
class FailedStateWidget extends StatelessWidget {
  const FailedStateWidget({
    required this.transcription,
    required this.onDelete,
    required this.onRetry,
    super.key,
  });

  final PodcastTranscriptionResponse transcription;
  final VoidCallback onDelete;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ext = appThemeOf(context);
    final errorMessage =
        transcription.errorMessage ??
        context.l10n.transcription_unknown_error;
    final friendlyMessage = getFriendlyErrorMessage(context, errorMessage);
    final suggestion = getErrorSuggestion(context, errorMessage);

    return Container(
      decoration: BoxDecoration(
        color: scheme.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(ext.cardRadius),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.15),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Error icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: scheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(Icons.error_outline, size: 40, color: scheme.error),
            ),

            const SizedBox(height: AppSpacing.md),

            // Title
            Text(
              context.l10n.transcription_failed_title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),

            const SizedBox(height: AppSpacing.sm),

            // Friendly error message
            Text(
              friendlyMessage,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),

            const SizedBox(height: AppSpacing.smMd),

            // Suggestion
            Container(
              padding: const EdgeInsets.all(AppSpacing.smMd),
              decoration: BoxDecoration(
                color: scheme.tertiary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(ext.buttonRadius),
                border: Border.all(color: scheme.tertiary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 16,
                    color: scheme.tertiary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      suggestion,
                      style: AppTheme.caption(scheme.tertiary),
                    ),
                  ),
                ],
              ),
            ),

            if (errorMessage != friendlyMessage) ...[
              const SizedBox(height: AppSpacing.smMd),
              // Technical details (expandable)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  context.l10n.transcription_technical_details,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(ext.buttonRadius),
                    ),
                    child: Text(
                      errorMessage,
                      style: AppTheme.monoStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: AppSpacing.md),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(
                      context.l10n.podcast_transcription_clear,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.smMd),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ext.buttonRadius),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.smMd),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: Text(
                      context.l10n.transcription_retry_button,
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.smMd),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ext.buttonRadius),
                      ),
                      backgroundColor: scheme.tertiary,
                      foregroundColor: scheme.onTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper functions (top-level, used by both CompletedStateWidget and
// FailedStateWidget)
// ---------------------------------------------------------------------------

/// Maps a raw error string to a user-friendly localized message.
String getFriendlyErrorMessage(BuildContext context, String error) {
  final l10n = context.l10n;
  final lowerError = error.toLowerCase();

  if (lowerError.contains('already in progress') ||
      lowerError.contains('already exists') ||
      lowerError.contains('locked')) {
    return l10n.transcription_error_already_progress;
  }
  if (lowerError.contains('network') ||
      lowerError.contains('connection') ||
      lowerError.contains('timeout')) {
    return l10n.transcription_error_network;
  }
  if (lowerError.contains('audio') || lowerError.contains('download')) {
    return l10n.transcription_error_audio_download;
  }
  if (lowerError.contains('api') || lowerError.contains('transcription')) {
    return l10n.transcription_error_service;
  }
  if (lowerError.contains('format') || lowerError.contains('convert')) {
    return l10n.transcription_error_format;
  }
  if (lowerError.contains('server restart')) {
    return l10n.transcription_error_server_restart;
  }

  return l10n.transcription_error_generic;
}

/// Returns a localized suggestion for resolving the given error.
String getErrorSuggestion(BuildContext context, String error) {
  final l10n = context.l10n;
  final lowerError = error.toLowerCase();

  if (lowerError.contains('network') ||
      lowerError.contains('connection') ||
      lowerError.contains('timeout')) {
    return l10n.transcription_suggest_network;
  }
  if (lowerError.contains('audio') || lowerError.contains('download')) {
    return l10n.transcription_suggest_audio;
  }
  if (lowerError.contains('api') || lowerError.contains('transcription')) {
    return l10n.transcription_suggest_service;
  }
  if (lowerError.contains('format') || lowerError.contains('convert')) {
    return l10n.transcription_suggest_format;
  }
  if (lowerError.contains('server restart')) {
    return l10n.transcription_suggest_restart;
  }

  return l10n.transcription_suggest_generic;
}

/// Formats duration in seconds to a human-readable string.
String formatDuration(int seconds) {
  return TimeFormatter.formatSecondsClock(seconds, padHours: false);
}

/// Formats an accuracy value (0.0–1.0) as a percentage string.
String formatAccuracy(double? accuracy) {
  if (accuracy == null) return '--';
  return '${(accuracy * 100).toStringAsFixed(0)}%';
}

/// Builds a single stat item (icon + value + label) for the completed state.
Widget _buildStatItem(
  BuildContext context,
  String value,
  String label,
  IconData icon,
) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  return Column(
    children: [
      Icon(icon, size: 20, color: scheme.primary),
      const SizedBox(height: AppSpacing.xs),
      Text(
        value,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}
