import 'package:flutter/material.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/shared/base_episode_card.dart' show BaseEpisodeCard;

import 'package:personal_ai_assistant/shared/widgets/loading_widget.dart';

/// A single shimmer rectangle with rounded corners.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = 4,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// A circular shimmer placeholder.
class SkeletonCircle extends StatelessWidget {
  const SkeletonCircle({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Skeleton for an episode feed card matching [BaseEpisodeCard] layout.
///
/// Wraps content in [ShimmerLoading] for animation.
class EpisodeCardSkeleton extends StatelessWidget {
  const EpisodeCardSkeleton({
    super.key,
    this.compact = false,
    this.showDescription = true,
    this.cardMargin,
  });

  final bool compact;
  final bool showDescription;
  final EdgeInsetsGeometry? cardMargin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 4, vertical: 6)
        : const EdgeInsets.fromLTRB(16, 12, 16, 12);
    final titleFont = compact
        ? theme.textTheme.titleSmall
        : theme.textTheme.titleMedium;
    final titleFontSize = titleFont?.fontSize ?? 14;
    final titleHeight = titleFont?.height ?? 1.0;
    final coverSize = 2 * (titleFontSize * titleHeight);
    const coverRadius = 8.0;

    return ShimmerLoading(
      child: Card(
        margin: cardMargin ?? (compact ? const EdgeInsets.symmetric(horizontal: 4, vertical: 6) : null),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: [image skeleton, title lines]
              Row(
                children: [
                  SkeletonBox(
                    width: coverSize,
                    height: coverSize,
                    borderRadius: coverRadius,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(height: titleFontSize + 2, width: double.infinity),
                        const SizedBox(height: 6),
                        SkeletonBox(height: titleFontSize + 2, width: compact ? 120 : 180),
                      ],
                    ),
                  ),
                ],
              ),
              if (showDescription) ...[
                const SizedBox(height: 8),
                const SkeletonBox(height: 12, width: double.infinity),
                const SizedBox(height: 4),
                SkeletonBox(height: 12, width: compact ? 200 : 280),
              ],
              const SizedBox(height: 8),
              // Meta row
              const Row(
                children: [
                  SkeletonBox(height: 10, width: 60, borderRadius: 6),
                  SizedBox(width: 8),
                  SkeletonBox(height: 10, width: 40, borderRadius: 6),
                  Spacer(),
                  SkeletonCircle(size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A list of skeleton cards for initial loading state.
class SkeletonCardList extends StatelessWidget {
  const SkeletonCardList({
    super.key,
    this.itemCount = 5,
    this.compact = false,
    this.showDescription = true,
  });

  final int itemCount;
  final bool compact;
  final bool showDescription;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: itemCount,
      itemBuilder: (context, index) => EpisodeCardSkeleton(
        compact: compact,
        showDescription: showDescription,
      ),
    );
  }
}

/// A grid of skeleton cards for desktop layout.
class SkeletonCardGrid extends StatelessWidget {
  const SkeletonCardGrid({
    required this.crossAxisCount, super.key,
    this.itemCount = 8,
    this.childAspectRatio = 2.0,
  });

  final int itemCount;
  final int crossAxisCount;
  final double childAspectRatio;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 4),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => const EpisodeCardSkeleton(
        
      ),
    );
  }
}
