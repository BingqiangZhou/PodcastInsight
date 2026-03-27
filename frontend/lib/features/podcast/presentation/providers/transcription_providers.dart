import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/podcast_transcription_model.dart';
import 'podcast_providers.dart';

/// Episode-scoped transcription provider with automatic lifecycle management.
///
/// Uses family.autoDispose so each episode gets its own notifier that is
/// automatically cleaned up when no longer watched.
final transcriptionProvider = AsyncNotifierProvider.autoDispose
    .family<TranscriptionNotifier, PodcastTranscriptionResponse?, int>(
  (int episodeId) => TranscriptionNotifier(episodeId),
);

/// Notifier for managing transcription state
class TranscriptionNotifier extends AsyncNotifier<PodcastTranscriptionResponse?> {
  final int episodeId;

  TranscriptionNotifier(this.episodeId);

  Timer? _pollTimer;
  bool _isDisposed = false;

  @override
  Future<PodcastTranscriptionResponse?> build() async {
    _isDisposed = false;
    // Cancel timer when provider is disposed
    ref.onDispose(() {
      _isDisposed = true;
      _pollTimer?.cancel();
      _pollTimer = null;
    });
    return null;
  }

  /// Load transcription for the episode
  Future<void> loadTranscription() async {
    if (_isDisposed) return;
    state = const AsyncValue.loading();

    try {
      final repository = ref.read(podcastRepositoryProvider);
      final transcription = await repository.getTranscription(episodeId);
      if (_isDisposed) return;
      state = AsyncValue.data(transcription);

      // If transcription is in progress, start polling
      if (transcription != null && transcription.isProcessing) {
        _startPolling();
      }
    } catch (error, stackTrace) {
      if (_isDisposed) return;
      if (error is DioException && error.response?.statusCode == 404) {
         state = const AsyncValue.data(null);
      } else {
         state = AsyncValue.error(error, stackTrace);
      }
    }
  }

  /// Check if transcription exists, if not start it. Always load/monitor.
  Future<void> checkOrStartTranscription() async {
    // OPTIMIZATION: Backend is now idempotent (returns existing task if found).
    // So we can just call startTranscription directly without checking first (1 round-trip instead of 2).
    await startTranscription();
  }

  /// Start transcription for the episode
  Future<void> startTranscription() async {
    if (_isDisposed) return;
    state = const AsyncValue.loading();

    try {
      final repository = ref.read(podcastRepositoryProvider);
      final transcription = await repository.startTranscription(episodeId);
      if (_isDisposed) return;
      state = AsyncValue.data(transcription);

      _startPolling();
    } catch (error, stackTrace) {
      if (_isDisposed) return;
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Refresh transcription status
  Future<void> refreshStatus() async {
    if (_isDisposed) return;
    // If we have no data yet, don't just refresh status, better to load
    if (state.value == null) {
      await loadTranscription();
      return;
    }

    try {
      final repository = ref.read(podcastRepositoryProvider);
      // Use getTranscription to poll status as it returns the full task info including status
      final transcription = await repository.getTranscription(episodeId);
      if (_isDisposed) return;
      state = AsyncValue.data(transcription);

      // Stop polling if completed or failed
      if (transcription != null && (transcription.isCompleted || transcription.isFailed)) {
        _stopPolling();
      }
    } catch (error, stackTrace) {
      if (_isDisposed) return;
      // Don't set state to error on poll fail, just log?
      // Or set error? If we set error, UI shows error.
      // Maybe specific error handling for polling?
      // For now, let's keep it simple.
      state = AsyncValue.error(error, stackTrace);
      _stopPolling();
    }
  }

  void _startPolling() {
    _stopPolling();
    // OPTIMIZATION: Poll every 5 seconds to reduce API calls by 40%
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      refreshStatus();
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Delete transcription
  Future<void> deleteTranscription() async {
    if (_isDisposed) return;
    _stopPolling();
    try {
      final repository = ref.read(podcastRepositoryProvider);
      await repository.deleteTranscription(episodeId);
      if (_isDisposed) return;
      state = const AsyncValue.data(null);
    } catch (error, stackTrace) {
      if (_isDisposed) return;
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Reset state
  void reset() {
    _stopPolling();
    state = const AsyncValue.data(null);
  }
}

// Provider for transcription search query
final transcriptionSearchQueryProvider = NotifierProvider<TranscriptionSearchQueryNotifier, String>(TranscriptionSearchQueryNotifier.new);

// Provider for transcription search results
final transcriptionSearchResultsProvider = NotifierProvider<TranscriptionSearchResultsNotifier, List<String>>(TranscriptionSearchResultsNotifier.new);

/// Notifier for managing transcription search query
class TranscriptionSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void updateQuery(String query) => state = query;
  void clearQuery() => state = '';
}

/// Notifier for managing transcription search results
class TranscriptionSearchResultsNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => [];

  void setResults(List<String> results) => state = results;
  void clearResults() => state = [];
}

// Helper functions for search
void updateTranscriptionSearchQuery(WidgetRef ref, String query) {
  ref.read(transcriptionSearchQueryProvider.notifier).updateQuery(query);
}

void clearTranscriptionSearchQuery(WidgetRef ref) {
  ref.read(transcriptionSearchQueryProvider.notifier).clearQuery();
  ref.read(transcriptionSearchResultsProvider.notifier).clearResults();
}

void searchTranscript(WidgetRef ref, String content, String query) {
  if (query.isEmpty || content.isEmpty) {
    ref.read(transcriptionSearchResultsProvider.notifier).clearResults();
    return;
  }

  final lines = content.split('\n');
  final results = <String>[];

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isNotEmpty && line.toLowerCase().contains(query.toLowerCase())) {
      results.add(line);
    }
  }

  ref.read(transcriptionSearchResultsProvider.notifier).setResults(results);
}

// Helper function to get transcription text content
String? getTranscriptionText(PodcastTranscriptionResponse? transcription) {
  return transcription?.displayContent;
}

// Helper function to check if transcription is processing
bool isTranscriptionProcessing(PodcastTranscriptionResponse? transcription) {
  return transcription?.isProcessing == true;
}

// Helper function to check if transcription is completed
bool isTranscriptionCompleted(PodcastTranscriptionResponse? transcription) {
  return transcription?.isCompleted == true;
}

// Helper function to check if transcription failed
bool isTranscriptionFailed(PodcastTranscriptionResponse? transcription) {
  return transcription?.isFailed == true;
}

// Helper function to get transcription progress
double getTranscriptionProgress(PodcastTranscriptionResponse? transcription) {
  return transcription?.progressPercentage ?? 0.0;
}