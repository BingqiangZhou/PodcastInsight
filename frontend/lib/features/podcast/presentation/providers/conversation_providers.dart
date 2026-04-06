import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_ai_assistant/features/podcast/data/models/podcast_conversation_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:riverpod/src/providers/async_notifier.dart';
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
