import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/providers/route_provider.dart';
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
    final trackedRoute = ref.watch(currentRouteProvider);
    final isExpanded = ref.watch(
      audioPlayerProvider.select((state) => state.isExpanded),
    );
    String resolvedRoute = trackedRoute;
    try {
      resolvedRoute = GoRouter.of(
        context,
      ).routerDelegate.currentConfiguration.uri.toString();
    } catch (_) {
      // Fall back to the globally tracked route outside router subtree updates.
    }
    final viewportSpec = resolvePodcastPlayerViewportSpec(
      context,
      layout,
      route: resolvedRoute,
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
            left: viewportSpec.leftInset,
            right: viewportSpec.rightInset,
            bottom: viewportSpec.bottomOffset,
            child: RepaintBoundary(
              child: SizedBox(
                width: double.infinity,
                child: PodcastBottomPlayerWidget(
                  key: const Key('global_podcast_player'),
                  applySafeArea: layout.applySafeArea,
                  viewportSpec: viewportSpec,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
