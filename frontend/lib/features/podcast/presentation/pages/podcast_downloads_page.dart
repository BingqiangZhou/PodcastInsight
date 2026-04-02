import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/services/audio_download_service.dart';
import 'package:personal_ai_assistant/core/services/download_provider.dart';
import 'package:personal_ai_assistant/core/database/app_database.dart';

/// Page for managing downloaded podcast episodes.
class PodcastDownloadsPage extends ConsumerWidget {
  const PodcastDownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final asyncDownloads = ref.watch(downloadsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.downloads_page_title),
        actions: [
          asyncDownloads.maybeWhen(
            data: (tasks) {
              final completed = tasks
                  .where((t) => t.status == 'completed')
                  .toList();
              if (completed.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.delete_sweep),
                tooltip: l10n.downloads_delete_all,
                onPressed: () => _confirmDeleteAll(context, ref, completed),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: asyncDownloads.when(
        data: (tasks) {
          if (tasks.isEmpty) {
            return _EmptyState();
          }

          final active =
              tasks.where((t) => t.status == 'pending' || t.status == 'downloading').toList();
          final completed =
              tasks.where((t) => t.status == 'completed').toList();
          final failed = tasks.where((t) => t.status == 'failed').toList();

          return ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              if (active.isNotEmpty) ...[
                _SectionHeader(title: l10n.downloads_active_title),
                ...active.map((t) => _DownloadTaskTile(task: t)),
              ],
              if (failed.isNotEmpty) ...[
                _SectionHeader(title: l10n.download_button_failed),
                ...failed.map((t) => _DownloadTaskTile(task: t)),
              ],
              if (completed.isNotEmpty) ...[
                _SectionHeader(title: l10n.downloads_completed_title),
                ...completed.map((t) => _DownloadTaskTile(task: t)),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(child: Text(e.toString())),
      ),
    );
  }

  void _confirmDeleteAll(
    BuildContext context,
    WidgetRef ref,
    List<DownloadTask> tasks,
  ) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.downloads_delete_confirm),
        content: Text(l10n.downloads_delete_confirm_message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              MaterialLocalizations.of(ctx).cancelButtonLabel,
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              final service = ref.read(downloadManagerProvider);
              for (final task in tasks) {
                service.delete(task.episodeId);
              }
            },
            child: Text(l10n.downloads_delete_all),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _DownloadTaskTile extends ConsumerWidget {
  final DownloadTask task;

  const _DownloadTaskTile({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final service = ref.read(downloadManagerProvider);

    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => service.delete(task.episodeId),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: theme.colorScheme.error,
        child: Icon(Icons.delete, color: theme.colorScheme.onError),
      ),
      child: ListTile(
        leading: _StatusIcon(task: task),
        title: Text(
          'Episode #${task.episodeId}',
          style: theme.textTheme.bodyMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: task.status == 'downloading'
            ? LinearProgressIndicator(value: task.progress)
            : Text(
                _statusText(task, l10n),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
        trailing: _trailingAction(task, service, l10n),
      ),
    );
  }

  Widget? _trailingAction(
    DownloadTask task,
    AudioDownloadService service,
    AppLocalizations l10n,
  ) {
    return switch (task.status) {
      'failed' => IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: l10n.download_button_retry,
          onPressed: () => service.download(
            episodeId: task.episodeId,
            audioUrl: task.audioUrl,
          ),
        ),
      'downloading' || 'pending' => IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.download_button_cancel,
          onPressed: () => service.cancel(task.episodeId),
        ),
      _ => null,
    };
  }

  String _statusText(DownloadTask task, AppLocalizations l10n) {
    return switch (task.status) {
      'completed' => l10n.download_button_downloaded,
      'failed' => l10n.download_button_failed,
      'pending' => l10n.download_button_download,
      'downloading' =>
        '${(task.progress * 100).toStringAsFixed(0)}%',
      _ => task.status,
    };
  }
}

class _StatusIcon extends StatelessWidget {
  final DownloadTask task;

  const _StatusIcon({required this.task});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return switch (task.status) {
      'completed' => CircleAvatar(
          backgroundColor:
              theme.colorScheme.primaryContainer,
          child: Icon(
            Icons.download_done,
            color: theme.colorScheme.onPrimaryContainer,
            size: 20,
          ),
        ),
      'failed' => CircleAvatar(
          backgroundColor: theme.colorScheme.errorContainer,
          child: Icon(
            Icons.error_outline,
            color: theme.colorScheme.onErrorContainer,
            size: 20,
          ),
        ),
      _ => CircleAvatar(
          backgroundColor:
              theme.colorScheme.secondaryContainer,
          child: task.status == 'downloading'
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    value: task.progress > 0 ? task.progress : null,
                    strokeWidth: 2,
                    color:
                        theme.colorScheme.onSecondaryContainer,
                  ),
                )
              : Icon(
                  Icons.downloading,
                  color:
                      theme.colorScheme.onSecondaryContainer,
                  size: 20,
                ),
        ),
    };
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.download_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.downloads_empty,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.downloads_empty_subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
