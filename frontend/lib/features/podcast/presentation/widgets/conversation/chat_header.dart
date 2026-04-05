import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/theme/app_theme.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_playback_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/summary_providers.dart';

/// Header bar for the conversation chat widget.
///
/// Displays title, model selector, and action buttons (new chat, history,
/// select mode, share, reload).
class ChatHeader extends ConsumerWidget {
  const ChatHeader({
    super.key,
    required this.hasMessages,
    required this.isSending,
    required this.isReady,
    required this.hasError,
    required this.isMessageSelectMode,
    required this.selectedMessageCount,
    required this.selectedModel,
    required this.onNewChat,
    required this.onToggleSelectMode,
    required this.onShareSelected,
    required this.onShareAll,
    required this.onReload,
    required this.onModelChanged,
    required this.onOpenHistory,
  });

  final bool hasMessages;
  final bool isSending;
  final bool isReady;
  final bool hasError;
  final bool isMessageSelectMode;
  final int selectedMessageCount;
  final SummaryModelInfo? selectedModel;
  final VoidCallback onNewChat;
  final VoidCallback onToggleSelectMode;
  final VoidCallback onShareSelected;
  final VoidCallback onShareAll;
  final VoidCallback onReload;
  final ValueChanged<SummaryModelInfo?> onModelChanged;
  final VoidCallback onOpenHistory;

  static const double modelSelectorMaxWidth = 160;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final availableModelsAsync = ref.watch(availableModelsProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        l10n.podcast_conversation_title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasMessages)
                    IconButton(
                      icon: const Icon(Icons.add_comment_outlined),
                      tooltip: l10n.podcast_conversation_new_chat,
                      onPressed: isSending ? null : onNewChat,
                    ),
                  Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.history),
                      tooltip: l10n.podcast_conversation_history,
                      onPressed: onOpenHistory,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              availableModelsAsync.when(
                data: (models) {
                  if (models.length <= 1) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: modelSelectorMaxWidth,
                      ),
                      child: _ModelSelector(
                        models: models,
                        selectedModel: selectedModel,
                        onChanged: onModelChanged,
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasMessages)
                          IconButton(
                            icon: Icon(
                              isMessageSelectMode
                                  ? Icons.deselect
                                  : Icons.check_box_outlined,
                            ),
                            tooltip: isMessageSelectMode
                                ? l10n.podcast_deselect_all
                                : l10n.podcast_enter_select_mode,
                            onPressed:
                                isSending ? null : onToggleSelectMode,
                          ),
                        if (isMessageSelectMode)
                          IconButton(
                            icon: const Icon(Icons.share_outlined),
                            tooltip: l10n.podcast_share_as_image,
                            onPressed:
                                isSending || selectedMessageCount == 0
                                    ? null
                                    : onShareSelected,
                          ),
                        if (hasMessages)
                          IconButton(
                            icon: const Icon(Icons.ios_share_outlined),
                            tooltip: l10n.podcast_share_all_content,
                            onPressed:
                                isSending ? null : onShareAll,
                          ),
                        if (hasError)
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            tooltip: l10n.podcast_conversation_reload,
                            onPressed: isSending ? null : onReload,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModelSelector extends StatefulWidget {
  const _ModelSelector({
    required this.models,
    required this.selectedModel,
    required this.onChanged,
  });

  final List<SummaryModelInfo> models;
  final SummaryModelInfo? selectedModel;
  final ValueChanged<SummaryModelInfo?> onChanged;

  @override
  State<_ModelSelector> createState() => _ModelSelectorState();
}

class _ModelSelectorState extends State<_ModelSelector> {
  @override
  void initState() {
    super.initState();
    _ensureSelectedModelValid();
  }

  @override
  void didUpdateWidget(covariant _ModelSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureSelectedModelValid();
  }

  void _ensureSelectedModelValid() {
    final selectedId = widget.selectedModel?.id;
    if (selectedId != null && !widget.models.any((m) => m.id == selectedId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onChanged(
            widget.models.firstWhere(
              (m) => m.isDefault,
              orElse: () => widget.models.first,
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<SummaryModelInfo>(
        value: widget.selectedModel,
        underline: const SizedBox.shrink(),
        isDense: true,
        isExpanded: true,
        icon: const Icon(Icons.expand_more, size: 18),
        hint: Text(
          l10n.podcast_ai_model,
          style: theme.textTheme.bodySmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
        selectedItemBuilder: (context) {
          return widget.models
              .map(
                (model) => Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    model.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              )
              .toList();
        },
        items: widget.models.map((model) {
          return DropdownMenuItem<SummaryModelInfo>(
            value: model,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      model.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (model.isDefault)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          l10n.podcast_default_model,
                          style: AppTheme.navLabel(
                            theme.colorScheme.primary,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
        onChanged: widget.onChanged,
      ),
    );
  }
}
