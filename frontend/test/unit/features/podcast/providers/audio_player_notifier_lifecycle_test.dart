import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/podcast/data/repositories/podcast_repository.dart';
import 'package:personal_ai_assistant/features/podcast/data/services/podcast_api_service.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/audio_handler.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioPlayerNotifier lifecycle', () {
    test(
      'replacing managed resources cancels stale subscriptions and timers',
      () async {
        final container = ProviderContainer(
          overrides: [
            podcastRepositoryProvider.overrideWithValue(
              _FakePodcastRepository(),
            ),
            audioHandlerProvider.overrideWithValue(_FakeAudioHandler()),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(audioPlayerProvider.notifier);
        final staleResources = _ManagedResourceBundle();
        addTearDown(staleResources.dispose);
        notifier.debugReplaceManagedResources(
          playerStateSubscription: staleResources.playerStateSubscription,
          positionSubscription: staleResources.positionSubscription,
          durationSubscription: staleResources.durationSubscription,
          syncThrottleTimer: staleResources.syncThrottleTimer,
          sleepTimerTickTimer: staleResources.sleepTimerTickTimer,
          snapshotPersistTimer: staleResources.snapshotPersistTimer,
        );

        final freshResources = _ManagedResourceBundle();
        addTearDown(freshResources.dispose);
        notifier.debugReplaceManagedResources(
          playerStateSubscription: freshResources.playerStateSubscription,
          positionSubscription: freshResources.positionSubscription,
          durationSubscription: freshResources.durationSubscription,
          syncThrottleTimer: freshResources.syncThrottleTimer,
          sleepTimerTickTimer: freshResources.sleepTimerTickTimer,
          snapshotPersistTimer: freshResources.snapshotPersistTimer,
        );

        await Future<void>.delayed(const Duration(milliseconds: 40));

        expect(staleResources.cancelCount, 3);
        expect(staleResources.firedTimerCount, 0);
        expect(freshResources.cancelCount, 0);
        expect(freshResources.firedTimerCount, 3);
      },
    );

    test('dispose cancels active managed resources', () async {
      final container = ProviderContainer(
        overrides: [
          podcastRepositoryProvider.overrideWithValue(_FakePodcastRepository()),
          audioHandlerProvider.overrideWithValue(
            PodcastAudioHandler.testOnly(),
          ),
        ],
      );

      final notifier = container.read(audioPlayerProvider.notifier);
      final resources = _ManagedResourceBundle();
      addTearDown(resources.dispose);
      notifier.debugReplaceManagedResources(
        playerStateSubscription: resources.playerStateSubscription,
        positionSubscription: resources.positionSubscription,
        durationSubscription: resources.durationSubscription,
        syncThrottleTimer: resources.syncThrottleTimer,
        sleepTimerTickTimer: resources.sleepTimerTickTimer,
        snapshotPersistTimer: resources.snapshotPersistTimer,
      );

      container.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(resources.cancelCount, 3);
      expect(resources.firedTimerCount, 0);
    });

    test(
      'setSleepTimerAfterEpisode is idempotent and clears countdown timer',
      () async {
        final container = ProviderContainer(
          overrides: [
            podcastRepositoryProvider.overrideWithValue(
              _FakePodcastRepository(),
            ),
            audioHandlerProvider.overrideWithValue(_FakeAudioHandler()),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(audioPlayerProvider.notifier);
        notifier.setSleepTimer(const Duration(milliseconds: 80));
        notifier.setSleepTimerAfterEpisode();
        final firstState = container.read(audioPlayerProvider);

        await Future<void>.delayed(const Duration(milliseconds: 30));
        notifier.setSleepTimerAfterEpisode();
        final secondState = container.read(audioPlayerProvider);

        expect(firstState.sleepTimerAfterEpisode, isTrue);
        expect(firstState.sleepTimerEndTime, isNull);
        expect(firstState.sleepTimerRemainingLabel, 'After current episode');
        // Only compare sleep-timer fields; processingState may differ due to
        // async listener callbacks from the audio handler during the delay.
        expect(secondState.sleepTimerAfterEpisode, firstState.sleepTimerAfterEpisode);
        expect(secondState.sleepTimerEndTime, firstState.sleepTimerEndTime);
        expect(secondState.sleepTimerRemainingLabel, firstState.sleepTimerRemainingLabel);
      },
    );
  });
}

class _ManagedResourceBundle {
  _ManagedResourceBundle() {
    _playerStateController = StreamController<void>.broadcast(
      onCancel: () => cancelCount++,
    );
    _positionController = StreamController<void>.broadcast(
      onCancel: () => cancelCount++,
    );
    _durationController = StreamController<void>.broadcast(
      onCancel: () => cancelCount++,
    );
    playerStateSubscription = _playerStateController.stream.listen((_) {});
    positionSubscription = _positionController.stream.listen((_) {});
    durationSubscription = _durationController.stream.listen((_) {});
    syncThrottleTimer = Timer(
      const Duration(milliseconds: 20),
      () => firedTimerCount++,
    );
    sleepTimerTickTimer = Timer(
      const Duration(milliseconds: 20),
      () => firedTimerCount++,
    );
    snapshotPersistTimer = Timer(
      const Duration(milliseconds: 20),
      () => firedTimerCount++,
    );
  }

  late final StreamController<void> _playerStateController;
  late final StreamController<void> _positionController;
  late final StreamController<void> _durationController;
  late final StreamSubscription<void> playerStateSubscription;
  late final StreamSubscription<void> positionSubscription;
  late final StreamSubscription<void> durationSubscription;
  late final Timer syncThrottleTimer;
  late final Timer sleepTimerTickTimer;
  late final Timer snapshotPersistTimer;
  int cancelCount = 0;
  int firedTimerCount = 0;

  Future<void> dispose() async {
    await playerStateSubscription.cancel();
    await positionSubscription.cancel();
    await durationSubscription.cancel();
    syncThrottleTimer.cancel();
    sleepTimerTickTimer.cancel();
    snapshotPersistTimer.cancel();
    await _playerStateController.close();
    await _positionController.close();
    await _durationController.close();
  }
}

class _FakePodcastRepository extends PodcastRepository {
  _FakePodcastRepository() : super(PodcastApiService(Dio()));
}

/// Fake audio handler that provides required streams without creating a real
/// AudioPlayer (which would fail with MissingPluginException in tests).
/// Extends PodcastAudioHandler via testOnly() and overrides positionStream
/// so the late-final _player is never accessed.
class _FakeAudioHandler extends PodcastAudioHandler {
  _FakeAudioHandler() : super.testOnly();

  @override
  Stream<Duration> get positionStream => const Stream.empty();
}
