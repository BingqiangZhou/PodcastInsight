import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_queue_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_state_models.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/pages/podcast_feed_page.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';

void main() {
  group('PodcastFeedPage card layout', () {
    testWidgets(
      'mobile card shows 2-line description and metadata/action row below',
      (WidgetTester tester) async {
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
                  isLoading: false,
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
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const PodcastFeedPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final descriptionFinder = find.byKey(
          const Key('podcast_feed_mobile_description'),
        );
        final metadataFinder = find.byKey(
          const Key('podcast_feed_mobile_metadata'),
        );
        final addButtonFinder = find.byKey(
          const Key('podcast_feed_mobile_add_to_queue'),
        );
        final playButtonFinder = find.byKey(
          const Key('podcast_feed_mobile_play'),
        );
        final headerRowFinder = find.byKey(
          const Key('podcast_feed_mobile_header_row'),
        );
        final metaActionRowFinder = find.byKey(
          const Key('podcast_feed_mobile_meta_action_row'),
        );
        final coverFinder = find.byKey(const Key('podcast_feed_mobile_cover'));
        final titleFinder = find.text('S2E7 Why does luck look effortless?');

        expect(descriptionFinder, findsOneWidget);
        expect(metadataFinder, findsOneWidget);
        expect(addButtonFinder, findsOneWidget);
        expect(playButtonFinder, findsOneWidget);
        expect(headerRowFinder, findsOneWidget);
        expect(metaActionRowFinder, findsOneWidget);
        expect(coverFinder, findsOneWidget);
        expect(titleFinder, findsOneWidget);
        expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);

        final descriptionText = tester.widget<Text>(descriptionFinder);
        expect(descriptionText.maxLines, 2);
        final titleText = tester.widget<Text>(titleFinder);

        final descriptionRect = tester.getRect(descriptionFinder);
        final metadataRect = tester.getRect(metadataFinder);
        final addButtonRect = tester.getRect(addButtonFinder);
        final playButtonRect = tester.getRect(playButtonFinder);
        final headerRowRect = tester.getRect(headerRowFinder);
        final metaActionRowRect = tester.getRect(metaActionRowFinder);
        final coverRect = tester.getRect(coverFinder);
        final cardRect = tester.getRect(find.byType(Card).first);
        final expectedCoverSize =
            2 *
            ((titleText.style?.fontSize ?? 13) *
                (titleText.style?.height ?? 1.0));

        expect(metadataRect.top, greaterThanOrEqualTo(descriptionRect.bottom));
        expect(addButtonRect.center.dx, greaterThan(metadataRect.center.dx));
        expect(
          playButtonRect.center.dx,
          greaterThanOrEqualTo(metadataRect.center.dx - 1),
        );
        expect(
          playButtonRect.center.dy,
          lessThan(addButtonRect.center.dy),
        );
        expect(
          (playButtonRect.center.dy - metadataRect.center.dy).abs(),
          greaterThan(24),
        );
        expect(addButtonRect.height, lessThanOrEqualTo(32));
        expect(playButtonRect.height, lessThanOrEqualTo(32));
        expect(coverRect.height, closeTo(expectedCoverSize, 0.5));
        expect(coverRect.width, closeTo(expectedCoverSize, 0.5));
        final topGap = headerRowRect.top - cardRect.top;
        final bottomGap = cardRect.bottom - metaActionRowRect.bottom;
        expect(topGap, closeTo(bottomGap, 3));
      },
    );

    testWidgets(
      'desktop card keeps play action and shows 4-line description with metadata below',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final container = ProviderContainer(
          overrides: [
            podcastFeedProvider.overrideWith(
              () => _MockPodcastFeedNotifier(
                PodcastFeedState(
                  episodes: [_buildEpisode()],
                  isLoading: false,
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
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const PodcastFeedPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final descriptionFinder = find.byKey(
          const Key('podcast_feed_desktop_description'),
        );
        final metadataFinder = find.byKey(
          const Key('podcast_feed_desktop_metadata'),
        );
        final addButtonFinder = find.byKey(
          const Key('podcast_feed_desktop_add_to_queue'),
        );
        final playButtonFinder = find.byKey(
          const Key('podcast_feed_desktop_play'),
        );
        final headerRowFinder = find.byKey(
          const Key('podcast_feed_desktop_header_row'),
        );
        final metaActionRowFinder = find.byKey(
          const Key('podcast_feed_desktop_meta_action_row'),
        );

        expect(descriptionFinder, findsOneWidget);
        expect(metadataFinder, findsOneWidget);
        expect(addButtonFinder, findsOneWidget);
        expect(playButtonFinder, findsOneWidget);
        expect(headerRowFinder, findsOneWidget);
        expect(metaActionRowFinder, findsOneWidget);
        expect(find.byIcon(Icons.play_arrow), findsOneWidget);

        final descriptionText = tester.widget<Text>(descriptionFinder);
        expect(descriptionText.maxLines, 4);

        final descriptionRect = tester.getRect(descriptionFinder);
        final metadataRect = tester.getRect(metadataFinder);
        final addButtonRect = tester.getRect(addButtonFinder);
        final playButtonRect = tester.getRect(playButtonFinder);
        final metaActionRowRect = tester.getRect(metaActionRowFinder);
        final playButtonWidget = tester.widget<IconButton>(playButtonFinder);
        final playButtonColor = playButtonWidget.style?.foregroundColor
            ?.resolve(<WidgetState>{});
        final scheme = Theme.of(tester.element(playButtonFinder)).colorScheme;

        expect(metadataRect.top, greaterThanOrEqualTo(descriptionRect.bottom));
        expect(addButtonRect.center.dx, greaterThan(metadataRect.center.dx));
        expect(
          playButtonRect.center.dx,
          greaterThanOrEqualTo(metadataRect.center.dx - 1),
        );
        expect(playButtonRect.center.dy, lessThan(addButtonRect.center.dy));
        expect(addButtonRect.height, lessThanOrEqualTo(32));
        expect(playButtonRect.height, lessThanOrEqualTo(32));
        expect(playButtonColor, equals(scheme.onSurfaceVariant));
        final descriptionToMetaGap =
            metaActionRowRect.top - descriptionRect.bottom;
        expect(descriptionToMetaGap, lessThanOrEqualTo(12));
      },
    );

    testWidgets('mobile podcast badge uses menu icon color in dark mode', (
      WidgetTester tester,
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
                isLoading: false,
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
      await tester.pumpAndSettle();

      final badgeFinder = find.byKey(
        const Key('podcast_feed_mobile_subscription_badge'),
      );
      expect(badgeFinder, findsOneWidget);

      final badge = tester.widget<Container>(badgeFinder);
      final badgeDecoration = badge.decoration! as BoxDecoration;
      final context = tester.element(badgeFinder);
      final scheme = Theme.of(context).colorScheme;
      expect(badgeDecoration.color, equals(scheme.onSurfaceVariant));
    });

    testWidgets('desktop podcast badge uses menu icon color in dark mode', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          podcastFeedProvider.overrideWith(
            () => _MockPodcastFeedNotifier(
              PodcastFeedState(
                episodes: [_buildEpisode()],
                isLoading: false,
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
      await tester.pumpAndSettle();

      final badgeFinder = find.byKey(
        const Key('podcast_feed_desktop_subscription_badge'),
      );
      expect(badgeFinder, findsOneWidget);

      final badge = tester.widget<Container>(badgeFinder);
      final badgeDecoration = badge.decoration! as BoxDecoration;
      final context = tester.element(badgeFinder);
      final scheme = Theme.of(context).colorScheme;
      expect(badgeDecoration.color, equals(scheme.onSurfaceVariant));
    });

    testWidgets('mobile podcast badge uses menu icon color in light mode', (
      WidgetTester tester,
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
                isLoading: false,
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
      await tester.pumpAndSettle();

      final badgeFinder = find.byKey(
        const Key('podcast_feed_mobile_subscription_badge'),
      );
      expect(badgeFinder, findsOneWidget);

      final badge = tester.widget<Container>(badgeFinder);
      final badgeDecoration = badge.decoration! as BoxDecoration;
      final context = tester.element(badgeFinder);
      final scheme = Theme.of(context).colorScheme;
      expect(badgeDecoration.color, equals(scheme.onSurfaceVariant));
    });

    testWidgets('desktop podcast badge uses menu icon color in light mode', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          podcastFeedProvider.overrideWith(
            () => _MockPodcastFeedNotifier(
              PodcastFeedState(
                episodes: [_buildEpisode()],
                isLoading: false,
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
      await tester.pumpAndSettle();

      final badgeFinder = find.byKey(
        const Key('podcast_feed_desktop_subscription_badge'),
      );
      expect(badgeFinder, findsOneWidget);

      final badge = tester.widget<Container>(badgeFinder);
      final badgeDecoration = badge.decoration! as BoxDecoration;
      final context = tester.element(badgeFinder);
      final scheme = Theme.of(context).colorScheme;
      expect(badgeDecoration.color, equals(scheme.onSurfaceVariant));
    });

    testWidgets('mobile card strips html tags in description', (
      WidgetTester tester,
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
                isLoading: false,
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
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PodcastFeedPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final descriptionFinder = find.byKey(
        const Key('podcast_feed_mobile_description'),
      );
      expect(descriptionFinder, findsOneWidget);

      final descriptionText = tester.widget<Text>(descriptionFinder);
      final renderedDescription = descriptionText.data ?? '';
      expect(renderedDescription, contains('A & B'));
      expect(renderedDescription, isNot(contains('<')));
      expect(renderedDescription, isNot(contains('>')));
      expect(renderedDescription, isNot(contains('style=')));
    });

    testWidgets('desktop card strips html tags in description', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
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
                isLoading: false,
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
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PodcastFeedPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final descriptionFinder = find.byKey(
        const Key('podcast_feed_desktop_description'),
      );
      expect(descriptionFinder, findsOneWidget);

      final descriptionText = tester.widget<Text>(descriptionFinder);
      final renderedDescription = descriptionText.data ?? '';
      expect(renderedDescription, contains('A & B'));
      expect(renderedDescription, isNot(contains('<')));
      expect(renderedDescription, isNot(contains('>')));
      expect(renderedDescription, isNot(contains('style=')));
    });

    testWidgets('desktop card strips malformed html tag fragments', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
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
                        '回到家，为什么总是前两天母慈子孝\n<p style="color:#333333;font-size:16px',
                  ),
                ],
                isLoading: false,
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
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PodcastFeedPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final descriptionFinder = find.byKey(
        const Key('podcast_feed_desktop_description'),
      );
      expect(descriptionFinder, findsOneWidget);

      final descriptionText = tester.widget<Text>(descriptionFinder);
      final renderedDescription = descriptionText.data ?? '';
      expect(renderedDescription, contains('回到家，为什么总是前两天母慈子孝'));
      expect(renderedDescription, isNot(contains('<p')));
      expect(renderedDescription, isNot(contains('style=')));
      expect(renderedDescription, isNot(contains('<')));
      expect(renderedDescription, isNot(contains('>')));
    });

    testWidgets('desktop card keeps content after malformed tag fragment', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
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
                        '<p style="color:#333333;font-size:16px;"This preview should stay visible',
                  ),
                ],
                isLoading: false,
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
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PodcastFeedPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final descriptionFinder = find.byKey(
        const Key('podcast_feed_desktop_description'),
      );
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
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
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
                        'This teaser should remain visible\n'
                        'color:#333333;font-weight:normal;font-size:16px;'
                        'line-height:30px;font-family:Helvetica,Arial,sans-serif;'
                        'hyphens:auto;text-align:justify;',
                  ),
                ],
                isLoading: false,
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
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const PodcastFeedPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final descriptionFinder = find.byKey(
        const Key('podcast_feed_desktop_description'),
      );
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
      (WidgetTester tester) async {
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
                  isLoading: false,
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
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const PodcastFeedPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final addButtonFinder = find.byKey(
          const Key('podcast_feed_mobile_add_to_queue'),
        );
        expect(addButtonFinder, findsOneWidget);
        expect(
          find.descendant(
            of: addButtonFinder,
            matching: find.byIcon(Icons.playlist_add),
          ),
          findsOneWidget,
        );

        await tester.tap(addButtonFinder);
        await tester.pump();
        expect(queueController.addToQueueCallCount, 1);
        expect(tester.widget<IconButton>(addButtonFinder).onPressed, isNull);
        expect(
          find.descendant(
            of: addButtonFinder,
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
        );

        queueController.completeAddToQueue();
        await tester.pumpAndSettle();
        expect(tester.widget<IconButton>(addButtonFinder).onPressed, isNotNull);
        expect(
          find.descendant(
            of: addButtonFinder,
            matching: find.byIcon(Icons.playlist_add),
          ),
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
