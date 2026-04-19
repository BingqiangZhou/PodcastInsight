import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/constants/app_radius.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/constants/breakpoints.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/providers/core_providers.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive_sliver_app_bar.dart';
import 'package:personal_ai_assistant/core/widgets/adaptive/adaptive.dart';
import 'package:personal_ai_assistant/core/widgets/app_dialog_helper.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/core/widgets/custom_adaptive_navigation.dart';
import 'package:personal_ai_assistant/core/widgets/top_floating_notice.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/constants/podcast_ui_constants.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_discover_provider.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_search_provider.dart'
    as search;

enum _CacheCategory { images, audio, other }

class _CategoryStats {

  const _CategoryStats({required this.count, required this.bytes});
  final int count;
  final int bytes;
}

class _MediaCacheStats {

  const _MediaCacheStats({
    required this.images,
    required this.audio,
    required this.other,
    required this.totalCount,
    required this.totalBytes,
    required this.objects,
  });
  final _CategoryStats images;
  final _CategoryStats audio;
  final _CategoryStats other;
  final int totalCount;
  final int totalBytes;
  final List<CacheObject> objects;
}

class _CachePagePalette {
  const _CachePagePalette({
    required this.images,
    required this.audio,
    required this.other,
    required this.emptySegment,
    required this.deepCleanBackground,
    required this.deepCleanForeground,
  });

  final Color images;
  final Color audio;
  final Color other;
  final Color emptySegment;
  final Color deepCleanBackground;
  final Color deepCleanForeground;

  static _CachePagePalette of(ThemeData theme) {
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return _CachePagePalette(
      images: scheme.onSurfaceVariant,
      audio: scheme.tertiary,
      other: scheme.secondary,
      emptySegment: scheme.surfaceContainerHighest,
      deepCleanBackground: isDark ? scheme.surface : scheme.onSurfaceVariant,
      deepCleanForeground: isDark ? scheme.onSurface : scheme.surface,
    );
  }
}

class ProfileCacheManagementPage extends ConsumerStatefulWidget {
  const ProfileCacheManagementPage({super.key});

  @override
  ConsumerState<ProfileCacheManagementPage> createState() =>
      _ProfileCacheManagementPageState();
}

class _ProfileCacheManagementPageState
    extends ConsumerState<ProfileCacheManagementPage> {
  static const _emptyStats = _MediaCacheStats(
    images: _CategoryStats(count: 0, bytes: 0),
    audio: _CategoryStats(count: 0, bytes: 0),
    other: _CategoryStats(count: 0, bytes: 0),
    totalCount: 0,
    totalBytes: 0,
    objects: <CacheObject>[],
  );

  _MediaCacheStats _stats = _emptyStats;
  bool _isLoading = true;

  double _contentHorizontalInset(BuildContext context) =>
      context.isMobile ? kPodcastRowCardHorizontalMargin : 0;

  EdgeInsets _contentHorizontalPadding(BuildContext context) =>
      EdgeInsets.symmetric(horizontal: _contentHorizontalInset(context));

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final stats = await _loadStats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  bool _isImageUrl(String url) {
    final uri = Uri.tryParse(url);
    final path = (uri?.path ?? url).toLowerCase();
    const exts = <String>{'png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp', 'heic'};
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) return false;
    final ext = path.substring(dot + 1);
    return exts.contains(ext);
  }

  bool _isAudioUrl(String url) {
    final uri = Uri.tryParse(url);
    final path = (uri?.path ?? url).toLowerCase();
    const exts = <String>{'mp3', 'm4a', 'aac', 'wav', 'flac', 'ogg', 'opus'};
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) return false;
    final ext = path.substring(dot + 1);
    return exts.contains(ext);
  }

  _CacheCategory _categoryFor(CacheObject object) {
    final url = object.url;
    if (_isImageUrl(url)) return _CacheCategory.images;
    if (_isAudioUrl(url)) return _CacheCategory.audio;
    return _CacheCategory.other;
  }

  int _objectBytes(CacheObject object) {
    final length = object.length;
    if (length != null && length >= 0) return length;
    return 0;
  }

  Future<_MediaCacheStats> _loadStats() async {
    final cacheService = ref.read(appCacheServiceProvider);
    final manager = cacheService.mediaCacheManager;
    try {
      final repo = manager.config.repo;
      await repo.open().timeout(const Duration(seconds: 3));
      final objects = await repo.getAllObjects().timeout(
        const Duration(seconds: 3),
      );

      var imagesCount = 0;
      var audioCount = 0;
      var otherCount = 0;
      var imagesBytes = 0;
      var audioBytes = 0;
      var otherBytes = 0;

      for (final obj in objects) {
        final bytes = _objectBytes(obj);
        switch (_categoryFor(obj)) {
          case _CacheCategory.images:
            imagesCount += 1;
            imagesBytes += bytes;
          case _CacheCategory.audio:
            audioCount += 1;
            audioBytes += bytes;
          case _CacheCategory.other:
            otherCount += 1;
            otherBytes += bytes;
        }
      }

      return _MediaCacheStats(
        images: _CategoryStats(count: imagesCount, bytes: imagesBytes),
        audio: _CategoryStats(count: audioCount, bytes: audioBytes),
        other: _CategoryStats(count: otherCount, bytes: otherBytes),
        totalCount: objects.length,
        totalBytes: imagesBytes + audioBytes + otherBytes,
        objects: objects,
      );
    } catch (e) {
      logger.AppLogger.debug('[Cache] Failed to load cache stats: $e');
      return _emptyStats;
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const k = 1024;
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var i = 0;
    while (value >= k && i < units.length - 1) {
      value /= k;
      i += 1;
    }
    final decimals = i == 0 ? 0 : (i == 1 ? 1 : 2);
    return '${value.toStringAsFixed(decimals)} ${units[i]}';
  }

  String _formatMB(int bytes) {
    if (bytes <= 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(2)} MB';
  }

  Future<void> _runBatched<T>(
    Iterable<T> items,
    int batchSize,
    Future<void> Function(T item) run,
  ) async {
    final list = items.toList(growable: false);
    for (var i = 0; i < list.length; i += batchSize) {
      final end = (i + batchSize) > list.length ? list.length : (i + batchSize);
      final batch = list.sublist(i, end);
      await Future.wait(batch.map(run));
    }
  }

  Future<void> _deleteCategory(
    _MediaCacheStats stats,
    _CacheCategory category,
  ) async {
    final l10n = context.l10n;
    final selectedObjects = stats.objects
        .where((o) => _categoryFor(o) == category)
        .toList(growable: false);
    final selectedBytes = selectedObjects.fold<int>(
      0,
      (acc, obj) => acc + _objectBytes(obj),
    );

    final confirm = await showAppConfirmationDialog(
      context: context,
      title: l10n.profile_clear_cache,
      message: l10n.profile_cache_manage_delete_selected_confirm(
        selectedObjects.length,
        _formatBytes(selectedBytes),
      ),
      confirmText: l10n.delete,
    );
    if (confirm != true || !mounted) return;

    try {
      final cacheService = ref.read(appCacheServiceProvider);
      final manager = cacheService.mediaCacheManager;
      await _runBatched<CacheObject>(
        selectedObjects,
        24,
        (obj) => manager.removeFile(obj.key),
      );
      if (category == _CacheCategory.images) {
        await cacheService.clearMemoryImageCache();
      }

      if (!mounted) return;
      showTopFloatingNotice(context, message: l10n.profile_cache_cleared);
      await _refresh();
    } catch (e) {
      logger.AppLogger.debug('[Cache] Failed to delete category: $e');
      if (!mounted) return;
      showTopFloatingNotice(
        context,
        message: l10n.profile_cache_clear_failed(e.toString()),
        isError: true,
      );
    }
  }

  Future<void> _clearAll() async {
    final l10n = context.l10n;
    final confirm = await showAppConfirmationDialog(
      context: context,
      title: l10n.profile_clear_cache,
      message: l10n.profile_clear_cache_confirm,
      confirmText: l10n.clear,
    );
    if (confirm != true || !mounted) return;

    final nav = Navigator.of(context);
    showAppDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog.adaptive(
        backgroundColor: Colors.transparent,
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: context.spacing.mdLg,
              height: context.spacing.mdLg,
              child: const CircularProgressIndicator.adaptive(strokeWidth: 2),
            ),
            SizedBox(width: context.spacing.md),
            Flexible(child: Text(l10n.profile_clearing_cache)),
          ],
        ),
      ),
    );

    try {
      final dioClient = ref.read(dioClientProvider);
      await dioClient.clearCache();
      dioClient.clearETagCache();
      await ref.read(appCacheServiceProvider).clearAll();
      ref.read(podcastDiscoverProvider.notifier).clearRuntimeCache();
      ref.read(search.iTunesSearchServiceProvider).clearCache();

      ref.invalidate(search.podcastSearchProvider);
      ref.invalidate(podcastDiscoverProvider);
      ref.invalidate(podcastFeedProvider);
      ref.invalidate(podcastSubscriptionProvider);
      ref.invalidate(podcastEpisodesProvider);
      ref.invalidate(profileStatsProvider);
      ref.invalidate(playbackHistoryLiteProvider);

      if (!mounted) return;
      nav.pop();
      showTopFloatingNotice(context, message: l10n.profile_cache_cleared);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      nav.pop();
      showTopFloatingNotice(
        context,
        message: l10n.profile_cache_clear_failed(e.toString()),
        isError: true,
      );
    }
  }

  Widget _buildLegendDot(Color color, {Key? key}) {
    return Container(
      key: key,
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _buildLegendItem(Color color, String label, {Key? dotKey}) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLegendDot(color, key: dotKey),
        SizedBox(width: context.spacing.sm),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentBar({
    required int imagesBytes,
    required int audioBytes,
    required int otherBytes,
    required _CachePagePalette palette,
  }) {
    final total = (imagesBytes + audioBytes + otherBytes).clamp(0, 1 << 62);

    int flexFor(int bytes) {
      if (total <= 0) return 1;
      final ratio = bytes / total;
      final flex = (ratio * 1000).round();
      return flex <= 0 ? 0 : flex;
    }

    final imagesFlex = flexFor(imagesBytes);
    final audioFlex = flexFor(audioBytes);
    final otherFlex = flexFor(otherBytes);
    final emptyFlex = 1000 - imagesFlex - audioFlex - otherFlex;

    return ClipRRect(
      borderRadius: AppRadius.mdRadius,
      child: SizedBox(
        height: 12,
        child: Row(
          children: [
            if (imagesFlex > 0)
              Expanded(
                flex: imagesFlex,
                child: Container(
                  key: const Key('cache_segment_images'),
                  color: palette.images,
                ),
              ),
            if (audioFlex > 0)
              Expanded(
                flex: audioFlex,
                child: Container(
                  key: const Key('cache_segment_audio'),
                  color: palette.audio,
                ),
              ),
            if (otherFlex > 0)
              Expanded(
                flex: otherFlex,
                child: Container(
                  key: const Key('cache_segment_other'),
                  color: palette.other,
                ),
              ),
            if (emptyFlex > 0)
              Expanded(
                flex: emptyFlex,
                child: Container(color: palette.emptySegment),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewSection(
    BuildContext context, {
    required _MediaCacheStats stats,
    required _CachePagePalette palette,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: _contentHorizontalPadding(context),
      child: Container(
        key: const Key('cache_manage_overview_section'),
        padding: EdgeInsets.fromLTRB(context.spacing.lg, context.spacing.lg, context.spacing.lg, context.spacing.smMd),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: AppRadius.xlRadius,
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.profile_cache_manage_total_used,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: context.spacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  (stats.totalBytes / (1024 * 1024)).toStringAsFixed(2),
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(width: context.spacing.sm),
                Padding(
                  padding: EdgeInsets.only(bottom: context.spacing.sm),
                  child: Text(
                    'MB',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: context.spacing.xs),
            Text(
              AppLocalizations.of(
                context,
              )!.profile_cache_manage_item_count(stats.totalCount),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: context.spacing.md),
            _buildSegmentBar(
              imagesBytes: stats.images.bytes,
              audioBytes: stats.audio.bytes,
              otherBytes: stats.other.bytes,
              palette: palette,
            ),
            SizedBox(height: context.spacing.smMd),
            Wrap(
              spacing: context.spacing.lg,
              runSpacing: context.spacing.sm,
              children: [
                _buildLegendItem(
                  palette.images,
                  context.l10n.profile_cache_manage_images,
                  dotKey: const Key('cache_legend_images'),
                ),
                _buildLegendItem(
                  palette.audio,
                  context.l10n.profile_cache_manage_audio,
                  dotKey: const Key('cache_legend_audio'),
                ),
                _buildLegendItem(
                  palette.other,
                  context.l10n.profile_cache_manage_other,
                  dotKey: const Key('cache_legend_other'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required BuildContext context,
    required _CacheCategory category,
    required IconData icon,
    required Color color,
    required String title,
    required _CategoryStats stats,
    required VoidCallback onClean,
  }) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: _contentHorizontalInset(context),
        vertical: kPodcastRowCardVerticalMargin,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(context.itemRadius),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.15)),
        ),
        padding: EdgeInsets.fromLTRB(context.spacing.smMd, context.spacing.sm, context.spacing.sm, context.spacing.sm),
      child: Row(
          children: [
            Container(
              width: context.spacing.xl,
              height: context.spacing.xl,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: AppRadius.mdLgRadius,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            SizedBox(width: context.spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: context.spacing.sm),
                      _buildLegendDot(color),
                    ],
                  ),
                  SizedBox(height: context.spacing.xs),
                  Text(
                    l10n.profile_cache_manage_item_count(stats.count),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: context.spacing.sm),
            Text(
              _formatMB(stats.bytes),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(width: context.spacing.smMd),
            HeaderCapsuleActionButton(
              key: Key('cache_manage_clean_${category.name}'),
              tooltip: l10n.profile_cache_manage_clean,
              onPressed: stats.count == 0 ? null : onClean,
              icon: Icons.cleaning_services_outlined,
              circular: true,
              density: HeaderCapsuleActionButtonDensity.iconOnly,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContentSlivers(
    BuildContext context, {
    required _MediaCacheStats stats,
    required _CachePagePalette palette,
  }) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tokens = appThemeOf(context);

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
                padding: EdgeInsets.fromLTRB(
                  context.spacing.mdLg,
                  context.spacing.mdLg,
                  context.spacing.mdLg,
                  context.spacing.smMd,
                ),
                child: AppSectionHeader(
                  title: l10n.profile_cache_manage_title,
                  subtitle: l10n.profile_cache_manage_item_count(stats.totalCount),
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
      // Content
      SliverToBoxAdapter(
        child: Container(
          color: theme.colorScheme.surfaceContainerLow,
          padding: EdgeInsets.fromLTRB(
            context.spacing.lg,
            context.spacing.mdLg,
            context.spacing.lg,
            context.spacing.mdLg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOverviewSection(context, stats: stats, palette: palette),
              SizedBox(height: context.spacing.smMd),
              Padding(
                padding: _contentHorizontalPadding(context),
                child: Text(
                  l10n.profile_cache_manage_details,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              SizedBox(height: context.spacing.sm),
              _buildDetailRow(
                context: context,
                category: _CacheCategory.images,
                icon: Icons.image_outlined,
                color: palette.images,
                title: l10n.profile_cache_manage_images,
                stats: stats.images,
                onClean: () => _deleteCategory(stats, _CacheCategory.images),
              ),
              _buildDetailRow(
                context: context,
                category: _CacheCategory.audio,
                icon: Icons.headphones,
                color: palette.audio,
                title: l10n.profile_cache_manage_audio,
                stats: stats.audio,
                onClean: () => _deleteCategory(stats, _CacheCategory.audio),
              ),
              _buildDetailRow(
                context: context,
                category: _CacheCategory.other,
                icon: Icons.folder_outlined,
                color: palette.other,
                title: l10n.profile_cache_manage_other,
                stats: stats.other,
                onClean: () => _deleteCategory(stats, _CacheCategory.other),
              ),
              SizedBox(height: context.spacing.md),
              Padding(
                padding: _contentHorizontalPadding(context),
                child: Container(
                  key: const Key('cache_manage_notice_box'),
                  padding: EdgeInsets.fromLTRB(context.spacing.md, context.spacing.md, context.spacing.md, context.spacing.md),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: theme.brightness == Brightness.dark
                          ? 0.24
                          : 0.16,
                    ),
                    borderRadius: AppRadius.lgRadius,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        key: const Key('cache_manage_notice_icon'),
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      SizedBox(width: context.spacing.sm),
                      Expanded(
                        child: Text(
                          l10n.profile_cache_manage_notice,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: context.spacing.lg),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  _contentHorizontalInset(context),
                  0,
                  _contentHorizontalInset(context),
                  context.spacing.xs,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('cache_manage_deep_clean_all'),
                    onPressed: _clearAll,
                    icon: const Icon(Icons.cleaning_services),
                    label: Text(
                      l10n.profile_cache_manage_deep_clean_all(
                        _formatBytes(stats.totalBytes),
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.deepCleanBackground,
                      foregroundColor: palette.deepCleanForeground,
                      padding: EdgeInsets.symmetric(vertical: context.spacing.lg),
                      textStyle: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
      // Bottom buffer
      SliverPadding(
        padding: EdgeInsets.only(bottom: context.spacing.xl),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final palette = _CachePagePalette.of(Theme.of(context));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Material(
        color: Colors.transparent,
        child: ResponsiveContainer(
          maxWidth: 1480,
          avoidTopSafeArea: true,
          alignment: Alignment.topCenter,
          child: AdaptiveRefreshIndicator.sliver(
            onRefresh: _refresh,
            child: const SizedBox.shrink(),
            builder: (context, refreshSliver) {
              return CustomScrollView(
                slivers: [
                  if (refreshSliver != null) refreshSliver,
                  AdaptiveSliverAppBar(
                    title: context.l10n.profile_cache_manage_title,
                    actions: [
                      HeaderCapsuleActionButton(
                        key: const Key('cache_manage_refresh_action'),
                        tooltip: context.l10n.refresh,
                        onPressed: _refresh,
                        icon: Icons.refresh_rounded,
                        circular: true,
                      ),
                    ],
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(height: context.spacing.smMd),
                  ),
                  if (_isLoading)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator.adaptive(),
                      ),
                    )
                  else
                    ..._buildContentSlivers(
                      context,
                      stats: _stats,
                      palette: palette,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
