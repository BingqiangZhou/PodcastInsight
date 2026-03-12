import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/podcast_playback_model.dart';
import '../../core/utils/summary_sanitizer.dart';
import 'podcast_providers.dart';

// Summary state providers for each episode
final summaryStateProviders =
    <int, NotifierProvider<SummaryNotifier, SummaryState>>{};

/// Get or create a summary state provider for a specific episode
NotifierProvider<SummaryNotifier, SummaryState> getSummaryProvider(
  int episodeId,
) {
  return summaryStateProviders.putIfAbsent(
    episodeId,
    () => NotifierProvider<SummaryNotifier, SummaryState>(
      () => SummaryNotifier(episodeId),
    ),
  );
}

// Provider for available summary models
final availableModelsProvider = FutureProvider<List<SummaryModelInfo>>((
  ref,
) async {
  final repository = ref.watch(podcastRepositoryProvider);
  try {
    return await repository.getSummaryModels();
  } catch (e) {
    return [];
  }
});

/// Summary state class
class SummaryState {
  static const Object _unset = Object();

  final String? summary;
  final String? modelUsed;
  final double? processingTime;
  final int? wordCount;
  final DateTime? generatedAt;
  final bool isLoading;
  final String? errorMessage;

  const SummaryState({
    this.summary,
    this.modelUsed,
    this.processingTime,
    this.wordCount,
    this.generatedAt,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get hasError => errorMessage != null;
  bool get hasSummary => summary != null && summary!.isNotEmpty;
  bool get isSuccess => hasSummary && !isLoading && !hasError;

  SummaryState copyWith({
    Object? summary = _unset,
    Object? modelUsed = _unset,
    Object? processingTime = _unset,
    Object? wordCount = _unset,
    Object? generatedAt = _unset,
    bool? isLoading,
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
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

/// Notifier for managing summary state
class SummaryNotifier extends Notifier<SummaryState> {
  static const Duration _pollInterval = Duration(seconds: 5);
  static const int _maxPollAttempts = 90;

  final int episodeId;
  Timer? _pollTimer;
  bool _isPolling = false;
  bool _pollInFlight = false;
  int _pollAttempts = 0;

  SummaryNotifier(this.episodeId);

  @override
  SummaryState build() {
    ref.onDispose(_stopPolling);
    return const SummaryState();
  }

  /// Generate AI summary
  Future<void> generateSummary({
    String? model,
    bool forceRegenerate = true,
  }) async {
    _stopPolling();
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final repository = ref.read(podcastRepositoryProvider);
      await repository.generateSummary(
        episodeId: episodeId,
        forceRegenerate: forceRegenerate,
        summaryModel: model,
      );
      _pollEpisodeDetailUntilSummarySync();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      _stopPolling();
    }
  }

  /// Regenerate summary
  Future<void> regenerateSummary({String? model}) async {
    return generateSummary(model: model, forceRegenerate: true);
  }

  /// Update summary from existing data (used when loading episode detail)
  void updateSummary(
    String summary, {
    String? modelUsed,
    double? processingTime,
    DateTime? generatedAt,
  }) {
    _stopPolling();
    final failureReason = SummarySanitizer.detectFailureReason(summary);
    if (failureReason != null) {
      state = state.copyWith(isLoading: false, errorMessage: failureReason);
      return;
    }
    final cleanedSummary = SummarySanitizer.clean(summary);
    state = SummaryState(
      summary: cleanedSummary,
      modelUsed: modelUsed ?? state.modelUsed,
      processingTime: processingTime ?? state.processingTime,
      wordCount: cleanedSummary.length,
      generatedAt: generatedAt ?? state.generatedAt,
      isLoading: false,
      errorMessage: null,
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
      ref.invalidate(episodeDetailProvider(episodeId));
      final episode = await ref.read(episodeDetailProvider(episodeId).future);
      final summary = episode?.aiSummary;
      final summaryStatus = episode?.summaryStatus;
      if (summaryStatus == 'summary_failed') {
        state = state.copyWith(
          isLoading: false,
          errorMessage:
              episode?.summaryErrorMessage ?? 'Summary generation failed',
        );
        _stopPolling();
        return;
      }

      if (summaryStatus == 'summarized' &&
          summary != null &&
          summary.isNotEmpty) {
        updateSummary(
          summary,
          modelUsed: episode?.summaryModelUsed,
          processingTime: episode?.summaryProcessingTime,
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
