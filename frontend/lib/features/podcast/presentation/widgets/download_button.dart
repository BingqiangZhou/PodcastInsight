import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/services/download_provider.dart';

/// A compact download status button for episode cards and detail pages.
///
/// Shows three states:
/// - Not downloaded: download icon, tap to start
/// - Downloading: progress indicator, tap to cancel
/// - Downloaded: check icon, tap to delete
class DownloadButton extends ConsumerWidget {

  const DownloadButton({
    required this.episodeId, required this.audioUrl, super.key,
    this.size = 20,
    this.title,
    this.subscriptionTitle,
    this.imageUrl,
    this.subscriptionImageUrl,
    this.subscriptionId,
    this.audioDuration,
    this.publishedAt,
  });
  final int episodeId;
  final String audioUrl;
  final double size;
  final String? title;
  final String? subscriptionTitle;
  final String? imageUrl;
  final String? subscriptionImageUrl;
  final int? subscriptionId;
  final int? audioDuration;
  final DateTime? publishedAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final asyncTask = ref.watch(episodeDownloadStatusProvider(episodeId));

    return asyncTask.when(
      data: (task) {
        if (task == null) {
          // Not downloaded
          return _IconButton(
            icon: Icons.download_outlined,
            size: size,
            color: theme.colorScheme.onSurfaceVariant,
            tooltip: l10n.download_button_download,
            onPressed: () => _startDownload(ref),
          );
        }

        return switch (task.status) {
          'pending' => _IconButton(
              icon: Icons.downloading,
              size: size,
              color: theme.colorScheme.primary,
              tooltip: l10n.download_button_downloading,
              onPressed: () => _cancel(ref),
            ),
          'downloading' => _StreamProgress(
              episodeId: episodeId,
              size: size,
              onCancel: () => _cancel(ref),
            ),
          'completed' => _IconButton(
              icon: Icons.download_done,
              size: size,
              color: theme.colorScheme.primary,
              tooltip: l10n.download_button_delete,
              onPressed: () => _delete(ref),
            ),
          'failed' => _IconButton(
              icon: Icons.error_outline,
              size: size,
              color: theme.colorScheme.error,
              tooltip: l10n.download_button_retry,
              onPressed: () => _startDownload(ref),
            ),
          _ => _IconButton(
              icon: Icons.download_outlined,
              size: size,
              color: theme.colorScheme.onSurfaceVariant,
              tooltip: l10n.download_button_download,
              onPressed: () => _startDownload(ref),
            ),
        };
      },
      loading: () => SizedBox(
        width: size + 8,
        height: size + 4,
        child: Center(
          child: SizedBox(
            width: size,
            height: size,
            child: const CircularProgressIndicator.adaptive(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, _) => _IconButton(
        icon: Icons.download_outlined,
        size: size,
        color: theme.colorScheme.onSurfaceVariant,
        tooltip: l10n.download_button_download,
        onPressed: () => _startDownload(ref),
      ),
    );
  }

  void _startDownload(WidgetRef ref) {
    ref.read(downloadManagerProvider).download(
          episodeId: episodeId,
          audioUrl: audioUrl,
          title: title,
          subscriptionTitle: subscriptionTitle,
          imageUrl: imageUrl,
          subscriptionImageUrl: subscriptionImageUrl,
          subscriptionId: subscriptionId,
          audioDuration: audioDuration,
          publishedAt: publishedAt,
        );
  }

  void _cancel(WidgetRef ref) {
    ref.read(downloadManagerProvider).cancel(episodeId);
  }

  void _delete(WidgetRef ref) {
    ref.read(downloadManagerProvider).delete(episodeId);
  }
}

/// Simple icon button with tooltip.
class _IconButton extends StatelessWidget {

  const _IconButton({
    required this.icon,
    required this.size,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });
  final IconData icon;
  final double size;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final buttonSize = size + 4;
    final buttonStyle = IconButton.styleFrom(
      minimumSize: Size(buttonSize, buttonSize),
      maximumSize: Size(buttonSize, buttonSize),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      foregroundColor: color,
    );

    return IconButton(
      style: buttonStyle,
      icon: Icon(icon, size: size),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}

/// Animated progress indicator during active download.
class _StreamProgress extends ConsumerWidget {

  const _StreamProgress({
    required this.episodeId,
    required this.size,
    required this.onCancel,
  });
  final int episodeId;
  final double size;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncTask = ref.watch(episodeDownloadStatusProvider(episodeId));
    final progress = asyncTask.value?.progress ?? 0.0;

    return GestureDetector(
      onTap: onCancel,
      child: Tooltip(
        message:
            '${(progress * 100).toStringAsFixed(0)}% — ${context.l10n.download_button_cancel}',
        child: SizedBox(
          width: size + 8,
          height: size + 4,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: size + 8,
                height: size + 8,
                child: Theme(
                  data: theme.copyWith(
                    colorScheme: theme.colorScheme.copyWith(
                      primary: theme.colorScheme.primary,
                    ),
                  ),
                  child: CircularProgressIndicator.adaptive(
                    value: progress > 0 ? progress : null,
                    strokeWidth: 2,
                  ),
                ),
              ),
              Icon(
                Icons.close,
                size: size * 0.6,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
