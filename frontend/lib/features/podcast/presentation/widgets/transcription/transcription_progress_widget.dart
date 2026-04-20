import 'package:flutter/material.dart';
import 'package:personal_ai_assistant/core/constants/app_text_styles.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/theme/app_theme.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_transcription_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_transcription_model_extensions.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/transcription/transcription_step_indicators.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/transcription/transcription_step_mapper.dart';
import 'package:personal_ai_assistant/core/utils/time_formatter.dart';

/// Widget displaying the pending/waiting state for transcription.
class PendingStateWidget extends StatelessWidget {
  const PendingStateWidget({super.key});

  @override
  Widget build(BuildContext context) {
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
                padding: EdgeInsets.all(isSmallScreen ? AppSpacing.smMd : AppSpacing.md),
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

                    SizedBox(height: isSmallScreen ? AppSpacing.smMd : AppSpacing.md),

                    // Title - 响应式字体大小
                    Text(
                      l10n.transcription_pending_title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),

                    SizedBox(height: isSmallScreen ? AppSpacing.xsSm : AppSpacing.sm),

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
}

/// Widget displaying the active processing state with progress ring.
class ProcessingStateWidget extends StatelessWidget {
  const ProcessingStateWidget({
    required this.transcription,
    super.key,
  });

  final PodcastTranscriptionResponse transcription;

  @override
  Widget build(BuildContext context) {
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
                padding: EdgeInsets.all(isSmallScreen ? AppSpacing.smMd : AppSpacing.md),
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
                            child: CircularProgressIndicator.adaptive(
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
                                style: AppTextStyles.monoStyle(
                                  fontSize: labelFontSize,
                                  color: scheme.primary.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: isSmallScreen ? AppSpacing.md : AppSpacing.mdLg),

                    // Current status with icon - 响应式字体大小
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? AppSpacing.smMd : AppSpacing.md,
                        vertical: isSmallScreen ? AppSpacing.sm : AppSpacing.smLg,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(ext.pillRadius),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TranscriptionStatusStepIcon(step: currentStep),
                          SizedBox(width: isSmallScreen ? AppSpacing.xsSm : AppSpacing.sm),
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

                    SizedBox(height: isSmallScreen ? AppSpacing.md : AppSpacing.mdLg),

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

                    SizedBox(height: isSmallScreen ? AppSpacing.smMd : AppSpacing.md),

                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(ext.buttonRadius),
                      child: LinearProgressIndicator(
                        value: progress / 100,
                        backgroundColor: scheme.outline.withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                        minHeight: isSmallScreen ? 4 : 6,
                      ),
                    ),

                    // Debug info (if available)
                    if (transcription.debugMessage case final debugMsg?) ...[
                      SizedBox(height: isSmallScreen ? AppSpacing.smMd : AppSpacing.md),
                      Container(
                        padding: EdgeInsets.all(isSmallScreen ? AppSpacing.sm : AppSpacing.smLg),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(ext.buttonRadius),
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
                            SizedBox(width: isSmallScreen ? AppSpacing.xsSm : AppSpacing.sm),
                            Expanded(
                              child: Text(
                                debugMsg,
                                style: AppTextStyles.monoStyle(
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
                      SizedBox(height: isSmallScreen ? AppSpacing.smLg : AppSpacing.smMd),
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
                                    formatDuration(durationSeconds),
                                  ),
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontSize: isSmallScreen ? 11.0 : null,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                              if (wordCount != null && durationSeconds != null)
                                SizedBox(width: isSmallScreen ? AppSpacing.smMd : AppSpacing.md),
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
}

/// Formats duration in seconds to a human-readable string.
String formatDuration(int seconds) {
  return TimeFormatter.formatSecondsClock(seconds, padHours: false);
}
