import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/constants/cache_constants.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/playback_history_lite_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/repositories/podcast_repository.dart';
import 'package:personal_ai_assistant/features/podcast/data/services/podcast_api_service.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';

void main() {
  group('PlaybackHistoryLiteNotifier', () {
    test('uses fresh cache for repeated load', () async {
      final repository = _FakePodcastRepository(
        history: <PlaybackHistoryLiteResponse>[_historyResponse(10)],
      );
      final container = ProviderContainer(
        overrides: [podcastRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(playbackHistoryLiteProvider.notifier);
      await notifier.load();
      await notifier.load();

      expect(repository.getPlaybackHistoryLiteCalls, 1);
      expect(container.read(playbackHistoryLiteProvider).value?.total, 10);
    });

    test('forceRefresh bypasses cache and updates state', () async {
      final repository = _FakePodcastRepository(
        history: <PlaybackHistoryLiteResponse>[
          _historyResponse(10),
          _historyResponse(20),
        ],
      );
      final container = ProviderContainer(
        overrides: [podcastRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(playbackHistoryLiteProvider.notifier);
      await notifier.load();
      await notifier.load(forceRefresh: true);

      expect(repository.getPlaybackHistoryLiteCalls, 2);
      expect(container.read(playbackHistoryLiteProvider).value?.total, 20);
    });

    test('reloads after TTL expires', () {
      fakeAsync((async) {
        final repository = _FakePodcastRepository(
          history: <PlaybackHistoryLiteResponse>[
            _historyResponse(10),
            _historyResponse(30),
          ],
        );
        final container = ProviderContainer(
          overrides: [
            podcastRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(playbackHistoryLiteProvider.notifier);
        async.run((_) {
          notifier.load();
        });
        async.flushMicrotasks();

        // Advance past the cache TTL
        async.elapse(CacheConstants.defaultListCacheDuration + const Duration(seconds: 1));

        async.run((_) {
          notifier.load();
        });
        async.flushMicrotasks();

        expect(repository.getPlaybackHistoryLiteCalls, 2);
        expect(container.read(playbackHistoryLiteProvider).value?.total, 30);
      });
    });
  });
}

class _FakePodcastRepository extends PodcastRepository {
  _FakePodcastRepository({required List<PlaybackHistoryLiteResponse> history})
    : _history = history,
      super(PodcastApiService(Dio()));

  final List<PlaybackHistoryLiteResponse> _history;
  int getPlaybackHistoryLiteCalls = 0;

  @override
  Future<PlaybackHistoryLiteResponse> getPlaybackHistoryLite({
    int page = 1,
    int size = 100,
  }) async {
    final index = getPlaybackHistoryLiteCalls < _history.length
        ? getPlaybackHistoryLiteCalls
        : _history.length - 1;
    getPlaybackHistoryLiteCalls += 1;
    return _history[index];
  }
}

PlaybackHistoryLiteResponse _historyResponse(int total) {
  final now = DateTime(2026, 2, 14, 10);
  return PlaybackHistoryLiteResponse(
    episodes: <PlaybackHistoryLiteItem>[
      PlaybackHistoryLiteItem(
        id: total,
        subscriptionId: 1,
        title: 'Episode $total',
        audioDuration: 300,
        playbackPosition: 10,
        lastPlayedAt: now,
        publishedAt: now,
      ),
    ],
    total: total,
    page: 1,
    size: 100,
    pages: 1,
  );
}
