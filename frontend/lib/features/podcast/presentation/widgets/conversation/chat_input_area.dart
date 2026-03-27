import 'package:flutter/material.dart';

import '../../../../../core/localization/app_localizations_extension.dart';

/// Input area for the conversation chat with a text field and send button.
///
/// Shows a send button that displays a loading indicator when sending,
/// and disables input when no summary is available.
class ChatInputArea extends StatelessWidget {
  const ChatInputArea({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.inputTextNotifier,
    required this.isReady,
    required this.isSending,
    required this.hasSummary,
    required this.onSend,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(
            color: scheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: scheme.outline,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: scheme.outline,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
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
                return IconButton.filled(
                  onPressed:
                      (isReady && inputText.trim().isNotEmpty && hasSummary)
                          ? onSend
                          : null,
                  icon: isSending
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.onSurfaceVariant,
                          ),
                        )
                      : const Icon(Icons.send),
                  style: IconButton.styleFrom(
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
