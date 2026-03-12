import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/audio_player_state_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_playback_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/repositories/podcast_repository.dart';
import 'package:personal_ai_assistant/features/podcast/data/services/podcast_api_service.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';

void main() {
  group('AudioPlayerNotifier playback-rate sync', () {
    test('uses server effective rate for speed sheet state', () async {
      final repository = _TrackingPodcastRepository(
        effectiveResponse: const PlaybackRateEffectiveResponse(
          globalPlaybackRate: 1.0,
          subscriptionPlaybackRate: 1.5,
          effectivePlaybackRate: 1.5,
          source: 'subscription',
        ),
      );
      final container = ProviderContainer(
        overrides: [
          podcastRepositoryProvider.overrideWithValue(repository),
          audioPlayerProvider.overrideWith(
            () => _TestAudioPlayerNotifier(
              AudioPlayerState(
                currentEpisode: _episode(playbackRate: 1.0),
                playbackRate: 1.0,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(audioPlayerProvider.notifier);
      final selection = await notifier
          .resolvePlaybackRateSelectionForCurrentContext();

      expect(selection.speed, 1.5);
      expect(selection.applyToSubscription, isTrue);
      expect(repository.effectivePlaybackRateRequests, <int?>[1]);
    });

    test('sync speed sheet snapshot falls back to local playback state', () {
      final repository = _TrackingPodcastRepository(
        effectivePlaybackRateError: Exception('offline'),
      );
      final container = ProviderContainer(
        overrides: [
          podcastRepositoryProvider.overrideWithValue(repository),
          audioPlayerProvider.overrideWith(
            () => _TestAudioPlayerNotifier(
              AudioPlayerState(
                currentEpisode: _episode(playbackRate: 1.25),
                playbackRate: 1.25,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final snapshot = container
          .read(audioPlayerProvider.notifier)
          .getPlaybackRateSelectionSnapshot();

      expect(snapshot.speed, 1.25);
      expect(snapshot.applyToSubscription, isFalse);
      expect(repository.effectivePlaybackRateRequests, isEmpty);
    });

    test(
      'falls back to current state when resolving effective rate fails',
      () async {
        final repository = _TrackingPodcastRepository(
          effectivePlaybackRateError: Exception('offline'),
        );
        final container = ProviderContainer(
          overrides: [
            podcastRepositoryProvider.overrideWithValue(repository),
            audioPlayerProvider.overrideWith(
              () => _TestAudioPlayerNotifier(
                AudioPlayerState(
                  currentEpisode: _episode(playbackRate: 1.25),
                  playbackRate: 1.25,
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(audioPlayerProvider.notifier);
        final selection = await notifier
            .resolvePlaybackRateSelectionForCurrentContext();

        expect(selection.speed, 1.25);
        expect(selection.applyToSubscription, isFalse);
        expect(repository.effectivePlaybackRateRequests, <int?>[1]);
      },
    );

    test('resume refreshes audio speed from server before playing', () async {
      final repository = _TrackingPodcastRepository(
        effectiveResponse: const PlaybackRateEffectiveResponse(
          globalPlaybackRate: 1.0,
          subscriptionPlaybackRate: 1.75,
          effectivePlaybackRate: 1.75,
          source: 'subscription',
        ),
      );
      final notifier = _TestAudioPlayerNotifier(
        AudioPlayerState(
          currentEpisode: _episode(playbackRate: 1.0),
          playbackRate: 1.0,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          podcastRepositoryProvider.overrideWithValue(repository),
          audioPlayerProvider.overrideWith(() => notifier),
        ],
      );
      addTearDown(container.dispose);

      await container.read(audioPlayerProvider.notifier).resume();

      expect(repository.effectivePlaybackRateRequests, <int?>[1]);
      expect(notifier.audioSpeedCalls, <double>[1.75]);
      expect(notifier.playAudioCalls, 1);
      expect(container.read(audioPlayerProvider).playbackRate, 1.75);
      expect(repository.updatePlaybackProgressCalls, 1);
    });

    test(
      'resume falls back to local playback rate when server lookup fails',
      () async {
        final repository = _TrackingPodcastRepository(
          effectivePlaybackRateError: Exception('offline'),
        );
        final notifier = _TestAudioPlayerNotifier(
          AudioPlayerState(
            currentEpisode: _episode(playbackRate: 1.25),
            playbackRate: 1.25,
          ),
        );
        final container = ProviderContainer(
          overrides: [
            podcastRepositoryProvider.overrideWithValue(repository),
            audioPlayerProvider.overrideWith(() => notifier),
          ],
        );
        addTearDown(container.dispose);

        await container.read(audioPlayerProvider.notifier).resume();

        expect(repository.effectivePlaybackRateRequests, <int?>[1]);
        expect(notifier.audioSpeedCalls, <double>[1.25]);
        expect(notifier.playAudioCalls, 1);
        expect(container.read(audioPlayerProvider).playbackRate, 1.25);
      },
    );

    test('setPlaybackRate refreshes cached speed selection snapshot', () async {
      final repository = _TrackingPodcastRepository();
      final notifier = _TestAudioPlayerNotifier(
        AudioPlayerState(
          currentEpisode: _episode(playbackRate: 1.0),
          playbackRate: 1.0,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          podcastRepositoryProvider.overrideWithValue(repository),
          audioPlayerProvider.overrideWith(() => notifier),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(audioPlayerProvider.notifier)
          .setPlaybackRate(1.75, applyToSubscription: true);

      final snapshot = container
          .read(audioPlayerProvider.notifier)
          .getPlaybackRateSelectionSnapshot();

      expect(repository.applyPlaybackRateCalls, 1);
      expect(snapshot.speed, 1.75);
      expect(snapshot.applyToSubscription, isTrue);
      expect(container.read(audioPlayerProvider).playbackRate, 1.75);
    });

    test(
      'sleep timer remains session-local and does not hit repository',
      () async {
        final repository = _TrackingPodcastRepository();
        final container = ProviderContainer(
          overrides: [podcastRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(container.dispose);

        final notifier = container.read(audioPlayerProvider.notifier);
        notifier.setSleepTimer(const Duration(minutes: 5));
        notifier.cancelSleepTimer();

        expect(container.read(audioPlayerProvider).isSleepTimerActive, isFalse);
        expect(repository.effectivePlaybackRateRequests, isEmpty);
        expect(repository.applyPlaybackRateCalls, 0);
        expect(repository.updatePlaybackProgressCalls, 0);
      },
    );

    test('sleep timer is cleared after provider rebuild', () async {
      final repository = _TrackingPodcastRepository();
      final firstContainer = ProviderContainer(
        overrides: [podcastRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(firstContainer.dispose);

      firstContainer
          .read(audioPlayerProvider.notifier)
          .setSleepTimer(const Duration(minutes: 5));
      expect(
        firstContainer.read(audioPlayerProvider).isSleepTimerActive,
        isTrue,
      );

      firstContainer.dispose();

      final secondContainer = ProviderContainer(
        overrides: [podcastRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(secondContainer.dispose);

      expect(
        secondContainer.read(audioPlayerProvider).isSleepTimerActive,
        isFalse,
      );
    });
  });
}

class _TestAudioPlayerNotifier extends AudioPlayerNotifier {
  _TestAudioPlayerNotifier(this._initialState);

  final AudioPlayerState _initialState;
  final List<double> audioSpeedCalls = <double>[];
  int playAudioCalls = 0;

  @override
  AudioPlayerState build() {
    super.build();
    return _initialState;
  }

  @override
  Future<void> setAudioSpeed(double rate) async {
    audioSpeedCalls.add(rate);
  }

  @override
  Future<void> playAudio() async {
    playAudioCalls += 1;
  }
}

class _TrackingPodcastRepository extends PodcastRepository {
  _TrackingPodcastRepository({
    this.effectiveResponse = const PlaybackRateEffectiveResponse(
      globalPlaybackRate: 1.0,
      subscriptionPlaybackRate: null,
      effectivePlaybackRate: 1.0,
      source: 'global',
    ),
    this.effectivePlaybackRateError,
  }) : super(PodcastApiService(Dio()));

  final PlaybackRateEffectiveResponse effectiveResponse;
  final Object? effectivePlaybackRateError;
  final List<int?> effectivePlaybackRateRequests = <int?>[];
  int updatePlaybackProgressCalls = 0;
  int applyPlaybackRateCalls = 0;

  @override
  Future<PlaybackRateEffectiveResponse> getEffectivePlaybackRate({
    int? subscriptionId,
  }) async {
    effectivePlaybackRateRequests.add(subscriptionId);
    if (effectivePlaybackRateError != null) {
      throw effectivePlaybackRateError!;
    }
    return effectiveResponse;
  }

  @override
  Future<PodcastPlaybackStateResponse> updatePlaybackProgress({
    required int episodeId,
    required int position,
    required bool isPlaying,
    double playbackRate = 1.0,
  }) async {
    updatePlaybackProgressCalls += 1;
    return PodcastPlaybackStateResponse(
      episodeId: episodeId,
      currentPosition: position,
      isPlaying: isPlaying,
      playbackRate: playbackRate,
      playCount: 1,
      lastUpdatedAt: DateTime(2026, 3, 12),
      progressPercentage: 0,
      remainingTime: 0,
    );
  }

  @override
  Future<PlaybackRateEffectiveResponse> applyPlaybackRatePreference({
    required double playbackRate,
    required bool applyToSubscription,
    int? subscriptionId,
  }) async {
    applyPlaybackRateCalls += 1;
    return PlaybackRateEffectiveResponse(
      globalPlaybackRate: playbackRate,
      subscriptionPlaybackRate: applyToSubscription ? playbackRate : null,
      effectivePlaybackRate: playbackRate,
      source: applyToSubscription ? 'subscription' : 'global',
    );
  }
}

PodcastEpisodeModel _episode({required double playbackRate}) {
  final now = DateTime(2026, 3, 12);
  return PodcastEpisodeModel(
    id: 7,
    subscriptionId: 1,
    title: 'Episode',
    audioUrl: 'https://example.com/audio.mp3',
    publishedAt: now,
    playbackRate: playbackRate,
    createdAt: now,
  );
}
