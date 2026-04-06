import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/audio_player_state_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_state_models.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/pages/podcast_episodes_page.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/podcast_bottom_player_widget.dart';

void main() {
  group('PodcastEpisodesPage global player layout', () {
    testWidgets('mobile keeps episode list above the fixed player', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final audioNotifier = _TestAudioPlayerNotifier(
        AudioPlayerState(currentEpisode: _episode(), duration: 180000),
      );
      final episodesNotifier = _TestPodcastEpisodesNotifier(
        PodcastEpisodesState(episodes: [_episode()], hasMore: false, total: 1),
      );

      await tester.pumpWidget(
        _createWidget(
          audioNotifier: audioNotifier,
          episodesNotifier: episodesNotifier,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      final playerFinder = find.byType(PodcastBottomPlayerWidget);
      expect(playerFinder, findsOneWidget);
      final listFinder = find.byType(ListView);
      final miniPlayerFinder = find.byKey(
        const Key('podcast_bottom_player_mini_wrapper'),
      );
      expect(listFinder, findsOneWidget);
      expect(miniPlayerFinder, findsOneWidget);
      expect(
        find.byKey(const Key('podcast_episodes_mobile_bottom_spacer')),
        findsNothing,
      );
      expect(tester.getRect(miniPlayerFinder).height, greaterThan(0));
    });

    testWidgets('mobile seeded expanded state still keeps only embedded dock', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final audioNotifier = _TestAudioPlayerNotifier(
        AudioPlayerState(currentEpisode: _episode(), duration: 180000),
      );
      final episodesNotifier = _TestPodcastEpisodesNotifier(
        PodcastEpisodesState(episodes: [_episode()], hasMore: false, total: 1),
      );

      await tester.pumpWidget(
        _createWidget(
          audioNotifier: audioNotifier,
          episodesNotifier: episodesNotifier,
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(PodcastBottomPlayerWidget), findsOneWidget);
      expect(
        find.byKey(const Key('podcast_bottom_player_expanded')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('podcast_episodes_mobile_bottom_spacer')),
        findsNothing,
      );
    });

    testWidgets(
      'mobile does not show player when there is no current episode',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final audioNotifier = _TestAudioPlayerNotifier(
          const AudioPlayerState(),
        );
        final episodesNotifier = _TestPodcastEpisodesNotifier(
          const PodcastEpisodesState(hasMore: false),
        );

        await tester.pumpWidget(
          _createWidget(
            audioNotifier: audioNotifier,
            episodesNotifier: episodesNotifier,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(PodcastBottomPlayerWidget), findsNothing);
      },
    );

    testWidgets('switching subscription triggers forced reload once', (
      tester,
    ) async {
      final audioNotifier = _TestAudioPlayerNotifier(const AudioPlayerState());
      final episodesNotifier = _TestPodcastEpisodesNotifier(
        const PodcastEpisodesState(hasMore: false),
      );

      await tester.pumpWidget(
        _createSwitchingWidget(
          audioNotifier: audioNotifier,
          episodesNotifier: episodesNotifier,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('switch_subscription')));
      await tester.pumpAndSettle();

      expect(episodesNotifier.loadCalls.length, 2);
      expect(episodesNotifier.loadCalls.first.subscriptionId, 1);
      expect(episodesNotifier.loadCalls.first.forceRefresh, isFalse);
      expect(episodesNotifier.loadCalls.last.subscriptionId, 2);
      expect(episodesNotifier.loadCalls.last.forceRefresh, isTrue);
    });
  });
}

Widget _createSwitchingWidget({
  required _TestAudioPlayerNotifier audioNotifier,
  required _TestPodcastEpisodesNotifier episodesNotifier,
}) {
  return ProviderScope(
    overrides: [
      audioPlayerProvider.overrideWith(() => audioNotifier),
      podcastEpisodesProvider.overrideWith(() => episodesNotifier),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: PodcastPlayerLayoutFrame(child: _SubscriptionSwitchHarness()),
    ),
  );
}

Widget _createWidget({
  required _TestAudioPlayerNotifier audioNotifier,
  required _TestPodcastEpisodesNotifier episodesNotifier,
  int subscriptionId = 1,
}) {
  return ProviderScope(
    overrides: [
      audioPlayerProvider.overrideWith(() => audioNotifier),
      podcastEpisodesProvider.overrideWith(() => episodesNotifier),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: PodcastPlayerLayoutFrame(
        child: PodcastEpisodesPage(
          subscriptionId: subscriptionId,
          podcastTitle: 'Demo',
        ),
      ),
    ),
  );
}

class _SubscriptionSwitchHarness extends StatefulWidget {
  const _SubscriptionSwitchHarness();

  @override
  State<_SubscriptionSwitchHarness> createState() =>
      _SubscriptionSwitchHarnessState();
}

class _SubscriptionSwitchHarnessState
    extends State<_SubscriptionSwitchHarness> {
  int _subscriptionId = 1;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextButton(
          key: const Key('switch_subscription'),
          onPressed: () {
            setState(() {
              _subscriptionId = 2;
            });
          },
          child: const Text('Switch'),
        ),
        Expanded(
          child: PodcastEpisodesPage(
            subscriptionId: _subscriptionId,
            podcastTitle: 'Demo',
          ),
        ),
      ],
    );
  }
}

class _TestAudioPlayerNotifier extends AudioPlayerNotifier {
  _TestAudioPlayerNotifier(this._initialState);

  final AudioPlayerState _initialState;

  @override
  AudioPlayerState build() {
    return _initialState;
  }
}

class _TestPodcastEpisodesNotifier extends PodcastEpisodesNotifier {
  _TestPodcastEpisodesNotifier(this._initialState);

  final PodcastEpisodesState _initialState;
  final List<_LoadEpisodesCall> loadCalls = [];

  @override
  PodcastEpisodesState build() {
    return _initialState;
  }

  @override
  Future<void> loadEpisodesForSubscription({
    required int subscriptionId,
    int page = 1,
    int size = 20,
    String? status,
    bool? hasSummary,
    bool forceRefresh = false,
  }) async {
    loadCalls.add(
      _LoadEpisodesCall(
        subscriptionId: subscriptionId,
        forceRefresh: forceRefresh,
      ),
    );
  }

  @override
  Future<void> loadMoreEpisodesForSubscription({
    required int subscriptionId,
    String? status,
    bool? hasSummary,
  }) async {}

  @override
  Future<void> refreshEpisodesForSubscription({
    required int subscriptionId,
    String? status,
    bool? hasSummary,
  }) async {}
}

class _LoadEpisodesCall {
  const _LoadEpisodesCall({
    required this.subscriptionId,
    required this.forceRefresh,
  });

  final int subscriptionId;
  final bool forceRefresh;
}

PodcastEpisodeModel _episode() {
  final now = DateTime.now();
  return PodcastEpisodeModel(
    id: 1,
    subscriptionId: 1,
    title: 'Test Episode',
    description: 'Description',
    audioUrl: 'https://example.com/audio.mp3',
    publishedAt: now,
    createdAt: now,
  );
}
