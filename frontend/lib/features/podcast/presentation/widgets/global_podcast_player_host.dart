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
    final isExpanded = ref.watch(podcastPlayerExpandedProvider);

    return Stack(
      key: const Key('global_podcast_player_host'),
      children: [
        Positioned.fill(
          child: PodcastPlayerModalBarrier(
            visible: layout.visible && isExpanded,
            onDismiss: () {
              ref.read(podcastPlayerUiProvider.notifier).collapse();
            },
          ),
        ),
        if (layout.visible)
          const Positioned.fill(
            child: RepaintBoundary(
              child: SizedBox(
                width: double.infinity,
                child: PodcastPlayerShell(
                  key: Key('global_podcast_player'),
                  embedExpandedInFlow: false,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
