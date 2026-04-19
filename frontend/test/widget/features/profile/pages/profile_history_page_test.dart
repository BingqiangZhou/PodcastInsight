import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_assistant/core/localization/app_localizations.dart';
import 'package:personal_ai_assistant/features/podcast/data/models/playback_history_lite_model.dart';
import 'package:personal_ai_assistant/features/podcast/presentation/providers/podcast_stats_providers.dart';
import 'package:personal_ai_assistant/features/profile/presentation/pages/profile_history_page.dart';
import 'package:personal_ai_assistant/shared/widgets/loading_widget.dart';

class _FixedPlaybackHistoryLiteNotifier
    extends PlaybackHistoryLiteNotifier {
  _FixedPlaybackHistoryLiteNotifier(this._value);

  final PlaybackHistoryLiteResponse? _value;

  @override
  FutureOr<PlaybackHistoryLiteResponse?> build() => _value;

  @override
  Future<PlaybackHistoryLiteResponse?> load({bool forceRefresh = false}) async {
    state = AsyncValue.data(_value);
    return _value;
  }
}

class _PendingPlaybackHistoryLiteNotifier
    extends PlaybackHistoryLiteNotifier {
  _PendingPlaybackHistoryLiteNotifier(this._pending);

  final Completer<PlaybackHistoryLiteResponse?> _pending;

  @override
  FutureOr<PlaybackHistoryLiteResponse?> build() => _pending.future;

  @override
  Future<PlaybackHistoryLiteResponse?> load({bool forceRefresh = false}) =>
      _pending.future;
}

class _ErrorPlaybackHistoryLiteNotifier
    extends PlaybackHistoryLiteNotifier {
  _ErrorPlaybackHistoryLiteNotifier();

  @override
  FutureOr<PlaybackHistoryLiteResponse?> build() async {
    throw 'Failed to load';
  }

  @override
  Future<PlaybackHistoryLiteResponse?> load({bool forceRefresh = false}) async {
    throw 'Failed to load';
  }
}

void main() {
  group('ProfileHistoryPage Widget Tests', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playbackHistoryLiteProvider.overrideWith(
              () => _FixedPlaybackHistoryLiteNotifier(null),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ProfileHistoryPage()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ProfileHistoryPage), findsOneWidget);
    });

    testWidgets('shows loading state', (tester) async {
      final pending = Completer<PlaybackHistoryLiteResponse?>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playbackHistoryLiteProvider.overrideWith(
              () => _PendingPlaybackHistoryLiteNotifier(pending),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ProfileHistoryPage()),
          ),
        ),
      );

      await tester.pump();

      expect(
          find.byKey(const Key('profile_history_loading_content')),
          findsOneWidget);
      expect(find.byType(LoadingStatusContent), findsOneWidget);

      // Complete the pending future to avoid hanging
      pending.complete(null);
      await tester.pumpAndSettle();
    });

    testWidgets('shows empty state when no history', (tester) async {
      final emptyResponse = PlaybackHistoryLiteResponse(
        episodes: const [],
        total: 0,
        page: 1,
        size: 20,
        pages: 0,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playbackHistoryLiteProvider.overrideWith(
              () => _FixedPlaybackHistoryLiteNotifier(emptyResponse),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ProfileHistoryPage()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final context = tester.element(find.byType(ProfileHistoryPage));
      final l10n = AppLocalizations.of(context)!;

      expect(find.byIcon(Icons.history), findsOneWidget);
      expect(find.text(l10n.server_history_empty), findsOneWidget);
    });

    testWidgets('shows history cards when data is present', (tester) async {
      final response = PlaybackHistoryLiteResponse(
        episodes: [
          PlaybackHistoryLiteItem(
            id: 1,
            subscriptionId: 10,
            title: 'Test Episode',
            imageUrl: 'https://example.com/image.jpg',
            subscriptionTitle: 'Test Podcast',
            subscriptionImageUrl: 'https://example.com/podcast.jpg',
            audioDuration: 3600,
            playbackPosition: 1800,
            lastPlayedAt: DateTime(2026, 4, 19),
            publishedAt: DateTime(2026, 4, 15),
          ),
        ],
        total: 1,
        page: 1,
        size: 20,
        pages: 1,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playbackHistoryLiteProvider.overrideWith(
              () => _FixedPlaybackHistoryLiteNotifier(response),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ProfileHistoryPage()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show episode title
      expect(find.text('Test Episode'), findsOneWidget);
      // Should show podcast subscription name
      expect(find.text('Test Podcast'), findsOneWidget);
      // Should render history card
      expect(
          find.byKey(const ValueKey('history_card_1')), findsOneWidget);
    });

    testWidgets('shows error state with retry button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playbackHistoryLiteProvider.overrideWith(
              () => _ErrorPlaybackHistoryLiteNotifier(),
            ),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ProfileHistoryPage()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final context = tester.element(find.byType(ProfileHistoryPage));
      final l10n = AppLocalizations.of(context)!;

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text(l10n.retry), findsOneWidget);
    });
  });
}
