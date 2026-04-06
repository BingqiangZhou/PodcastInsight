import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/podcast/core/utils/html_sanitizer.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_playback_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:riverpod/src/providers/notifier.dart';

/// Episode-scoped summary provider with automatic lifecycle management.
///
/// Uses family.autoDispose so each episode gets its own notifier that is
/// automatically cleaned up when no longer watched.
final NotifierProviderFamily<SummaryNotifier, SummaryState, int> summaryProvider = NotifierProvider.autoDispose
    .family<SummaryNotifier, SummaryState, int>(
  SummaryNotifier.new,
);

// Provider for available summary models
final availableModelsProvider = FutureProvider<List<SummaryModelInfo>>((
  ref,
) async {
  final repository = ref.read(podcastRepositoryProvider);
  return repository.getSummaryModels();
});

/// Summary state class
class SummaryState extends Equatable {

  const SummaryState({
    this.summary,
    this.modelUsed,
    this.processingTime,
    this.wordCount,
    this.generatedAt,
    this.isLoading = false,
    this.hidePersistedSummary = false,
    this.errorMessage,
  });
  static const Object _unset = Object();

  final String? summary;
  final String? modelUsed;
  final double? processingTime;
  final int? wordCount;
  final DateTime? generatedAt;
  final bool isLoading;
  final bool hidePersistedSummary;
  final String? errorMessage;

  bool get hasError => errorMessage != null;
  bool get hasSummary => summary?.isNotEmpty ?? false;
  bool get isSuccess => hasSummary && !isLoading && !hasError;

  SummaryState copyWith({
    Object? summary = _unset,
    Object? modelUsed = _unset,
    Object? processingTime = _unset,
    Object? wordCount = _unset,
    Object? generatedAt = _unset,
    bool? isLoading,
    bool? hidePersistedSummary,
    Object? errorMessage = _unset,
  }) {
    return SummaryState(
      summary: identical(summary, _unset) ? this.summary : summary as String?,
      modelUsed: identical(modelUsed, _unset)
          ? this.modelUsed
          : modelUsed as String?,
      processingTime: identical(processingTime, _unset)
          ? this.processingTime
          : processingTime as double?,
      wordCount: identical(wordCount, _unset)
          ? this.wordCount
          : wordCount as int?,
      generatedAt: identical(generatedAt, _unset)
          ? this.generatedAt
          : generatedAt as DateTime?,
      isLoading: isLoading ?? this.isLoading,
      hidePersistedSummary: hidePersistedSummary ?? this.hidePersistedSummary,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  @override
  List<Object?> get props => [
        summary,
        modelUsed,
        processingTime,
        wordCount,
        generatedAt,
        isLoading,
        hidePersistedSummary,
        errorMessage,
      ];
}

/// Notifier for managing summary state
class SummaryNotifier extends Notifier<SummaryState> {

  SummaryNotifier(this.episodeId);
  static const Duration _pollInterval = Duration(seconds: 5);
  static const int _maxPollAttempts = 90;

  final int episodeId;
  Timer? _pollTimer;
  bool _isPolling = false;
  bool _pollInFlight = false;
  int _pollAttempts = 0;

  @override
  SummaryState build() {
    ref.onDispose(_stopPolling);
    return const SummaryState();
  }

  /// Generate AI summary
  Future<PodcastSummaryStartResponse?> generateSummary({
    String? model,
    bool forceRegenerate = true,
  }) async {
    _stopPolling();
    state = state.copyWith(
      summary: null,
      isLoading: true,
      hidePersistedSummary: true,
      errorMessage: null,
    );

    try {
      final repository = ref.read(podcastRepositoryProvider);
      final response = await repository.generateSummary(
        episodeId: episodeId,
        forceRegenerate: forceRegenerate,
        summaryModel: model,
      );
      _pollEpisodeDetailUntilSummarySync();
      return response;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      _stopPolling();
      return null;
    }
  }

  /// Regenerate summary
  Future<PodcastSummaryStartResponse?> regenerateSummary({
    String? model,
  }) async {
    return generateSummary(model: model);
  }

  /// Update summary from existing data (used when loading episode detail)
  void updateSummary(
    String summary, {
    String? modelUsed,
    double? processingTime,
    DateTime? generatedAt,
  }) {
    _stopPolling();
    final failureReason = HtmlSanitizer.detectFailureReason(summary);
    if (failureReason != null) {
      state = state.copyWith(isLoading: false, errorMessage: failureReason);
      return;
    }
    final cleanedSummary = HtmlSanitizer.cleanModelReasoning(summary);
    state = SummaryState(
      summary: cleanedSummary,
      modelUsed: modelUsed ?? state.modelUsed,
      processingTime: processingTime ?? state.processingTime,
      wordCount: cleanedSummary.length,
      generatedAt: generatedAt ?? state.generatedAt,
    );
  }

  /// Clear error
  void clearError() {
    if (state.hasError) {
      state = state.copyWith(errorMessage: null);
    }
  }

  void _pollEpisodeDetailUntilSummarySync() {
    _stopPolling();
    _isPolling = true;
    _pollAttempts = 0;
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      unawaited(_syncFromEpisodeDetail());
    });
    unawaited(_syncFromEpisodeDetail());
  }

  Future<void> _syncFromEpisodeDetail() async {
    if (!_isPolling || _pollInFlight) {
      return;
    }

    _pollInFlight = true;
    try {
      // Read directly from the repository to check status without
      // invalidating the provider, which would cause a full re-fetch
      // and disrupt any UI watching the episode detail provider.
      final repository = ref.read(podcastRepositoryProvider);
      final episode = await repository.getEpisode(episodeId);
      final summary = episode.aiSummary;
      final summaryStatus = episode.summaryStatus;
      if (summaryStatus == 'summary_failed') {
        state = state.copyWith(
          isLoading: false,
          errorMessage:
              episode.summaryErrorMessage ?? 'Summary generation failed',
        );
        _stopPolling();
        return;
      }

      if (summaryStatus == 'summarized' &&
          summary != null &&
          summary.isNotEmpty) {
        updateSummary(
          summary,
          modelUsed: episode.summaryModelUsed,
          processingTime: episode.summaryProcessingTime,
        );
        return;
      }

      _pollAttempts += 1;
      if (_pollAttempts >= _maxPollAttempts) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Summary generation is taking longer than expected.',
        );
        _stopPolling();
      }
    } finally {
      _pollInFlight = false;
    }
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _isPolling = false;
    _pollInFlight = false;
    _pollAttempts = 0;
  }
}
