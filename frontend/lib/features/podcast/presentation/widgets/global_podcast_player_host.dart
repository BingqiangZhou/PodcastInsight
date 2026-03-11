import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/podcast_providers.dart';
import 'podcast_bottom_player_widget.dart';

class GlobalPodcastPlayerHost extends ConsumerWidget {
  const GlobalPodcastPlayerHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episode = ref.watch(audioCurrentEpisodeProvider);
    if (episode == null) {
      return const SizedBox.shrink();
    }

    final layout = ref.watch(podcastPlayerHostLayoutProvider);
    final isExpanded = ref.watch(
      audioPlayerProvider.select((state) => state.isExpanded),
    );
    final bottomOffset = resolvePodcastPlayerOverlayBottomOffset(
      context,
      override: layout.overlayBottomOffset,
    );

    return Stack(
      key: const Key('global_podcast_player_host'),
      children: [
        Positioned.fill(
          child: PodcastPlayerModalBarrier(
            visible: layout.visible && isExpanded,
            onDismiss: () {
              ref.read(audioPlayerProvider.notifier).setExpanded(false);
            },
          ),
        ),
        if (layout.visible)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            left: layout.overlayLeftInset ?? 0,
            right: layout.overlayRightInset ?? 0,
            bottom: bottomOffset,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: RepaintBoundary(
                child: PodcastBottomPlayerWidget(
                  key: const Key('global_podcast_player'),
                  applySafeArea: layout.applySafeArea,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
