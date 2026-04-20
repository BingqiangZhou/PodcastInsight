import 'dart:async';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_ai_assistant/features/podcast/core/utils/html_sanitizer.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_conversation_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_playback_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_transcription_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_core_providers.dart';
import 'package:riverpod/src/providers/async_notifier.dart';
import 'package:riverpod/src/providers/future_provider.dart';
import 'package:riverpod/src/providers/notifier.dart';

// === Providers ===
// All three providers use family.autoDispose for automatic lifecycle management.
// Each episode ID gets its own notifier instance that is cleaned up when no
// longer watched.

/// Episode-scoped conversation (messages) provider.
final NotifierProviderFamily<ConversationNotifier, ConversationState, int> conversationProvider = NotifierProvider.autoDispose
    .family<ConversationNotifier, ConversationState, int>(
  ConversationNotifier.new,
);

/// Episode-scoped session list provider.
final AsyncNotifierProviderFamily<SessionListNotifier, List<ConversationSession>, int> sessionListProvider = AsyncNotifierProvider.autoDispose
    .family<SessionListNotifier, List<ConversationSession>, int>(
  SessionListNotifier.new,
);

/// Episode-scoped current session ID provider.
final NotifierProviderFamily<SessionIdNotifier, int?, int> currentSessionIdProvider = NotifierProvider.autoDispose
    .family<SessionIdNotifier, int?, int>(
  SessionIdNotifier.new,
);

class SessionIdNotifier extends Notifier<int?> {
  SessionIdNotifier(this.episodeId);

  final int episodeId;

  @override
  int? build() {
    return null;
  }

  void set(int? id) => state = id;
}

// === State Classes ===

/// Conversation state class
class ConversationState extends Equatable { // Active session ID

  const ConversationState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.errorMessage,
    this.currentSendingTurn,
    this.sessionId,
  });
  final List<PodcastConversationMessage> messages;
  final bool isLoading;
  final bool isSending;
  final String? errorMessage;
  final int? currentSendingTurn;
  final int? sessionId;

  bool get hasError => errorMessage != null;
  bool get hasMessages => messages.isNotEmpty;
  bool get isEmpty => messages.isEmpty;
  bool get isReady => !isLoading && !isSending;

  // Sentinel to distinguish "not provided" from explicit null
  static const _unsetErrorMessage = Object();

  ConversationState copyWith({
    List<PodcastConversationMessage>? messages,
    bool? isLoading,
    bool? isSending,
    Object? errorMessage = _unsetErrorMessage,
    int? currentSendingTurn,
    int? sessionId,
  }) {
    return ConversationState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      errorMessage: identical(errorMessage, _unsetErrorMessage)
          ? this.errorMessage
          : errorMessage as String?,
      currentSendingTurn: currentSendingTurn ?? this.currentSendingTurn,
      sessionId: sessionId ?? this.sessionId,
    );
  }

  @override
  List<Object?> get props => [
        messages,
        isLoading,
        isSending,
        errorMessage,
        currentSendingTurn,
        sessionId,
      ];
}

// === Notifiers ===

/// Notifier for managing the list of sessions
class SessionListNotifier extends AsyncNotifier<List<ConversationSession>> {

  SessionListNotifier(this.episodeId);
  final int episodeId;

  @override
  Future<List<ConversationSession>> build() async {
    return _loadSessions();
  }

  Future<List<ConversationSession>> _loadSessions() async {
    final repository = ref.read(podcastRepositoryProvider);
    final response = await repository.getConversationSessions(episodeId: episodeId);

    // Automatically set current session if not set and we have sessions
    final currentSessionId = ref.read(currentSessionIdProvider(episodeId));
    if (currentSessionId == null && response.sessions.isNotEmpty) {
       // Defer the state update to avoid build-phase modification issues
       Future(() {
         ref.read(currentSessionIdProvider(episodeId).notifier).set(response.sessions.first.id);
       });
    }

    return response.sessions;
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_loadSessions);
  }

  /// Create a new session and switch to it.
  /// Throws on failure so callers can show error feedback.
  Future<ConversationSession?> createSession({String? title}) async {
    try {
      final repository = ref.read(podcastRepositoryProvider);
      final session = await repository.createConversationSession(
        episodeId: episodeId,
        title: title,
      );

      // Refresh list
      await refresh();

      // Switch to new session
      ref.read(currentSessionIdProvider(episodeId).notifier).set(session.id);

      return session;
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a session by ID.
  /// Throws on failure so callers can show error feedback.
  Future<void> deleteSession(int sessionId) async {
    try {
      final repository = ref.read(podcastRepositoryProvider);
      await repository.deleteConversationSession(
          episodeId: episodeId, sessionId: sessionId);

      // Refresh list
      await refresh();

      // If deleted session was active, switch to another or null
      final currentSessionId = ref.read(currentSessionIdProvider(episodeId));
      if (currentSessionId == sessionId) {
        final sessions = state.value ?? [];
        if (sessions.isNotEmpty) {
           ref.read(currentSessionIdProvider(episodeId).notifier).set(sessions.first.id);
        } else {
           ref.read(currentSessionIdProvider(episodeId).notifier).set(null);
        }
      }
    } catch (e) {
      rethrow;
    }
  }
}

/// Notifier for managing conversation state (messages)
class ConversationNotifier extends Notifier<ConversationState> {

  ConversationNotifier(this.episodeId);
  final int episodeId;
  Completer<void>? _loadCompleter;
  int? _loadingSessionId;

  @override
  ConversationState build() {
    ref.onDispose(() {
      _loadCompleter?.completeError('Disposed');
      _loadCompleter = null;
    });

    // Watch current session ID to reload on change
    final sessionId = ref.watch(currentSessionIdProvider(episodeId));

    // Load conversation history when building or when session changes
    _loadHistory(sessionId);

    return ConversationState(
      isLoading: true,
      sessionId: sessionId,
    );
  }

  /// Load conversation history from backend
  Future<void> _loadHistory(int? sessionId) async {
    if (sessionId == null) return;

    // Cancel if session changed since last load started
    if (_loadingSessionId != null && _loadingSessionId != sessionId) {
      _loadCompleter?.completeError('Session changed');
      _loadCompleter = null;
    }

    // Skip if already loading the SAME session
    final completer = _loadCompleter;
    if (completer != null && !completer.isCompleted) return;

    _loadingSessionId = sessionId;
    _loadCompleter = Completer<void>();

    try {
      final repository = ref.read(podcastRepositoryProvider);
      final response = await repository.getConversationHistory(
        episodeId: episodeId,
        sessionId: sessionId,
      );

      state = ConversationState(
        messages: response.messages,
        sessionId: sessionId,
      );
      _loadCompleter?.complete();
    } catch (e) {
      state = ConversationState(
        errorMessage: e.toString(),
        sessionId: sessionId,
      );
      _loadCompleter?.completeError(e);
    } finally {
      _loadCompleter = null;
      _loadingSessionId = null;
    }
  }

  /// Refresh conversation history
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final sessionId = ref.read(currentSessionIdProvider(episodeId));
    await _loadHistory(sessionId);
  }

  /// Send a message to AI
  Future<void> sendMessage(String message, {String? modelName}) async {
    // Current session
    final sessionId = ref.read(currentSessionIdProvider(episodeId));

    // Optimistically add user message to state
    final userTurn = state.messages.length;
    final optimisticUserMessage = PodcastConversationMessage(
      id: -userTurn, // Temporary negative ID
      role: 'user',
      content: message,
      conversationTurn: userTurn,
      createdAt: DateTime.now().toIso8601String(),
    );

    state = state.copyWith(
      messages: [...state.messages, optimisticUserMessage],
      isSending: true,
      currentSendingTurn: userTurn,
      errorMessage: null,
    );

    try {
      final repository = ref.read(podcastRepositoryProvider);
      await repository.sendConversationMessage(
        episodeId: episodeId,
        request: PodcastConversationSendRequest(
          message: message,
          modelName: modelName,
          sessionId: sessionId,
        ),
      );

      // Send succeeded, reload full conversation history from server to ensure
      // both user message and AI reply are correctly displayed.
      final historyResponse = await repository.getConversationHistory(
        episodeId: episodeId,
        sessionId: sessionId, // This might be null if a default session was created
      );

      // Store the session ID if it was returned (implies new session created/assigned)
      if (sessionId == null && historyResponse.sessionId != null) {
          ref.read(currentSessionIdProvider(episodeId).notifier).set(historyResponse.sessionId);
          // Refresh session list to show new session
          ref.read(sessionListProvider(episodeId).notifier).refresh();
      }

      state = ConversationState(
        messages: historyResponse.messages,
        sessionId: historyResponse.sessionId ?? sessionId,
      );
    } catch (e) {
      // Remove optimistic message on error
      final updatedMessages = List<PodcastConversationMessage>.from(state.messages);
      updatedMessages.removeWhere((m) => m.id < 0);

      state = ConversationState(
        messages: updatedMessages,
        errorMessage: e.toString(),
        sessionId: sessionId,
      );
    }
  }

  /// Clear conversation history for current session
  Future<void> clearHistory() async {
    final sessionId = ref.read(currentSessionIdProvider(episodeId));
    state = state.copyWith(isLoading: true);

    try {
      final repository = ref.read(podcastRepositoryProvider);
      await repository.clearConversationHistory(
        episodeId: episodeId,
        sessionId: sessionId,
      );

      state = ConversationState(
        sessionId: sessionId,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Start a new chat (convenience method)
  Future<void> startNewChat() async {
      // Create a new session
      final sessionListNotifier = ref.read(sessionListProvider(episodeId).notifier);
      await sessionListNotifier.createSession();
      // createSession handles switching
  }

  /// Clear error
  void clearError() {
    if (state.hasError) {
      state = state.copyWith(errorMessage: null);
    }
  }

  /// Get last assistant message
  PodcastConversationMessage? get lastAssistantMessage {
    for (var i = state.messages.length - 1; i >= 0; i--) {
      if (state.messages[i].isAssistant) {
        return state.messages[i];
      }
    }
    return null;
  }

  /// Get conversation title (first user message)
  String get conversationTitle {
    final firstUserMessage = state.messages.isNotEmpty && state.messages.first.isUser
        ? state.messages.first.content
        : 'Conversation';
    // Truncate if too long
    if (firstUserMessage.length > 30) {
      return '${firstUserMessage.substring(0, 30)}...';
    }
    return firstUserMessage;
  }
}

// === Transcription Providers ===

/// Episode-scoped transcription provider with automatic lifecycle management.
///
/// Uses family.autoDispose so each episode gets its own notifier that is
/// automatically cleaned up when no longer watched.
final AsyncNotifierProviderFamily<TranscriptionNotifier, PodcastTranscriptionResponse?, int> transcriptionProvider = AsyncNotifierProvider.autoDispose
    .family<TranscriptionNotifier, PodcastTranscriptionResponse?, int>(
  TranscriptionNotifier.new,
);

/// Notifier for managing transcription state
class TranscriptionNotifier extends AsyncNotifier<PodcastTranscriptionResponse?> {

  TranscriptionNotifier(this.episodeId);
  final int episodeId;

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

// === Summary Providers ===

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
