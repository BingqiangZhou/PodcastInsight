import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/constants/app_radius.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/database/app_database.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/services/audio_download_service.dart';
import 'package:personal_ai_assistant/core/services/download_provider.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/core/widgets/app_dialog_helper.dart';
import 'package:personal_ai_assistant/core/widgets/custom_adaptive_navigation.dart';
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_episodes_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/podcast_image_widget.dart';

/// Page for managing downloaded podcast episodes.
class PodcastDownloadsPage extends ConsumerWidget {
  const PodcastDownloadsPage({super.key});

  static const double _bottomBufferForPlayer = 100;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tokens = appThemeOf(context);
    final asyncDownloads = ref.watch(downloadsListProvider);
    final grouped = ref.watch(groupedDownloadsProvider);

    final deleteButton = grouped.completed.isNotEmpty
        ? HeaderCapsuleActionButton(
            icon: Icons.delete_sweep,
            tooltip: l10n.downloads_delete_all,
            circular: true,
            onPressed: () =>
                _confirmDeleteAll(context, ref, grouped.completed),
          )
        : null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Material(
        color: Colors.transparent,
        child: ResponsiveContainer(
          maxWidth: 1480,
          avoidTopSafeArea: true,
          alignment: Alignment.topCenter,
          child: AdaptiveRefreshIndicator.sliver(
            onRefresh: () async {
              ref.invalidate(downloadsListProvider);
            },
            child: const SizedBox.shrink(),
            builder: (context, refreshSliver) {
              return CustomScrollView(
                slivers: [
                  if (refreshSliver != null) refreshSliver,
                  AdaptiveSliverAppBar(
                    title: l10n.downloads_page_title,
                    actions: [if (deleteButton != null) deleteButton],
                  ),
                  SliverToBoxAdapter(child: SizedBox(height: context.spacing.smMd)),
                  ...asyncDownloads.when(
                    data: (tasks) {
                      if (tasks.isEmpty) {
                        return _buildEmptySlivers(context, l10n, tokens);
                      }
                      return _buildDataSlivers(
                        context,
                        grouped,
                        l10n,
                        theme,
                        tokens,
                      );
                    },
                    loading: () => _buildLoadingSlivers(context, l10n, tokens),
                    error: (e, _) =>
                        _buildErrorSlivers(context, ref, l10n, theme, e),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAll(
    BuildContext context,
    WidgetRef ref,
    List<DownloadTask> tasks,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showAppConfirmationDialog(
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

  List<Widget> _buildEmptySlivers(
    BuildContext context,
    AppLocalizations l10n,
    AppThemeExtension tokens,
  ) {
    final theme = Theme.of(context);
    return [
      SliverFillRemaining(
        hasScrollBody: false,
        child: SurfacePanel(
          padding: EdgeInsets.zero,
          showBorder: false,
          borderRadius: tokens.cardRadius,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(context.spacing.mdLg, context.spacing.md, context.spacing.mdLg, context.spacing.smMd),
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
                  padding: EdgeInsets.all(context.spacing.mdLg),
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: AppRadius.xxlCardRadius,
                      border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15)),
                    ),
                    padding: EdgeInsets.all(context.spacing.md),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.download_outlined,
                            size: 48,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          SizedBox(height: context.spacing.smMd),
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
        ),
      ),
    ];
  }

  List<Widget> _buildDataSlivers(
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

    return [
      // Header panel top
      SliverToBoxAdapter(
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(tokens.cardRadius),
              topRight: Radius.circular(tokens.cardRadius),
            ),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(context.spacing.mdLg, context.spacing.md, context.spacing.mdLg, context.spacing.smMd),
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
            ],
          ),
        ),
      ),
      // List items
      SliverList.builder(
        itemCount: allTasks.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              context.spacing.sm,
              index == 0 ? context.spacing.sm : 0,
              context.spacing.sm,
              context.spacing.sm,
            ),
            child: _DownloadTaskCard(task: allTasks[index]),
          );
        },
      ),
      // Bottom cap
      SliverToBoxAdapter(
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(tokens.cardRadius),
              bottomRight: Radius.circular(tokens.cardRadius),
            ),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15),
            ),
          ),
          height: context.spacing.smMd,
        ),
      ),
      // Bottom buffer for player
      SliverPadding(
        padding: EdgeInsets.only(bottom: _bottomBufferForPlayer),
      ),
    ];
  }

  List<Widget> _buildLoadingSlivers(
    BuildContext context,
    AppLocalizations l10n,
    AppThemeExtension tokens,
  ) {
    return [
      SliverFillRemaining(
        hasScrollBody: false,
        child: SurfacePanel(
          padding: EdgeInsets.zero,
          showBorder: false,
          borderRadius: tokens.cardRadius,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(context.spacing.mdLg, context.spacing.md, context.spacing.mdLg, context.spacing.smMd),
                child: AppSectionHeader(
                  title: l10n.downloads_page_title,
                  subtitle: l10n.loading,
                  hideTitle: true,
                ),
              ),
              Divider(
                height: 1,
                color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.45),
              ),
              const Expanded(
                child: Center(child: CircularProgressIndicator.adaptive()),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildErrorSlivers(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    ThemeData theme,
    Object error,
  ) {
    return [
      SliverFillRemaining(
        hasScrollBody: false,
        child: SurfacePanel(
          padding: EdgeInsets.zero,
          showBorder: false,
          borderRadius: appThemeOf(context).cardRadius,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(context.spacing.mdLg, context.spacing.md, context.spacing.mdLg, context.spacing.smMd),
                child: AppSectionHeader(
                  title: l10n.downloads_page_title,
                  subtitle: l10n.podcast_downloads_load_error,
                  hideTitle: true,
                ),
              ),
              Divider(
                height: 1,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(context.spacing.lg),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: theme.colorScheme.error,
                        ),
                        SizedBox(height: context.spacing.lg),
                        Text(
                          l10n.podcast_downloads_load_error,
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: context.spacing.md),
                        FilledButton.tonal(
                          onPressed: () => ref.invalidate(downloadsListProvider),
                          child: Text(l10n.retry),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
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

    return AdaptiveDismissible(
      key: ValueKey(task.id),
      onDelete: () => service.delete(task.episodeId),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.xxlCardRadius,
          onTap: null,
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: AppRadius.xxlCardRadius,
              border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15)),
            ),
            padding: EdgeInsets.fromLTRB(context.spacing.md, context.spacing.smMd, context.spacing.smMd, context.spacing.smMd),
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
                SizedBox(width: context.spacing.md), // icon-size, not spacing
                // Title and subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        episodeTitle ?? l10n.podcast_episode_fallback_title(task.episodeId),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: context.spacing.xs),
                      if (podcastTitle != null) ...[
                        Text(
                          podcastTitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: context.spacing.xs / 2),
                      ],
                      if (task.status == DownloadStatus.downloading)
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
                  SizedBox(width: context.spacing.sm),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      icon: Icon(_trailingIcon(task), size: 18),
                      padding: EdgeInsets.zero,
                      tooltip: _trailingTooltip(task, l10n),
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
      DownloadStatus.failed => Icons.refresh,
      DownloadStatus.downloading || DownloadStatus.pending => Icons.close,
      _ => null,
    };
  }

  VoidCallback? _trailingAction(
    DownloadTask task,
    AudioDownloadService service,
  ) {
    return switch (task.status) {
      DownloadStatus.failed => () => service.download(
            episodeId: task.episodeId,
            audioUrl: task.audioUrl,
          ),
      DownloadStatus.downloading || DownloadStatus.pending => () => service.cancel(task.episodeId),
      _ => null,
    };
  }

  String _trailingTooltip(DownloadTask task, AppLocalizations l10n) {
    return switch (task.status) {
      DownloadStatus.failed => l10n.download_button_retry,
      DownloadStatus.downloading || DownloadStatus.pending => l10n.download_button_cancel,
      _ => '',
    };
  }

  String _statusText(DownloadTask task, AppLocalizations l10n) {
    return switch (task.status) {
      DownloadStatus.completed => l10n.download_button_downloaded,
      DownloadStatus.failed => l10n.download_button_failed,
      DownloadStatus.pending => l10n.download_button_download,
      DownloadStatus.downloading => '${(task.progress * 100).toStringAsFixed(0)}%',
      _ => task.status.name,
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
      DownloadStatus.completed => CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            Icons.download_done,
            color: theme.colorScheme.onPrimaryContainer,
            size: 20,
          ),
        ),
      DownloadStatus.failed => CircleAvatar(
          backgroundColor: theme.colorScheme.errorContainer,
          child: Icon(
            Icons.error_outline,
            color: theme.colorScheme.onErrorContainer,
            size: 20,
          ),
        ),
      _ => CircleAvatar(
          backgroundColor: theme.colorScheme.secondaryContainer,
          child: task.status == DownloadStatus.downloading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: Theme(
                    data: theme.copyWith(
                      colorScheme: theme.colorScheme.copyWith(
                        primary: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                    child: CircularProgressIndicator.adaptive(
                      value: task.progress > 0 ? task.progress : null,
                      strokeWidth: 2,
                    ),
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
