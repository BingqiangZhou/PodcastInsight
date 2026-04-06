import 'package:flutter/material.dart';

import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_conversation_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/conversation/chat_message_bubble.dart';

/// Displays the list of conversation messages with loading, error,
/// and empty states.
class ChatMessagesList extends StatelessWidget {
  const ChatMessagesList({
    required this.messages, required this.isLoading, required this.hasError, required this.errorMessage, required this.isEmpty, required this.scrollController, required this.isSelectMode, required this.isMessageSelected, required this.onToggleSelection, required this.onTextSelected, required this.emptyStateWidget, super.key,
  });

  final List<PodcastConversationMessage> messages;
  final bool isLoading;
  final bool hasError;
  final String? errorMessage;
  final bool isEmpty;
  final ScrollController scrollController;
  final bool isSelectMode;
  final bool Function(PodcastConversationMessage) isMessageSelected;
  final void Function(PodcastConversationMessage) onToggleSelection;
  final void Function(String selectedText, {required bool isUser, required String roleLabel})
      onTextSelected;
  final Widget emptyStateWidget;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: scheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.podcast_conversation_loading_failed,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage ?? '',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (isEmpty) {
      return emptyStateWidget;
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final message = messages[index];
        return ChatMessageBubble(
          message: message,
          isSelectMode: isSelectMode,
          isSelected: isMessageSelected(message),
          onToggleSelection: () => onToggleSelection(message),
          onTextSelected: onTextSelected,
        );
      },
    );
  }
}
