import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/repositories/podcast_repository.dart';
import 'package:personal_ai_assistant/features/podcast/data/services/podcast_api_service.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';

void main() {
  group('PodcastEpisodesNotifier cache scope', () {
    test('reuses fresh cache only for same subscription and filters', () async {
      final repository = _FakePodcastRepository();
      final container = ProviderContainer(
        overrides: [podcastRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(podcastEpisodesProvider.notifier);
      await notifier.loadEpisodesForSubscription(subscriptionId: 1);
      await notifier.loadEpisodesForSubscription(subscriptionId: 1);

      expect(repository.listEpisodesCalls, 1);
      expect(container.read(podcastEpisodesProvider).cachedSubscriptionId, 1);
    });

    test('does not reuse fresh cache across different subscriptions', () async {
      final repository = _FakePodcastRepository();
      final container = ProviderContainer(
        overrides: [podcastRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(podcastEpisodesProvider.notifier);
      await notifier.loadEpisodesForSubscription(subscriptionId: 1);
      await notifier.loadEpisodesForSubscription(subscriptionId: 2);

      final state = container.read(podcastEpisodesProvider);
      expect(repository.listEpisodesCalls, 2);
      expect(state.cachedSubscriptionId, 2);
      expect(state.episodes.first.subscriptionId, 2);
    });

    test(
      'does not reuse fresh cache when status/summary filters differ',
      () async {
        final repository = _FakePodcastRepository();
        final container = ProviderContainer(
          overrides: [podcastRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);

        final notifier = container.read(podcastEpisodesProvider.notifier);
        await notifier.loadEpisodesForSubscription(
          subscriptionId: 1,
          status: 'played',
          hasSummary: true,
        );
        await notifier.loadEpisodesForSubscription(
          subscriptionId: 1,
          status: 'unplayed',
          hasSummary: true,
        );

        final state = container.read(podcastEpisodesProvider);
        expect(repository.listEpisodesCalls, 2);
        expect(state.cachedStatus, 'unplayed');
        expect(state.cachedHasSummary, true);
      },
    );
  });
}

class _FakePodcastRepository extends PodcastRepository {
  _FakePodcastRepository() : super(PodcastApiService(Dio()));

  int listEpisodesCalls = 0;

  @override
  Future<PodcastEpisodeListResponse> listEpisodes({
    int? subscriptionId,
    int page = 1,
    int size = 20,
    bool? hasSummary,
    bool? isPlayed,
  }) async {
    listEpisodesCalls += 1;
    final subId = subscriptionId ?? 0;
    final episodeId = subId * 100 + listEpisodesCalls;
    return PodcastEpisodeListResponse(
      episodes: <PodcastEpisodeModel>[_episode(id: episodeId, subId: subId)],
      total: 1,
      page: page,
      size: size,
      pages: 1,
      subscriptionId: subId,
    );
  }
}

PodcastEpisodeModel _episode({required int id, required int subId}) {
  final now = DateTime(2026, 2, 14, 10);
  return PodcastEpisodeModel(
    id: id,
    subscriptionId: subId,
    title: 'Episode $id',
    audioUrl: 'https://example.com/$id.mp3',
    publishedAt: now,
    createdAt: now,
  );
}
