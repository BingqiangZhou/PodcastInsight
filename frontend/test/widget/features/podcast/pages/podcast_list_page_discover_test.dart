import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/storage/local_storage_service.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/itunes_episode_lookup_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_search_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_state_models.dart';
import 'package:personal_ai_assistant/features/podcast/data/services/apple_podcast_rss_service.dart';
import 'package:personal_ai_assistant/features/podcast/data/services/itunes_search_service.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/pages/podcast_list_page.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_playback_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_search_provider.dart'
    as search;
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/country_selector_dropdown.dart';
import '../../../../helpers/podcast_list_page_helper.dart';

// ---------------------------------------------------------------------------
// Tests merged from:
//   - podcast_list_page_discover_actions_test.dart
//   - podcast_list_page_discover_search_sections_test.dart
//   - podcast_list_page_header_discover_test.dart
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // =========================================================================
  // Discover actions  (origin: discover_actions_test.dart)
  // =========================================================================
  group('PodcastListPage discover actions', () {
    testWidgets('show subscribe button uses lookup and subscribes', (
      tester,
    ) async {
      final fakeLookupService = FakeITunesSearchService();
      final fakeSubscriptionNotifier = FakePodcastSubscriptionNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(
              MockLocalStorageService(),
            ),
            applePodcastRssServiceProvider.overrideWithValue(
              SingleItemFakeApplePodcastRssService(),
            ),
            search.iTunesSearchServiceProvider.overrideWithValue(
              fakeLookupService,
            ),
            podcastSubscriptionProvider.overrideWith(
              () => fakeSubscriptionNotifier,
            ),
            search.podcastSearchProvider.overrideWith(
              () => PassthroughPodcastSearchNotifier(
                  const search.PodcastSearchState()),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PodcastListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('podcast_discover_tab_podcasts')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('podcast_discover_subscribe_111')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 4));

      expect(fakeLookupService.lookupCalled, isTrue);
      expect(
        fakeSubscriptionNotifier.lastAddedFeedUrl,
        'https://example.com/feed.xml',
      );
    });

    testWidgets(
      'podcast row opens episodes info sheet and has no open button',
      (tester) async {
        final fakeLookupService = FakeITunesSearchService();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              localStorageServiceProvider.overrideWithValue(
                MockLocalStorageService(),
              ),
              applePodcastRssServiceProvider.overrideWithValue(
                SingleItemFakeApplePodcastRssService(),
              ),
              search.iTunesSearchServiceProvider.overrideWithValue(
                fakeLookupService,
              ),
              podcastSubscriptionProvider.overrideWith(
                FakePodcastSubscriptionNotifier.new,
              ),
              search.podcastSearchProvider.overrideWith(
                () => PassthroughPodcastSearchNotifier(
                    const search.PodcastSearchState()),
              ),
            ],
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: PodcastListPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('podcast_discover_tab_podcasts')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('podcast_discover_open_111')),
          findsNothing,
        );
        await tester.tap(
          find.byKey(const Key('podcast_discover_chart_row_111')),
        );
        await tester.pumpAndSettle();

        expect(fakeLookupService.lookupEpisodesCalled, isTrue);
        expect(
          find.byKey(const Key('discover_show_episodes_sheet')),
          findsOneWidget,
        );
        expect(find.text('Show Episode Preview'), findsOneWidget);
      },
    );

    testWidgets('episodes support detail sheet and internal play button', (
      tester,
    ) async {
      final audioNotifier = MockAudioPlayerNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWithValue(
              MockLocalStorageService(),
            ),
            applePodcastRssServiceProvider.overrideWithValue(
              SingleItemFakeApplePodcastRssService(),
            ),
            search.iTunesSearchServiceProvider.overrideWithValue(
              FakeITunesSearchService(),
            ),
            podcastSubscriptionProvider.overrideWith(
              FakePodcastSubscriptionNotifier.new,
            ),
            audioPlayerProvider.overrideWith(() => audioNotifier),
            search.podcastSearchProvider.overrideWith(
              () => PassthroughPodcastSearchNotifier(
                  const search.PodcastSearchState()),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: PodcastListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('podcast_discover_open_222')), findsNothing);
      expect(
        find.byKey(const Key('podcast_discover_play_222')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('podcast_discover_chart_row_222')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('discover_episode_detail_sheet')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('discover_episode_detail_play_button')),
      );
      await tester.pumpAndSettle();

      final played = audioNotifier.lastPlayedEpisode;
      expect(played, isNotNull);
      expect(played!.id, 222);
      expect(played.metadata?['discover_preview'], isTrue);
    });
  });

  // =========================================================================
  // Discover search sections  (origin: discover_search_sections_test.dart)
  // =========================================================================
  group('PodcastListPage discover search mode selector', () {
    testWidgets('shows selector and renders podcast results in podcast mode',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(
            MockLocalStorageService(),
          ),
          applePodcastRssServiceProvider.overrideWithValue(
            FakeApplePodcastRssService(),
          ),
          podcastSubscriptionProvider.overrideWith(
            EmptyPodcastSubscriptionNotifier.new,
          ),
          search.podcastSearchProvider.overrideWith(
            () => PassthroughPodcastSearchNotifier(
              const search.PodcastSearchState(
                hasSearched: true,
                searchMode: search.PodcastSearchMode.podcasts,
                podcastResults: [
                  PodcastSearchResult(
                    collectionId: 100,
                    collectionName: 'Test Podcast',
                    artistName: 'Tester',
                    feedUrl: 'https://example.com/feed.xml',
                    artworkUrl100: 'https://example.com/podcast.png',
                    trackCount: 10,
                    primaryGenreName: 'Tech',
                  ),
                ],
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
            home: PodcastListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('podcast_discover_search_results')), findsOneWidget);
      expect(
        find.byKey(const Key('podcast_discover_tab_selector')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('search_https://example.com/feed.xml')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('episode_search_200')), findsNothing);
    });

    testWidgets('shows selector and renders episode results in episode mode',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(
            MockLocalStorageService(),
          ),
          applePodcastRssServiceProvider.overrideWithValue(
            FakeApplePodcastRssService(),
          ),
          podcastSubscriptionProvider.overrideWith(
            EmptyPodcastSubscriptionNotifier.new,
          ),
          search.podcastSearchProvider.overrideWith(
            () => PassthroughPodcastSearchNotifier(
              search.PodcastSearchState(
                hasSearched: true,
                episodeResults: [
                  ITunesPodcastEpisodeResult(
                    trackId: 200,
                    collectionId: 100,
                    trackName: 'Episode 1',
                    collectionName: 'Test Podcast',
                    feedUrl: 'https://example.com/feed.xml',
                    previewUrl: 'https://example.com/ep.mp3',
                    releaseDate: DateTime(2026, 2, 14),
                    trackTimeMillis: 1200000,
                    artworkUrl100: 'https://example.com/ep.png',
                  ),
                ],
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
            home: PodcastListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('podcast_discover_search_results')), findsOneWidget);
      expect(
        find.byKey(const Key('podcast_discover_tab_selector')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('episode_search_200')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('search_https://example.com/feed.xml')),
        findsNothing,
      );
    });
  });

  // =========================================================================
  // Discover header  (origin: header_discover_test.dart)
  // =========================================================================
  group('PodcastListPage discover header', () {
    testWidgets('renders discover structure and sections', (tester) async {
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(
            MockLocalStorageService(),
          ),
          podcastSubscriptionProvider.overrideWith(
            () => TestPodcastSubscriptionNotifier(
              PodcastSubscriptionState(
                subscriptions: [createTestSubscription()],
                hasMore: false,
                total: 1,
              ),
            ),
          ),
          applePodcastRssServiceProvider.overrideWithValue(
            FakeApplePodcastRssService(),
          ),
          search.podcastSearchProvider.overrideWith(
            () => InteractivePodcastSearchNotifier(
                const search.PodcastSearchState()),
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
            home: PodcastListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Discover'), findsOneWidget);
      expect(find.text('Start with a search'), findsNothing);
      expect(find.text('Refine query'), findsNothing);
      expect(find.text('Update query or switch modes.'), findsNothing);
      expect(
        find.byKey(const Key('podcast_discover_country_button')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('podcast_discover_country_button')),
          matching: find.text('CN'),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('podcast_discover_country_button')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CountrySelectorDropdown), findsOneWidget);
      Navigator.of(tester.element(find.byType(CountrySelectorDropdown))).pop();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('podcast_discover_search_bar')),
        findsOneWidget,
      );
      expect(find.byType(HeroHeader), findsOneWidget);
      expect(
        find.byKey(const Key('podcast_discover_search_input')),
        findsOneWidget,
      );
      expect(find.text('Find a show or browse charts.'), findsNothing);
      final searchInputWidget = tester.widget<TextField>(
        find.byKey(const Key('podcast_discover_search_input')),
      );
      final decoration = searchInputWidget.decoration;
      expect(decoration, isNotNull);
      expect(decoration!.border, InputBorder.none);
      expect(decoration.enabledBorder, InputBorder.none);
      expect(decoration.focusedBorder, InputBorder.none);
      expect(decoration.disabledBorder, InputBorder.none);
      expect(decoration.errorBorder, InputBorder.none);
      expect(decoration.focusedErrorBorder, InputBorder.none);
      expect(
        find.byKey(const Key('podcast_discover_tab_selector')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('podcast_discover_tab_podcasts')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('podcast_discover_tab_episodes')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('podcast_discover_top_charts')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('podcast_discover_category_chips')),
        findsOneWidget,
      );
      final chipsTop = tester
          .getTopLeft(find.byKey(const Key('podcast_discover_category_chips')))
          .dy;
      final topChartsTop = tester
          .getTopLeft(find.byKey(const Key('podcast_discover_top_charts')))
          .dy;
      expect(chipsTop, greaterThan(topChartsTop));
      expect(find.byKey(const Key('podcast_discover_see_all')), findsNothing);
      expect(
        find.byKey(const Key('podcast_discover_category_chip_all')),
        findsOneWidget,
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(PodcastListPage)),
      )!;
      expect(find.text(l10n.podcast_discover_browse_by_category), findsNothing);

      expect(find.byKey(const Key('podcast_list_header_title')), findsNothing);
      expect(
        find.byKey(const Key('podcast_list_discover_title')),
        findsNothing,
      );
    });

    testWidgets('search clear button follows controller text changes', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(
            MockLocalStorageService(),
          ),
          podcastSubscriptionProvider.overrideWith(
            () => TestPodcastSubscriptionNotifier(
              PodcastSubscriptionState(
                subscriptions: [createTestSubscription()],
                hasMore: false,
                total: 1,
              ),
            ),
          ),
          applePodcastRssServiceProvider.overrideWithValue(
            FakeApplePodcastRssService(),
          ),
          search.podcastSearchProvider.overrideWith(
            () => InteractivePodcastSearchNotifier(
                const search.PodcastSearchState()),
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
            home: PodcastListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final searchInput = find.byKey(
        const Key('podcast_discover_search_input'),
      );
      final clearButton = find.descendant(
        of: find.byKey(const Key('podcast_discover_search_bar')),
        matching: find.byIcon(Icons.clear),
      );

      expect(clearButton, findsNothing);

      await tester.enterText(searchInput, 'flutter');
      await tester.pump();

      expect(clearButton, findsOneWidget);

      await tester.tap(clearButton);
      await tester.pump();

      final textField = tester.widget<TextField>(searchInput);
      expect(textField.controller?.text, isEmpty);
      expect(clearButton, findsNothing);
    });
  });
}
