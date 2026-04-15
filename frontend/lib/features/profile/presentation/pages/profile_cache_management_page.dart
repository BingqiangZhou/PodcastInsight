import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personal_ai_assistant/core/constants/app_radius.dart';
import 'package:personal_ai_assistant/core/constants/breakpoints.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/providers/core_providers.dart';
import 'package:personal_ai_assistant/core/theme/app_colors.dart';
import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/core/widgets/custom_adaptive_navigation.dart';
import 'package:personal_ai_assistant/core/widgets/glass_dialog_helper.dart';
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

  late Future<_MediaCacheStats> _statsFuture;

  double _contentHorizontalInset(BuildContext context) =>
      context.isMobile ? kPodcastRowCardHorizontalMargin : 0;

  EdgeInsets _contentHorizontalPadding(BuildContext context) =>
      EdgeInsets.symmetric(horizontal: _contentHorizontalInset(context));

  @override
  void initState() {
    super.initState();
    _statsFuture = _loadStats();
  }

  Future<void> _refresh() async {
    setState(() {
      _statsFuture = _loadStats();
    });
    await _statsFuture;
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

  Future<int> _objectBytes(CacheObject object) async {
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
        final bytes = await _objectBytes(obj);
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
      (acc, obj) => acc + (obj.length ?? 0),
    );

    final confirm = await showGlassConfirmationDialog(
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
    final confirm = await showGlassConfirmationDialog(
      context: context,
      title: l10n.profile_clear_cache,
      message: l10n.profile_clear_cache_confirm,
      confirmText: l10n.clear,
    );
    if (confirm != true || !mounted) return;

    showGlassDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
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
      Navigator.of(context).pop();
      showTopFloatingNotice(context, message: l10n.profile_cache_cleared);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
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
        const SizedBox(width: 6),
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

  Widget _buildHeaderPanel(BuildContext context) {
    final l10n = context.l10n;
    final isMobile = context.isMobile;

    return CompactHeaderPanel(
      key: const Key('cache_manage_header_panel'),
      title: l10n.profile_cache_manage_title,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HeaderCapsuleActionButton(
            key: const Key('cache_manage_refresh_action'),
            tooltip: l10n.refresh,
            onPressed: _refresh,
            icon: Icons.refresh_rounded,
            circular: true,
          ),
          if (!isMobile) ...[
            const SizedBox(width: 8),
            HeaderCapsuleActionButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: Icons.arrow_back_rounded,
              onPressed: () => context.canPop() ? context.pop() : context.go('/'),
              circular: true,
            ),
          ],
        ],
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
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
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatMB(stats.totalBytes).replaceAll(' MB', ''),
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
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
            const SizedBox(height: 2),
            Text(
              AppLocalizations.of(
                context,
              )!.profile_cache_manage_item_count(stats.totalCount),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildSegmentBar(
              imagesBytes: stats.images.bytes,
              audioBytes: stats.audio.bytes,
              otherBytes: stats.other.bytes,
              palette: palette,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 8,
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
          borderRadius: BorderRadius.circular(kPodcastRowCardCornerRadius),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.15)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: AppRadius.mdLgRadius,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
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
                      const SizedBox(width: 8),
                      _buildLegendDot(color),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.profile_cache_manage_item_count(stats.count),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _formatMB(stats.bytes),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 10),
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

  Widget _buildContentPanel(
    BuildContext context, {
    required _MediaCacheStats stats,
    required bool isLoading,
  }) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final palette = _CachePagePalette.of(theme);

    return SurfacePanel(
      key: const Key('cache_manage_content_panel'),
      padding: EdgeInsets.zero,
      borderRadius: appThemeOf(context).cardRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLoading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
              children: [
                _buildOverviewSection(context, stats: stats, palette: palette),
                const SizedBox(height: 14),
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
                const SizedBox(height: 8),
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
                const SizedBox(height: 12),
                Padding(
                  padding: _contentHorizontalPadding(context),
                  child: Container(
                    key: const Key('cache_manage_notice_box'),
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
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
                        const SizedBox(width: 10),
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
                const SizedBox(height: 16),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    _contentHorizontalInset(context),
                    0,
                    _contentHorizontalInset(context),
                    4,
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
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Material(
        color: Colors.transparent,
        child: SafeArea(
          bottom: false,
          child: ResponsiveContainer(
                maxWidth: 1480,
                alignment: Alignment.topCenter,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderPanel(context),
                    const SizedBox(height: 12),
                    Expanded(
                      child: FutureBuilder<_MediaCacheStats>(
                        future: _statsFuture,
                        builder: (context, snapshot) {
                          final isLoading =
                              snapshot.connectionState != ConnectionState.done;
                          final stats = snapshot.data ?? _emptyStats;

                          return RefreshIndicator(
                            onRefresh: _refresh,
                            child: _buildContentPanel(
                              context,
                              stats: stats,
                              isLoading: isLoading,
                            ),
                          );
                        },
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
}
