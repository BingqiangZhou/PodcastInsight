import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';

import 'package:personal_ai_assistant/core/constants/app_radius.dart';
import 'package:personal_ai_assistant/core/constants/app_text_styles.dart';

import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_playback_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/conversation_providers.dart';

/// Header bar for the conversation chat widget.
///
/// Displays title, model selector, and action buttons (new chat, history,
/// select mode, share, reload).
class ChatHeader extends ConsumerWidget {
  const ChatHeader({
    required this.hasMessages, required this.isSending, required this.isReady, required this.hasError, required this.isMessageSelectMode, required this.selectedMessageCount, required this.selectedModel, required this.onNewChat, required this.onToggleSelectMode, required this.onShareSelected, required this.onShareAll, required this.onReload, required this.onModelChanged, required this.onOpenHistory, super.key,
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
    final extension = appThemeOf(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: context.spacing.md, vertical: context.spacing.md),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
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
                    SizedBox(width: context.spacing.smMd),
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
          SizedBox(height: context.spacing.sm),
          Row(
            children: [
              availableModelsAsync.when(
                data: (models) {
                  if (models.length <= 1) return const SizedBox.shrink();
                  return Padding(
                    padding: EdgeInsetsDirectional.only(end: context.spacing.sm),
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
                  alignment: AlignmentDirectional.centerEnd,
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
                            icon: Icon(Icons.adaptive.share),
                            tooltip: l10n.podcast_share_as_image,
                            onPressed:
                                isSending || selectedMessageCount == 0
                                    ? null
                                    : onShareSelected,
                          ),
                        if (hasMessages)
                          IconButton(
                            icon: Icon(Icons.adaptive.share),
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
    final scheme = theme.colorScheme;
    final extension = appThemeOf(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: context.spacing.sm, vertical: context.spacing.xxs),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(extension.itemRadius),
      ),
      child: DropdownButton<SummaryModelInfo>(
        value: widget.selectedModel,
        underline: const SizedBox.shrink(),
        isDense: true,
        isExpanded: true,
        icon: const Icon(Icons.expand_more, size: 18),
        hint: Text(
          l10n.podcast_ai_model,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.darkOnSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        style: theme.textTheme.bodySmall?.copyWith(
          color: AppColors.darkOnBackground,
        ),
        selectedItemBuilder: (context) {
          return widget.models
              .map(
                (model) => Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    model.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.darkOnBackground,
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
                      padding: EdgeInsetsDirectional.only(start: context.spacing.sm),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: context.spacing.xs,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLowest,
                          borderRadius: AppRadius.xsRadius,
                        ),
                        child: Text(
                          l10n.podcast_default_model,
                          style: AppTextStyles.navLabel(
                            scheme.primary,
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
