import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/podcast_bottom_player_widget.dart';

class GlobalPodcastPlayerHost extends ConsumerWidget {
  const GlobalPodcastPlayerHost({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SizedBox(
      key: Key('global_podcast_player_host'),
      width: double.infinity,
      child: PodcastPlayerLayoutFrame(
        manageBottomPadding: false,
        manageDesktopPanelPadding: false,
        child: SizedBox.expand(
          child: SizedBox(key: Key('global_podcast_player')),
        ),
      ),
    );
  }
}
