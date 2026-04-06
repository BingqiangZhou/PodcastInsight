import 'package:flutter/material.dart';

import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_conversation_model.dart';

/// A single message bubble in the conversation chat.
///
/// Displays the message content with a role header (user/assistant),
/// and supports select mode and text selection for sharing.
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isSelectMode,
    required this.isSelected,
    required this.onToggleSelection,
    required this.onTextSelected,
  });

  final PodcastConversationMessage message;
  final bool isSelectMode;
  final bool isSelected;
  final VoidCallback onToggleSelection;
  final void Function(String selectedText, {required bool isUser, required String roleLabel})
      onTextSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final extension = appThemeOf(context);
    final isUser = message.isUser;
    final cardR = extension.cardRadius;
    final bubbleRadius = BorderRadius.only(
      topLeft: isUser ? Radius.circular(cardR) : const Radius.circular(4),
      topRight: isUser ? const Radius.circular(4) : Radius.circular(cardR),
      bottomLeft: Radius.circular(cardR),
      bottomRight: Radius.circular(cardR),
    );
    final l10n = AppLocalizations.of(context)!;
    final roleLabel = isUser
        ? l10n.podcast_conversation_user
        : l10n.podcast_conversation_assistant;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isSelectMode ? onToggleSelection : null,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.75,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isUser
                ? extension.cardTierFill
                : extension.surfaceTierFill,
            borderRadius: bubbleRadius,
            border: isUser
                ? null
                : Border(
                    left: BorderSide(
                      color: scheme.primary,
                      width: 3,
                    ),
                  ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Message header with role and time
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isUser ? Icons.person_outline : Icons.smart_toy_outlined,
                    size: 14,
                    color: AppColors.darkOnBackground,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    roleLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.darkOnBackground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (isSelectMode) ...[
                    const SizedBox(width: 6),
                    Icon(
                      isSelected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 16,
                      color:
                          isSelected ? scheme.primary : AppColors.darkOnSurface,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              isSelectMode
                  ? Text(
                      message.content,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.darkOnBackground,
                        height: 1.5,
                      ),
                    )
                  : SelectableText(
                      message.content,
                      onSelectionChanged: (selection, _) {
                        if (selection.isCollapsed ||
                            selection.start < 0 ||
                            selection.end <= selection.start ||
                            selection.end > message.content.length) {
                          onTextSelected('', isUser: isUser, roleLabel: roleLabel);
                          return;
                        }
                        final selectedText = message.content
                            .substring(selection.start, selection.end)
                            .trim();
                        onTextSelected(selectedText,
                            isUser: isUser, roleLabel: roleLabel);
                      },
                      contextMenuBuilder: (context, editableTextState) {
                        return AdaptiveTextSelectionToolbar.buttonItems(
                          anchors: editableTextState.contextMenuAnchors,
                          buttonItems: [
                            ...editableTextState.contextMenuButtonItems,
                            ContextMenuButtonItem(
                              label: AppLocalizations.of(context)!
                                  .podcast_share_as_image,
                              onPressed: () {
                                final value =
                                    editableTextState.textEditingValue;
                                final selectedText = value.selection
                                    .textInside(value.text)
                                    .trim();
                                onTextSelected(selectedText,
                                    isUser: isUser, roleLabel: roleLabel);
                                ContextMenuController.removeAny();
                              },
                            ),
                          ],
                        );
                      },
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.darkOnBackground,
                        height: 1.5,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
