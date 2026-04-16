import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive.dart';
import 'package:personal_ai_assistant/core/widgets/app_dialog_helper.dart';
import 'package:personal_ai_assistant/core/widgets/top_floating_notice.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_conversation_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/conversation_providers.dart';

/// Drawer showing conversation session history.
///
/// Displays a list of past sessions with selection state, delete capability,
/// and a button to start a new chat.
class ChatSessionsDrawer extends ConsumerWidget {
  const ChatSessionsDrawer({
    required this.episodeId, required this.onStartNewChat, super.key,
  });

  final int episodeId;
  final VoidCallback onStartNewChat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final sessionsAsync = ref.watch(sessionListProvider(episodeId));
    final currentSessionId = ref.watch(
      currentSessionIdProvider(episodeId),
    );

    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.75,
      backgroundColor: AppColors.darkSurface,
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Colors.transparent,
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
                  const SizedBox(height: AppSpacing.md),
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
                        color: AppColors.darkOnSurfaceMuted,
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
                    return _SessionListTile(
                      session: session,
                      isSelected: isSelected,
                      episodeId: episodeId,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator.adaptive()),
              error: (e, _) => Center(
                child: Text(
                  AppLocalizations.of(context)?.error_prefix(e.toString()) ??
                      'Error: $e',
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context); // Close drawer first
                  onStartNewChat();
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
}

class _SessionListTile extends ConsumerWidget {
  const _SessionListTile({
    required this.session,
    required this.isSelected,
    required this.episodeId,
  });

  final ConversationSession session;
  final bool isSelected;
  final int episodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final extension = appThemeOf(context);

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? scheme.surfaceContainerLowest
            : Colors.transparent,
        border: isSelected
            ? Border(
                left: BorderSide(
                  color: scheme.primary,
                  width: 3,
                ),
              )
            : null,
      ),
      child: AdaptiveListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        leading: Icon(
          isSelected ? Icons.chat_bubble : Icons.chat_bubble_outline,
          color: isSelected ? scheme.primary : AppColors.darkOnSurface,
        ),
        title: Text(
          session.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isSelected ? AppColors.darkOnBackground : AppColors.darkOnSurface,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        subtitle: Text(
          session.createdAt.substring(0, 10),
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.darkOnSurfaceMuted,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          color: AppColors.darkOnSurfaceMuted,
          onPressed: () async {
            final confirm = await showAppConfirmationDialog(
              context: context,
              title: l10n.podcast_conversation_delete_title,
              message: l10n.podcast_conversation_delete_confirm,
              confirmText: l10n.delete,
              isDestructive: true,
            );
            if (confirm == true) {
              try {
                await ref
                    .read(sessionListProvider(episodeId).notifier)
                    .deleteSession(session.id);
              } catch (e) {
                if (context.mounted) {
                  final l10n = AppLocalizations.of(context);
                  showTopFloatingNotice(
                    context,
                    message: l10n?.session_delete_failed ??
                        'Failed to delete conversation',
                    isError: true,
                  );
                }
              }
            }
          },
        ),
        onTap: () {
          ref
              .read(currentSessionIdProvider(episodeId).notifier)
              .set(session.id);
          Navigator.pop(context); // Close drawer
        },
      ),
    );
  }
}
