import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/theme/app_theme.dart';
import 'package:personal_ai_assistant/core/utils/time_formatter.dart';
import 'package:personal_ai_assistant/core/widgets/top_floating_notice.dart';

import 'package:personal_ai_assistant/features/podcast/presentation/providers/transcription_providers.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_transcription_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_transcription_model_extensions.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/transcription/transcription_step_indicators.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/transcription/transcription_step_mapper.dart';

class TranscriptionStatusWidget extends ConsumerWidget {
  final int episodeId;
  final PodcastTranscriptionResponse? transcription;

  const TranscriptionStatusWidget({
    super.key,
    required this.episodeId,
    this.transcription,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = transcription;
    if (t == null) {
      return _buildNotStartedState(context, ref);
    }

    switch (t.transcriptionStatus) {
      case TranscriptionStatus.pending:
        return _buildPendingState(context);
      case TranscriptionStatus.downloading:
      case TranscriptionStatus.converting:
      case TranscriptionStatus.transcribing:
      case TranscriptionStatus.processing:
        return _buildProcessingState(context, t);
      case TranscriptionStatus.completed:
        return _buildCompletedState(context, t, ref);
      case TranscriptionStatus.failed:
        return _buildFailedState(context, t, ref);
    }
  }

  Widget _buildNotStartedState(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ext = appThemeOf(context);
    final accentColor = theme.brightness == Brightness.dark
        ? scheme.tertiary
        : scheme.primary;
    return Card(
      elevation: 0,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ext.cardRadius),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(Icons.transcribe, size: 40, color: accentColor),
            ),

            const SizedBox(height: 16),

            // Title
            Text(
              l10n.transcription_start_title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),

            const SizedBox(height: 8),

            // Description
            Text(
              l10n.transcription_start_desc,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 24),

            // Start button with enhanced feedback
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _startTranscriptionWithFeedback(ref, context),
                icon: const Icon(Icons.play_arrow),
                label: Text(l10n.transcription_start_button),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(ext.buttonRadius),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Auto-start info text
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(ext.buttonRadius),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      l10n.transcription_auto_hint,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startTranscriptionWithFeedback(
    WidgetRef ref,
    BuildContext context,
  ) async {
    // Show immediate feedback
    showTopFloatingNotice(
      context,
      message: context.l10n.transcription_starting,
    );

    try {
      final provider = transcriptionProvider(episodeId);
      await ref.read(provider.notifier).startTranscription();

      // Show success feedback
      if (context.mounted) {
        showTopFloatingNotice(
          context,
          message: context.l10n.transcription_started_success,
        );
      }
    } catch (e) {
      if (context.mounted) {
        showTopFloatingNotice(
          context,
          message: AppLocalizations.of(
            context,
          )!.transcription_start_failed(e.toString()),
          isError: true,
        );
      }
    }
  }

  Widget _buildPendingState(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        // 根据可用宽度确定组件尺寸
        final isSmallScreen = constraints.maxWidth < 400;
        final isLargeScreen = constraints.maxWidth > 800;

        // 响应式尺寸
        final iconSize = isSmallScreen ? 50.0 : (isLargeScreen ? 100.0 : 80.0);
        final iconInnerSize = iconSize * 0.5;
        final titleFontSize = isSmallScreen
            ? 16.0
            : (isLargeScreen ? 20.0 : 18.0);
        final descriptionFontSize = isSmallScreen ? 13.0 : 14.0;

        return Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.transparent,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isLargeScreen ? 600 : double.infinity,
              ),
              child: Padding(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon - 响应式大小
                    Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        color: scheme.tertiary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(iconSize / 2),
                      ),
                      child: Icon(
                        Icons.pending_actions,
                        size: iconInnerSize,
                        color: scheme.tertiary,
                      ),
                    ),

                    SizedBox(height: isSmallScreen ? 12 : 16),

                    // Title - 响应式字体大小
                    Text(
                      l10n.transcription_pending_title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),

                    SizedBox(height: isSmallScreen ? 6 : 8),

                    // Description - 响应式字体大小
                    Text(
                      l10n.transcription_pending_desc,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: descriptionFontSize,
                        color: scheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProcessingState(
    BuildContext context,
    PodcastTranscriptionResponse transcription,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ext = appThemeOf(context);
    final progress = transcription.progressPercentage;
    final statusText = transcription.getLocalizedStatusDescription(context);
    final currentStep = transcriptionCurrentStepNumber(progress);

    return LayoutBuilder(
      builder: (context, constraints) {
        // 根据可用宽度确定组件尺寸
        final isSmallScreen = constraints.maxWidth < 400;
        final isLargeScreen = constraints.maxWidth > 800;

        // 响应式尺寸
        final progressContainerSize = isSmallScreen
            ? 70.0
            : (isLargeScreen ? 120.0 : 100.0);
        final progressIndicatorSize = progressContainerSize * 0.8;
        final progressStrokeWidth = isSmallScreen ? 4.0 : 6.0;
        final percentageFontSize = isSmallScreen
            ? 16.0
            : (isLargeScreen ? 24.0 : 20.0);
        final labelFontSize = isSmallScreen ? 8.0 : 10.0;
        final statusFontSize = isSmallScreen ? 14.0 : 16.0;

        return Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.transparent,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isLargeScreen ? 700 : double.infinity,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated icon with progress ring - 响应式尺寸
                    Container(
                      width: progressContainerSize,
                      height: progressContainerSize,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          progressContainerSize / 2,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Progress ring
                          SizedBox(
                            width: progressIndicatorSize,
                            height: progressIndicatorSize,
                            child: CircularProgressIndicator(
                              value: progress / 100,
                              strokeWidth: progressStrokeWidth,
                              backgroundColor: scheme.primary.withValues(
                                alpha: 0.2,
                              ),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                scheme.primary,
                              ),
                            ),
                          ),
                          // Center percentage - 响应式字体大小
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${progress.toStringAsFixed(0)}%',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontSize: percentageFontSize,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.primary,
                                ),
                              ),
                              Text(
                                l10n.transcription_progress_complete,
                                style: AppTheme.monoStyle(
                                  fontSize: labelFontSize,
                                  color: scheme.primary.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: isSmallScreen ? 16 : 20),

                    // Current status with icon - 响应式字体大小
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 12 : 16,
                        vertical: isSmallScreen ? 8 : 10,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(ext.pillRadius),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TranscriptionStatusStepIcon(step: currentStep),
                          SizedBox(width: isSmallScreen ? 6 : 8),
                          Flexible(
                            child: Text(
                              statusText,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: statusFontSize,
                                fontWeight: FontWeight.w600,
                                color: scheme.primary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: isSmallScreen ? 16 : 20),

                    // Step indicators
                    TranscriptionStepIndicators(
                      progressPercentage: progress,
                      steps: [
                        TranscriptionStepDescriptor(
                          icon: Icons.download,
                          label: l10n.transcription_step_download,
                        ),
                        TranscriptionStepDescriptor(
                          icon: Icons.transform,
                          label: l10n.transcription_step_convert,
                        ),
                        TranscriptionStepDescriptor(
                          icon: Icons.content_cut,
                          label: l10n.transcription_step_split,
                        ),
                        TranscriptionStepDescriptor(
                          icon: Icons.transcribe,
                          label: l10n.transcription_step_transcribe,
                        ),
                        TranscriptionStepDescriptor(
                          icon: Icons.merge_type,
                          label: l10n.transcription_step_merge,
                        ),
                      ],
                    ),

                    SizedBox(height: isSmallScreen ? 12 : 16),

                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(ext.inputRadius),
                      child: LinearProgressIndicator(
                        value: progress / 100,
                        backgroundColor: scheme.outline.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                        minHeight: isSmallScreen ? 4 : 6,
                      ),
                    ),

                    // Debug info (if available)
                    if (transcription.debugMessage case final debugMsg?) ...[
                      SizedBox(height: isSmallScreen ? 12 : 16),
                      Container(
                        padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(ext.inputRadius),
                          border: Border.all(
                            color: scheme.outline.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: isSmallScreen ? 12 : 14,
                              color: scheme.secondary,
                            ),
                            SizedBox(width: isSmallScreen ? 6 : 8),
                            Expanded(
                              child: Text(
                                debugMsg,
                                style: AppTheme.monoStyle(
                                  fontSize: isSmallScreen ? 10.0 : 11.0,
                                  color: scheme.secondary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Additional info
                    if (transcription.wordCount != null ||
                        transcription.durationSeconds != null) ...[
                      SizedBox(height: isSmallScreen ? 10 : 12),
                      Builder(
                        builder: (context) {
                          final wordCount = transcription.wordCount;
                          final durationSeconds = transcription.durationSeconds;
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (durationSeconds != null) ...[
                                Icon(
                                  Icons.schedule,
                                  size: isSmallScreen ? 12 : 14,
                                  color: scheme.onSurfaceVariant,
                                ),
                                SizedBox(width: isSmallScreen ? 3 : 4),
                                Text(
                                  l10n.transcription_duration_label(
                                    _formatDuration(durationSeconds),
                                  ),
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontSize: isSmallScreen ? 11.0 : null,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                              if (wordCount != null && durationSeconds != null)
                                SizedBox(width: isSmallScreen ? 12 : 16),
                              if (wordCount != null) ...[
                                Icon(
                                  Icons.text_fields,
                                  size: isSmallScreen ? 12 : 14,
                                  color: scheme.onSurfaceVariant,
                                ),
                                SizedBox(width: isSmallScreen ? 3 : 4),
                                Text(
                                  l10n.transcription_words_label(
                                    (wordCount / 1000).toStringAsFixed(1),
                                  ),
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontSize: isSmallScreen ? 11.0 : null,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompletedState(
    BuildContext context,
    PodcastTranscriptionResponse transcription,
    WidgetRef ref,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ext = appThemeOf(context);
    final wordCount = transcription.wordCount ?? 0;
    final duration = transcription.durationSeconds ?? 0;
    final completedAt = transcription.completedAt;

    return Card(
      elevation: 0,
      color: scheme.tertiary.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ext.cardRadius),
        side: BorderSide(color: scheme.tertiary.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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

            const SizedBox(height: 16),

            // Title
            Text(
              context.l10n.transcription_complete_title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),

            const SizedBox(height: 8),

            // Description
            Text(
              context.l10n.transcription_complete_desc,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 16),

            // Stats
            Container(
              padding: const EdgeInsets.all(12),
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
                        _formatDuration(duration),
                        AppLocalizations.of(
                          context,
                        )!.transcription_stat_duration,
                        Icons.schedule,
                      ),
                      _buildStatItem(
                        context,
                        _formatAccuracy(null),
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
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(
                  context,
                )!.transcription_completed_at(TimeFormatter.formatFullDateTime(completedAt)),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _deleteTranscription(ref),
                    icon: const Icon(Icons.delete_outline),
                    label: Text(
                      AppLocalizations.of(
                        context,
                      )!.podcast_transcription_delete,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _viewTranscription(ref),
                    icon: const Icon(Icons.visibility),
                    label: Text(
                      context.l10n.transcription_view_button,
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
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

  Widget _buildFailedState(
    BuildContext context,
    PodcastTranscriptionResponse transcription,
    WidgetRef ref,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ext = appThemeOf(context);
    final errorMessage =
        transcription.errorMessage ??
        context.l10n.transcription_unknown_error;
    final friendlyMessage = _getFriendlyErrorMessage(context, errorMessage);
    final suggestion = _getErrorSuggestion(context, errorMessage);

    return Card(
      elevation: 0,
      color: scheme.error.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ext.cardRadius),
        side: BorderSide(color: scheme.error.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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

            const SizedBox(height: 16),

            // Title
            Text(
              context.l10n.transcription_failed_title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),

            const SizedBox(height: 8),

            // Friendly error message
            Text(
              friendlyMessage,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 12),

            // Suggestion
            Container(
              padding: const EdgeInsets.all(12),
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
                  const SizedBox(width: 8),
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
              const SizedBox(height: 12),
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(ext.inputRadius),
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

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _deleteTranscription(ref),
                    icon: const Icon(Icons.delete_outline),
                    label: Text(
                      context.l10n.podcast_transcription_clear,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(ext.buttonRadius),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _retryTranscription(ref),
                    icon: const Icon(Icons.refresh),
                    label: Text(
                      context.l10n.transcription_retry_button,
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
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

  String _getFriendlyErrorMessage(BuildContext context, String error) {
    final lowerError = error.toLowerCase();

    if (lowerError.contains('already in progress') ||
        lowerError.contains('already exists') ||
        lowerError.contains('locked')) {
      return context.l10n.transcription_error_already_progress;
    }
    if (lowerError.contains('network') ||
        lowerError.contains('connection') ||
        lowerError.contains('timeout')) {
      return context.l10n.transcription_error_network;
    }
    if (lowerError.contains('audio') || lowerError.contains('download')) {
      return context.l10n.transcription_error_audio_download;
    }
    if (lowerError.contains('api') || lowerError.contains('transcription')) {
      return context.l10n.transcription_error_service;
    }
    if (lowerError.contains('format') || lowerError.contains('convert')) {
      return context.l10n.transcription_error_format;
    }
    if (lowerError.contains('server restart')) {
      return context.l10n.transcription_error_server_restart;
    }

    return context.l10n.transcription_error_generic;
  }

  String _getErrorSuggestion(BuildContext context, String error) {
    final lowerError = error.toLowerCase();

    if (lowerError.contains('network') ||
        lowerError.contains('connection') ||
        lowerError.contains('timeout')) {
      return context.l10n.transcription_suggest_network;
    }
    if (lowerError.contains('audio') || lowerError.contains('download')) {
      return context.l10n.transcription_suggest_audio;
    }
    if (lowerError.contains('api') || lowerError.contains('transcription')) {
      return context.l10n.transcription_suggest_service;
    }
    if (lowerError.contains('format') || lowerError.contains('convert')) {
      return context.l10n.transcription_suggest_format;
    }
    if (lowerError.contains('server restart')) {
      return context.l10n.transcription_suggest_restart;
    }

    return context.l10n.transcription_suggest_generic;
  }

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
        const SizedBox(height: 4),
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

  Future<void> _deleteTranscription(WidgetRef ref) async {
    try {
      final provider = transcriptionProvider(episodeId);
      await ref.read(provider.notifier).deleteTranscription();
    } catch (e) {
      // Error will be handled by the provider
    }
  }

  void _viewTranscription(WidgetRef ref) {
    // This will be handled by the parent widget
    // Just update the tab to show transcription
  }

  Future<void> _retryTranscription(WidgetRef ref) async {
    // Show retry feedback
    try {
      final provider = transcriptionProvider(episodeId);
      await ref.read(provider.notifier).startTranscription();
    } catch (e) {
      // Error will be handled by the provider
    }
  }

  String _formatDuration(int seconds) {
    return TimeFormatter.formatSecondsClock(seconds, padHours: false);
  }

  String _formatAccuracy(double? accuracy) {
    if (accuracy == null) return '--';
    return '${(accuracy * 100).toStringAsFixed(0)}%';
  }
}
