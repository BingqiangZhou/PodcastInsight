import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_conversation_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/conversation_providers.dart';

void main() {
  group('ConversationProviders', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('conversationProvider is autoDispose family keyed by episodeId', () {
      // Verify the provider is a family provider by checking different keys
      // produce distinct provider instances.
      final prov1 = conversationProvider(1001);
      final prov2 = conversationProvider(2002);
      expect(identical(prov1, prov2), isFalse);
    });

    test('currentSessionIdProvider is autoDispose family keyed by episodeId', () {
      // Default value is null
      expect(container.read(currentSessionIdProvider(3001)), isNull);

      // Can set a session ID
      container.read(currentSessionIdProvider(3001).notifier).set(42);
      expect(container.read(currentSessionIdProvider(3001)), 42);

      // Different episode ID is independent
      expect(container.read(currentSessionIdProvider(3002)), isNull);
    });

    test('currentSessionIdProvider can be cleared', () {
      container.read(currentSessionIdProvider(4001).notifier).set(99);
      expect(container.read(currentSessionIdProvider(4001)), 99);

      container.read(currentSessionIdProvider(4001).notifier).set(null);
      expect(container.read(currentSessionIdProvider(4001)), isNull);
    });

    test('ConversationState defaults', () {
      const state = ConversationState();
      expect(state.messages, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.isSending, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.currentSendingTurn, isNull);
      expect(state.sessionId, isNull);
      expect(state.hasError, isFalse);
      expect(state.hasMessages, isFalse);
      expect(state.isEmpty, isTrue);
      expect(state.isReady, isTrue);
    });

    test('ConversationState copyWith preserves unspecified fields', () {
      const state = ConversationState(
        isLoading: true,
        sessionId: 5,
      );

      final copied = state.copyWith(isLoading: false);
      expect(copied.isLoading, isFalse);
      expect(copied.sessionId, 5);
      expect(copied.messages, isEmpty);
    });

    test('ConversationState copyWith can clear error', () {
      const state = ConversationState(errorMessage: 'test error');

      final cleared = state.copyWith(errorMessage: null);
      expect(cleared.errorMessage, isNull);
      expect(cleared.hasError, isFalse);
    });

    test('ConversationState hasMessages and isEmpty', () {
      // Create a message to test with
      final message = PodcastConversationMessage(
        id: 1,
        role: 'user',
        content: 'Hello',
        conversationTurn: 0,
        createdAt: DateTime.now().toIso8601String(),
      );

      final state = ConversationState(messages: [message]);
      expect(state.hasMessages, isTrue);
      expect(state.isEmpty, isFalse);
    });

    test('autoDispose releases provider when no longer watched', () async {
      // Create a scoped container
      final scoped = ProviderContainer();

      // Access provider
      scoped.read(currentSessionIdProvider(5001).notifier).set(10);
      expect(scoped.read(currentSessionIdProvider(5001)), 10);

      // Refresh the provider to trigger autoDispose
      scoped.invalidate(currentSessionIdProvider(5001));

      // After invalidation, value resets to default
      expect(scoped.read(currentSessionIdProvider(5001)), isNull);

      scoped.dispose();
    });
  });
}
