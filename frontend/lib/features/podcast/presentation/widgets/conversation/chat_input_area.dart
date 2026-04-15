import 'package:flutter/material.dart';

import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/theme/app_theme.dart';

/// Input area for the conversation chat with a text field and send button.
///
/// Shows a send button that displays a loading indicator when sending,
/// and disables input when no summary is available.
class ChatInputArea extends StatelessWidget {
  const ChatInputArea({
    required this.controller, required this.focusNode, required this.inputTextNotifier, required this.isReady, required this.isSending, required this.hasSummary, required this.onSend, super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueNotifier<String> inputTextNotifier;
  final bool isReady;
  final bool isSending;
  final bool hasSummary;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final extension = appThemeOf(context);
    final gradient = LinearGradient(
      colors: [scheme.primary, scheme.primary.withOpacity(0.8)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    return Container(
      color: scheme.surfaceContainerLow,
      padding: const EdgeInsets.all(16),
      child: SafeArea(
      top: false,
      child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: isReady && hasSummary,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface,
                ),
                cursorColor: scheme.primary,
                maxLines: null,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: !hasSummary
                      ? l10n.podcast_conversation_no_summary_hint
                      : l10n.podcast_conversation_send_hint,
                  hintStyle: TextStyle(color: scheme.onSurfaceVariant),
                  filled: true,
                  fillColor: Colors.transparent,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(extension.cardRadius),
                    borderSide: BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(extension.cardRadius),
                    borderSide: BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(extension.cardRadius),
                    borderSide: BorderSide(
                      color: scheme.primary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<String>(
              valueListenable: inputTextNotifier,
              builder: (context, inputText, child) {
                final canSend = isReady && inputText.trim().isNotEmpty && hasSummary;
                return Container(
                  decoration: BoxDecoration(
                    gradient: canSend ? gradient : null,
                    color: canSend ? null : scheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(extension.cardRadius),
                  ),
                  child: IconButton(
                    onPressed: canSend ? onSend : null,
                    icon: isSending
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: canSend
                                  ? scheme.onSurface
                                  : scheme.onSurfaceVariant,
                            ),
                          )
                        : Icon(
                            Icons.send,
                            color: canSend
                                ? scheme.onSurface
                                : scheme.onSurfaceVariant,
                          ),
                    padding: const EdgeInsets.all(12),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
