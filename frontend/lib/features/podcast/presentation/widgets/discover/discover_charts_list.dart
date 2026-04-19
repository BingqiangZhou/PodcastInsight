import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/constants/app_spacing.dart';

import 'package:personal_ai_assistant/core/constants/breakpoints.dart';
import 'package:personal_ai_assistant/core/constants/scroll_constants.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_discover_chart_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_discover_provider.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/discover/discover_chart_row.dart';

/// Charts list widget for displaying discover items with pagination.
///
/// Adapts layout based on screen width:
/// - Mobile (<600px): vertical [ListView.builder]
/// - Desktop (>=600px): [GridView.builder] with 2/3/4 columns
class DiscoverChartsList extends ConsumerWidget {
  const DiscoverChartsList({
    required this.state,
    required this.scrollController,
    required this.onItemTap,
    required this.onItemSubscribe,
    required this.onItemPlay,
    required this.subscribingShowIds,
    required this.subscribedShowIds,
    super.key,
    this.isDense = false,
  });

  final PodcastDiscoverState state;
  final ScrollController scrollController;
  final ValueChanged<PodcastDiscoverItem> onItemTap;
  final ValueChanged<PodcastDiscoverItem> onItemSubscribe;
  final ValueChanged<PodcastDiscoverItem> onItemPlay;
  final Set<int> subscribingShowIds;
  final Set<int> subscribedShowIds;
  final bool isDense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibleItems = state.visibleItems;
    final itemCount = visibleItems.isEmpty
        ? 1
        : (state.isCurrentTabLoadingMore
            ? visibleItems.length + 1
            : visibleItems.length);

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isMobile = screenWidth < Breakpoints.medium;

        if (isMobile) {
          return ListView.builder(
            key: const Key('podcast_discover_list'),
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding:
                EdgeInsets.only(bottom: context.spacing.md),
            cacheExtent: ScrollConstants.largeListCacheExtent,
            itemCount: itemCount,
            itemBuilder: (context, index) =>
                _buildItem(context, visibleItems, index),
          );
        }

        final crossAxisCount = screenWidth < Breakpoints.mediumLarge
            ? 2
            : (screenWidth < Breakpoints.large ? 3 : 4);
        final spacing = context.spacing.sm;
        final availableWidth =
            screenWidth - (crossAxisCount - 1) * spacing;
        final cardWidth = availableWidth / crossAxisCount;
        const cardHeight = 72.0;
        final childAspectRatio = cardWidth / cardHeight;

        return GridView.builder(
          key: const Key('podcast_discover_grid'),
          controller: scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding:
              EdgeInsets.only(bottom: context.spacing.md),
          cacheExtent: ScrollConstants.largeListCacheExtent,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: itemCount,
          itemBuilder: (context, index) =>
              _buildItem(context, visibleItems, index, gridMode: true),
        );
      },
    );
  }

  Widget _buildItem(
    BuildContext context,
    List<PodcastDiscoverItem> visibleItems,
    int index, {
    bool gridMode = false,
  }) {
    final l10n = context.l10n;

    if (visibleItems.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: context.spacing.md),
        child: Center(child: Text(l10n.podcast_discover_no_chart_data)),
      );
    }

    if (index >= visibleItems.length) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
          ),
        ),
      );
    }

    final item = visibleItems[index];
    final itunesId = item.itunesId;
    final isSubscribing =
        itunesId != null && subscribingShowIds.contains(itunesId);
    final isSubscribed =
        itunesId != null && subscribedShowIds.contains(itunesId);

    return RepaintBoundary(
      key: ValueKey('chart_row_${item.itemId}'),
      child: DiscoverChartRow(
        rank: index + 1,
        item: item,
        onTap: () => onItemTap(item),
        onSubscribe: () => onItemSubscribe(item),
        onPlay: () => onItemPlay(item),
        isSubscribing: isSubscribing,
        isSubscribed: isSubscribed,
        isDense: isDense,
        cardMargin: gridMode ? EdgeInsets.zero : null,
      ),
    );
  }
}
