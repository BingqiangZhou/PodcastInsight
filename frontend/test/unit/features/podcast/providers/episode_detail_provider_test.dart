import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/repositories/podcast_repository.dart';
import 'package:personal_ai_assistant/features/podcast/data/services/podcast_api_service.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';

void main() {
  group('episodeDetailProvider', () {
    test(
      'keeps cache isolated by episodeId and supports invalidation',
      () async {
        final repository = _FakePodcastRepository();
        final container = ProviderContainer(
          overrides: [podcastRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);

        final episode1 = await container.read(episodeDetailProvider(1).future);
        final episode2 = await container.read(episodeDetailProvider(2).future);

        expect(episode1?.id, 1);
        expect(episode2?.id, 2);
        expect(repository.getEpisodeCalls, 2);

        container.invalidate(episodeDetailProvider(1));
        final episode1Reloaded = await container.read(
          episodeDetailProvider(1).future,
        );
        expect(episode1Reloaded?.id, 1);
        expect(repository.getEpisodeCalls, 3);
      },
    );
  });
}

class _FakePodcastRepository extends PodcastRepository {
  _FakePodcastRepository() : super(PodcastApiService(Dio()));

  int getEpisodeCalls = 0;

  @override
  Future<PodcastEpisodeModel> getEpisode(int episodeId) async {
    getEpisodeCalls += 1;
    final now = DateTime(2026, 2, 14, 10);
    return PodcastEpisodeModel(
      id: episodeId,
      subscriptionId: 100 + episodeId,
      title: 'Episode $episodeId',
      audioUrl: 'https://example.com/$episodeId.mp3',
      publishedAt: now,
      createdAt: now,
    );
  }
}
