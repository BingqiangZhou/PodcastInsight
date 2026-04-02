import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/localization/app_localizations_extension.dart';
import '../../providers/conversation_providers.dart';

/// Drawer showing conversation session history.
///
/// Displays a list of past sessions with selection state, delete capability,
/// and a button to start a new chat.
class ChatSessionsDrawer extends ConsumerWidget {
  const ChatSessionsDrawer({
    super.key,
    required this.episodeId,
    required this.onStartNewChat,
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
                    return _SessionListTile(
                      session: session,
                      isSelected: isSelected,
                      episodeId: episodeId,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  AppLocalizations.of(context)?.error_prefix(e.toString()) ??
                      'Error: $e',
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
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

  final dynamic session;
  final bool isSelected;
  final int episodeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      leading: Icon(
        isSelected ? Icons.chat_bubble : Icons.chat_bubble_outline,
        color: isSelected ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(
        session.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isSelected ? Theme.of(context).colorScheme.primary : null,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        session.createdAt.substring(0, 10),
        style: Theme.of(context).textTheme.labelSmall,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, size: 20),
        onPressed: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(l10n.podcast_conversation_delete_title),
              content: Text(l10n.podcast_conversation_delete_confirm),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l10n.cancel),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(
                    l10n.delete,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          );
          if (confirm == true) {
            ref
                .read(sessionListProvider(episodeId).notifier)
                .deleteSession(session.id);
          }
        },
      ),
      selected: isSelected,
      onTap: () {
        ref
            .read(currentSessionIdProvider(episodeId).notifier)
            .set(session.id);
        Navigator.pop(context); // Close drawer
      },
    );
  }
}
