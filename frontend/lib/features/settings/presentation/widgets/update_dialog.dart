import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_ai_assistant/core/constants/app_radius.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/constants/breakpoints.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/platform/platform_helper.dart';
import 'package:personal_ai_assistant/core/services/app_update_service.dart';
import 'package:personal_ai_assistant/core/theme/app_theme.dart';
import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;
import 'package:personal_ai_assistant/core/widgets/app_dialog_helper.dart';
import 'package:personal_ai_assistant/core/widgets/responsive_dialog_helper.dart';
import 'package:personal_ai_assistant/core/widgets/top_floating_notice.dart';
import 'package:personal_ai_assistant/features/settings/presentation/providers/app_update_provider.dart';
import 'package:personal_ai_assistant/shared/models/github_release.dart';
import 'package:url_launcher/url_launcher.dart';

class _UpdateDialogPalette {
  const _UpdateDialogPalette({
    required this.accent,
    required this.accentOn,
    required this.stateSecondaryText,
    required this.loadingIndicator,
    required this.errorIcon,
  });

  final Color accent;
  final Color accentOn;
  final Color stateSecondaryText;
  final Color loadingIndicator;
  final Color errorIcon;

  static _UpdateDialogPalette of(ThemeData theme) {
    final scheme = theme.colorScheme;
    return _UpdateDialogPalette(
      accent: scheme.primary,
      accentOn: scheme.onPrimary,
      stateSecondaryText: scheme.onSurfaceVariant,
      loadingIndicator: scheme.onSurfaceVariant,
      errorIcon: scheme.error,
    );
  }
}

class _UpdateStatusMark extends StatelessWidget {
  const _UpdateStatusMark({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('manual_update_uptodate_mark'),
      width: 84,
      height: 84,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 5),
        ),
        child: Icon(Icons.check, size: 44, color: color),
      ),
    );
  }
}

/// App Update Dialog / 应用更新对话框
///
/// Material 3 styled dialog for displaying available app updates.
/// Shows release information, download options, and user actions.
class AppUpdateDialog extends ConsumerStatefulWidget {

  const AppUpdateDialog({
    required this.release, required this.currentVersion, super.key,
  });
  final GitHubRelease release;
  final String currentVersion;

  /// Show the dialog
  static Future<void> show({
    required BuildContext context,
    required GitHubRelease release,
    required String currentVersion,
  }) {
    return showAppDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          AppUpdateDialog(release: release, currentVersion: currentVersion),
    );
  }

  @override
  ConsumerState<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends ConsumerState<AppUpdateDialog> {
  bool _isDownloading = false;

  /// The matched asset for the current platform, resolved once.
  GitHubAsset? get _platformAsset =>
      widget.release.getAssetForPlatform(AppUpdateService.getCurrentPlatform());

  bool get _hasPlatformAsset => _platformAsset != null;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final palette = _UpdateDialogPalette.of(theme);
    final isMobile = context.isMobile;
    final dialogWidth = ResponsiveDialogHelper.maxWidth(
      context,
      desktopMaxWidth: 500,
    );

    return AlertDialog.adaptive(
      backgroundColor: Colors.transparent,
      insetPadding: isMobile
          ? ResponsiveDialogHelper.insetPadding()
          : EdgeInsets.symmetric(horizontal: context.spacing.xl, vertical: context.spacing.lg),
      title: Row(
        children: [
          Icon(Icons.system_update_alt, color: palette.accent, size: context.spacing.xl),
          SizedBox(width: context.spacing.smMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.update_new_version_available),
                Text(
                  '${widget.currentVersion} → ${widget.release.version}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Release info
              _buildReleaseInfo(context),
              SizedBox(height: context.spacing.lg),

              // Release notes
              _buildReleaseNotes(context),
            ],
          ),
        ),
      ),
      actions: isMobile
          ? _buildMobileActions(context, theme)
          : _buildDesktopActions(context, theme),
    );
  }

  /// Desktop actions layout
  List<Widget> _buildDesktopActions(BuildContext context, ThemeData theme) {
    final l10n = context.l10n;
    final palette = _UpdateDialogPalette.of(theme);
    final spacing = context.spacing;
    return [
      // Use Row to control alignment
      Row(
        children: [
          // Skip this version (left)
          TextButton.icon(
            onPressed: () => _handleSkip(context),
            icon: const Icon(Icons.skip_next, size: 18),
            label: Text(l10n.update_skip_this_version),
          ),

          const Spacer(),

          // Later + Download (right)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.update_later),
          ),

          SizedBox(width: spacing.sm),

          // Download button (primary action) — disabled when no platform asset
          Flexible(
            child: FilledButton.icon(
              onPressed: _isDownloading || !_hasPlatformAsset
                  ? null
                  : () => _handleDownload(context),
              icon: _isDownloading
                  ? SizedBox(
                      width: spacing.lg,
                      height: spacing.lg,
                      child: CircularProgressIndicator.adaptive(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.download, size: 18),
              label: Text(
                _hasPlatformAsset
                    ? l10n.update_download
                    : l10n.update_platform_no_asset,
                overflow: TextOverflow.ellipsis,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: palette.accent,
                foregroundColor: palette.accentOn,
              ),
            ),
          ),
        ],
      ),
    ];
  }

  /// Mobile actions layout
  List<Widget> _buildMobileActions(BuildContext context, ThemeData theme) {
    final l10n = context.l10n;
    final palette = _UpdateDialogPalette.of(theme);
    final spacing = context.spacing;
    return [
      SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.icon(
              onPressed: _isDownloading || !_hasPlatformAsset
                  ? null
                  : () => _handleDownload(context),
              icon: _isDownloading
                  ? SizedBox(
                      width: spacing.lg,
                      height: spacing.lg,
                      child: CircularProgressIndicator.adaptive(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.download, size: 18),
              label: Text(
                _hasPlatformAsset
                    ? l10n.update_download
                    : l10n.update_platform_no_asset,
                overflow: TextOverflow.ellipsis,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: palette.accent,
                foregroundColor: palette.accentOn,
                padding: EdgeInsets.symmetric(vertical: spacing.smMd),
              ),
            ),
            SizedBox(height: spacing.sm),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _handleSkip(context),
                    icon: const Icon(Icons.skip_next, size: 18),
                    label: Text(
                      l10n.update_skip_this_version,
                      style: AppTheme.caption(),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: spacing.sm),
                    ),
                  ),
                ),
                SizedBox(width: spacing.sm),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.update_later),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildReleaseInfo(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final palette = _UpdateDialogPalette.of(theme);
    final isMobile = context.isMobile;
    final asset = _platformAsset;
    final spacing = context.spacing;

    return Container(
      padding: EdgeInsets.all(spacing.smMd),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: AppRadius.mdLgRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Version row
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: palette.accent),
              SizedBox(width: spacing.sm),
              Expanded(
                child: Text(
                  l10n.update_latest_version,
                  style: theme.textTheme.labelMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: context.spacing.sm),
              Text(
                'v${widget.release.version}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: palette.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: context.spacing.sm),
          // Release date and file size - aligned with icon
          if (isMobile) ...[
            // Mobile: vertical layout
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    SizedBox(width: context.spacing.sm),
                    Expanded(
                      child: Text(
                        '${l10n.update_published_at}: ${widget.release.formattedPublishedDate}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                if (asset != null) ...[
                  SizedBox(height: spacing.xs),
                  Row(
                    children: [
                      Icon(
                        Icons.file_download,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      SizedBox(width: context.spacing.sm),
                      Expanded(
                        child: Text(
                          '${l10n.update_file_size}: ${asset.formattedSize}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ] else ...[
            // Desktop: horizontal layout
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                SizedBox(width: context.spacing.sm),
                Text(
                  '${l10n.update_published_at}: ${widget.release.formattedPublishedDate}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (asset != null) ...[
                  SizedBox(width: spacing.lg),
                  Icon(
                    Icons.file_download,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  SizedBox(width: context.spacing.sm),
                  Text(
                    '${l10n.update_file_size}: ${asset.formattedSize}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReleaseNotes(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final palette = _UpdateDialogPalette.of(theme);
    final releaseNotes = widget.release.body.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.description, size: 18, color: palette.accent),
            SizedBox(width: context.spacing.sm),
            Text(l10n.update_release_notes, style: theme.textTheme.labelMedium),
          ],
        ),
        SizedBox(height: context.spacing.sm),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(context.spacing.smMd),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: AppRadius.mdLgRadius,
          ),
          child: releaseNotes.isEmpty
              ? Text(
                  l10n.no_data,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              : MarkdownBody(
                  data: releaseNotes,
                  onTapLink: (text, href, title) {
                    _handleReleaseNotesLinkTap(href);
                  },
                  styleSheet: MarkdownStyleSheet(
                    p: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    h1: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                    h2: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                    h3: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                    listBullet: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    strong: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                    code: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                      backgroundColor:
                          Colors.transparent,
                    ),
                    codeblockPadding: EdgeInsets.all(context.spacing.smMd),
                    codeblockDecoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: AppRadius.mdLgRadius,
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    blockquotePadding: EdgeInsets.all(context.spacing.smMd),
                    blockquoteDecoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: AppRadius.mdLgRadius,
                      border: Border(
                        left: BorderSide(color: palette.accent, width: 3),
                      ),
                    ),
                    horizontalRuleDecoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                    a: theme.textTheme.bodySmall?.copyWith(
                      color: palette.accent,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _handleReleaseNotesLinkTap(String? href) async {
    if (href == null || href.isEmpty) {
      return;
    }

    try {
      final uri = Uri.parse(href);
      final canOpen = await canLaunchUrl(uri);
      if (!mounted) return;
      if (!canOpen) {
        _showReleaseNotesLinkError();
        return;
      }

      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      if (!opened) {
        _showReleaseNotesLinkError();
      }
    } catch (e, stackTrace) {
      logger.AppLogger.debug(
        '[UpdateDialog] Failed to open release notes link: $href, error: $e',
      );
      logger.AppLogger.debug('[UpdateDialog] Stack trace: $stackTrace');
      if (!mounted) return;
      _showReleaseNotesLinkError();
    }
  }

  void _showReleaseNotesLinkError() {
    if (!mounted) return;
    final l10n = context.l10n;
    showTopFloatingNotice(
      context,
      message: l10n.update_download_failed,
      isError: true,
    );
  }

  Future<void> _handleDownload(BuildContext context) async {
    setState(() {
      _isDownloading = true;
    });

    try {
      final asset = _platformAsset;

      if (asset == null) {
        // No platform asset available, open release page in browser
        final uri = Uri.parse(widget.release.htmlUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (context.mounted) {
            showTopFloatingNotice(
              context,
              message: context.l10n.update_download_url_failed,
              isError: true,
            );
          }
        }
      } else if (PlatformHelper.isAndroid(context) &&
          AppUpdateService.supportsBackgroundDownload) {
        // Use native background download on Android
        final service = ref.read(appUpdateServiceProvider);
        final success = await service.startBackgroundDownload(
          downloadUrl: asset.downloadUrl,
          fileName: _extractFileName(asset.downloadUrl),
        );

        if (!success && context.mounted) {
          final l10n = context.l10n;
          showTopFloatingNotice(
            context,
            message: l10n.update_download_failed,
            isError: true,
          );
        } else if (success && context.mounted) {
          // Download started, close dialog and show message
          final l10n = context.l10n;
          showTopFloatingNotice(
            context,
            message: l10n.downloading_in_background,
            duration: const Duration(seconds: 5),
          );
          Navigator.of(context).pop();
        }
      } else {
        // Other platforms: open the matched asset URL externally
        final uri = Uri.parse(asset.downloadUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          // Fallback to release page
          final releaseUri = Uri.parse(widget.release.htmlUrl);
          if (await canLaunchUrl(releaseUri)) {
            await launchUrl(releaseUri, mode: LaunchMode.externalApplication);
          } else {
            if (context.mounted) {
              showTopFloatingNotice(
                context,
                message: context.l10n.update_download_url_failed,
                isError: true,
              );
            }
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        final l10n = context.l10n;
        showTopFloatingNotice(
          context,
          message: l10n.update_download_failed,
          isError: true,
        );
      }
    } finally {
      if (context.mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  /// Extract filename from download URL
  String _extractFileName(String url) {
    final uri = Uri.parse(url);
    final pathSegments = uri.pathSegments;
    if (pathSegments.isNotEmpty) {
      final filename = pathSegments.last;
      if (filename.endsWith('.apk')) {
        return filename;
      }
    }
    return 'app_update.apk';
  }

  void _handleSkip(BuildContext context) {
    ref.read(appUpdateProvider.notifier).skipVersion();
    Navigator.of(context).pop();
  }
}

/// Manual Update Check Dialog / 手动检查更新对话框
///
/// Shows a loading state while checking for updates,
/// then displays the result (update available or up to date).
class ManualUpdateCheckDialog extends ConsumerStatefulWidget {
  const ManualUpdateCheckDialog({super.key});
  static bool _isShowing = false;

  static Future<void> show(BuildContext context) {
    if (_isShowing) return Future.value();
    _isShowing = true;
    try {
      return showAppDialog(
        context: context,
        builder: (context) => const ManualUpdateCheckDialog(),
      );
    } finally {
      _isShowing = false;
    }
  }

  @override
  ConsumerState<ManualUpdateCheckDialog> createState() =>
      _ManualUpdateCheckDialogState();
}

class _ManualUpdateCheckDialogState
    extends ConsumerState<ManualUpdateCheckDialog> {
  bool _redirectingToUpdateDialog = false;

  @override
  void initState() {
    super.initState();
    // Trigger check on dialog open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(manualUpdateCheckProvider.notifier).check();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(manualUpdateCheckProvider);
    _maybeRedirectToDetailedDialog(context, state);
    final dialogWidth = ResponsiveDialogHelper.maxWidth(
      context,
      desktopMaxWidth: 400,
    );
    return AlertDialog.adaptive(
      backgroundColor: Colors.transparent,
      insetPadding: ResponsiveDialogHelper.insetPadding(),
      title: Text(l10n.update_check_updates),
      content: SizedBox(
        width: dialogWidth,
        child: _buildContent(context, state),
      ),
      actions: _buildActions(context, state),
    );
  }

  void _maybeRedirectToDetailedDialog(
    BuildContext context,
    AppUpdateState state,
  ) {
    final release = state.latestRelease;
    final shouldRedirect =
        !state.isLoading &&
        state.error == null &&
        state.hasUpdate &&
        release != null &&
        !_redirectingToUpdateDialog;

    if (!shouldRedirect) {
      return;
    }

    _redirectingToUpdateDialog = true;
    final currentVersion = state.currentVersion;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pop();
      AppUpdateDialog.show(
        context: context,
        release: release,
        currentVersion: currentVersion,
      );
    });
  }

  Widget _buildContent(BuildContext context, AppUpdateState state) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final palette = _UpdateDialogPalette.of(theme);

    if (state.isLoading) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: CircularProgressIndicator.adaptive(
              strokeWidth: 3,
            ),
          ),
          SizedBox(height: context.spacing.mdLg),
          Text(l10n.update_checking, style: theme.textTheme.bodyLarge),
        ],
      );
    }

    if (state.error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: palette.errorIcon),
          SizedBox(height: context.spacing.mdLg),
          Text(l10n.update_check_failed, style: theme.textTheme.titleMedium),
          SizedBox(height: context.spacing.sm),
          Text(
            state.error!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.stateSecondaryText,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    if (state.hasUpdate && state.latestRelease != null) {
      return const SizedBox.shrink();
    }

    // Up to date
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _UpdateStatusMark(color: palette.stateSecondaryText),
        SizedBox(height: context.spacing.lg),
        Text(
          key: const Key('manual_update_uptodate_text'),
          l10n.update_up_to_date,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: palette.stateSecondaryText,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: context.spacing.smMd),
        Text(
          'v${state.currentVersion}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: palette.stateSecondaryText,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildActions(BuildContext context, AppUpdateState state) {
    final l10n = context.l10n;
    final palette = _UpdateDialogPalette.of(Theme.of(context));

    if (state.isLoading) {
      return [];
    }

    if (state.error != null) {
      return [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: palette.accent),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: palette.accent),
          onPressed: () {
            ref.read(manualUpdateCheckProvider.notifier).check();
          },
          child: Text(l10n.update_try_again),
        ),
      ];
    }

    if (state.hasUpdate && state.latestRelease != null) {
      return [];
    }

    return [
      TextButton(
        style: TextButton.styleFrom(
          foregroundColor: palette.stateSecondaryText,
        ),
        onPressed: () => Navigator.of(context).pop(),
        child: Text(l10n.ok),
      ),
    ];
  }
}

/// Show a top floating notice when an update is available.
void showUpdateAvailableSnackBar({
  required BuildContext context,
  required GitHubRelease release,
}) {
  final l10n = context.l10n;

  showTopFloatingNotice(
    context,
    message: '${l10n.update_new_version_available}: v${release.version}',
    duration: const Duration(seconds: 10),
  );
}
