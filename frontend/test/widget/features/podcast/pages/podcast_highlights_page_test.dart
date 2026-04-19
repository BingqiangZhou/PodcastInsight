import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/features/auth/presentation/providers/auth_provider.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/podcast_highlight_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/pages/podcast_highlights_page.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_highlights_providers.dart';

// ---------------------------------------------------------------------------
// Fakes & helpers (top-level — Dart does not allow classes inside functions)
// ---------------------------------------------------------------------------

class FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(isAuthenticated: true);
}

class FakeSelectedHighlightDateNotifier
    extends SelectedHighlightDateNotifier {
  @override
  DateTime? build() => null;

  @override
  void setDate(DateTime? value) {}
}

class FakeHighlightsNotifier extends HighlightsNotifier {
  FakeHighlightsNotifier(this._value, [this._completer]);
  final AsyncValue<HighlightsListResponse?> _value;
  final Completer<HighlightsListResponse?>? _completer;

  @override
  Future<HighlightsListResponse?> build() {
    if (_completer != null) return _completer!.future;
    return _value.when(
      data: (d) => Future.value(d),
      loading: () => Future.value(null),
      error: (e, st) => Future.error(e, st),
    );
  }

  @override
  Future<HighlightsListResponse?> load({
    DateTime? date,
    int page = 1,
    int? perPage,
    bool forceRefresh = false,
  }) async =>
      _value.asData?.value;

  @override
  Future<void> toggleFavorite(int highlightId) async {}

  @override
  Future<void> loadNextPage({DateTime? date}) async {}
}

class FakeHighlightDatesNotifier extends HighlightDatesNotifier {
  FakeHighlightDatesNotifier(this._value);
  final AsyncValue<HighlightDatesResponse?> _value;

  @override
  Future<HighlightDatesResponse?> build() => _value.when(
        data: (d) => Future.value(d),
        loading: () => Future.value(null),
        error: (e, st) => Future.error(e, st),
      );

  @override
  Future<HighlightDatesResponse?> load({bool forceRefresh = false}) async =>
      _value.asData?.value;

  @override
  Future<void> ensureMonthCoverage(DateTime date) async {}
}

HighlightResponse createTestHighlight({
  int id = 1,
  int episodeId = 100,
  String episodeTitle = 'Test Episode',
  String originalText = 'This is a highlight text.',
}) {
  return HighlightResponse(
    id: id,
    episodeId: episodeId,
    episodeTitle: episodeTitle,
    originalText: originalText,
    insightScore: 0.9,
    noveltyScore: 0.8,
    actionabilityScore: 0.7,
    overallScore: 0.85,
    createdAt: DateTime(2026, 4, 19),
  );
}

HighlightsListResponse createTestHighlightsResponse({
  List<HighlightResponse>? items,
  int total = 1,
  int page = 1,
  int size = 20,
  int pages = 1,
}) {
  return HighlightsListResponse(
    items: items ?? [createTestHighlight()],
    total: total,
    page: page,
    size: size,
    pages: pages,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PodcastHighlightsPage', () {
    testWidgets('renders without crashing (smoke test)', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(FakeAuthNotifier.new),
          selectedHighlightDateProvider
              .overrideWith(FakeSelectedHighlightDateNotifier.new),
          highlightsProvider.overrideWith(
            () => FakeHighlightsNotifier(
              AsyncValue<HighlightsListResponse?>.data(
                createTestHighlightsResponse(),
              ),
            ),
          ),
          highlightDatesProvider.overrideWith(
            () => FakeHighlightDatesNotifier(
              AsyncValue<HighlightDatesResponse?>.data(
                HighlightDatesResponse(dates: []),
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
            home: PodcastHighlightsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PodcastHighlightsPage), findsOneWidget);
      expect(find.byKey(const Key('highlights_page')), findsOneWidget);
    });

    testWidgets('shows loading state when highlights are loading',
        (tester) async {
      // Use a Completer that is never completed so the AsyncNotifier stays
      // in the loading state indefinitely during the test.
      final loadingCompleter =
          Completer<HighlightsListResponse?>();

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(FakeAuthNotifier.new),
          selectedHighlightDateProvider
              .overrideWith(FakeSelectedHighlightDateNotifier.new),
          highlightsProvider.overrideWith(
            () => FakeHighlightsNotifier(
              const AsyncValue<HighlightsListResponse?>.loading(),
              loadingCompleter,
            ),
          ),
          highlightDatesProvider.overrideWith(
            () => FakeHighlightDatesNotifier(
              AsyncValue<HighlightDatesResponse?>.data(
                HighlightDatesResponse(dates: []),
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
            home: PodcastHighlightsPage(),
          ),
        ),
      );
      // Pump once to let providers resolve; do NOT pumpAndSettle because
      // the loading notifier's build() returns a never-completing future.
      await tester.pump();

      // The loading state shows a LoadingStatusContent widget with the key
      expect(
        find.byKey(const Key('highlights_loading_content')),
        findsOneWidget,
      );
    });

    testWidgets('shows empty state when no highlights exist', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(FakeAuthNotifier.new),
          selectedHighlightDateProvider
              .overrideWith(FakeSelectedHighlightDateNotifier.new),
          highlightsProvider.overrideWith(
            () => FakeHighlightsNotifier(
              AsyncValue<HighlightsListResponse?>.data(
                createTestHighlightsResponse(items: [], total: 0),
              ),
            ),
          ),
          highlightDatesProvider.overrideWith(
            () => FakeHighlightDatesNotifier(
              AsyncValue<HighlightDatesResponse?>.data(
                HighlightDatesResponse(dates: []),
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
            home: PodcastHighlightsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Empty state shows the "No highlights yet" text
      expect(find.text('No highlights yet'), findsOneWidget);
    });

    testWidgets('shows highlight items when data is available',
        (tester) async {
      final highlights = [
        createTestHighlight(id: 1, episodeTitle: 'Episode A'),
        createTestHighlight(id: 2, episodeTitle: 'Episode B'),
      ];
      final response = createTestHighlightsResponse(
        items: highlights,
        total: 2,
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(FakeAuthNotifier.new),
          selectedHighlightDateProvider
              .overrideWith(FakeSelectedHighlightDateNotifier.new),
          highlightsProvider.overrideWith(
            () => FakeHighlightsNotifier(
              AsyncValue<HighlightsListResponse?>.data(response),
            ),
          ),
          highlightDatesProvider.overrideWith(
            () => FakeHighlightDatesNotifier(
              AsyncValue<HighlightDatesResponse?>.data(
                HighlightDatesResponse(dates: []),
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
            home: PodcastHighlightsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Each highlight card is keyed by 'highlight_{id}'
      expect(find.byKey(const Key('highlight_1')), findsOneWidget);
      expect(find.byKey(const Key('highlight_2')), findsOneWidget);
    });

    testWidgets('calendar menu button exists and is tappable',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(FakeAuthNotifier.new),
          selectedHighlightDateProvider
              .overrideWith(FakeSelectedHighlightDateNotifier.new),
          highlightsProvider.overrideWith(
            () => FakeHighlightsNotifier(
              AsyncValue<HighlightsListResponse?>.data(
                createTestHighlightsResponse(),
              ),
            ),
          ),
          highlightDatesProvider.overrideWith(
            () => FakeHighlightDatesNotifier(
              AsyncValue<HighlightDatesResponse?>.data(
                HighlightDatesResponse(dates: []),
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
            home: PodcastHighlightsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The calendar button should be visible in the app bar
      final calendarButton =
          find.byKey(const Key('highlights_calendar_menu_button'));
      expect(calendarButton, findsOneWidget);

      // Tapping it opens the calendar panel dialog
      await tester.tap(calendarButton);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('highlights_calendar_panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('highlights_calendar')),
        findsOneWidget,
      );
    });
  });
}
