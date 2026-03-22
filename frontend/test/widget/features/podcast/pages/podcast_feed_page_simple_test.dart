import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/features/auth/presentation/providers/auth_provider.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_episode_model.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_state_models.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/pages/podcast_feed_page.dart';
import 'package:personal_ai_assistant/core/widgets/custom_adaptive_navigation.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_providers.dart';

class _TestPodcastFeedNotifier extends PodcastFeedNotifier {
  _TestPodcastFeedNotifier(this._initialState);

  final PodcastFeedState _initialState;

  @override
  PodcastFeedState build() => _initialState;

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

class _TestAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(isAuthenticated: false);
}

void main() {
  group('PodcastFeedPage Basic Widget Tests', () {
    Widget wrapWidget(Widget child, {required PodcastFeedState feedState}) {
      return ProviderScope(
        overrides: [
          authProvider.overrideWith(_TestAuthNotifier.new),
          podcastFeedProvider.overrideWith(
            () => _TestPodcastFeedNotifier(feedState),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: child,
        ),
      );
    }

    PodcastFeedState createFeedState() {
      final now = DateTime.now();
      return PodcastFeedState(
        episodes: [
          PodcastEpisodeModel(
            id: 1,
            subscriptionId: 1,
            title: 'The Future of AI in Software Development',
            audioUrl: 'https://example.com/a.mp3',
            publishedAt: now,
            createdAt: now,
            audioDuration: 1800,
          ),
          PodcastEpisodeModel(
            id: 2,
            subscriptionId: 1,
            title: 'Building Scalable Microservices',
            audioUrl: 'https://example.com/b.mp3',
            publishedAt: now,
            createdAt: now,
            audioDuration: 2400,
          ),
          PodcastEpisodeModel(
            id: 3,
            subscriptionId: 2,
            title: 'The Psychology of Product Design',
            audioUrl: 'https://example.com/c.mp3',
            publishedAt: now,
            createdAt: now,
            audioDuration: 1500,
          ),
        ],
        hasMore: false,
        total: 3,
      );
    }

    testWidgets('renders with localized page title and page structure', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapWidget(const PodcastFeedPage(), feedState: createFeedState()),
      );

      final l10n = AppLocalizations.of(
        tester.element(find.byType(PodcastFeedPage)),
      )!;
      expect(find.text(l10n.podcast_feed_page_title), findsOneWidget);

      expect(find.byType(PodcastFeedPage), findsOneWidget);
      expect(find.byType(ResponsiveContainer), findsOneWidget);
      final viewportClip = tester.widget<ClipRRect>(
        find.byKey(const Key('content_shell_viewport_clip')),
      );
      expect(viewportClip.borderRadius, BorderRadius.circular(16));
    });

    testWidgets('displays mock data on mobile screen', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        wrapWidget(const PodcastFeedPage(), feedState: createFeedState()),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('The Future of AI in Software Development'),
        findsOneWidget,
      );
      expect(find.text('Building Scalable Microservices'), findsOneWidget);
      expect(find.text('The Psychology of Product Design'), findsOneWidget);

      expect(find.byType(Card), findsWidgets);
    });

    testWidgets('displays mock data on desktop screen', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        wrapWidget(const PodcastFeedPage(), feedState: createFeedState()),
      );

      await tester.pumpAndSettle();

      expect(
        find.text('The Future of AI in Software Development'),
        findsOneWidget,
      );
      expect(find.text('Building Scalable Microservices'), findsOneWidget);

      expect(find.byType(Card), findsWidgets);
    });

    testWidgets('has no overflow errors on small screens', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        wrapWidget(const PodcastFeedPage(), feedState: createFeedState()),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      expect(find.byType(Card), findsWidgets);
    });

    testWidgets('cards contain play buttons', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        wrapWidget(const PodcastFeedPage(), feedState: createFeedState()),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.play_arrow), findsWidgets);
    });

    testWidgets('cards contain metadata icons', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        wrapWidget(const PodcastFeedPage(), feedState: createFeedState()),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.calendar_today_outlined), findsWidgets);
      expect(find.byIcon(Icons.schedule), findsWidgets);
    });
  });
}
