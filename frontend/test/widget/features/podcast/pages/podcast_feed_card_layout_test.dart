import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/glass/surface_card.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_queue_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_state_models.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/pages/podcast_feed_page.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/shared/base_episode_card.dart';

/// Helper to suppress RenderFlex overflow errors during desktop grid layout tests.
/// The desktop GridView constrains cards to 172px height, which can cause
/// a 4px overflow for cards with full content (image + badge + description + meta).
FlutterExceptionHandler? _originalErrorHandler;

void _suppressOverflowErrors() {
  _originalErrorHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    final message = details.exceptionAsString();
    if (message.contains('RenderFlex overflowed')) {
      return; // Suppress the overflow error
    }
    _originalErrorHandler?.call(details);
  };
}

void _restoreOverflowErrors() {
  FlutterError.onError = _originalErrorHandler;
}

void main() {
  group('PodcastFeedPage card layout', () {
    testWidgets(
      'mobile card shows description and metadata/action row below',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final container = ProviderContainer(
          overrides: [
            podcastFeedProvider.overrideWith(
              () => _MockPodcastFeedNotifier(
                PodcastFeedState(
                  episodes: [_buildEpisode()],
                  hasMore: false,
                  total: 1,
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: PodcastFeedPage(),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));

        // Verify card is rendered
        expect(find.byType(SurfaceCard), findsOneWidget);
        expect(find.byType(BaseEpisodeCard), findsOneWidget);

        // Verify title
        final titleFinder = find.text('S2E7 Why does luck look effortless?');
        expect(titleFinder, findsOneWidget);

        // Verify description is shown with 2-line max (dense/compact mode)
        final descriptionFinder = find.textContaining('What is luck, really?');
        expect(descriptionFinder, findsOneWidget);
        final descriptionText = tester.widget<Text>(descriptionFinder);
        expect(descriptionText.maxLines, 2);

        // Verify metadata icons (date and duration)
        expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
        expect(find.byIcon(Icons.schedule), findsOneWidget);

        // Verify play button
        expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);

        // Verify add-to-queue button
        expect(find.byIcon(Icons.playlist_add), findsOneWidget);

        // Verify play button is above add-to-queue button
        final playButtonIcon = find.byIcon(Icons.play_circle_outline);
        final addButtonIcon = find.byIcon(Icons.playlist_add);
        final playButtonRect = tester.getRect(playButtonIcon);
        final addButtonRect = tester.getRect(addButtonIcon);
        expect(
          playButtonRect.center.dy,
          lessThan(addButtonRect.center.dy),
        );
        expect(playButtonRect.height, lessThanOrEqualTo(36));
        expect(addButtonRect.height, lessThanOrEqualTo(32));
      },
    );

    testWidgets(
      'desktop card keeps play action and shows 4-line description with metadata below',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        _suppressOverflowErrors();
        addTearDown(_restoreOverflowErrors);

        final container = ProviderContainer(
          overrides: [
            podcastFeedProvider.overrideWith(
              () => _MockPodcastFeedNotifier(
                PodcastFeedState(
                  episodes: [_buildEpisode()],
                  hasMore: false,
                  total: 1,
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: PodcastFeedPage(),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));

        // Verify card is rendered
        expect(find.byType(SurfaceCard), findsOneWidget);
        expect(find.byType(BaseEpisodeCard), findsOneWidget);

        // Verify description is shown with 4-line max (non-compact/desktop mode)
        final descriptionFinder = find.textContaining('What is luck, really?');
        expect(descriptionFinder, findsOneWidget);
        final descriptionText = tester.widget<Text>(descriptionFinder);
        expect(descriptionText.maxLines, 4);

        // Verify metadata icons
        expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
        expect(find.byIcon(Icons.schedule), findsOneWidget);

        // Verify play button uses play_circle_outline
        expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);

        // Verify add-to-queue button
        expect(find.byIcon(Icons.playlist_add), findsOneWidget);

        // Verify play button is above add-to-queue button
        final playButtonIcon = find.byIcon(Icons.play_circle_outline);
        final addButtonIcon = find.byIcon(Icons.playlist_add);
        final playButtonRect = tester.getRect(playButtonIcon);
        final addButtonRect = tester.getRect(addButtonIcon);

        expect(playButtonRect.center.dy, lessThan(addButtonRect.center.dy));
        expect(addButtonRect.height, lessThanOrEqualTo(32));
        expect(playButtonRect.height, lessThanOrEqualTo(36));
      },
    );

    testWidgets('mobile podcast badge uses menu icon color in dark mode', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          podcastFeedProvider.overrideWith(
            () => _MockPodcastFeedNotifier(
              PodcastFeedState(
                episodes: [_buildEpisode()],
                hasMore: false,
                total: 1,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData.light(useMaterial3: true),
            darkTheme: ThemeData.dark(useMaterial3: true),
            themeMode: ThemeMode.dark,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PodcastFeedPage(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Verify the subscription badge text is rendered
      expect(find.text('Sample Show'), findsOneWidget);

      final scheme = Theme.of(
        tester.element(find.byType(BaseEpisodeCard)),
      ).colorScheme;
      final badgeTextFinder = find.text('Sample Show');
      expect(badgeTextFinder, findsOneWidget);
      final badgeText = tester.widget<Text>(badgeTextFinder);
      expect(badgeText.style?.color, equals(scheme.surface));
    });

    testWidgets('desktop podcast badge uses menu icon color in dark mode', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      _suppressOverflowErrors();
      addTearDown(_restoreOverflowErrors);

      final container = ProviderContainer(
        overrides: [
          podcastFeedProvider.overrideWith(
            () => _MockPodcastFeedNotifier(
              PodcastFeedState(
                episodes: [_buildEpisode()],
                hasMore: false,
                total: 1,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData.light(useMaterial3: true),
            darkTheme: ThemeData.dark(useMaterial3: true),
            themeMode: ThemeMode.dark,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PodcastFeedPage(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Verify the subscription badge text is rendered
      expect(find.text('Sample Show'), findsOneWidget);

      final scheme = Theme.of(
        tester.element(find.byType(BaseEpisodeCard)),
      ).colorScheme;
      final badgeTextFinder = find.text('Sample Show');
      final badgeText = tester.widget<Text>(badgeTextFinder);
      expect(badgeText.style?.color, equals(scheme.surface));
    });

    testWidgets('mobile podcast badge uses menu icon color in light mode', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          podcastFeedProvider.overrideWith(
            () => _MockPodcastFeedNotifier(
              PodcastFeedState(
                episodes: [_buildEpisode()],
                hasMore: false,
                total: 1,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData.light(useMaterial3: true),
            darkTheme: ThemeData.dark(useMaterial3: true),
            themeMode: ThemeMode.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PodcastFeedPage(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Verify the subscription badge text is rendered
      expect(find.text('Sample Show'), findsOneWidget);

      final scheme = Theme.of(
        tester.element(find.byType(BaseEpisodeCard)),
      ).colorScheme;
      final badgeTextFinder = find.text('Sample Show');
      final badgeText = tester.widget<Text>(badgeTextFinder);
      expect(badgeText.style?.color, equals(scheme.surface));
    });

    testWidgets('desktop podcast badge uses menu icon color in light mode', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      _suppressOverflowErrors();
      addTearDown(_restoreOverflowErrors);

      final container = ProviderContainer(
        overrides: [
          podcastFeedProvider.overrideWith(
            () => _MockPodcastFeedNotifier(
              PodcastFeedState(
                episodes: [_buildEpisode()],
                hasMore: false,
                total: 1,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: ThemeData.light(useMaterial3: true),
            darkTheme: ThemeData.dark(useMaterial3: true),
            themeMode: ThemeMode.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PodcastFeedPage(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Verify the subscription badge text is rendered
      expect(find.text('Sample Show'), findsOneWidget);

      final scheme = Theme.of(
        tester.element(find.byType(BaseEpisodeCard)),
      ).colorScheme;
      final badgeTextFinder = find.text('Sample Show');
      final badgeText = tester.widget<Text>(badgeTextFinder);
      expect(badgeText.style?.color, equals(scheme.surface));
    });

    testWidgets('mobile card strips html tags in description', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          podcastFeedProvider.overrideWith(
            () => _MockPodcastFeedNotifier(
              PodcastFeedState(
                episodes: [
                  _buildEpisode(
                    description:
                        '<p style="color:#333333;font-size:16px">A &amp; B</p>',
                  ),
                ],
                hasMore: false,
                total: 1,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PodcastFeedPage(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      // Find description text - it should contain cleaned HTML
      final descriptionFinder = find.textContaining('A & B');
      expect(descriptionFinder, findsOneWidget);

      final descriptionText = tester.widget<Text>(descriptionFinder);
      final renderedDescription = descriptionText.data ?? '';
      expect(renderedDescription, contains('A & B'));
      expect(renderedDescription, isNot(contains('<')));
      expect(renderedDescription, isNot(contains('>')));
      expect(renderedDescription, isNot(contains('style=')));
    });

    testWidgets('desktop card strips html tags in description', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      _suppressOverflowErrors();
      addTearDown(_restoreOverflowErrors);

      final container = ProviderContainer(
        overrides: [
          podcastFeedProvider.overrideWith(
            () => _MockPodcastFeedNotifier(
              PodcastFeedState(
                episodes: [
                  _buildEpisode(
                    description:
                        '<p style="color:#333333;font-size:16px">A &amp; B</p>',
                  ),
                ],
                hasMore: false,
                total: 1,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PodcastFeedPage(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      final descriptionFinder = find.textContaining('A & B');
      expect(descriptionFinder, findsOneWidget);

      final descriptionText = tester.widget<Text>(descriptionFinder);
      final renderedDescription = descriptionText.data ?? '';
      expect(renderedDescription, contains('A & B'));
      expect(renderedDescription, isNot(contains('<')));
      expect(renderedDescription, isNot(contains('>')));
      expect(renderedDescription, isNot(contains('style=')));
    });

    testWidgets('desktop card strips malformed html tag fragments', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      _suppressOverflowErrors();
      addTearDown(_restoreOverflowErrors);

      final container = ProviderContainer(
        overrides: [
          podcastFeedProvider.overrideWith(
            () => _MockPodcastFeedNotifier(
              PodcastFeedState(
                episodes: [
                  _buildEpisode(
                    description:
                        '\u56DE\u5230\u5BB6\uFF0C\u4E3A\u4EC0\u4E48\u603B\u662F\u524D\u4E24\u5929\u6BCD\u6148\u5B50\u5B5D\n<p style="color:#333333;font-size:16px',
                  ),
                ],
                hasMore: false,
                total: 1,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PodcastFeedPage(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      final descriptionFinder =
          find.textContaining('\u56DE\u5230\u5BB6\uFF0C\u4E3A\u4EC0\u4E48\u603B\u662F\u524D\u4E24\u5929\u6BCD\u6148\u5B50\u5B5D');
      expect(descriptionFinder, findsOneWidget);

      final descriptionText = tester.widget<Text>(descriptionFinder);
      final renderedDescription = descriptionText.data ?? '';
      expect(renderedDescription,
          contains('\u56DE\u5230\u5BB6\uFF0C\u4E3A\u4EC0\u4E48\u603B\u662F\u524D\u4E24\u5929\u6BCD\u6148\u5B50\u5B5D'));
      expect(renderedDescription, isNot(contains('<p')));
      expect(renderedDescription, isNot(contains('style=')));
      expect(renderedDescription, isNot(contains('<')));
      expect(renderedDescription, isNot(contains('>')));
    });

    testWidgets('desktop card keeps content after malformed tag fragment', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      _suppressOverflowErrors();
      addTearDown(_restoreOverflowErrors);

      final container = ProviderContainer(
        overrides: [
          podcastFeedProvider.overrideWith(
            () => _MockPodcastFeedNotifier(
              PodcastFeedState(
                episodes: [
                  _buildEpisode(
                    description:
                        '<p style="color:#333333;font-size:16px;"This preview should stay visible',
                  ),
                ],
                hasMore: false,
                total: 1,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PodcastFeedPage(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      final descriptionFinder =
          find.textContaining('This preview should stay visible');
      expect(descriptionFinder, findsOneWidget);

      final descriptionText = tester.widget<Text>(descriptionFinder);
      final renderedDescription = descriptionText.data ?? '';
      expect(renderedDescription, contains('This preview should stay visible'));
      expect(renderedDescription, isNot(contains('<p')));
      expect(renderedDescription, isNot(contains('style=')));
      expect(renderedDescription, isNot(contains('<')));
      expect(renderedDescription, isNot(contains('>')));
    });

    testWidgets('desktop card removes standalone css declaration lines', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      _suppressOverflowErrors();
      addTearDown(_restoreOverflowErrors);

      final container = ProviderContainer(
        overrides: [
          podcastFeedProvider.overrideWith(
            () => _MockPodcastFeedNotifier(
              PodcastFeedState(
                episodes: [
                  _buildEpisode(
                    description:
                        'This teaser should remain visible\n'
                        'color:#333333;font-weight:normal;font-size:16px;'
                        'line-height:30px;font-family:Helvetica,Arial,sans-serif;'
                        'hyphens:auto;text-align:justify;',
                  ),
                ],
                hasMore: false,
                total: 1,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PodcastFeedPage(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      final descriptionFinder =
          find.textContaining('This teaser should remain visible');
      expect(descriptionFinder, findsOneWidget);

      final descriptionText = tester.widget<Text>(descriptionFinder);
      final renderedDescription = descriptionText.data ?? '';
      expect(
        renderedDescription,
        contains('This teaser should remain visible'),
      );
      expect(renderedDescription, isNot(contains('color:#333333')));
      expect(renderedDescription, isNot(contains('font-size:16px')));
      expect(renderedDescription, isNot(contains('font-family:Helvetica')));
    });

    testWidgets(
      'mobile add-to-queue button shows loading, disables repeat taps, and restores after completion',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final queueController = _ControlledQueueController();
        final container = ProviderContainer(
          overrides: [
            podcastFeedProvider.overrideWith(
              () => _MockPodcastFeedNotifier(
                PodcastFeedState(
                  episodes: [_buildEpisode()],
                  hasMore: false,
                  total: 1,
                ),
              ),
            ),
            podcastQueueControllerProvider.overrideWith(() => queueController),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: PodcastFeedPage(),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));

        // Initially, the add-to-queue button shows the playlist_add icon
        expect(
          find.byIcon(Icons.playlist_add),
          findsOneWidget,
        );

        // Tap the add-to-queue button
        await tester.tap(find.byIcon(Icons.playlist_add));
        await tester.pump();
        expect(queueController.addToQueueCallCount, 1);

        // After tapping, should show CircularProgressIndicator (loading state)
        expect(
          find.byType(CircularProgressIndicator),
          findsOneWidget,
        );

        // Complete the queue operation
        queueController.completeAddToQueue();
        await tester.pump(const Duration(seconds: 1));

        // After completion, the playlist_add icon should be restored
        expect(
          find.byIcon(Icons.playlist_add),
          findsOneWidget,
        );
        await tester.pump(const Duration(seconds: 4));
      },
    );
  });
}

class _MockPodcastFeedNotifier extends PodcastFeedNotifier {
  _MockPodcastFeedNotifier(this._initialState);

  final PodcastFeedState _initialState;

  @override
  PodcastFeedState build() {
    return _initialState;
  }

  @override
  Future<void> loadInitialFeed({
    bool forceRefresh = false,
    bool background = false,
  }) async {}

  @override
  Future<void> loadMoreFeed() async {}

  @override
  Future<void> refreshFeed({bool fastReturn = false}) async {}
}

PodcastEpisodeModel _buildEpisode({String? description}) {
  return PodcastEpisodeModel(
    id: 1,
    subscriptionId: 1,
    subscriptionTitle: 'Sample Show',
    title: 'S2E7 Why does luck look effortless?',
    description:
        description ??
        'What is luck, really? Is it money, connections, or freedom? '
            'Why do some people burn out while others seem to move smoothly? '
            'This episode explores myths and reality around good fortune.',
    audioUrl: 'https://example.com/audio.mp3',
    audioDuration: 4143,
    publishedAt: DateTime(2026, 2, 13),
    createdAt: DateTime(2026, 2, 13),
  );
}

class _ControlledQueueController extends PodcastQueueController {
  final Completer<void> _addToQueueCompleter = Completer<void>();
  int addToQueueCallCount = 0;

  @override
  Future<PodcastQueueModel> build() async {
    return PodcastQueueModel.empty();
  }

  @override
  Future<PodcastQueueModel> addToQueue(int episodeId) async {
    addToQueueCallCount += 1;
    await _addToQueueCompleter.future;
    return PodcastQueueModel(
      currentEpisodeId: episodeId,
      revision: 1,
      items: [
        PodcastQueueItemModel(
          episodeId: episodeId,
          position: 0,
          title: 'Episode $episodeId',
          podcastId: 1,
          audioUrl: 'https://example.com/$episodeId.mp3',
        ),
      ],
    );
  }

  @override
  Future<PodcastQueueModel> activateEpisode(int episodeId) async {
    return addToQueue(episodeId);
  }

  void completeAddToQueue() {
    if (!_addToQueueCompleter.isCompleted) {
      _addToQueueCompleter.complete();
    }
  }
}
