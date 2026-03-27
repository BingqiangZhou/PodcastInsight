import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/app_localizations_extension.dart';
import '../../../../core/utils/resource_cleanup_mixin.dart';
import '../../../../core/widgets/top_floating_notice.dart';
import '../../data/models/podcast_conversation_model.dart';
import '../../data/models/podcast_playback_model.dart';
import '../providers/conversation_providers.dart';
import '../providers/summary_providers.dart';
import '../services/content_image_share_service.dart';

/// AI对话聊天界面组件
class ConversationChatWidget extends ConsumerStatefulWidget {
  final int episodeId;
  final String episodeTitle;
  final String? aiSummary;

  const ConversationChatWidget({
    super.key,
    required this.episodeId,
    required this.episodeTitle,
    this.aiSummary,
  });

  @override
  ConsumerState<ConversationChatWidget> createState() =>
      ConversationChatWidgetState();
}

class ConversationChatWidgetState
    extends ConsumerState<ConversationChatWidget>
    with ResourceCleanupMixin {
  static const double _modelSelectorMaxWidth = 160;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final ValueNotifier<String> _inputTextNotifier = ValueNotifier('');
  SummaryModelInfo? _selectedModel;
  Timer? _pendingScrollTimer;
  String _lastSelectedChatText = '';
  String _lastSelectedChatRoleLabel = '';
  bool _lastSelectedChatIsUser = false;
  bool _isMessageSelectMode = false;
  final Set<int> _selectedMessageIds = <int>{};
  ProviderSubscription<ConversationState>? _conversationSubscription;
  int _episodeVersion = 0;

  void _onMessageInputChanged() {
    _inputTextNotifier.value = _messageController.text;
  }

  /// 滚动到顶部
  void scrollToTop() {
    if (!mounted || !_scrollController.hasClients) {
      return;
    }
    _scrollController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onMessageInputChanged);
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _scheduleScrollToBottom(const Duration(milliseconds: 300));
      }
    });
    // 自动选择默认模型
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final modelsAsync = ref.read(availableModelsProvider);
      modelsAsync.when(
        data: (models) {
          if (models.isNotEmpty) {
            final defaultModel = models.firstWhere(
              (m) => m.isDefault,
              orElse: () => models.first,
            );
            if (mounted) {
              setState(() => _selectedModel = defaultModel);
            }
          }
        },
        loading: () {},
        error: (_, _) {},
      );
    });
    _bindConversationListener();
  }

  @override
  void dispose() {
    _conversationSubscription?.close();
    _pendingScrollTimer?.cancel();
    // No manual release needed - autoDispose handles cleanup
    _messageController.removeListener(_onMessageInputChanged);
    _inputTextNotifier.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ConversationChatWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.episodeId != widget.episodeId) {
      _episodeVersion++;
      final currentVersion = _episodeVersion;

      _conversationSubscription?.close();
      // No manual release needed - autoDispose handles cleanup

      // Use addPostFrameCallback to ensure execution after current frame completes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Check version and mounted state to prevent race conditions
        if (!mounted || _episodeVersion != currentVersion) return;
        _bindConversationListener();
      });
    }
  }

  void _bindConversationListener() {
    _conversationSubscription?.close();
    _conversationSubscription = ref.listenManual<ConversationState>(
      conversationProvider(widget.episodeId),
      (previous, next) {
        _syncSelectedMessageIds(next.messages);
        if (next.messages.length > (previous?.messages.length ?? 0)) {
          _scheduleScrollToBottom(const Duration(milliseconds: 100));
        }
      },
    );
  }

  void _scheduleScrollToBottom(Duration delay) {
    _pendingScrollTimer?.cancel();
    _pendingScrollTimer = Timer(delay, _scrollToBottom);
    registerTimer(_pendingScrollTimer!);
  }

  void _scrollToBottom() {
    if (!mounted || !_scrollController.hasClients) {
      return;
    }
    if (_scrollController.position.maxScrollExtent > 0) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final notifier = ref.read(
      conversationProvider(widget.episodeId).notifier,
    );
    notifier.sendMessage(message, modelName: _selectedModel?.name);

    _messageController.clear();
    _focusNode.requestFocus();
  }

  void _updateSelectedChatText(
    String sourceText,
    TextSelection selection, {
    required bool isUser,
    required String roleLabel,
  }) {
    if (selection.isCollapsed ||
        selection.start < 0 ||
        selection.end <= selection.start ||
        selection.end > sourceText.length) {
      _lastSelectedChatText = '';
      return;
    }
    _lastSelectedChatText = sourceText
        .substring(selection.start, selection.end)
        .trim();
    _lastSelectedChatIsUser = isUser;
    _lastSelectedChatRoleLabel = roleLabel;
  }

  void _setMessageSelectMode(bool enabled) {
    setState(() {
      _isMessageSelectMode = enabled;
      if (!enabled) {
        _selectedMessageIds.clear();
      }
    });
  }

  void _toggleMessageSelection(PodcastConversationMessage message) {
    setState(() {
      if (_selectedMessageIds.contains(message.id)) {
        _selectedMessageIds.remove(message.id);
      } else {
        _selectedMessageIds.add(message.id);
      }
    });
  }

  void _syncSelectedMessageIds(List<PodcastConversationMessage> messages) {
    if (_selectedMessageIds.isEmpty && !_isMessageSelectMode) {
      return;
    }
    final validIds = messages.map((m) => m.id).toSet();
    final filteredIds = _selectedMessageIds
        .where((id) => validIds.contains(id))
        .toSet();
    final shouldExitMode = _isMessageSelectMode && filteredIds.isEmpty;
    final hasChanged = filteredIds.length != _selectedMessageIds.length;
    if (!hasChanged && !shouldExitMode) {
      return;
    }
    setState(() {
      _selectedMessageIds
        ..clear()
        ..addAll(filteredIds);
      if (_selectedMessageIds.isEmpty) {
        _isMessageSelectMode = false;
      }
    });
  }

  int get _selectedMessageCount => _selectedMessageIds.length;

  bool _isMessageSelected(PodcastConversationMessage message) {
    return _selectedMessageIds.contains(message.id);
  }

  String _messageRoleLabel(PodcastConversationMessage message) {
    final l10n = context.l10n;
    return message.isUser
        ? l10n.podcast_conversation_user
        : l10n.podcast_conversation_assistant;
  }

  List<PodcastConversationMessage> _resolveSelectedMessages(
    ConversationState state,
  ) {
    if (_selectedMessageIds.isEmpty) {
      return const <PodcastConversationMessage>[];
    }
    return state.messages
        .where((message) => _selectedMessageIds.contains(message.id))
        .toList();
  }

  List<ShareConversationItem> _buildShareConversationItems(
    List<PodcastConversationMessage> messages,
  ) {
    final l10n = context.l10n;
    return messages
        .map(
          (message) => ShareConversationItem(
            roleLabel: message.isUser
                ? l10n.podcast_conversation_user
                : l10n.podcast_conversation_assistant,
            content: message.content.trim(),
            isUser: message.isUser,
          ),
        )
        .where((item) => item.content.isNotEmpty)
        .toList();
  }

  Future<void> _shareConversationMessagesAsImage(
    List<PodcastConversationMessage> messages,
  ) async {
    final l10n = context.l10n;
    final conversationItems = _buildShareConversationItems(messages);
    final plainText = formatShareConversationItems(conversationItems);
    try {
      await ContentImageShareService.shareAsImage(
        context,
        ShareImagePayload(
          episodeTitle: widget.episodeTitle,
          contentType: ShareContentType.chat,
          content: plainText,
          sourceLabel: l10n.podcast_tab_chat,
          renderMode: ShareImageRenderMode.conversation,
          conversationItems: conversationItems,
        ),
      );
    } on ContentImageShareException catch (e) {
      if (!mounted) {
        return;
      }
      showTopFloatingNotice(context, message: e.message, isError: true);
    }
  }

  Future<void> _shareSelectedChatAsImage() async {
    final l10n = context.l10n;
    final roleLabel = _lastSelectedChatRoleLabel.isNotEmpty
        ? _lastSelectedChatRoleLabel
        : (_lastSelectedChatIsUser
              ? l10n.podcast_conversation_user
              : l10n.podcast_conversation_assistant);
    try {
      await ContentImageShareService.shareAsImage(
        context,
        ShareImagePayload(
          episodeTitle: widget.episodeTitle,
          contentType: ShareContentType.chat,
          content: _lastSelectedChatText,
          sourceLabel: l10n.podcast_tab_chat,
          renderMode: ShareImageRenderMode.conversation,
          conversationItems: <ShareConversationItem>[
            ShareConversationItem(
              roleLabel: roleLabel,
              content: _lastSelectedChatText,
              isUser: _lastSelectedChatIsUser,
            ),
          ],
        ),
      );
    } on ContentImageShareException catch (e) {
      if (!mounted) {
        return;
      }
      showTopFloatingNotice(context, message: e.message, isError: true);
    }
  }

  Future<void> _shareAllChatAsImage(ConversationState state) async {
    await _shareConversationMessagesAsImage(state.messages);
  }

  Future<void> _shareSelectedMessagesAsImage(ConversationState state) async {
    final selectedMessages = _resolveSelectedMessages(state);
    await _shareConversationMessagesAsImage(selectedMessages);
  }

  void _startNewChat() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.podcast_conversation_new_chat),
          content: Text(l10n.podcast_conversation_new_chat_confirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.podcast_conversation_new_chat),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await ref
          .read(conversationProvider(widget.episodeId).notifier)
          .startNewChat();
      if (!mounted) {
        return;
      }
      _messageController.clear();
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversationState = ref.watch(
      conversationProvider(widget.episodeId),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      endDrawer: _buildSessionsDrawer(context),
      body: Column(
        children: [
          // Header with title and actions
          _buildHeader(context, conversationState),

          // Messages list
          Expanded(child: _buildMessagesList(context, conversationState)),

          // Input field
          _buildInputArea(context, conversationState),
        ],
      ),
    );
  }

  Widget _buildSessionsDrawer(BuildContext context) {
    final l10n = context.l10n;
    final sessionsAsync = ref.watch(sessionListProvider(widget.episodeId));
    final currentSessionId = ref.watch(
      currentSessionIdProvider(widget.episodeId),
    );

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.75,
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.podcast_conversation_history,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: sessionsAsync.when(
              data: (sessions) {
                if (sessions.isEmpty) {
                  return Center(
                    child: Text(
                      l10n.podcast_conversation_empty_title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    final isSelected = session.id == currentSessionId;
                    return ListTile(
                      leading: Icon(
                        isSelected
                            ? Icons.chat_bubble
                            : Icons.chat_bubble_outline,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      title: Text(
                        session.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : null,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        session.createdAt.substring(
                          0,
                          10,
                        ), // Simple date format
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(
                                l10n.podcast_conversation_delete_title,
                              ),
                              content: Text(
                                l10n.podcast_conversation_delete_confirm,
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: Text(l10n.cancel),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: Text(
                                    l10n.delete,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            ref
                                .read(
                                  sessionListProvider(
                                    widget.episodeId,
                                  ).notifier,
                                )
                                .deleteSession(session.id);
                          }
                        },
                      ),
                      selected: isSelected,
                      onTap: () {
                        ref
                            .read(
                              currentSessionIdProvider(
                                widget.episodeId,
                              ).notifier,
                            )
                            .set(session.id);
                        Navigator.pop(context); // Close drawer
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context); // Close drawer first
                  _startNewChat();
                },
                icon: const Icon(Icons.add),
                label: Text(l10n.podcast_conversation_new_chat),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ConversationState state) {
    final l10n = context.l10n;
    final availableModelsAsync = ref.watch(availableModelsProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
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
                  if (state.hasMessages)
                    IconButton(
                      icon: const Icon(Icons.add_comment_outlined),
                      tooltip: l10n.podcast_conversation_new_chat,
                      onPressed: state.isSending ? null : _startNewChat,
                    ),
                  Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.history),
                      tooltip: l10n.podcast_conversation_history,
                      onPressed: () {
                        Scaffold.of(context).openEndDrawer();
                      },
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
                        maxWidth: _modelSelectorMaxWidth,
                      ),
                      child: _buildModelSelector(context, models),
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
                        if (state.hasMessages)
                          IconButton(
                            icon: Icon(
                              _isMessageSelectMode
                                  ? Icons.deselect
                                  : Icons.check_box_outlined,
                            ),
                            tooltip: _isMessageSelectMode
                                ? l10n.podcast_deselect_all
                                : l10n.podcast_enter_select_mode,
                            onPressed: state.isSending
                                ? null
                                : () => _setMessageSelectMode(
                                    !_isMessageSelectMode,
                                  ),
                          ),
                        if (_isMessageSelectMode)
                          IconButton(
                            icon: const Icon(Icons.share_outlined),
                            tooltip: l10n.podcast_share_as_image,
                            onPressed:
                                state.isSending || _selectedMessageCount == 0
                                ? null
                                : () => unawaited(
                                    _shareSelectedMessagesAsImage(state),
                                  ),
                          ),
                        if (state.hasMessages)
                          IconButton(
                            icon: const Icon(Icons.ios_share_outlined),
                            tooltip: l10n.podcast_share_all_content,
                            onPressed: state.isSending
                                ? null
                                : () => unawaited(_shareAllChatAsImage(state)),
                          ),
                        if (state.hasError)
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            tooltip: l10n.podcast_conversation_reload,
                            onPressed: state.isSending
                                ? null
                                : () => ref
                                      .read(
                                        conversationProvider(
                                          widget.episodeId,
                                        ).notifier,
                                      )
                                      .refresh(),
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

  Widget _buildModelSelector(
    BuildContext context,
    List<SummaryModelInfo> models,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    // 确保_selectedModel在可用列表中
    final selectedModelId = _selectedModel?.id;
    if (selectedModelId != null && !models.any((m) => m.id == selectedModelId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _selectedModel = models.firstWhere(
              (m) => m.isDefault,
              orElse: () => models.first,
            );
          });
        }
      });
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<SummaryModelInfo>(
        value: _selectedModel,
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
          return models
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
        items: models.map((model) {
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
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() => _selectedModel = value);
        },
      ),
    );
  }

  Widget _buildMessagesList(BuildContext context, ConversationState state) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.hasError) {
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
              state.errorMessage ?? '',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (state.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: state.messages.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final message = state.messages[index];
        return _buildMessageBubble(context, message);
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_outlined,
              size: 64,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.podcast_conversation_empty_title,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.podcast_conversation_empty_hint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (widget.aiSummary case final summary? when summary.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: scheme.outlineVariant,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.summarize_outlined,
                          size: 16,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.podcast_filter_with_summary,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      summary.length > 200
                          ? '${summary.substring(0, 200)}...'
                          : summary,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    BuildContext context,
    PodcastConversationMessage message,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isUser = message.isUser;
    final userTextColor = scheme.onSurface;
    final isSelected = _isMessageSelected(message);
    final roleLabel = _messageRoleLabel(message);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _isMessageSelectMode
            ? () => _toggleMessageSelection(message)
            : null,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isUser
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isMessageSelectMode
                  ? (isSelected
                        ? scheme.primary
                        : scheme.outlineVariant.withValues(alpha: 0.35))
                  : (isUser
                        ? scheme.primary.withValues(alpha: 0.3)
                        : scheme.outlineVariant.withValues(alpha: 0.3)),
              width: _isMessageSelectMode && isSelected ? 1.6 : 1,
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
                    color: isUser
                        ? userTextColor
                        : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    roleLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isUser
                          ? userTextColor
                          : scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_isMessageSelectMode) ...[
                    const SizedBox(width: 6),
                    Icon(
                      isSelected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 16,
                      color: isSelected
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              _isMessageSelectMode
                  ? Text(
                      message.content,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isUser
                            ? userTextColor
                            : scheme.onSurface,
                        height: 1.5,
                      ),
                    )
                  : SelectableText(
                      message.content,
                      onSelectionChanged: (selection, _) {
                        _updateSelectedChatText(
                          message.content,
                          selection,
                          isUser: isUser,
                          roleLabel: roleLabel,
                        );
                      },
                      contextMenuBuilder: (context, editableTextState) {
                        return AdaptiveTextSelectionToolbar.buttonItems(
                          anchors: editableTextState.contextMenuAnchors,
                          buttonItems: [
                            ...editableTextState.contextMenuButtonItems,
                            ContextMenuButtonItem(
                              label: AppLocalizations.of(
                                context,
                              )!.podcast_share_as_image,
                              onPressed: () {
                                final value =
                                    editableTextState.textEditingValue;
                                _lastSelectedChatText = value.selection
                                    .textInside(value.text)
                                    .trim();
                                _lastSelectedChatRoleLabel = roleLabel;
                                _lastSelectedChatIsUser = isUser;
                                ContextMenuController.removeAny();
                                unawaited(_shareSelectedChatAsImage());
                              },
                            ),
                          ],
                        );
                      },
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isUser
                            ? userTextColor
                            : scheme.onSurface,
                        height: 1.5,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea(BuildContext context, ConversationState state) {
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
                controller: _messageController,
                focusNode: _focusNode,
                enabled: state.isReady && widget.aiSummary != null,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface,
                ),
                cursorColor: scheme.primary,
                maxLines: null,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: widget.aiSummary == null
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
              valueListenable: _inputTextNotifier,
              builder: (context, inputText, child) {
                return IconButton.filled(
                  onPressed:
                      (state.isReady &&
                          inputText.trim().isNotEmpty &&
                          widget.aiSummary != null)
                      ? _sendMessage
                      : null,
                  icon: state.isSending
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
