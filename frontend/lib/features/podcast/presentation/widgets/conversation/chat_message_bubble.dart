import 'package:flutter/material.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';

import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/theme/app_theme.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_conversation_model.dart';

/// A single message bubble in the conversation chat.
///
/// Displays the message content with a role header (user/assistant),
/// and supports select mode and text selection for sharing.
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    required this.message, required this.isSelectMode, required this.isSelected, required this.onToggleSelection, required this.onTextSelected, super.key,
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
    final bubbleRadius = BorderRadiusDirectional.only(
      topStart: isUser ? Radius.circular(cardR) : const Radius.circular(4),
      topEnd: isUser ? const Radius.circular(4) : Radius.circular(cardR),
      bottomStart: Radius.circular(cardR),
      bottomEnd: Radius.circular(cardR),
    );
    final l10n = AppLocalizations.of(context)!;
    final roleLabel = isUser
        ? l10n.podcast_conversation_user
        : l10n.podcast_conversation_assistant;

    // User: right-aligned with surfaceContainerLow, AI: left-aligned with surfaceContainerLowest + primary gradient left bar
    return Align(
      alignment: isUser ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isSelectMode ? onToggleSelection : null,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.75,
          ),
          decoration: BoxDecoration(
            color: isUser ? scheme.surfaceContainerLow : scheme.surfaceContainerLowest,
            borderRadius: bubbleRadius,
          ),
          child: isUser
              ? _buildUserContent(
                  context,
                  theme,
                  scheme,
                  roleLabel,
                  extension,
                )
              : _buildAssistantContent(
                  context,
                  theme,
                  scheme,
                  roleLabel,
                  cardR,
                  extension,
                ),
        ),
      ),
    );
  }

  Widget _buildUserContent(
    BuildContext context,
    ThemeData theme,
    ColorScheme scheme,
    String roleLabel,
    AppThemeExtension extension,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.spacing.md, vertical: context.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_outline,
                size: 14,
                color: scheme.onSurface,
              ),
              SizedBox(width: context.spacing.xs),
              Text(
                roleLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isSelectMode) ...[
                SizedBox(width: context.spacing.smMd),
                Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 16,
                  color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ],
            ],
          ),
          SizedBox(height: context.spacing.smMd),
          if (isSelectMode) Text(
                  message.content,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface,
                    height: 1.5,
                  ),
                ) else SelectableText(
                  message.content,
                  onSelectionChanged: (selection, _) {
                    if (selection.isCollapsed ||
                        selection.start < 0 ||
                        selection.end <= selection.start ||
                        selection.end > message.content.length) {
                      onTextSelected('', isUser: true, roleLabel: roleLabel);
                      return;
                    }
                    final selectedText = message.content
                        .substring(selection.start, selection.end)
                        .trim();
                    onTextSelected(selectedText, isUser: true, roleLabel: roleLabel);
                  },
                  contextMenuBuilder: (context, editableTextState) {
                    return AdaptiveTextSelectionToolbar.buttonItems(
                      anchors: editableTextState.contextMenuAnchors,
                      buttonItems: [
                        ...editableTextState.contextMenuButtonItems,
                        ContextMenuButtonItem(
                          label: AppLocalizations.of(context)!.podcast_share_as_image,
                          onPressed: () {
                            final value = editableTextState.textEditingValue;
                            final selectedText = value.selection.textInside(value.text).trim();
                            onTextSelected(selectedText, isUser: true, roleLabel: roleLabel);
                            ContextMenuController.removeAny();
                          },
                        ),
                      ],
                    );
                  },
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface,
                    height: 1.5,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildAssistantContent(
    BuildContext context,
    ThemeData theme,
    ColorScheme scheme,
    String roleLabel,
    double cardRadius,
    AppThemeExtension extension,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Primary gradient left bar
        Container(
          width: 3,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [scheme.primary, scheme.primary.withValues(alpha: 0.6)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(4),
              bottomLeft: Radius.circular(cardRadius),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: context.spacing.md, vertical: context.spacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.smart_toy_outlined,
                      size: 14,
                      color: scheme.onSurface,
                    ),
                    SizedBox(width: context.spacing.xs),
                    Text(
                      roleLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isSelectMode) ...[
                      SizedBox(width: context.spacing.smMd),
                      Icon(
                        isSelected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 16,
                        color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),
                SizedBox(height: context.spacing.smMd),
                if (isSelectMode) Text(
                        message.content,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface,
                          height: 1.5,
                        ),
                      ) else SelectableText(
                        message.content,
                        onSelectionChanged: (selection, _) {
                          if (selection.isCollapsed ||
                              selection.start < 0 ||
                              selection.end <= selection.start ||
                              selection.end > message.content.length) {
                            onTextSelected('', isUser: false, roleLabel: roleLabel);
                            return;
                          }
                          final selectedText = message.content
                              .substring(selection.start, selection.end)
                              .trim();
                          onTextSelected(selectedText, isUser: false, roleLabel: roleLabel);
                        },
                        contextMenuBuilder: (context, editableTextState) {
                          return AdaptiveTextSelectionToolbar.buttonItems(
                            anchors: editableTextState.contextMenuAnchors,
                            buttonItems: [
                              ...editableTextState.contextMenuButtonItems,
                              ContextMenuButtonItem(
                                label: AppLocalizations.of(context)!.podcast_share_as_image,
                                onPressed: () {
                                  final value = editableTextState.textEditingValue;
                                  final selectedText = value.selection.textInside(value.text).trim();
                                  onTextSelected(selectedText, isUser: false, roleLabel: roleLabel);
                                  ContextMenuController.removeAny();
                                },
                              ),
                            ],
                          );
                        },
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface,
                          height: 1.5,
                        ),
                      ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
