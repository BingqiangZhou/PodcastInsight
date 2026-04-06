import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/theme/app_theme.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_conversation_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_playback_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_transcription_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/conversation_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/summary_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/conversation_chat_widget.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/transcript_display_widget.dart';

void main() {
  testWidgets('Conversation chat shows share-all entry when messages exist', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conversationProvider(
            1,
          ).overrideWith(_ConversationWithMessagesNotifier.new),
          sessionListProvider(
            1,
          ).overrideWith(_EmptySessionListNotifier.new),
          currentSessionIdProvider(
            1,
          ).overrideWith(_NullSessionIdNotifier.new),
          availableModelsProvider.overrideWith(
            (ref) async => <SummaryModelInfo>[],
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: ConversationChatWidget(
              episodeId: 1,
              episodeTitle: 'Test Episode',
              aiSummary: 'Summary exists',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byTooltip('Share All'), findsOneWidget);
  });

  testWidgets('Conversation header does not show message count badge', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conversationProvider(
            1,
          ).overrideWith(_ConversationWithMixedMessagesNotifier.new),
          sessionListProvider(
            1,
          ).overrideWith(_EmptySessionListNotifier.new),
          currentSessionIdProvider(
            1,
          ).overrideWith(_NullSessionIdNotifier.new),
          availableModelsProvider.overrideWith(
            (ref) async => <SummaryModelInfo>[],
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: ConversationChatWidget(
              episodeId: 1,
              episodeTitle: 'Test Episode',
              aiSummary: 'Summary exists',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final context = tester.element(find.byType(ConversationChatWidget));
    final l10n = AppLocalizations.of(context)!;

    expect(find.text(l10n.podcast_conversation_message_count(1)), findsNothing);
    expect(find.text(l10n.podcast_conversation_message_count(2)), findsNothing);
  });

  testWidgets(
    'Conversation selection can toggle by tapping bubble header area',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationProvider(
              1,
            ).overrideWith(_ConversationWithMessagesNotifier.new),
            sessionListProvider(
              1,
            ).overrideWith(_EmptySessionListNotifier.new),
            currentSessionIdProvider(
              1,
            ).overrideWith(_NullSessionIdNotifier.new),
            availableModelsProvider.overrideWith(
              (ref) async => <SummaryModelInfo>[],
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: ConversationChatWidget(
                episodeId: 1,
                episodeTitle: 'Test Episode',
                aiSummary: 'Summary exists',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final context = tester.element(find.byType(ConversationChatWidget));
      final l10n = AppLocalizations.of(context)!;

      await tester.tap(find.byIcon(Icons.check_box_outlined));
      await tester.pumpAndSettle();

      final assistantIconFinder = find.byIcon(Icons.smart_toy_outlined);
      expect(assistantIconFinder, findsOneWidget);
      await tester.tap(assistantIconFinder);
      await tester.pumpAndSettle();

      expect(find.text(l10n.podcast_selected_count(1)), findsNothing);

      await tester.tap(assistantIconFinder);
      await tester.pumpAndSettle();

      expect(find.text(l10n.podcast_selected_count(1)), findsNothing);
    },
  );

  testWidgets('Conversation selection/share icons are replaced as expected', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conversationProvider(
            1,
          ).overrideWith(_ConversationWithMessagesNotifier.new),
          sessionListProvider(
            1,
          ).overrideWith(_EmptySessionListNotifier.new),
          currentSessionIdProvider(
            1,
          ).overrideWith(_NullSessionIdNotifier.new),
          availableModelsProvider.overrideWith(
            (ref) async => <SummaryModelInfo>[],
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: ConversationChatWidget(
              episodeId: 1,
              episodeTitle: 'Test Episode',
              aiSummary: 'Summary exists',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_box_outlined), findsOneWidget);
    expect(find.byIcon(Icons.deselect), findsNothing);
    expect(find.byIcon(Icons.share_outlined), findsNothing);
    expect(find.byIcon(Icons.ios_share_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.check_box_outlined));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.deselect), findsOneWidget);
    expect(find.byIcon(Icons.share_outlined), findsOneWidget);
    expect(find.byIcon(Icons.ios_share_outlined), findsOneWidget);
  });

  testWidgets('Conversation new-chat and history buttons are on title row', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conversationProvider(
            1,
          ).overrideWith(_ConversationWithMessagesNotifier.new),
          sessionListProvider(
            1,
          ).overrideWith(_EmptySessionListNotifier.new),
          currentSessionIdProvider(
            1,
          ).overrideWith(_NullSessionIdNotifier.new),
          availableModelsProvider.overrideWith(
            (ref) async => <SummaryModelInfo>[],
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: ConversationChatWidget(
              episodeId: 1,
              episodeTitle: 'Test Episode',
              aiSummary: 'Summary exists',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final context = tester.element(find.byType(ConversationChatWidget));
    final l10n = AppLocalizations.of(context)!;

    final titleFinder = find.text(l10n.podcast_conversation_title);
    final newChatFinder = find.byIcon(Icons.add_comment_outlined);
    final historyFinder = find.byIcon(Icons.history);

    expect(titleFinder, findsOneWidget);
    expect(newChatFinder, findsOneWidget);
    expect(historyFinder, findsOneWidget);

    final titleDy = tester.getTopLeft(titleFinder).dy;
    final newChatDy = tester.getTopLeft(newChatFinder).dy;
    final historyDy = tester.getTopLeft(historyFinder).dy;

    expect((newChatDy - titleDy).abs(), lessThan(8));
    expect((historyDy - titleDy).abs(), lessThan(8));
  });

  testWidgets(
    'Conversation chat keeps share-all visible with long model names on small width',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            conversationProvider(
              1,
            ).overrideWith(_ConversationWithMessagesNotifier.new),
            sessionListProvider(
              1,
            ).overrideWith(_EmptySessionListNotifier.new),
            currentSessionIdProvider(
              1,
            ).overrideWith(_NullSessionIdNotifier.new),
            availableModelsProvider.overrideWith(
              (ref) async => _longNameModels,
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: ConversationChatWidget(
                episodeId: 1,
                episodeTitle: 'Test Episode',
                aiSummary: 'Summary exists',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(DropdownButton<SummaryModelInfo>), findsOneWidget);
      expect(find.byTooltip('Share All'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Conversation chat enables send button after typing text', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conversationProvider(
            1,
          ).overrideWith(_ConversationWithMessagesNotifier.new),
          sessionListProvider(
            1,
          ).overrideWith(_EmptySessionListNotifier.new),
          currentSessionIdProvider(
            1,
          ).overrideWith(_NullSessionIdNotifier.new),
          availableModelsProvider.overrideWith(
            (ref) async => <SummaryModelInfo>[],
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: ConversationChatWidget(
              episodeId: 1,
              episodeTitle: 'Test Episode',
              aiSummary: 'Summary exists',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final sendButtonFinder = find.ancestor(
      of: find.byIcon(Icons.send),
      matching: find.byType(IconButton),
    );
    expect(sendButtonFinder, findsOneWidget);
    expect(tester.widget<IconButton>(sendButtonFinder).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump();

    expect(tester.widget<IconButton>(sendButtonFinder).onPressed, isNotNull);
    await tester.pump(const Duration(milliseconds: 350));
  });

  testWidgets('Conversation user message uses onSurface color in light theme', (
    tester,
  ) async {
    const userMessage = 'User asks a question';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conversationProvider(
            1,
          ).overrideWith(_ConversationWithUserMessageNotifier.new),
          sessionListProvider(
            1,
          ).overrideWith(_EmptySessionListNotifier.new),
          currentSessionIdProvider(
            1,
          ).overrideWith(_NullSessionIdNotifier.new),
          availableModelsProvider.overrideWith(
            (ref) async => <SummaryModelInfo>[],
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: ConversationChatWidget(
              episodeId: 1,
              episodeTitle: 'Test Episode',
              aiSummary: 'Summary exists',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final textFinder = find.byWidgetPredicate(
      (widget) => widget is SelectableText && widget.data == userMessage,
    );
    expect(textFinder, findsOneWidget);

    final selectableText = tester.widget<SelectableText>(textFinder);
    final context = tester.element(find.byType(ConversationChatWidget));
    final expectedColor = Theme.of(context).colorScheme.onSurface;

    expect(selectableText.style?.color, expectedColor);
    expect(selectableText.style?.color, isNot(Colors.white));
  });

  testWidgets('Transcript widget has no share-all entry', (tester) async {
    final transcription = PodcastTranscriptionResponse(
      id: 1,
      episodeId: 1,
      status: 'completed',
      transcriptContent: 'This is a transcript sentence.',
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TranscriptDisplayWidget(
              episodeId: 1,
              episodeTitle: 'Test Episode',
              transcription: transcription,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byTooltip('Share All'), findsNothing);
    expect(find.text('Share All'), findsNothing);
  });
}

const List<SummaryModelInfo> _longNameModels = <SummaryModelInfo>[
  SummaryModelInfo(
    id: 11,
    name: 'primary-model',
    displayName:
        'A very long model display name that should be truncated in the selector',
    provider: 'openai',
    modelId: 'gpt-4.1-long-name-variant',
    isDefault: true,
  ),
  SummaryModelInfo(
    id: 12,
    name: 'backup-model',
    displayName:
        'Another extremely long model name for overflow behavior verification',
    provider: 'openai',
    modelId: 'gpt-4.1-mini-long-name',
    isDefault: false,
  ),
];

class _ConversationWithMessagesNotifier extends ConversationNotifier {
  _ConversationWithMessagesNotifier() : super(1);

  @override
  ConversationState build() {
    return ConversationState(
      messages: [
        PodcastConversationMessage(
          id: 1,
          role: 'assistant',
          content: 'Hello from assistant',
          conversationTurn: 1,
          createdAt: DateTime.now().toIso8601String(),
        ),
      ],
    );
  }
}

class _ConversationWithMixedMessagesNotifier extends ConversationNotifier {
  _ConversationWithMixedMessagesNotifier() : super(1);

  @override
  ConversationState build() {
    return ConversationState(
      messages: [
        PodcastConversationMessage(
          id: 10,
          role: 'user',
          content: 'User says hello',
          conversationTurn: 1,
          createdAt: DateTime.now().toIso8601String(),
        ),
        PodcastConversationMessage(
          id: 11,
          role: 'assistant',
          content: 'Assistant replies',
          conversationTurn: 2,
          createdAt: DateTime.now().toIso8601String(),
        ),
      ],
    );
  }
}

class _ConversationWithUserMessageNotifier extends ConversationNotifier {
  _ConversationWithUserMessageNotifier() : super(1);

  @override
  ConversationState build() {
    return ConversationState(
      messages: [
        PodcastConversationMessage(
          id: 2,
          role: 'user',
          content: 'User asks a question',
          conversationTurn: 1,
          createdAt: DateTime.now().toIso8601String(),
        ),
      ],
    );
  }
}

class _EmptySessionListNotifier extends SessionListNotifier {
  _EmptySessionListNotifier() : super(1);

  @override
  Future<List<ConversationSession>> build() async => [];
}

class _NullSessionIdNotifier extends SessionIdNotifier {
  _NullSessionIdNotifier() : super(1);

  @override
  int? build() => null;
}
