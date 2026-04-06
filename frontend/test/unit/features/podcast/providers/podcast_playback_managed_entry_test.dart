import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/audio_player_state_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_queue_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';

void main() {
  group('AudioPlayerNotifier.playManagedEpisode', () {
    test('activates queue before playing normal podcast episodes', () async {
      final audioNotifier = _TrackingAudioPlayerNotifier();
      final queueController = _QueuePreparingController(
        const PodcastQueueModel(
          currentEpisodeId: 7,
          revision: 3,
          items: [
            PodcastQueueItemModel(
              episodeId: 7,
              position: 0,
              title: 'Managed Episode',
              podcastId: 1,
              audioUrl: 'https://example.com/managed.mp3',
            ),
          ],
        ),
      );
      final container = ProviderContainer(
        overrides: [
          audioPlayerProvider.overrideWith(() => audioNotifier),
          podcastQueueControllerProvider.overrideWith(() => queueController),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(audioPlayerProvider.notifier)
          .playManagedEpisode(_episode(7));

      expect(queueController.activateEpisodeCalls, 1);
      expect(audioNotifier.playEpisodeCalls, 1);
      expect(audioNotifier.lastPlaySource, PlaySource.queue);
      expect(audioNotifier.lastQueueEpisodeId, 7);
      expect(audioNotifier.lastPlayedEpisode?.id, 7);
    });

    test('keeps discover preview episodes on direct playback path', () async {
      final audioNotifier = _TrackingAudioPlayerNotifier();
      final queueController = _QueuePreparingController(
        const PodcastQueueModel(),
      );
      final container = ProviderContainer(
        overrides: [
          audioPlayerProvider.overrideWith(() => audioNotifier),
          podcastQueueControllerProvider.overrideWith(() => queueController),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(audioPlayerProvider.notifier)
          .playManagedEpisode(
            _episode(
              9,
              metadata: const {'discover_preview': true, 'source': 'discover'},
            ),
          );

      expect(queueController.activateEpisodeCalls, 0);
      expect(audioNotifier.playEpisodeCalls, 1);
      expect(audioNotifier.lastPlaySource, PlaySource.direct);
      expect(audioNotifier.lastQueueEpisodeId, isNull);
      expect(audioNotifier.lastPlayedEpisode?.id, 9);
    });
  });
}

PodcastEpisodeModel _episode(int id, {Map<String, dynamic>? metadata}) {
  return PodcastEpisodeModel(
    id: id,
    subscriptionId: 1,
    title: 'Episode $id',
    audioUrl: 'https://example.com/audio-$id.mp3',
    publishedAt: DateTime(2026, 2, 14),
    createdAt: DateTime(2026, 2, 14),
    metadata: metadata,
  );
}

class _TrackingAudioPlayerNotifier extends AudioPlayerNotifier {
  int playEpisodeCalls = 0;
  PodcastEpisodeModel? lastPlayedEpisode;
  PlaySource? lastPlaySource;
  int? lastQueueEpisodeId;

  @override
  AudioPlayerState build() {
    return const AudioPlayerState();
  }

  @override
  Future<void> playEpisode(
    PodcastEpisodeModel episode, {
    PlaySource source = PlaySource.direct,
    int? queueEpisodeId,
  }) async {
    playEpisodeCalls += 1;
    lastPlayedEpisode = episode;
    lastPlaySource = source;
    lastQueueEpisodeId = queueEpisodeId;
  }
}

class _QueuePreparingController extends PodcastQueueController {
  _QueuePreparingController(this.queue);

  final PodcastQueueModel queue;
  int activateEpisodeCalls = 0;

  @override
  Future<PodcastQueueModel> build() async {
    return queue;
  }

  @override
  Future<PodcastQueueModel> activateEpisode(int episodeId) async {
    activateEpisodeCalls += 1;
    state = AsyncValue.data(queue);
    return queue;
  }
}
