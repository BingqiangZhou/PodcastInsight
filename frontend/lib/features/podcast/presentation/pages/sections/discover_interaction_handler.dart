import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/core/utils/app_logger.dart' as logger;
import 'package:personal_ai_assistant/core/widgets/adaptive_sheet_helper.dart';
import 'package:personal_ai_assistant/core/widgets/top_floating_notice.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/itunes_episode_lookup_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_discover_chart_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_search_model.dart' show PodcastSearchResult;
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_search_provider.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/discover_episode_detail_sheet.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/discover_show_episodes_sheet.dart';

/// Static helper methods for discover-page interactions.
///
/// Extracted from PodcastListPage to reduce its size and isolate discover logic.
/// All methods are static to avoid mixin/State generic compatibility issues.
class DiscoverInteractionHandler {
  DiscoverInteractionHandler._();

  // --- Subscribe ---

  static Future<void> subscribeFromSearch(
    WidgetRef ref,
    BuildContext context,
    PodcastSearchResult result,
  ) async {
    final l10n = context.l10n;
    final feedUrl = result.feedUrl;
    final collectionName = result.collectionName;
    if (feedUrl == null || collectionName == null) {
      showErrorNotice(context, l10n.podcast_subscribe_failed('Invalid podcast data'));
      return;
    }

    try {
      await ref.read(podcastSubscriptionProvider.notifier).addSubscription(feedUrl: feedUrl);
      if (!context.mounted) return;
      showSuccessNotice(context, l10n.podcast_subscribe_success(collectionName));
    } catch (error) {
      if (!context.mounted) return;
      showErrorNotice(context, l10n.podcast_subscribe_failed(error.toString()));
    }
  }

  // --- Episode tap / play ---

  static Future<void> handleEpisodeTap(
    WidgetRef ref,
    BuildContext context,
    ITunesPodcastEpisodeResult episode,
  ) async {
    final resolved = await resolveEpisodeForSearchResult(ref, episode);
    if (!context.mounted || resolved == null) {
      if (context.mounted) showErrorNotice(context, context.l10n.podcast_failed_load_episodes);
      return;
    }
    await showEpisodeDetailSheetFromSearch(ref, context, resolved);
  }

  static Future<void> handleEpisodePlay(
    WidgetRef ref,
    BuildContext context,
    ITunesPodcastEpisodeResult episode,
  ) async {
    final resolved = await resolveEpisodeForSearchResult(ref, episode);
    if (!context.mounted || resolved == null) {
      if (context.mounted) showErrorNotice(context, context.l10n.podcast_player_no_audio);
      return;
    }
    await playDiscoverEpisode(ref, context, episode: resolved, showId: resolved.collectionId);
  }

  static Future<void> handleChartRowTap(
    WidgetRef ref,
    BuildContext context,
    PodcastDiscoverItem item,
  ) async {
    if (item.isPodcastShow) {
      await showPodcastEpisodeInfoSheet(ref, context, item);
    } else {
      await showEpisodeDetailSheetFromChart(ref, context, item);
    }
  }

  static Future<void> playEpisodeFromChartRow(
    WidgetRef ref,
    BuildContext context,
    PodcastDiscoverItem item,
  ) async {
    final selection = await resolveDiscoverEpisodeSelection(ref, context, item);
    if (selection != null) {
      await playDiscoverEpisode(
        ref,
        context,
        episode: selection.episode,
        showId: selection.showId,
      );
    }
  }

  // --- Sheets ---

  static Future<void> showPodcastEpisodeInfoSheet(
    WidgetRef ref,
    BuildContext context,
    PodcastDiscoverItem item,
  ) async {
    final l10n = context.l10n;
    final country = ref.read(countrySelectorProvider).selectedCountry;
    final searchService = ref.read(iTunesSearchServiceProvider);
    final showId = item.itunesId ?? searchService.extractShowIdFromApplePodcastUrl(item.url);
    if (showId == null) {
      showErrorNotice(context, l10n.podcast_failed_load_episodes);
      return;
    }

    try {
      final lookup = await searchService.lookupPodcastEpisodes(
        showId: showId,
        country: country,
      );
      if (!context.mounted || lookup.episodes.isEmpty) {
        if (context.mounted) showErrorNotice(context, l10n.podcast_no_episodes_found);
        return;
      }

      await showAdaptiveSheet<void>(
        context: context,
        builder: (sheetContext) {
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.8,
            ),
            child: DiscoverShowEpisodesSheet(
              showId: showId,
              showTitle: lookup.collectionName ?? item.title,
              episodes: lookup.episodes,
              onEpisodeSelected: (episode) {
                Navigator.of(sheetContext).pop();
                showEpisodeDetailSheetFromSearch(ref, context, episode);
              },
              onPlayEpisode: (episode) {
                Navigator.of(sheetContext).pop();
                playDiscoverEpisode(ref, context, episode: episode, showId: showId);
              },
            ),
          );
        },
      );
    } catch (e) {
      logger.AppLogger.debug('[Discover] Failed to show podcast episodes: $e');
      showErrorNotice(context, l10n.podcast_failed_load_episodes);
    }
  }

  static Future<void> showEpisodeDetailSheetFromChart(
    WidgetRef ref,
    BuildContext context,
    PodcastDiscoverItem item,
  ) async {
    final selection = await resolveDiscoverEpisodeSelection(ref, context, item);
    if (selection == null || !context.mounted) return;

    await showAdaptiveSheet<void>(
      context: context,
      builder: (sheetContext) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.9,
          ),
          child: DiscoverEpisodeDetailSheet(
            episode: selection.episode,
            onPlay: () {
              Navigator.of(sheetContext).pop();
              playDiscoverEpisode(
                ref,
                context,
                episode: selection.episode,
                showId: selection.showId,
              );
            },
          ),
        );
      },
    );
  }

  static Future<void> showEpisodeDetailSheetFromSearch(
    WidgetRef ref,
    BuildContext context,
    ITunesPodcastEpisodeResult episode,
  ) async {
    await showAdaptiveSheet<void>(
      context: context,
      builder: (sheetContext) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.9,
          ),
          child: DiscoverEpisodeDetailSheet(
            episode: episode,
            onPlay: () {
              Navigator.of(sheetContext).pop();
              playDiscoverEpisode(ref, context, episode: episode, showId: episode.collectionId);
            },
          ),
        );
      },
    );
  }

  // --- Resolution ---

  static Future<DiscoverEpisodeSelection?> resolveDiscoverEpisodeSelection(
    WidgetRef ref,
    BuildContext context,
    PodcastDiscoverItem item,
  ) async {
    final l10n = context.l10n;
    final country = ref.read(countrySelectorProvider).selectedCountry;
    final searchService = ref.read(iTunesSearchServiceProvider);
    final showId = searchService.extractShowIdFromApplePodcastUrl(item.url);
    final episodeTrackId =
        searchService.extractEpisodeIdFromApplePodcastUrl(item.url) ?? item.itunesId;

    if (showId == null || episodeTrackId == null) {
      showErrorNotice(context, l10n.podcast_failed_load_episodes);
      return null;
    }

    try {
      final episode = await searchService.findEpisodeInLookup(
        showId: showId,
        episodeTrackId: episodeTrackId,
        country: country,
      );
      if (episode == null) {
        showErrorNotice(context, l10n.podcast_failed_load_episodes);
        return null;
      }
      return DiscoverEpisodeSelection(showId: showId, episode: episode);
    } catch (e) {
      logger.AppLogger.debug('[Discover] Failed to resolve episode selection: $e');
      showErrorNotice(context, l10n.podcast_failed_load_episodes);
      return null;
    }
  }

  static Future<ITunesPodcastEpisodeResult?> resolveEpisodeForSearchResult(
    WidgetRef ref,
    ITunesPodcastEpisodeResult episode,
  ) async {
    if (episode.resolvedAudioUrl?.isNotEmpty == true) return episode;
    final country = ref.read(countrySelectorProvider).selectedCountry;
    final searchService = ref.read(iTunesSearchServiceProvider);
    try {
      return await searchService.findEpisodeInLookup(
        showId: episode.collectionId,
        episodeTrackId: episode.trackId,
        country: country,
      );
    } catch (e) {
      logger.AppLogger.debug('[Search] Failed to resolve episode: $e');
      return null;
    }
  }

  // --- Play ---

  static Future<void> playDiscoverEpisode(
    WidgetRef ref,
    BuildContext context, {
    required ITunesPodcastEpisodeResult episode,
    required int showId,
  }) async {
    final audioUrl = episode.resolvedAudioUrl;
    if (audioUrl == null || audioUrl.isEmpty) {
      showErrorNotice(context, context.l10n.podcast_player_no_audio);
      return;
    }

    final now = DateTime.now();
    final discoverEpisode = PodcastEpisodeModel(
      id: episode.trackId,
      subscriptionId: 0,
      title: episode.trackName,
      subscriptionTitle: episode.collectionName,
      description: episode.description ?? episode.shortDescription,
      audioUrl: audioUrl,
      audioDuration: switch (episode.trackTimeMillis) {
        null => null,
        final millis => (millis / 1000).round(),
      },
      publishedAt: episode.releaseDate ?? now,
      imageUrl: episode.artworkUrl600 ?? episode.artworkUrl100,
      itemLink: episode.trackViewUrl,
      metadata: {
        'discover_preview': true,
        'source': 'top_charts',
        'show_id': showId,
        'track_id': episode.trackId,
      },
      createdAt: now,
    );

    try {
      await ref.read(audioPlayerProvider.notifier).playEpisode(discoverEpisode);
    } catch (e) {
      logger.AppLogger.debug('[Discover] Failed to play episode: $e');
      showErrorNotice(context, context.l10n.podcast_player_no_audio);
    }
  }

  // --- Notice helpers ---

  static void showErrorNotice(BuildContext context, String message) {
    if (!context.mounted) return;
    showTopFloatingNotice(context, message: message, isError: true);
  }

  static void showSuccessNotice(BuildContext context, String message) {
    if (!context.mounted) return;
    showTopFloatingNotice(context, message: message);
  }
}

class DiscoverEpisodeSelection {
  const DiscoverEpisodeSelection({
    required this.showId,
    required this.episode,
  });

  final int showId;
  final ITunesPodcastEpisodeResult episode;
}
