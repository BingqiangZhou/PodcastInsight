import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations_extension.dart';
import 'podcast_transcription_model.dart';

/// Extension on [TranscriptionStatus] to provide localized status descriptions
extension TranscriptionStatusLocalization on TranscriptionStatus {
  /// Get the localized status description for this transcription status
  String getLocalizedDescription(BuildContext context) {
    final l10n = context.l10n;
    switch (this) {
      case TranscriptionStatus.pending:
        return l10n.transcription_status_pending;
      case TranscriptionStatus.downloading:
        return l10n.transcription_status_downloading;
      case TranscriptionStatus.converting:
        return l10n.transcription_status_converting;
      case TranscriptionStatus.transcribing:
        return l10n.transcription_status_transcribing;
      case TranscriptionStatus.processing:
        return l10n.transcription_status_processing;
      case TranscriptionStatus.completed:
        return l10n.transcription_status_completed;
      case TranscriptionStatus.failed:
        return l10n.transcription_status_failed;
    }
  }
}

/// Extension on [PodcastTranscriptionResponse] to provide localized status descriptions
extension PodcastTranscriptionResponseLocalization on PodcastTranscriptionResponse {
  /// Get the localized status description for this transcription
  String getLocalizedStatusDescription(BuildContext context) {
    return transcriptionStatus.getLocalizedDescription(context);
  }
}
