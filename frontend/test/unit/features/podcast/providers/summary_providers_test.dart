import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_playback_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/services/podcast_api_service.dart';
import 'package:personal_ai_assistant/features/podcast/data/repositories/podcast_repository.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/summary_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

void main() {
  test('summary polling stops after episode detail is updated', () {
    fakeAsync((async) {
      final repository = _FakeSummaryRepository(
        episodeId: 1001,
        summaryAvailableOnFetch: 2,
      );
      final container = ProviderContainer(
        overrides: [
          podcastRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final provider = getSummaryProvider(1001);
      container.read(provider.notifier).generateSummary();
      async.flushMicrotasks();

      expect(repository.generateSummaryCalls, 1);
      expect(container.read(provider).hasSummary, isTrue);

      async.elapse(const Duration(seconds: 5));
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 5));
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 10));
      async.flushMicrotasks();

      expect(repository.getEpisodeCalls, 2);
      expect(container.read(provider).summary, 'Persisted summary');
    });
  });
}

class _FakeSummaryRepository extends PodcastRepository {
  _FakeSummaryRepository({
    required this.episodeId,
    required this.summaryAvailableOnFetch,
  }) : super(PodcastApiService(Dio()));

  final int episodeId;
  final int summaryAvailableOnFetch;
  int generateSummaryCalls = 0;
  int getEpisodeCalls = 0;

  @override
  Future<PodcastSummaryResponse> generateSummary({
    required int episodeId,
    bool forceRegenerate = false,
    bool? useTranscript,
    String? summaryModel,
    String? customPrompt,
  }) async {
    generateSummaryCalls += 1;
    return PodcastSummaryResponse(
      episodeId: episodeId,
      summary: 'Fresh summary',
      version: 'v1',
      transcriptUsed: false,
      generatedAt: DateTime.utc(2026, 3, 10),
      wordCount: 2,
      modelUsed: summaryModel,
      processingTime: 1.2,
    );
  }

  @override
  Future<PodcastEpisodeDetailResponse> getEpisode(int id) async {
    getEpisodeCalls += 1;
    return PodcastEpisodeDetailResponse(
      id: episodeId,
      subscriptionId: 1,
      title: 'Episode',
      description: 'Description',
      audioUrl: 'https://example.com/audio.mp3',
      publishedAt: DateTime.utc(2026, 3, 10),
      createdAt: DateTime.utc(2026, 3, 10),
      aiSummary: getEpisodeCalls >= summaryAvailableOnFetch
          ? 'Persisted summary'
          : null,
    );
  }
}
