import 'package:flutter/material.dart';

import 'package:personal_ai_assistant/core/constants/app_spacing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations_extension.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/itunes_episode_lookup_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_search_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/utils/podcast_url_utils.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_search_provider.dart' as search;
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_subscription_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/podcast_episode_search_result_card.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/podcast_search_result_card.dart';

/// Search results list widget for displaying podcast/episode search results
class PodcastSearchResultsList extends ConsumerWidget {
  const PodcastSearchResultsList({
    required this.searchState, required this.onEpisodeTap, required this.onEpisodePlay, required this.onPodcastSubscribe, required this.isDense, super.key,
  });

  final search.PodcastSearchState searchState;
  final ValueChanged<ITunesPodcastEpisodeResult> onEpisodeTap;
  final ValueChanged<ITunesPodcastEpisodeResult> onEpisodePlay;
  final ValueChanged<PodcastSearchResult> onPodcastSubscribe;
  final bool isDense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    if (searchState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (searchState.error != null) {
      return _buildErrorView(context, l10n, searchState.error!);
    }

    final resultsEmpty = searchState.searchMode == search.PodcastSearchMode.episodes
        ? searchState.episodeResults.isEmpty
        : searchState.podcastResults.isEmpty;

    if (resultsEmpty) {
      return Center(
        child: Text(
          l10n.podcast_search_no_results,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    if (searchState.searchMode == search.PodcastSearchMode.episodes) {
      return _buildEpisodeResults(context, l10n);
    }

    return _buildPodcastResults(context, ref);
  }

  Widget _buildErrorView(BuildContext context, AppLocalizations l10n, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 44),
          const SizedBox(height: AppSpacing.smMd),
          Text(error, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.smMd),
          FilledButton.icon(
            onPressed: () => onEpisodeTap as void Function(String)?,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.retry),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodeResults(BuildContext context, AppLocalizations l10n) {
    return ListView.builder(
      key: const Key('podcast_discover_search_results'),
      cacheExtent: 200,
      itemCount: searchState.episodeResults.length,
      itemBuilder: (context, index) {
        final episode = searchState.episodeResults[index];
        return RepaintBoundary(
          key: ValueKey('episode_result_${episode.trackId}'),
          child: _EpisodeSearchResultItem(
            episode: episode,
            isDense: isDense,
            onTap: () => onEpisodeTap(episode),
            onPlay: () => onEpisodePlay(episode),
          ),
        );
      },
    );
  }

  Widget _buildPodcastResults(BuildContext context, WidgetRef ref) {
    final normalizedSubscribedFeedUrls = ref.watch(
      subscribedNormalizedFeedUrlsProvider,
    );
    final normalizedSubscribingFeedUrls = ref.watch(
      subscribingNormalizedFeedUrlsProvider,
    );

    return ListView.builder(
      key: const Key('podcast_discover_search_results'),
      cacheExtent: 200,
      itemCount: searchState.podcastResults.length,
      itemBuilder: (context, index) {
        final result = searchState.podcastResults[index];
        return RepaintBoundary(
          key: ValueKey('podcast_result_${result.feedUrl}'),
          child: _PodcastSearchResultItem(
            result: result,
            isDense: isDense,
            searchCountry: searchState.searchCountry,
            normalizedSubscribedFeedUrls: normalizedSubscribedFeedUrls,
            normalizedSubscribingFeedUrls: normalizedSubscribingFeedUrls,
            onSubscribe: onPodcastSubscribe,
          ),
        );
      },
    );
  }
}

class _EpisodeSearchResultItem extends StatelessWidget {
  const _EpisodeSearchResultItem({
    required this.episode,
    required this.isDense,
    required this.onTap,
    required this.onPlay,
  });

  final ITunesPodcastEpisodeResult episode;
  final bool isDense;
  final VoidCallback onTap;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return PodcastEpisodeSearchResultCard(
      episode: episode,
      dense: isDense,
      onTap: onTap,
      onPlay: onPlay,
      key: ValueKey('episode_search_${episode.trackId}'),
    );
  }
}

class _PodcastSearchResultItem extends StatelessWidget {
  const _PodcastSearchResultItem({
    required this.result,
    required this.isDense,
    required this.searchCountry,
    required this.normalizedSubscribedFeedUrls,
    required this.normalizedSubscribingFeedUrls,
    required this.onSubscribe,
  });

  final PodcastSearchResult result;
  final bool isDense;
  final PodcastCountry searchCountry;
  final Set<String> normalizedSubscribedFeedUrls;
  final Set<String> normalizedSubscribingFeedUrls;
  final ValueChanged<PodcastSearchResult> onSubscribe;

  @override
  Widget build(BuildContext context) {
    final normalizedResultFeedUrl = result.feedUrl == null
        ? null
        : PodcastUrlUtils.normalizeFeedUrl(result.feedUrl!);
    final isSubscribed =
        normalizedResultFeedUrl != null &&
        normalizedSubscribedFeedUrls.contains(normalizedResultFeedUrl);
    final isSubscribing =
        normalizedResultFeedUrl != null &&
        normalizedSubscribingFeedUrls.contains(normalizedResultFeedUrl);

    return PodcastSearchResultCard(
      result: result,
      onSubscribe: onSubscribe,
      isSubscribed: isSubscribed,
      isSubscribing: isSubscribing,
      searchCountry: searchCountry,
      dense: isDense,
      key: ValueKey('search_${result.feedUrl}'),
    );
  }
}
