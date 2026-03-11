import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../navigation/podcast_navigation.dart';
import '../providers/podcast_providers.dart';
import '../widgets/podcast_bottom_player_widget.dart';

class PodcastPlayerPage extends ConsumerWidget {
  const PodcastPlayerPage({super.key, this.args});

  final PodcastPlayerPageArgs? args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentEpisode = ref.watch(audioCurrentEpisodeProvider);
    final viewportSpec = resolvePodcastPlayerViewportSpec(
      context,
      const PodcastPlayerHostLayout(
        visible: true,
        surfaceContext: PodcastPlayerSurfaceContext.standard,
        homeShellDesktopNavExpanded: true,
        contentBottomInset: 0,
        overlayBottomOffset: 0,
        applySafeArea: false,
        hiddenByPage: false,
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.podcast_player_now_playing)),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(viewportSpec.fullScreenHorizontalPadding),
            child: ConstrainedBox(
              key: const Key('podcast_fullscreen_player_panel'),
              constraints: BoxConstraints(
                maxWidth: viewportSpec.maxPlayerWidth,
              ),
              child: currentEpisode == null
                  ? _EmptyPlayerState(args: args)
                  : PodcastExpandedPlayerPanel(
                      episode: currentEpisode,
                      fullScreen: true,
                      elevation: 0,
                      borderRadius: BorderRadius.circular(24),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyPlayerState extends StatelessWidget {
  const _EmptyPlayerState({required this.args});

  final PodcastPlayerPageArgs? args;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final episodeTitle =
        args?.episodeTitle ?? l10n.podcast_player_unknown_episode;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.podcasts_rounded,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              episodeTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.podcast_coming_soon,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
