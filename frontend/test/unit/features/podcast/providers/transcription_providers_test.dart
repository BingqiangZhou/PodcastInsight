import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_transcription_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/repositories/podcast_repository.dart';
import 'package:personal_ai_assistant/features/podcast/data/services/podcast_api_service.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/transcription_providers.dart';
import 'package:dio/dio.dart';

void main() {
  test('transcription polling stops after terminal state', () {
    fakeAsync((async) {
      final repository = _FakeTranscriptionRepository(terminalAfterCalls: 2);
      final container = ProviderContainer(
        overrides: [
          podcastRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final provider = getTranscriptionProvider(2001);
      container.read(provider.notifier).loadTranscription();
      async.flushMicrotasks();

      expect(repository.getTranscriptionCalls, 1);

      async.elapse(const Duration(seconds: 3));
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 6));
      async.flushMicrotasks();

      expect(repository.getTranscriptionCalls, 2);
      expect(container.read(provider).value?.isCompleted, isTrue);
    });
  });

  test('transcription polling is cleaned up on dispose', () {
    fakeAsync((async) {
      final repository = _FakeTranscriptionRepository(terminalAfterCalls: 99);
      final container = ProviderContainer(
        overrides: [
          podcastRepositoryProvider.overrideWithValue(repository),
        ],
      );

      final provider = getTranscriptionProvider(2002);
      container.read(provider.notifier).loadTranscription();
      async.flushMicrotasks();
      expect(repository.getTranscriptionCalls, 1);

      container.dispose();

      async.elapse(const Duration(seconds: 6));
      async.flushMicrotasks();

      expect(repository.getTranscriptionCalls, 1);
    });
  });
}

class _FakeTranscriptionRepository extends PodcastRepository {
  _FakeTranscriptionRepository({required this.terminalAfterCalls})
    : super(PodcastApiService(Dio()));

  final int terminalAfterCalls;
  int getTranscriptionCalls = 0;

  @override
  Future<PodcastTranscriptionResponse?> getTranscription(int episodeId) async {
    getTranscriptionCalls += 1;
    return PodcastTranscriptionResponse(
      id: 1,
      episodeId: episodeId,
      status: getTranscriptionCalls >= terminalAfterCalls
          ? 'completed'
          : 'processing',
      createdAt: DateTime.utc(2026, 3, 10),
      transcriptContent: getTranscriptionCalls >= terminalAfterCalls
          ? 'Transcript'
          : null,
    );
  }
}
