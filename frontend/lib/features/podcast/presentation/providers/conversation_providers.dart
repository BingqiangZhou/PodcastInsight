import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/podcast_conversation_model.dart';
import 'podcast_providers.dart';

// === Providers ===

// Conversation state providers for each episode (Messages)
final conversationStateProviders =
    <int, NotifierProvider<ConversationNotifier, ConversationState>>{};

/// Get or create a conversation state provider for a specific episode
NotifierProvider<ConversationNotifier, ConversationState> getConversationProvider(
    int episodeId) {
  return conversationStateProviders.putIfAbsent(
    episodeId,
    () => NotifierProvider<ConversationNotifier, ConversationState>(
        () => ConversationNotifier(episodeId)),
  );
}

// Session List Providers
final sessionListProviders = <int,
    AsyncNotifierProvider<SessionListNotifier, List<ConversationSession>>>{};

AsyncNotifierProvider<SessionListNotifier, List<ConversationSession>>
    getSessionListProvider(int episodeId) {
  return sessionListProviders.putIfAbsent(
    episodeId,
    () => AsyncNotifierProvider<SessionListNotifier, List<ConversationSession>>(
        () => SessionListNotifier(episodeId)),
  );
}

// Current Session ID Providers
final currentSessionIdProviders = <int, NotifierProvider<SessionIdNotifier, int?>>{};

NotifierProvider<SessionIdNotifier, int?> getCurrentSessionIdProvider(int episodeId) {
  return currentSessionIdProviders.putIfAbsent(
    episodeId,
    () => NotifierProvider<SessionIdNotifier, int?>(() => SessionIdNotifier()),
  );
}

class SessionIdNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void set(int? id) => state = id;
}

// === State Classes ===

/// Conversation state class
class ConversationState {
  final List<PodcastConversationMessage> messages;
  final bool isLoading;
  final bool isSending;
  final String? errorMessage;
  final int? currentSendingTurn;
  final int? sessionId; // Active session ID

  const ConversationState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.errorMessage,
    this.currentSendingTurn,
    this.sessionId,
  });

  bool get hasError => errorMessage != null;
  bool get hasMessages => messages.isNotEmpty;
  bool get isEmpty => messages.isEmpty;
  bool get isReady => !isLoading && !isSending;

  ConversationState copyWith({
    List<PodcastConversationMessage>? messages,
    bool? isLoading,
    bool? isSending,
    String? errorMessage,
    int? currentSendingTurn,
    int? sessionId,
  }) {
    return ConversationState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      errorMessage: errorMessage ?? this.errorMessage,
      currentSendingTurn: currentSendingTurn ?? this.currentSendingTurn,
      sessionId: sessionId ?? this.sessionId,
    );
  }
}

// === Notifiers ===

/// Notifier for managing the list of sessions
class SessionListNotifier extends AsyncNotifier<List<ConversationSession>> {
  final int episodeId;

  SessionListNotifier(this.episodeId);

  @override
  Future<List<ConversationSession>> build() async {
    return _loadSessions();
  }

  Future<List<ConversationSession>> _loadSessions() async {
    final repository = ref.read(podcastRepositoryProvider);
    final response = await repository.getConversationSessions(episodeId: episodeId);
    
    // Automatically set current session if not set and we have sessions
    final currentSessionId = ref.read(getCurrentSessionIdProvider(episodeId));
    if (currentSessionId == null && response.sessions.isNotEmpty) {
       // Defer the state update to avoid build-phase modification issues
       Future(() {
         ref.read(getCurrentSessionIdProvider(episodeId).notifier).set(response.sessions.first.id);
       });
    }
    
    return response.sessions;
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _loadSessions());
  }

  /// Create a new session and switch to it
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
      ref.read(getCurrentSessionIdProvider(episodeId).notifier).set(session.id);
      
      return session;
    } catch (e) {
      // Handle error (maybe show toast via a provider or throw)
      return null;
    }
  }

  Future<void> deleteSession(int sessionId) async {
    try {
      final repository = ref.read(podcastRepositoryProvider);
      await repository.deleteConversationSession(
          episodeId: episodeId, sessionId: sessionId);
          
      // Refresh list
      await refresh();
      
      // If deleted session was active, switch to another or null
      final currentSessionId = ref.read(getCurrentSessionIdProvider(episodeId));
      if (currentSessionId == sessionId) {
        final sessions = state.value ?? [];
        if (sessions.isNotEmpty) {
           ref.read(getCurrentSessionIdProvider(episodeId).notifier).set(sessions.first.id);
        } else {
           ref.read(getCurrentSessionIdProvider(episodeId).notifier).set(null);
        }
      }
    } catch (e) {
      // Handle error
    }
  }
}

/// Notifier for managing conversation state (messages)
class ConversationNotifier extends Notifier<ConversationState> {
  final int episodeId;

  ConversationNotifier(this.episodeId);

  @override
  ConversationState build() {
    // Watch current session ID to reload on change
    final sessionId = ref.watch(getCurrentSessionIdProvider(episodeId));
    
    // Load conversation history when building or when session changes
    _loadHistory(sessionId);
    
    return ConversationState(
      isLoading: true,
      sessionId: sessionId,
    );
  }

  /// Load conversation history from backend
  Future<void> _loadHistory(int? sessionId) async {
    try {
      final repository = ref.read(podcastRepositoryProvider);
      final response = await repository.getConversationHistory(
        episodeId: episodeId,
        sessionId: sessionId,
      );

      state = ConversationState(
        messages: response.messages,
        isLoading: false,
        sessionId: sessionId,
      );
    } catch (e) {
      state = ConversationState(
        messages: const [],
        isLoading: false,
        errorMessage: e.toString(),
        sessionId: sessionId,
      );
    }
  }

  /// Refresh conversation history
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final sessionId = ref.read(getCurrentSessionIdProvider(episodeId));
    await _loadHistory(sessionId);
  }

  /// Send a message to AI
  Future<void> sendMessage(String message, {String? modelName}) async {
    // Current session
    final sessionId = ref.read(getCurrentSessionIdProvider(episodeId));

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

      // 发送成功后从服务器重新加载完整对话历史，确保用户消息和AI回复都正确显示
      final historyResponse = await repository.getConversationHistory(
        episodeId: episodeId,
        sessionId: sessionId, // This might be null if a default session was created
      );

      // Store the session ID if it was returned (implies new session created/assigned)
      if (sessionId == null && historyResponse.sessionId != null) {
          ref.read(getCurrentSessionIdProvider(episodeId).notifier).set(historyResponse.sessionId);
          // Refresh session list to show new session
          ref.read(getSessionListProvider(episodeId).notifier).refresh();
      }

      state = ConversationState(
        messages: historyResponse.messages,
        isSending: false,
        currentSendingTurn: null,
        sessionId: historyResponse.sessionId ?? sessionId,
      );
    } catch (e) {
      // Remove optimistic message on error
      final updatedMessages = List<PodcastConversationMessage>.from(state.messages);
      updatedMessages.removeWhere((m) => m.id < 0);

      state = ConversationState(
        messages: updatedMessages,
        isSending: false,
        currentSendingTurn: null,
        errorMessage: e.toString(),
        sessionId: sessionId,
      );
    }
  }

  /// Clear conversation history for current session
  Future<void> clearHistory() async {
    final sessionId = ref.read(getCurrentSessionIdProvider(episodeId));
    state = state.copyWith(isLoading: true);

    try {
      final repository = ref.read(podcastRepositoryProvider);
      await repository.clearConversationHistory(
        episodeId: episodeId, 
        sessionId: sessionId,
      );

      state = ConversationState(
        messages: [],
        isLoading: false,
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
      final sessionListNotifier = ref.read(getSessionListProvider(episodeId).notifier);
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
