import 'package:flutter/material.dart';

import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';

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
    const gradient = LinearGradient(
      colors: AppColors.violetColors,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    return Container(
      color: const Color(0xFF252540),
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
                  color: AppColors.darkOnBackground,
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
                  hintStyle: const TextStyle(color: AppColors.darkOnSurfaceMuted),
                  filled: true,
                  fillColor: Colors.transparent,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(extension.cardRadius),
                    borderSide: const BorderSide(
                      color: AppColors.darkBorder,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(extension.cardRadius),
                    borderSide: const BorderSide(
                      color: AppColors.darkBorder,
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
                    color: canSend ? null : AppColors.darkSurfaceVariant,
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
                                  ? AppColors.darkOnBackground
                                  : AppColors.darkOnSurfaceMuted,
                            ),
                          )
                        : Icon(
                            Icons.send,
                            color: canSend
                                ? AppColors.darkOnBackground
                                : AppColors.darkOnSurfaceMuted,
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
