import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/core/storage/local_storage_service.dart';
import 'package:personal_ai_assistant/core/widgets/app_shells.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_discover_chart_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_search_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_state_models.dart';
import 'package:personal_ai_assistant/features/podcast/data/services/apple_podcast_rss_service.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/pages/podcast_list_page.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_discover_provider.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_search_provider.dart'
    as search;
import 'package:personal_ai_assistant/features/podcast/presentation/widgets/podcast_image_widget.dart';
import '../../../../helpers/podcast_list_page_helper.dart';

// ---------------------------------------------------------------------------
// Tests merged from:
//   - podcast_list_page_desktop_list_layout_test.dart
//   - podcast_list_page_mobile_card_layout_test.dart
//   - podcast_list_page_layout_stable_dense_test.dart
// ---------------------------------------------------------------------------

void main() {
  // =========================================================================
  // Desktop discover layout  (origin: desktop_list_layout_test.dart)
  // =========================================================================
  group('PodcastListPage desktop discover layout', () {
    testWidgets('renders and allows switching to episodes tab', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(
            MockLocalStorageService(),
          ),
          applePodcastRssServiceProvider.overrideWithValue(
            FakeApplePodcastRssService(
              showsBaseId: 1000,
              episodesBaseId: 2000,
            ),
          ),
          podcastSubscriptionProvider.overrideWith(
            EmptyPodcastSubscriptionNotifier.new,
          ),
          search.podcastSearchProvider.overrideWith(
            () => PassthroughPodcastSearchNotifier(
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

      expect(find.byKey(const Key('podcast_discover_list')), findsOneWidget);
      expect(
        find.byKey(const Key('podcast_discover_category_chips')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('podcast_discover_category_chip_all')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('podcast_discover_category_chip_technology')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('podcast_discover_chart_row_2000')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('podcast_discover_category_chip_technology')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('podcast_discover_chart_row_2000')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('podcast_discover_tab_podcasts')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('podcast_discover_chart_row_1000')),
        findsOneWidget,
      );
    });

    testWidgets(
      'uses menu icon color as selected category background in dark mode',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final container = ProviderContainer(
          overrides: [
            localStorageServiceProvider.overrideWithValue(
              MockLocalStorageService(),
            ),
            applePodcastRssServiceProvider.overrideWithValue(
              FakeApplePodcastRssService(showsBaseId: 1000, episodesBaseId: 2000),
            ),
            podcastSubscriptionProvider.overrideWith(
              EmptyPodcastSubscriptionNotifier.new,
            ),
            search.podcastSearchProvider.overrideWith(
              () => PassthroughPodcastSearchNotifier(
                  const search.PodcastSearchState()),
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
              home: const PodcastListPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final allChipFinder = find.byKey(
          const Key('podcast_discover_category_chip_all'),
        );
        expect(allChipFinder, findsOneWidget);
        final allChip = tester.widget<ChoiceChip>(allChipFinder);
        final context = tester.element(allChipFinder);
        final scheme = Theme.of(context).colorScheme;

        expect(allChip.selected, isTrue);
        expect(allChip.selectedColor, equals(scheme.primary));
      },
    );

    testWidgets(
      'uses menu icon color as selected category background in light mode',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final container = ProviderContainer(
          overrides: [
            localStorageServiceProvider.overrideWithValue(
              MockLocalStorageService(),
            ),
            applePodcastRssServiceProvider.overrideWithValue(
              FakeApplePodcastRssService(showsBaseId: 1000, episodesBaseId: 2000),
            ),
            podcastSubscriptionProvider.overrideWith(
              EmptyPodcastSubscriptionNotifier.new,
            ),
            search.podcastSearchProvider.overrideWith(
              () => PassthroughPodcastSearchNotifier(
                  const search.PodcastSearchState()),
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
              home: const PodcastListPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final allChipFinder = find.byKey(
          const Key('podcast_discover_category_chip_all'),
        );
        expect(allChipFinder, findsOneWidget);
        final allChip = tester.widget<ChoiceChip>(allChipFinder);
        final context = tester.element(allChipFinder);
        final scheme = Theme.of(context).colorScheme;

        expect(allChip.selected, isTrue);
        expect(allChip.selectedColor, equals(scheme.primary));
      },
    );

    testWidgets(
      'uses desktop hero spacing and keeps trending label inset from the right edge',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final container = ProviderContainer(
          overrides: [
            localStorageServiceProvider.overrideWithValue(
              MockLocalStorageService(),
            ),
            applePodcastRssServiceProvider.overrideWithValue(
              FakeApplePodcastRssService(showsBaseId: 1000, episodesBaseId: 2000),
            ),
            podcastSubscriptionProvider.overrideWith(
              EmptyPodcastSubscriptionNotifier.new,
            ),
            search.podcastSearchProvider.overrideWith(
              () => PassthroughPodcastSearchNotifier(
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

        final heroRect = tester.getRect(find.byType(HeroHeader));
        final searchBarRect = tester.getRect(
          find.byKey(const Key('podcast_discover_search_bar')),
        );
        final topChartsRect = tester.getRect(
          find.byKey(const Key('podcast_discover_top_charts')),
        );
        final trendingFinder = find.byKey(
          const Key('podcast_discover_trending_label'),
        );
        final trendingRect = tester.getRect(trendingFinder);
        final trendingText = tester.widget<Text>(trendingFinder);

        final heroSpacing = searchBarRect.top - heroRect.bottom;
        final trendingInset = topChartsRect.right - trendingRect.right;
        expect(heroSpacing, greaterThanOrEqualTo(8));
        expect(heroSpacing, lessThanOrEqualTo(16));
        expect(trendingInset, greaterThanOrEqualTo(8));
        expect(trendingInset, lessThanOrEqualTo(16));
        expect(trendingText.maxLines, 1);
        expect(trendingText.overflow, TextOverflow.ellipsis);
      },
    );
  });

  // =========================================================================
  // Mobile discover list  (origin: mobile_card_layout_test.dart)
  // =========================================================================
  group('PodcastListPage mobile discover list', () {
    testWidgets('keeps top charts header fixed while chart rows scroll', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
          search.podcastSearchProvider.overrideWithValue(
            const search.PodcastSearchState(),
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

      final headerFinder = find.byKey(const Key('podcast_discover_top_charts'));
      final chipsFinder = find.byKey(
        const Key('podcast_discover_category_chips'),
      );
      final listFinder = find.byKey(const Key('podcast_discover_list'));
      final scrollableFinder = find.descendant(
        of: listFinder,
        matching: find.byType(Scrollable),
      );

      final headerTopBefore = tester.getTopLeft(headerFinder).dy;
      final chipsTopBefore = tester.getTopLeft(chipsFinder).dy;
      final scrollPositionBefore =
          tester.state<ScrollableState>(scrollableFinder).position.pixels;

      await tester.fling(listFinder, const Offset(0, -80), 3000);
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(headerFinder).dy, equals(headerTopBefore));
      expect(tester.getTopLeft(chipsFinder).dy, equals(chipsTopBefore));
      expect(
        tester.state<ScrollableState>(scrollableFinder).position.pixels,
        greaterThan(scrollPositionBefore),
      );
    });

    testWidgets(
      'shows rows, filters by category chip, and paginates to 100 while scrolling',
      (tester) async {
        tester.view.physicalSize = const Size(390, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

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
            search.podcastSearchProvider.overrideWithValue(
              const search.PodcastSearchState(),
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

        expect(
          find.byKey(const Key('podcast_discover_chart_row_1000')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('podcast_discover_chart_row_1000')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const Key('podcast_discover_category_chip_technology')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('podcast_discover_chart_row_1001')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('podcast_discover_chart_row_1000')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const Key('podcast_discover_category_chip_all')),
        );
        await tester.pumpAndSettle();

        final listFinder = find.byKey(const Key('podcast_discover_list'));
        for (var index = 0; index < 4; index++) {
          await tester.fling(listFinder, const Offset(0, -1200), 3000);
          await tester.pumpAndSettle();
        }

        expect(
          find.byKey(const Key('podcast_discover_chart_row_1099')),
          findsOneWidget,
        );

        final rankTextFinder = find.byKey(
          const Key('podcast_discover_chart_rank_text_1099'),
        );
        expect(rankTextFinder, findsOneWidget);
        expect(tester.widget<Text>(rankTextFinder).data, equals('100'));

        final rankParagraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: rankTextFinder, matching: find.byType(RichText)),
        );
        expect(rankParagraph.didExceedMaxLines, isFalse);
      },
    );
  });

  // =========================================================================
  // Layout stable / dense  (origin: layout_stable_dense_test.dart)
  // =========================================================================
  group('PodcastListPage layout stable dense', () {
    testWidgets('Discover layout stays dense when subscriptions update', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(
            MockLocalStorageService(),
          ),
          applePodcastRssServiceProvider.overrideWithValue(
            FakeApplePodcastRssService(),
          ),
          podcastSubscriptionProvider.overrideWith(
            DelayedSubscriptionNotifier.new,
          ),
          search.podcastSearchProvider.overrideWithValue(
            const search.PodcastSearchState(),
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

      await tester.pump();
      final tabSelector = find.byKey(const Key('podcast_discover_tab_selector'));
      final searchBar = find.byKey(const Key('podcast_discover_search_bar'));
      expect(tabSelector, findsOneWidget);
      expect(searchBar, findsOneWidget);
      final initialTabHeight = tester.getSize(tabSelector).height;
      final initialSearchHeight = tester.getSize(searchBar).height;
      expect(initialTabHeight, lessThanOrEqualTo(40));
      expect(initialSearchHeight, lessThanOrEqualTo(44));

      await tester.pump(const Duration(milliseconds: 30));
      expect(tester.getSize(tabSelector).height, initialTabHeight);
      expect(tester.getSize(searchBar).height, initialSearchHeight);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Discover uses shared shell and backdrop on short screens', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          localStorageServiceProvider.overrideWithValue(
            MockLocalStorageService(),
          ),
          applePodcastRssServiceProvider.overrideWithValue(
            FakeApplePodcastRssService(),
          ),
          podcastSubscriptionProvider.overrideWith(
            DelayedSubscriptionNotifier.new,
          ),
          search.podcastSearchProvider.overrideWithValue(
            const search.PodcastSearchState(),
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

      expect(find.byType(HeroHeader), findsOneWidget);
      expect(find.text('Discover'), findsOneWidget);
      expect(
        find.byKey(const Key('podcast_discover_country_button')),
        findsOneWidget,
      );
      final viewportClip = tester.widget<ClipRRect>(
        find.byKey(const Key('content_shell_viewport_clip')),
      );
      expect(viewportClip.borderRadius, BorderRadius.circular(14));
    });

    testWidgets(
      'Discover uses profile-style mobile spacing below the hero card',
      (tester) async {
        tester.view.physicalSize = const Size(390, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final container = ProviderContainer(
          overrides: [
            localStorageServiceProvider.overrideWithValue(
              MockLocalStorageService(),
            ),
            applePodcastRssServiceProvider.overrideWithValue(
              FakeApplePodcastRssService(),
            ),
            podcastSubscriptionProvider.overrideWith(
              DelayedSubscriptionNotifier.new,
            ),
            search.podcastSearchProvider.overrideWithValue(
              const search.PodcastSearchState(),
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

        final heroRect = tester.getRect(find.byType(HeroHeader));
        final searchBarRect = tester.getRect(
          find.byKey(const Key('podcast_discover_search_bar')),
        );

        final spacing = searchBarRect.top - heroRect.bottom;
        expect(spacing, greaterThanOrEqualTo(8));
        expect(spacing, lessThanOrEqualTo(24));
      },
    );

    testWidgets('uses dense layout when subscription total is at least 20', (
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
                total: 25,
              ),
            ),
          ),
          applePodcastRssServiceProvider.overrideWithValue(
            FakeApplePodcastRssService(),
          ),
          search.podcastSearchProvider.overrideWithValue(
            const search.PodcastSearchState(),
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

      final rowFinder = find.byKey(
        const Key('podcast_discover_chart_row_1000'),
      );
      expect(rowFinder, findsOneWidget);

      final imageWidget = tester.widget<PodcastImageWidget>(
        find
            .descendant(
              of: rowFinder,
              matching: find.byType(PodcastImageWidget),
            )
            .first,
      );
      expect(imageWidget.width, 56.0);
    });
  });
}
