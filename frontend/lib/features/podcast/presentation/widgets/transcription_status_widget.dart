import 'package:flutter/material.dart';

import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/theme/app_theme.dart';
import 'package:personal_ai_assistant/core/widgets/top_floating_notice.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_transcription_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/conversation_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/transcription/transcript_result_widget.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/transcription/transcription_progress_widget.dart';

class TranscriptionStatusWidget extends ConsumerWidget {

  const TranscriptionStatusWidget({
    required this.episodeId, super.key,
    this.transcription,
  });
  final int episodeId;
  final PodcastTranscriptionResponse? transcription;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = transcription;
    if (t == null) {
      return _buildNotStartedState(context, ref);
    }

    switch (t.transcriptionStatus) {
      case TranscriptionStatus.pending:
        return const PendingStateWidget();
      case TranscriptionStatus.downloading:
      case TranscriptionStatus.converting:
      case TranscriptionStatus.transcribing:
      case TranscriptionStatus.processing:
        return ProcessingStateWidget(transcription: t);
      case TranscriptionStatus.completed:
        return CompletedStateWidget(
          transcription: t,
          onDelete: () => _deleteTranscription(ref),
          onView: () => _viewTranscription(ref),
        );
      case TranscriptionStatus.failed:
        return FailedStateWidget(
          transcription: t,
          onDelete: () => _deleteTranscription(ref),
          onRetry: () => _retryTranscription(ref),
        );
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
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(ext.cardRadius),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.15),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(context.spacing.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: const BorderRadius.all(Radius.circular(40)),
              ),
              child: Icon(Icons.transcribe, size: 40, color: accentColor),
            ),

            SizedBox(height: context.spacing.md),

            // Title
            Text(
              l10n.transcription_start_title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),

            SizedBox(height: context.spacing.sm),

            // Description
            Text(
              l10n.transcription_start_desc,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),

            SizedBox(height: context.spacing.lg),

            // Start button with enhanced feedback
            SizedBox(
              width: double.infinity,
              child: AdaptiveButton(
                onPressed: () => _startTranscriptionWithFeedback(ref, context),
                icon: const Icon(Icons.play_arrow),
                padding: EdgeInsets.symmetric(vertical: context.spacing.smMd),
                child: Text(l10n.transcription_start_button),
              ),
            ),

            SizedBox(height: context.spacing.smMd),

            // Auto-start info text
            Container(
              padding: EdgeInsets.symmetric(horizontal: context.spacing.smMd, vertical: context.spacing.sm),
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
                  SizedBox(width: context.spacing.sm),
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
}
