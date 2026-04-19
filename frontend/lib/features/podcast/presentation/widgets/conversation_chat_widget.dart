import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/constants/app_durations.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/utils/resource_cleanup_mixin.dart';
import 'package:personal_ai_assistant/core/widgets/app_dialog_helper.dart';
import 'package:personal_ai_assistant/core/widgets/top_floating_notice.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_conversation_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_playback_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/conversation_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/summary_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/services/content_image_share_service.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/conversation/chat_empty_state.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/conversation/chat_header.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/conversation/chat_input_area.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/conversation/chat_messages_list.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/conversation/chat_sessions_drawer.dart';

/// AI conversation chat interface component
class ConversationChatWidget extends ConsumerStatefulWidget {

  const ConversationChatWidget({
    required this.episodeId, required this.episodeTitle, super.key,
    this.aiSummary,
  });
  final int episodeId;
  final String episodeTitle;
  final String? aiSummary;

  @override
  ConsumerState<ConversationChatWidget> createState() =>
      ConversationChatWidgetState();
}

class ConversationChatWidgetState
    extends ConsumerState<ConversationChatWidget>
    with ResourceCleanupMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final ValueNotifier<String> _inputTextNotifier = ValueNotifier('');
  SummaryModelInfo? _selectedModel;
  Timer? _pendingScrollTimer;
  bool _isMessageSelectMode = false;
  final Set<int> _selectedMessageIds = <int>{};
  ProviderSubscription<ConversationState>? _conversationSubscription;
  int _episodeVersion = 0;

  void _onMessageInputChanged() {
    _inputTextNotifier.value = _messageController.text;
  }

  /// Scroll to top
  void scrollToTop() {
    if (!mounted || !_scrollController.hasClients) {
      return;
    }
    _scrollController.animateTo(
      0,
      duration: AppDurations.scrollAnimation,
      curve: Curves.easeInOut,
    );
  }

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onMessageInputChanged);
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _scheduleScrollToBottom(AppDurations.scrollAnimation);
      }
    });
    // Auto-select default model
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

      _isMessageSelectMode = false;
      _selectedMessageIds.clear();
      _conversationSubscription?.close();

      WidgetsBinding.instance.addPostFrameCallback((_) {
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
          _scheduleScrollToBottom(AppDurations.staggerNormal);
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
        duration: AppDurations.scrollAnimation,
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
        .where(validIds.contains)
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

  Future<void> _shareAllChatAsImage(ConversationState state) async {
    await _shareConversationMessagesAsImage(state.messages);
  }

  Future<void> _shareSelectedMessagesAsImage(ConversationState state) async {
    final selectedMessages = _resolveSelectedMessages(state);
    await _shareConversationMessagesAsImage(selectedMessages);
  }

  Future<void> _startNewChat() async {
    final l10n = context.l10n;
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: l10n.podcast_conversation_new_chat,
      message: l10n.podcast_conversation_new_chat_confirm,
      confirmText: l10n.podcast_conversation_new_chat,
    );

    if (confirmed == true && mounted) {
      try {
        await ref
            .read(conversationProvider(widget.episodeId).notifier)
            .startNewChat();
      } catch (e) {
        if (mounted) {
          showTopFloatingNotice(
            context,
            message: context.l10n.session_create_failed,
            isError: true,
          );
        }
        return;
      }
      if (!mounted) {
        return;
      }
      _messageController.clear();
      _focusNode.requestFocus();
    }
  }

  void _handleTextSelected(String selectedText, {required bool isUser, required String roleLabel}) {
    // Text selection is tracked by the platform; no additional action needed.
  }

  @override
  Widget build(BuildContext context) {
    final conversationState = ref.watch(
      conversationProvider(widget.episodeId),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      endDrawer: ChatSessionsDrawer(
        episodeId: widget.episodeId,
        onStartNewChat: _startNewChat,
      ),
      body: Column(
        children: [
          // Header with title and actions
          ChatHeader(
            hasMessages: conversationState.hasMessages,
            isSending: conversationState.isSending,
            isReady: conversationState.isReady,
            hasError: conversationState.hasError,
            isMessageSelectMode: _isMessageSelectMode,
            selectedMessageCount: _selectedMessageCount,
            selectedModel: _selectedModel,
            onNewChat: _startNewChat,
            onToggleSelectMode: () => _setMessageSelectMode(!_isMessageSelectMode),
            onShareSelected: () => unawaited(_shareSelectedMessagesAsImage(conversationState)),
            onShareAll: () => unawaited(_shareAllChatAsImage(conversationState)),
            onReload: () => ref.read(conversationProvider(widget.episodeId).notifier).refresh(),
            onModelChanged: (value) => setState(() => _selectedModel = value),
            onOpenHistory: () => Scaffold.of(context).openEndDrawer(),
          ),

          // Messages list
          Expanded(
            child: ChatMessagesList(
              messages: conversationState.messages,
              isLoading: conversationState.isLoading,
              hasError: conversationState.hasError,
              errorMessage: conversationState.errorMessage,
              isEmpty: conversationState.isEmpty,
              isSelectMode: _isMessageSelectMode,
              scrollController: _scrollController,
              isMessageSelected: _isMessageSelected,
              onToggleSelection: _toggleMessageSelection,
              onTextSelected: _handleTextSelected,
              emptyStateWidget: ChatEmptyState(aiSummary: widget.aiSummary),
            ),
          ),

          // Input field — scoped rebuild via Consumer so only isReady/isSending
          // changes trigger this subtree, not message-list streaming updates.
          Consumer(builder: (context, ref, _) {
            final state = ref.watch(conversationProvider(widget.episodeId));
            return ChatInputArea(
              controller: _messageController,
              focusNode: _focusNode,
              inputTextNotifier: _inputTextNotifier,
              isReady: state.isReady,
              isSending: state.isSending,
              hasSummary: widget.aiSummary != null,
              onSend: _sendMessage,
            );
          }),
        ],
      ),
    );
  }
}
