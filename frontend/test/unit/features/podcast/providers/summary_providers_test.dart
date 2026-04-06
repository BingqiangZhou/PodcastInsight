import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_playback_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/repositories/podcast_repository.dart';
import 'package:personal_ai_assistant/features/podcast/data/services/podcast_api_service.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/summary_providers.dart';

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
          episodeDetailProvider(1001).overrideWith((ref) async {
            return repository.getEpisode(1001);
          }),
        ],
      );
      final provider = summaryProvider(1001);
      final subscription = container.listen(
        provider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(() {
        subscription.close();
        container.dispose();
      });

      container.read(provider.notifier).generateSummary();

      // Flush to resolve generateSummary API call + immediate _syncFromEpisodeDetail.
      // Riverpod provider rebuild needs multiple microtask rounds.
      for (var i = 0; i < 10; i++) {
        async.flushMicrotasks();
      }

      expect(repository.generateSummaryCalls, 1);
      expect(container.read(provider).isLoading, isTrue);
      // Immediate sync makes the first getEpisode call (summary not yet available)
      expect(repository.getEpisodeCalls, 1);

      // Timer tick at 5s: second getEpisode call (summary now available)
      async.elapse(const Duration(seconds: 5));
      for (var i = 0; i < 10; i++) {
        async.flushMicrotasks();
      }

      expect(repository.getEpisodeCalls, 2);
      expect(container.read(provider).summary, 'Persisted summary');

      // Verify polling stopped (no more getEpisode calls after another tick)
      final callsBefore = repository.getEpisodeCalls;
      async.elapse(const Duration(seconds: 5));
      for (var i = 0; i < 10; i++) {
        async.flushMicrotasks();
      }
      expect(repository.getEpisodeCalls, callsBefore);
    });
  });

  test(
    'clearError removes stale error and retry keeps summary state usable',
    () {
      fakeAsync((async) {
        final repository = _FakeSummaryRepository(
          episodeId: 1002,
          summaryAvailableOnFetch: 1,
          failGenerateCalls: const {1},
        );
        final container = ProviderContainer(
          overrides: [
            podcastRepositoryProvider.overrideWithValue(repository),
            episodeDetailProvider(1002).overrideWith((ref) async {
              return repository.getEpisode(1002);
            }),
          ],
        );
        final provider = summaryProvider(1002);
        final subscription = container.listen(
          provider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(() {
          subscription.close();
          container.dispose();
        });

        container.read(provider.notifier).generateSummary();
        for (var i = 0; i < 10; i++) {
          async.flushMicrotasks();
        }

        expect(container.read(provider).hasError, isTrue);

        container.read(provider.notifier).clearError();
        expect(container.read(provider).hasError, isFalse);

        container.read(provider.notifier).generateSummary();
        for (var i = 0; i < 10; i++) {
          async.flushMicrotasks();
        }

        // Elapse to let timer tick + resolve provider rebuild
        async.elapse(const Duration(seconds: 5));
        for (var i = 0; i < 10; i++) {
          async.flushMicrotasks();
        }

        expect(repository.generateSummaryCalls, 2);
        expect(container.read(provider).hasError, isFalse);
        expect(container.read(provider).summary, 'Persisted summary');
      });
    },
  );

  test('summary actions never forward custom prompt from provider layer', () {
    fakeAsync((async) {
      final repository = _FakeSummaryRepository(
        episodeId: 1003,
        summaryAvailableOnFetch: 1,
      );
      final container = ProviderContainer(
        overrides: [
          podcastRepositoryProvider.overrideWithValue(repository),
          episodeDetailProvider(1003).overrideWith((ref) async {
            return repository.getEpisode(1003);
          }),
        ],
      );
      addTearDown(container.dispose);

      final provider = summaryProvider(1003);

      container.read(provider.notifier).generateSummary(model: 'model-a');
      for (var i = 0; i < 10; i++) {
        async.flushMicrotasks();
      }
      async.elapse(const Duration(seconds: 5));
      for (var i = 0; i < 10; i++) {
        async.flushMicrotasks();
      }

      container.read(provider.notifier).regenerateSummary(model: 'model-b');
      for (var i = 0; i < 10; i++) {
        async.flushMicrotasks();
      }

      expect(repository.customPromptValues, [null, null]);
      expect(repository.summaryModelValues, ['model-a', 'model-b']);
    });
  });

  test('html error page in persisted summary becomes error state', () {
    fakeAsync((async) {
      final repository = _FakeSummaryRepository(
        episodeId: 1004,
        summaryAvailableOnFetch: 1,
        persistedSummary:
            '<!DOCTYPE html><html><head><title>524: A timeout occurred</title></head></html>',
      );
      final container = ProviderContainer(
        overrides: [
          podcastRepositoryProvider.overrideWithValue(repository),
          episodeDetailProvider(1004).overrideWith((ref) async {
            return repository.getEpisode(1004);
          }),
        ],
      );
      final provider = summaryProvider(1004);
      final subscription = container.listen(
        provider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(() {
        subscription.close();
        container.dispose();
      });

      container.read(provider.notifier).generateSummary();
      for (var i = 0; i < 10; i++) {
        async.flushMicrotasks();
      }

      // Elapse to trigger sync which finds the HTML error page
      async.elapse(const Duration(seconds: 5));
      for (var i = 0; i < 10; i++) {
        async.flushMicrotasks();
      }

      expect(container.read(provider).hasError, isTrue);
      expect(container.read(provider).hasSummary, isFalse);
    });
  });

  test(
    'regenerate clears current summary and suppresses persisted fallback',
    () {
      fakeAsync((async) {
        final repository = _FakeSummaryRepository(
          episodeId: 1005,
          summaryAvailableOnFetch: 3,
        );
        final container = ProviderContainer(
          overrides: [
            podcastRepositoryProvider.overrideWithValue(repository),
            episodeDetailProvider(1005).overrideWith((ref) async {
              return repository.getEpisode(1005);
            }),
          ],
        );
        addTearDown(container.dispose);

        final provider = summaryProvider(1005);
        container
            .read(provider.notifier)
            .updateSummary('Existing summary', modelUsed: 'model-a');

        container.read(provider.notifier).regenerateSummary();
        async.flushMicrotasks();

        final state = container.read(provider);
        expect(state.isLoading, isTrue);
        expect(state.hasSummary, isFalse);
        expect(state.summary, isNull);
        expect(state.hidePersistedSummary, isTrue);
      });
    },
  );

}

class _FakeSummaryRepository extends PodcastRepository {
  _FakeSummaryRepository({
    required this.episodeId,
    required this.summaryAvailableOnFetch,
    this.failGenerateCalls = const {},
    this.persistedSummary = 'Persisted summary',
  }) : super(PodcastApiService(Dio()));

  final int episodeId;
  final int summaryAvailableOnFetch;
  final Set<int> failGenerateCalls;
  final String persistedSummary;
  int generateSummaryCalls = 0;
  int getEpisodeCalls = 0;
  final List<String?> customPromptValues = [];
  final List<String?> summaryModelValues = [];

  @override
  Future<PodcastSummaryStartResponse> generateSummary({
    required int episodeId,
    bool forceRegenerate = false,
    bool? useTranscript,
    String? summaryModel,
    String? customPrompt,
  }) async {
    generateSummaryCalls += 1;
    customPromptValues.add(customPrompt);
    summaryModelValues.add(summaryModel);
    if (failGenerateCalls.contains(generateSummaryCalls)) {
      throw StateError('summary generation failed');
    }
    return PodcastSummaryStartResponse(
      episodeId: episodeId,
      summaryStatus: 'summary_generating',
      acceptedAt: DateTime.utc(2026, 3, 10),
      messageEn: 'accepted',
      messageZh: 'accepted',
    );
  }

  @override
  Future<PodcastEpisodeModel> getEpisode(int id) async {
    getEpisodeCalls += 1;
    return PodcastEpisodeModel(
      id: episodeId,
      subscriptionId: 1,
      title: 'Episode',
      description: 'Description',
      audioUrl: 'https://example.com/audio.mp3',
      publishedAt: DateTime.utc(2026, 3, 10),
      createdAt: DateTime.utc(2026, 3, 10),
      aiSummary: getEpisodeCalls >= summaryAvailableOnFetch
          ? persistedSummary
          : null,
      summaryStatus: getEpisodeCalls >= summaryAvailableOnFetch
          ? 'summarized'
          : 'summary_generating',
    );
  }
}
