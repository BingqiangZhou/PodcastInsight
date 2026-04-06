import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/features/auth/presentation/providers/auth_provider.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_daily_report_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/repositories/podcast_repository.dart';
import 'package:personal_ai_assistant/features/podcast/data/services/podcast_api_service.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';

void main() {
  group('PodcastFeedNotifier', () {
    test('uses fresh cache and skips repeated initial request', () async {
      final fakeRepository = _FakePodcastRepository(
        responses: <PodcastFeedResponse>[
          _responseWithEpisodeIds(<int>[1]),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          podcastRepositoryProvider.overrideWithValue(fakeRepository),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(podcastFeedProvider.notifier);
      await notifier.loadInitialFeed();
      await notifier.loadInitialFeed();

      expect(fakeRepository.getPodcastFeedCalls, 1);
    });

    test(
      'keeps existing episodes while background refresh is in flight',
      () async {
        final fakeRepository = _FakePodcastRepository(
          responses: <PodcastFeedResponse>[
            _responseWithEpisodeIds(<int>[1]),
            _responseWithEpisodeIds(<int>[2]),
          ],
          delays: const <Duration>[Duration.zero, Duration(milliseconds: 120)],
        );
        final container = ProviderContainer(
          overrides: [
            podcastRepositoryProvider.overrideWithValue(fakeRepository),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(podcastFeedProvider.notifier);
        await notifier.loadInitialFeed();

        final refreshFuture = notifier.loadInitialFeed(
          forceRefresh: true,
          background: true,
        );

        await Future<void>.delayed(const Duration(milliseconds: 40));
        final inFlightState = container.read(podcastFeedProvider);
        expect(inFlightState.episodes.first.id, 1);
        expect(inFlightState.isLoading, isFalse);

        await refreshFuture;
        final finalState = container.read(podcastFeedProvider);
        expect(finalState.episodes.first.id, 2);
      },
    );

    test(
      'keeps loading hidden when background prefetch starts with empty cache',
      () async {
        final fakeRepository = _FakePodcastRepository(
          responses: <PodcastFeedResponse>[
            _responseWithEpisodeIds(<int>[1]),
          ],
          delays: const <Duration>[Duration(milliseconds: 120)],
        );
        final container = ProviderContainer(
          overrides: [
            podcastRepositoryProvider.overrideWithValue(fakeRepository),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(podcastFeedProvider.notifier);
        final inFlight = notifier.loadInitialFeed(background: true);

        await Future<void>.delayed(const Duration(milliseconds: 20));
        final loadingState = container.read(podcastFeedProvider);
        expect(loadingState.episodes, isEmpty);
        expect(loadingState.isLoading, isFalse);

        await inFlight;
        final loadedState = container.read(podcastFeedProvider);
        expect(loadedState.episodes.first.id, 1);
        expect(loadedState.isLoading, isFalse);
      },
    );

    test('shows loading on foreground initial load with empty cache', () async {
      final fakeRepository = _FakePodcastRepository(
        responses: <PodcastFeedResponse>[
          _responseWithEpisodeIds(<int>[1]),
        ],
        delays: const <Duration>[Duration(milliseconds: 120)],
      );
      final container = ProviderContainer(
        overrides: [
          podcastRepositoryProvider.overrideWithValue(fakeRepository),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(podcastFeedProvider.notifier);
      final inFlight = notifier.loadInitialFeed();

      await Future<void>.delayed(const Duration(milliseconds: 20));
      final loadingState = container.read(podcastFeedProvider);
      expect(loadingState.episodes, isEmpty);
      expect(loadingState.isLoading, isTrue);

      await inFlight;
      final loadedState = container.read(podcastFeedProvider);
      expect(loadedState.episodes.first.id, 1);
      expect(loadedState.isLoading, isFalse);
    });

    test('forceRefresh requests again and replaces old feed data', () async {
      final fakeRepository = _FakePodcastRepository(
        responses: <PodcastFeedResponse>[
          _responseWithEpisodeIds(<int>[1]),
          _responseWithEpisodeIds(<int>[2]),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          podcastRepositoryProvider.overrideWithValue(fakeRepository),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(podcastFeedProvider.notifier);
      await notifier.loadInitialFeed();
      expect(container.read(podcastFeedProvider).episodes.first.id, 1);

      await notifier.loadInitialFeed(forceRefresh: true);
      final refreshedState = container.read(podcastFeedProvider);
      expect(refreshedState.episodes.first.id, 2);
      expect(fakeRepository.getPodcastFeedCalls, 2);
    });

    test('deduplicates concurrent initial loads', () async {
      final fakeRepository = _FakePodcastRepository(
        responses: <PodcastFeedResponse>[
          _responseWithEpisodeIds(<int>[1]),
        ],
        delays: const <Duration>[Duration(milliseconds: 100)],
      );
      final container = ProviderContainer(
        overrides: [
          podcastRepositoryProvider.overrideWithValue(fakeRepository),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(podcastFeedProvider.notifier);
      await Future.wait<void>([
        notifier.loadInitialFeed(),
        notifier.loadInitialFeed(),
      ]);

      expect(fakeRepository.getPodcastFeedCalls, 1);
    });

    test('refreshFeed does not trigger daily report providers', () async {
      final fakeRepository = _FakePodcastRepository(
        responses: <PodcastFeedResponse>[
          _responseWithEpisodeIds(<int>[1]),
        ],
      );
      final dailyReportNotifier = _TrackingDailyReportNotifier();
      final dailyReportDatesNotifier = _TrackingDailyReportDatesNotifier();
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(_AuthenticatedAuthNotifier.new),
          podcastRepositoryProvider.overrideWithValue(fakeRepository),
          dailyReportProvider.overrideWith(() => dailyReportNotifier),
          dailyReportDatesProvider.overrideWith(() => dailyReportDatesNotifier),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(podcastFeedProvider.notifier);
      await notifier.refreshFeed();

      expect(fakeRepository.getPodcastFeedCalls, 1);
      expect(dailyReportNotifier.loadCalls, 0);
      expect(dailyReportDatesNotifier.loadCalls, 0);
    });

    test(
      'refreshFeed fastReturn returns quickly and updates feed in background',
      () async {
        final fakeRepository = _FakePodcastRepository(
          responses: <PodcastFeedResponse>[
            _responseWithEpisodeIds(<int>[1]),
            _responseWithEpisodeIds(<int>[2]),
          ],
          delays: const <Duration>[Duration.zero, Duration(milliseconds: 250)],
        );
        final container = ProviderContainer(
          overrides: [
            authProvider.overrideWith(_AuthenticatedAuthNotifier.new),
            podcastRepositoryProvider.overrideWithValue(fakeRepository),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(podcastFeedProvider.notifier);
        await notifier.loadInitialFeed();
        expect(container.read(podcastFeedProvider).episodes.first.id, 1);

        final stopwatch = Stopwatch()..start();
        await notifier.refreshFeed(fastReturn: true);
        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThan(200));
        expect(container.read(podcastFeedProvider).episodes.first.id, 1);

        await Future<void>.delayed(const Duration(milliseconds: 320));
        expect(container.read(podcastFeedProvider).episodes.first.id, 2);
      },
    );
  });
}

PodcastFeedResponse _responseWithEpisodeIds(List<int> episodeIds) {
  return PodcastFeedResponse(
    items: episodeIds.map(_episode).toList(),
    hasMore: false,
    total: episodeIds.length,
  );
}

PodcastEpisodeModel _episode(int id) {
  final now = DateTime(2026, 2, 14, 10);
  return PodcastEpisodeModel(
    id: id,
    subscriptionId: 100 + id,
    title: 'Episode $id',
    audioUrl: 'https://example.com/$id.mp3',
    publishedAt: now,
    createdAt: now,
  );
}

class _FakePodcastRepository extends PodcastRepository {
  _FakePodcastRepository({
    required List<PodcastFeedResponse> responses,
    List<Duration> delays = const <Duration>[],
  }) : _responses = responses,
       _delays = delays,
       super(PodcastApiService(Dio()));

  final List<PodcastFeedResponse> _responses;
  final List<Duration> _delays;
  int getPodcastFeedCalls = 0;

  @override
  Future<PodcastFeedResponse> getPodcastFeed({
    required int page,
    required int pageSize,
    String? cursor,
  }) async {
    final callIndex = getPodcastFeedCalls++;
    if (callIndex < _delays.length) {
      await Future<void>.delayed(_delays[callIndex]);
    }

    if (_responses.isEmpty) {
      return const PodcastFeedResponse(
        items: <PodcastEpisodeModel>[],
        hasMore: false,
        total: 0,
      );
    }

    final responseIndex = callIndex < _responses.length
        ? callIndex
        : _responses.length - 1;
    return _responses[responseIndex];
  }
}

class _AuthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(isAuthenticated: true);
}

class _TrackingDailyReportNotifier extends DailyReportNotifier {
  int loadCalls = 0;

  @override
  FutureOr<PodcastDailyReportResponse?> build() => null;

  @override
  Future<PodcastDailyReportResponse?> load({
    DateTime? date,
    bool forceRefresh = false,
  }) async {
    loadCalls += 1;
    return null;
  }
}

class _TrackingDailyReportDatesNotifier extends DailyReportDatesNotifier {
  int loadCalls = 0;

  @override
  FutureOr<PodcastDailyReportDatesResponse?> build() => null;

  @override
  Future<PodcastDailyReportDatesResponse?> load({
    int page = 1,
    int size = 30,
    bool forceRefresh = false,
  }) async {
    loadCalls += 1;
    return null;
  }
}
