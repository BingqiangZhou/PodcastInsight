import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:personal_ai_assistant/core/constants/scroll_constants.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_discover_chart_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_discover_provider.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/discover/discover_chart_row.dart';

/// Charts list widget for displaying discover items with pagination
class DiscoverChartsList extends ConsumerWidget {
  const DiscoverChartsList({
    required this.state, required this.scrollController, required this.onItemTap, required this.onItemSubscribe, required this.onItemPlay, required this.subscribingShowIds, required this.subscribedShowIds, super.key,
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
    final l10n = context.l10n;
    final visibleItems = state.visibleItems;

    return ListView.builder(
      key: const Key('podcast_discover_list'),
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: isDense ? AppSpacing.md : AppSpacing.md),
      cacheExtent: ScrollConstants.largeListCacheExtent,
      itemCount: visibleItems.isEmpty
          ? 1
          : (state.isCurrentTabLoadingMore
              ? visibleItems.length + 1
              : visibleItems.length),
      itemBuilder: (context, index) {
        if (visibleItems.isEmpty) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(child: Text(l10n.podcast_discover_no_chart_data)),
          );
        }

        if (index >= visibleItems.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
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
          ),
        );
      },
    );
  }
}
