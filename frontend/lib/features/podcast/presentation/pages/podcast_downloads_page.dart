import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_ai_assistant/core/constants/breakpoints.dart';
import 'package:personal_ai_assistant/core/database/app_database.dart';
import 'package:personal_ai_assistant/core/glass/glass_background.dart';
import 'package:personal_ai_assistant/core/glass/surface_card.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/services/audio_download_service.dart';
import 'package:personal_ai_assistant/core/services/download_provider.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/core/widgets/custom_adaptive_navigation.dart';
import 'package:personal_ai_assistant/core/widgets/glass_dialog_helper.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_episodes_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/podcast_image_widget.dart';

/// Page for managing downloaded podcast episodes.
class PodcastDownloadsPage extends ConsumerWidget {
  const PodcastDownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tokens = appThemeOf(context);
    final asyncDownloads = ref.watch(downloadsListProvider);
    final grouped = ref.watch(groupedDownloadsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Material(
        color: Colors.transparent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const GlassBackground(
              theme: GlassBackgroundTheme.neutral,
              child: SizedBox.expand(),
            ),
            SafeArea(
              bottom: false,
              child: ResponsiveContainer(
                maxWidth: 1480,
                alignment: Alignment.topCenter,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderPanel(context, ref, l10n, grouped),
                    const SizedBox(height: 12),
                    Expanded(
                      child: asyncDownloads.when(
                        data: (tasks) {
                          if (tasks.isEmpty) {
                            return _buildEmptyState(context, l10n, tokens);
                          }
                          return _buildDownloadsPanel(
                            context,
                            grouped,
                            l10n,
                            theme,
                            tokens,
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Center(child: Text(e.toString())),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderPanel(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    GroupedDownloads grouped,
  ) {
    final isMobile = MediaQuery.sizeOf(context).width < Breakpoints.medium;

    final deleteButton = grouped.completed.isNotEmpty
        ? HeaderCapsuleActionButton(
            icon: Icons.delete_sweep,
            tooltip: l10n.downloads_delete_all,
            circular: true,
            onPressed: () =>
                _confirmDeleteAll(context, ref, grouped.completed),
          )
        : null;

    return CompactHeaderPanel(
      title: l10n.downloads_page_title,
      trailing: isMobile
          ? deleteButton
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (deleteButton != null) ...[
                  deleteButton,
                  const SizedBox(width: 8),
                ],
                HeaderCapsuleActionButton(
                  tooltip:
                      MaterialLocalizations.of(context).backButtonTooltip,
                  icon: Icons.arrow_back_rounded,
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/');
                    }
                  },
                  circular: true,
                ),
              ],
            ),
    );
  }

  Future<void> _confirmDeleteAll(
    BuildContext context,
    WidgetRef ref,
    List<DownloadTask> tasks,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showGlassConfirmationDialog(
      context: context,
      title: l10n.downloads_delete_confirm,
      message: l10n.downloads_delete_confirm_message,
      confirmText: l10n.downloads_delete_all,
      isDestructive: true,
    );
    if (confirmed != true) return;

    final service = ref.read(downloadManagerProvider);
    for (final task in tasks) {
      service.delete(task.episodeId);
    }
  }

  Widget _buildEmptyState(
    BuildContext context,
    AppLocalizations l10n,
    AppThemeExtension tokens,
  ) {
    final theme = Theme.of(context);
    return SurfacePanel(
      padding: EdgeInsets.zero,
      showBorder: false,
      borderRadius: tokens.cardRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: AppSectionHeader(
              title: l10n.downloads_page_title,
              subtitle: l10n.downloads_empty,
              hideTitle: true,
            ),
          ),
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SurfaceCard(
                borderRadius: 22,
                padding: const EdgeInsets.all(18),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.download_outlined,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 12),
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadsPanel(
    BuildContext context,
    GroupedDownloads grouped,
    AppLocalizations l10n,
    ThemeData theme,
    AppThemeExtension tokens,
  ) {
    final totalDownloads = grouped.active.length +
        grouped.failed.length +
        grouped.completed.length;

    final allTasks = [
      ...grouped.active,
      ...grouped.failed,
      ...grouped.completed,
    ];

    return SurfacePanel(
      padding: EdgeInsets.zero,
      showBorder: false,
      borderRadius: tokens.cardRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: AppSectionHeader(
              title: l10n.downloads_page_title,
              subtitle: l10n.downloads_items(totalDownloads),
              hideTitle: true,
            ),
          ),
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(
                left: 8,
                right: 8,
                top: 8,
                bottom: 100,
              ),
              children: allTasks.map(
                (task) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _DownloadTaskCard(task: task),
                ),
              ).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadTaskCard extends ConsumerWidget {
  const _DownloadTaskCard({required this.task});
  final DownloadTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final service = ref.read(downloadManagerProvider);
    final episodeAsync = ref.watch(episodeCacheMetaProvider(task.episodeId));

    final cached = episodeAsync.asData?.value;
    final apiAsync =
        cached == null ? ref.watch(episodeDetailProvider(task.episodeId)) : null;

    final episodeTitle = cached?.title ?? apiAsync?.asData?.value?.title;
    final podcastTitle = cached?.subscriptionTitle ??
        apiAsync?.asData?.value?.subscription?['title'] as String?;
    final imageUrl = cached?.subscriptionImageUrl ??
        cached?.imageUrl ??
        apiAsync?.asData?.value?.subscriptionImageUrl ??
        apiAsync?.asData?.value?.imageUrl;

    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => service.delete(task.episodeId),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.error,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Icon(Icons.delete, color: theme.colorScheme.onError),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {},
          child: SurfaceCard(
            borderRadius: 22,
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                // Leading image or status icon
                if (imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(
                      appThemeOf(context).itemRadius,
                    ),
                    child: PodcastImageWidget(
                      imageUrl: imageUrl,
                      width: 44,
                      height: 44,
                      iconSize: 22,
                    ),
                  )
                else
                  _StatusIcon(task: task),
                const SizedBox(width: 14),
                // Title and subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        episodeTitle ?? 'Episode #${task.episodeId}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (podcastTitle != null) ...[
                        Text(
                          podcastTitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                      ],
                      if (task.status == 'downloading')
                        LinearProgressIndicator(value: task.progress)
                      else
                        Text(
                          _statusText(task, l10n),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                // Trailing action
                if (_trailingIcon(task) != null) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      icon: Icon(_trailingIcon(task), size: 18),
                      padding: EdgeInsets.zero,
                      onPressed: _trailingAction(task, service),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData? _trailingIcon(DownloadTask task) {
    return switch (task.status) {
      'failed' => Icons.refresh,
      'downloading' || 'pending' => Icons.close,
      _ => null,
    };
  }

  VoidCallback? _trailingAction(
    DownloadTask task,
    AudioDownloadService service,
  ) {
    return switch (task.status) {
      'failed' => () => service.download(
            episodeId: task.episodeId,
            audioUrl: task.audioUrl,
          ),
      'downloading' || 'pending' => () => service.cancel(task.episodeId),
      _ => null,
    };
  }

  String _statusText(DownloadTask task, AppLocalizations l10n) {
    return switch (task.status) {
      'completed' => l10n.download_button_downloaded,
      'failed' => l10n.download_button_failed,
      'pending' => l10n.download_button_download,
      'downloading' => '${(task.progress * 100).toStringAsFixed(0)}%',
      _ => task.status,
    };
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.task});
  final DownloadTask task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return switch (task.status) {
      'completed' => CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
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
          backgroundColor: theme.colorScheme.secondaryContainer,
          child: task.status == 'downloading'
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    value: task.progress > 0 ? task.progress : null,
                    strokeWidth: 2,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                )
              : Icon(
                  Icons.downloading,
                  color: theme.colorScheme.onSecondaryContainer,
                  size: 20,
                ),
        ),
    };
  }
}
